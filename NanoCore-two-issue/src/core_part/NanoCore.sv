/*************************************************************/
//  Module name: NanoCore
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/28
//  Function outline: risc-v core (riscv32im)
/*************************************************************/

`timescale 1 ns / 1 ps

import NanoCore_pkg::*;

module NanoCore #(
  parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
  parameter [ 0:0] TWO_CYCLE_ALU = 0,
  parameter [ 0:0] CATCH_MISALIGN = 1,
  parameter [ 0:0] CATCH_ILLINSN = 1,
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [31:0] PROGADDR_IRQ = 32'b0
) (
  input                 clk, resetn,
  output  reg           trap,
  
  input   wire          data_gnt_i,
  output  wire          data_req_o,
  output  wire          data_we_o,
  output  wire  [31:0]  data_addr_o,
  output  wire  [ 3:0]  data_wstrb_o,
  output  wire  [31:0]  data_wdata_o,
  input   wire          data_ready_ns_i,
  input   wire          data_ready_i,
  input   wire  [31:0]  data_rdata_i,

  input   wire          instr_gnt_i,
  output  wire          instr_req_o,    //* ahead of instr_req_2b_o;
  output  wire  [ 1:0]  instr_req_2b_o,
  output  wire  [31:0]  instr_addr_o,
  input   wire  [ 1:0]  instr_ready_i,
  input   wire  [63:0]  instr_rdata_i,

  input         [31:0]  i_irq,
  output  wire          o_irq_ack,
  output  wire  [4:0]   o_irq_id
);

  wire  [63:0]  count_cycle, count_instr;
  wire  [31:0]  reg_pc_d1, cur_pc_d2, pc_2ex_d2, cur_pc_ex0, cur_pc_ex1;
  wire  [31:0]  alu_op1_2ex0_d2, alu_op2_2ex0_d2,
                alu_op1_2ex1_d2, alu_op2_2ex1_d2,
                alu_op1_2mu_d2, alu_op2_2mu_d2,
                alu_op1_2lsu_d2,alu_op2_2lsu_d2;
  wire  [31:0]  alu_rst_idu, alu_rst_ex0, alu_rst_ex1, alu_rst_lsu, alu_rst_mu;
  wire  [31:0]  branch_pc_d1, branch_pc_d2, 
                branch_pc_ex, branch_pc_ex0, branch_pc_ex1;

  //* iq pointer
  wire  [ 2:0]  iq_prefetch_ptr, iq_rd_ptr;
  //* register file
  reg   [31:0]  cpuregs [0:regfile_size-1];
  //* uop_ctl_idu_d1 used to read register file
  //* uop_ctl_idu sent to executor
  uop_ctl_t uop_ctl_m0_d1, uop_ctl_m0_d2, 
            uop_ctl_m1_d1, uop_ctl_m1_d2,
            uop_ctl_2ex0_d2,uop_ctl_2ex1_d2, 
            uop_ctl_2mu_d2, uop_ctl_2lsu_d2;
  //* used to stall div instr
  wire div_ready;
  
  wire is_branch_d2, is_branch_ex, is_branch_ex0, is_branch_ex1;
  assign is_branch_ex = is_branch_ex0 | is_branch_ex1;
  assign branch_pc_ex = is_branch_ex0? branch_pc_ex0: branch_pc_ex1;
  wire flush = is_branch_d2 | is_branch_ex;
  logic [31:0]  branch_pc;
  always_comb begin
    casez({is_branch_d2,is_branch_ex})
      2'b?1: branch_pc   = branch_pc_ex & ~1;
      2'b10: branch_pc   = branch_pc_d2 & ~1;
      default: branch_pc = '0;
    endcase
  end

  wire                      rf_we_d2, rf_we_ex0, rf_we_ex1, rf_we_lsu, rf_we_mu;
  wire  [regindex_bits-1:0] rf_dst_d2, rf_dst_ex0, rf_dst_ex1, 
                            rf_dst_lsu_ns, rf_dst_lsu, rf_dst_mu;
  reg   [31:0]  cpuregs_rs1_m0,cpuregs_rs2_m0,cpuregs_rs1_m1,cpuregs_rs2_m1;

  //* write rf
  always_ff @(posedge clk) begin
    for(integer i=1; i<32; i=i+1) begin
      cpuregs[i] <= (~is_branch_ex && rf_we_d2 &&     rf_dst_d2 == i)?   alu_rst_idu:
                    (~is_branch_ex && is_branch_d2 && rf_dst_d2 == i)?  (cur_pc_d2 + 4):
                    (~is_branch_ex0 && rf_we_ex0 &&   rf_dst_ex0 == i)?  alu_rst_ex0:
                    (is_branch_ex0 &&                 rf_dst_ex0 == i)? (cur_pc_ex0 + 4):
                    (~is_branch_ex1 && rf_we_ex1 &&   rf_dst_ex1 == i)?  alu_rst_ex1:
                    (is_branch_ex1 &&                 rf_dst_ex1 == i)? (cur_pc_ex1 + 4):
                    (rf_we_lsu &&                     rf_dst_lsu == i)?  alu_rst_lsu:
                    (rf_we_mu &&                      rf_dst_mu == i)?   alu_rst_mu: cpuregs[i];
    end
  end

  //* read rf at d1; {lsu,ex1,ex0}
  wire [1:0][2:0] alu_op_bypass_m0_d1, alu_op_bypass_m1_d1;
  always_comb begin
    cpuregs_rs1_m0 = alu_op_bypass_m0_d1[0][0]? alu_rst_ex0 : 
                     alu_op_bypass_m0_d1[0][1]? alu_rst_ex1 :
                     alu_op_bypass_m0_d1[0][2]? alu_rst_lsu :
                    (uop_ctl_m0_d1.decoded_rs1 ? cpuregs[uop_ctl_m0_d1.decoded_rs1] : 'b0);
    cpuregs_rs2_m0 = alu_op_bypass_m0_d1[1][0]? alu_rst_ex0 : 
                     alu_op_bypass_m0_d1[1][1]? alu_rst_ex1 : 
                     alu_op_bypass_m0_d1[1][2]? alu_rst_lsu :
                    (uop_ctl_m0_d1.decoded_rs2 ? cpuregs[uop_ctl_m0_d1.decoded_rs2] : 'b0);
    cpuregs_rs1_m1 = alu_op_bypass_m1_d1[0][0]? alu_rst_ex0 : 
                     alu_op_bypass_m1_d1[0][1]? alu_rst_ex1 : 
                     alu_op_bypass_m1_d1[0][2]? alu_rst_lsu :
                    (uop_ctl_m1_d1.decoded_rs1 ? cpuregs[uop_ctl_m1_d1.decoded_rs1] : 'b0);
    cpuregs_rs2_m1 = alu_op_bypass_m1_d1[1][0]? alu_rst_ex0 : 
                     alu_op_bypass_m1_d1[1][1]? alu_rst_ex1 :
                     alu_op_bypass_m1_d1[1][2]? alu_rst_lsu :
                    (uop_ctl_m1_d1.decoded_rs2 ? cpuregs[uop_ctl_m1_d1.decoded_rs2] : 'b0);
  end

  always_ff @(posedge clk) begin
    trap <= 'b0;
  end

  //* TODO, to_ex0_v, to_ex1_v
  wire to_ex0_v, to_ex1_v, to_ld_v, to_st_v, to_mu_v;
  //* uid is used to reorder writing rf for testing
  wire  [7:0]   uid_d2, uid_ex0, uid_ex1, uid_mu, uid_lsu,
                uid_2ex0_d2, uid_2ex1_d2, uid_2mu_d2, uid_2lsu_d2;
  //* uid_we_d2 is wren for instr0/1 of ex/mu/lsu
  //* uid_ready_we_d2 is wren for instr0/1 of d2
  wire  [1:0]   uid_we_d2, uid_ready_we_d2;
  //* lsu is not ready
  wire          lsu_stall_idu;

  wire  [31:0]  irq_mask;
  wire  [4:0]   irq_offset;
  irq_calc_offset u_irq_calc_offset (
    .clk              (clk              ),
    .resetn           (resetn           ),
    .irq              (i_irq            ),
    .irq_mask         (irq_mask         ),
    .irq_offset       (irq_offset       )
  );


`ifdef ENABLE_BP
  //* do not update "not jump predictor"
  wire          btb_upd_v_ex, btb_upd_v_ex0, btb_upd_v_ex1;
  btb_update_t  btb_upd_info_ex, btb_upd_info_ex0, btb_upd_info_ex1;
  wire          btb_ctl_m0_v_ifu, btb_ctl_m1_v_ifu;
  btb_ctl_t     btb_ctl_m0_ifu, btb_ctl_m1_ifu, btb_ctl_d2;
  wire          sbp_upd_v_d1;
  sbp_update_t  sbp_upd_d1;
  assign btb_upd_v_ex = btb_upd_v_ex0 | btb_upd_v_ex1;
  assign btb_upd_info_ex = btb_upd_v_ex0? btb_upd_info_ex0: btb_upd_info_ex1;
`endif

  N2_ifu  
  #(
    .CATCH_MISALIGN(CATCH_MISALIGN),
    .PROGADDR_RESET(PROGADDR_RESET)
  ) u_ifu(
    .clk              (clk),
    .resetn           (resetn),

    .flush_i          (flush            ),
    .branch_pc_i      (branch_pc        ),
    .instr_gnt_i      (instr_gnt_i      ),
    .instr_req_o      (instr_req_o      ),
    .instr_req_2b_o   (instr_req_2b_o   ),
    .instr_addr_o     (instr_addr_o     ),
  `ifdef ENABLE_BP  
    .btb_upd_v_i      (btb_upd_v_ex     ),
    .btb_upd_info_i   (btb_upd_info_ex  ),
    .btb_ctl_m0_v_o   (btb_ctl_m0_v_ifu ),
    .btb_ctl_m0_o     (btb_ctl_m0_ifu   ),
    .btb_ctl_m1_v_o   (btb_ctl_m1_v_ifu ),
    .btb_ctl_m1_o     (btb_ctl_m1_ifu   ),
    .sbp_upd_v_i      (sbp_upd_v_d1     ),
    .sbp_upd_i        (sbp_upd_d1       ),
  `endif
    .iq_prefetch_ptr  (iq_prefetch_ptr  ),
    .iq_rd_ptr        (iq_rd_ptr        )
  );

  N2_idu #(
    .CATCH_MISALIGN   (CATCH_MISALIGN   ),
    .CATCH_ILLINSN    (CATCH_ILLINSN    ),
    .PROGADDR_RESET   (PROGADDR_RESET   ),
    .TWO_CYCLE_ALU    (TWO_CYCLE_ALU    ),
    .TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE)
  ) u_idu(
    .clk              (clk),
    .resetn           (resetn),

    .cpuregs_rs1_m0   (cpuregs_rs1_m0   ),
    .cpuregs_rs2_m0   (cpuregs_rs2_m0   ),
    .cpuregs_rs1_m1   (cpuregs_rs1_m1   ),
    .cpuregs_rs2_m1   (cpuregs_rs2_m1   ),
    .rf_we_d2_o       (rf_we_d2         ),
    .rf_dst_d2_o      (rf_dst_d2        ),

    .alu_op1_2ex0_d2_o(alu_op1_2ex0_d2  ),
    .alu_op2_2ex0_d2_o(alu_op2_2ex0_d2  ),
    .alu_op1_2ex1_d2_o(alu_op1_2ex1_d2  ),
    .alu_op2_2ex1_d2_o(alu_op2_2ex1_d2  ),
    .alu_op1_2mu_d2_o (alu_op1_2mu_d2   ),
    .alu_op2_2mu_d2_o (alu_op2_2mu_d2   ),
    .alu_op1_2lsu_d2_o(alu_op1_2lsu_d2  ),
    .alu_op2_2lsu_d2_o(alu_op2_2lsu_d2  ),
    // .alu_op1_d2_o     (alu_op1_idu      ),
    // .alu_op2_d2_o     (alu_op2_idu      ),
    .alu_rst_d2_o     (alu_rst_idu      ),
    .is_branch_d2_o   (is_branch_d2     ),
    .branch_pc_d2_o   (branch_pc_d2     ),
    .uid_we_d2_o      (uid_we_d2        ),
    .uid_d2_o         (uid_d2           ),
    .uid_ready_we_d2_o(uid_ready_we_d2  ),
    .uid_2ex0_d2_o    (uid_2ex0_d2      ),
    .uid_2ex1_d2_o    (uid_2ex1_d2      ),
    .uid_2mu_d2_o     (uid_2mu_d2       ),
    .uid_2lsu_d2_o    (uid_2lsu_d2      ),

    .pc_d2_o          (cur_pc_d2        ),
    .pc_2ex_d2_o      (pc_2ex_d2        ),
    // .pc_d1_o          (reg_pc_d1        ),
    .irq_mask_o       (irq_mask         ),

    .iq_prefetch_ptr  (iq_prefetch_ptr  ),
    .iq_rd_ptr_o      (iq_rd_ptr        ),
    .uop_ctl_m0_d1_o  (uop_ctl_m0_d1    ),
    .uop_ctl_m1_d1_o  (uop_ctl_m1_d1    ),
    .uop_ctl_m0_d2_o  (uop_ctl_m0_d2    ),
    .uop_ctl_m1_d2_o  (uop_ctl_m1_d2    ),
    .uop_ctl_2ex0_d2_o(uop_ctl_2ex0_d2  ),
    .uop_ctl_2ex1_d2_o(uop_ctl_2ex1_d2  ),
    .uop_ctl_2lsu_d2_o(uop_ctl_2lsu_d2  ),
    .uop_ctl_2mu_d2_o (uop_ctl_2mu_d2   ),
    .alu_op_bypass_m0_d1_o(alu_op_bypass_m0_d1),
    .alu_op_bypass_m1_d1_o(alu_op_bypass_m1_d1),
    .instr_ready_i    (instr_ready_i    ),
    .instr_rdata_i    (instr_rdata_i    ),
    .is_branch_ex_i   (is_branch_ex     ),

    .to_ex0_v_o       (to_ex0_v         ),
    .to_ex1_v_o       (to_ex1_v         ),
    .to_ld_v_o        (to_ld_v          ),
    .to_st_v_o        (to_st_v          ),
    .to_mu_v_o        (to_mu_v          ),

    .irq_offset_i     (irq_offset       ),
    .irq_ack_o        (o_irq_ack        ),
    .irq_id_o         (o_irq_id         ),

    .rf_dst_idu_i     (rf_dst_d2        ),
    .rf_we_idu_i      (rf_we_d2 | is_branch_d2    ),
    .rf_dst_ex0_i     (rf_dst_ex0       ),
    .rf_we_ex0_i      (rf_we_ex0 | is_branch_ex0  ),
    .rf_dst_ex1_i     (rf_dst_ex1       ),
    .rf_we_ex1_i      (rf_we_ex1 | is_branch_ex1  ),
    .rf_dst_lsu_ns_i  (rf_dst_lsu_ns    ),
    .rf_dst_lsu_i     (rf_dst_lsu       ),
    .rf_we_lsu_ns_i   (data_ready_ns_i  ),
    .rf_we_lsu_i      (rf_we_lsu        ),
    .rf_dst_mu_i      (rf_dst_mu        ),
    .rf_we_mu_i       (rf_we_mu         ),
    .lsu_finish_i     (data_ready_i     ),
    .mu_finish_i      (div_ready        ),
    .lsu_stall_idu_i  (lsu_stall_idu    ),

  `ifdef ENABLE_BP
    .btb_ctl_m0_v_i   (btb_ctl_m0_v_ifu ),
    .btb_ctl_m0_i     (btb_ctl_m0_ifu   ),
    .btb_ctl_m1_v_i   (btb_ctl_m1_v_ifu ),
    .btb_ctl_m1_i     (btb_ctl_m1_ifu   ),
    .btb_ctl_d2_o     (btb_ctl_d2       ),
    .sbp_upd_v_d1_o   (sbp_upd_v_d1     ),
    .sbp_upd_d1_o     (sbp_upd_d1       ),
  `endif

    .count_cycle_o    (count_cycle      ),
    .count_instr_o    (count_instr      )
  );


N2_exec #(
  .TWO_CYCLE_ALU    (TWO_CYCLE_ALU    ),
  .TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE)
) u_exec0(
  .clk              (clk              ),
  .resetn           (resetn           ),
  .to_ex_v_i        (to_ex0_v         ),
  .uid_d2_i         (uid_2ex0_d2      ),
  .uid_ex_o         (uid_ex0          ),

  .rf_dst_ex_o      (rf_dst_ex0       ),
  .uop_ctl_i        (uop_ctl_2ex0_d2  ),
  .alu_op1_i        (alu_op1_2ex0_d2  ),
  .alu_op2_i        (alu_op2_2ex0_d2  ),
  .alu_rst_ex_o     (alu_rst_ex0      ),
  .rf_we_ex_o       (rf_we_ex0        ),
  .is_branch_ex_o   (is_branch_ex0    ),
  .branch_pc_ex_o   (branch_pc_ex0    ),

`ifdef ENABLE_BP  
  .btb_upd_v_o      (btb_upd_v_ex0    ),
  .btb_upd_info_o   (btb_upd_info_ex0 ),
  .btb_ctl_i        (btb_ctl_d2       ),
`endif

  .cur_pc_d2_i      (pc_2ex_d2        ),
  .cur_pc_ex_o      (cur_pc_ex0       )
);


N2_exec #(
  .TWO_CYCLE_ALU    (TWO_CYCLE_ALU    ),
  .TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE)
) u_exec1(
  .clk              (clk              ),
  .resetn           (resetn           ),
  .to_ex_v_i        (to_ex1_v         ),
  .uid_d2_i         (uid_2ex1_d2      ),
  .uid_ex_o         (uid_ex1          ),

  .rf_dst_ex_o      (rf_dst_ex1       ),
  .uop_ctl_i        (uop_ctl_2ex1_d2  ),
  .alu_op1_i        (alu_op1_2ex1_d2  ),
  .alu_op2_i        (alu_op2_2ex1_d2  ),
  .alu_rst_ex_o     (alu_rst_ex1      ),
  .rf_we_ex_o       (rf_we_ex1        ),
  .is_branch_ex_o   (is_branch_ex1    ),
  .branch_pc_ex_o   (branch_pc_ex1    ),

`ifdef ENABLE_BP  
  .btb_upd_v_o      (btb_upd_v_ex1    ),
  .btb_upd_info_o   (btb_upd_info_ex1 ),
  .btb_ctl_i        (btb_ctl_d2       ),
`endif

  .cur_pc_d2_i      (pc_2ex_d2        ),
  .cur_pc_ex_o      (cur_pc_ex1       )
);

N2_lsu u_lsu(
  .clk              (clk              ),
  .resetn           (resetn           ),
  .to_ld_v_i        (to_ld_v          ),
  .to_st_v_i        (to_st_v          ),
  .uid_d2_i         (uid_2lsu_d2      ),
  .uid_lsu_o        (uid_lsu          ),

  .alu_op1_i        (alu_op1_2lsu_d2  ),
  .alu_op2_i        (alu_op2_2lsu_d2  ),
  .alu_rst_o        (alu_rst_lsu      ),
  .rf_dst_lsu_ns_o  (rf_dst_lsu_ns    ),
  .rf_dst_lsu_o     (rf_dst_lsu       ),
  .uop_ctl_i        (uop_ctl_2lsu_d2  ),
  .data_gnt_i       (data_gnt_i       ),
  .data_req_o       (data_req_o       ),
  .data_we_o        (data_we_o        ),
  .data_addr_o      (data_addr_o      ),
  .data_wstrb_o     (data_wstrb_o     ),
  .data_wdata_o     (data_wdata_o     ),
  .data_ready_i     (data_ready_i     ),
  .data_rdata_i     (data_rdata_i     ),
  
  .rf_we_lsu_o      (rf_we_lsu        ),
  .lsu_stall_idu_o  (lsu_stall_idu    )
);

N2_mu u_mu (
  .clk              (clk              ),
  .resetn           (resetn           ),

  .uop_ctl_i        (uop_ctl_2mu_d2   ),
  .mu_rs1_i         (alu_op1_2mu_d2   ),
  .mu_rs2_i         (alu_op2_2mu_d2   ),
  .div_ready_o      (div_ready        ),

  .mul_div_v        (to_mu_v          ),
  .uid_d2_i         (uid_2mu_d2       ),
  .uid_mu_o         (uid_mu           ),
  .alu_rst_mu_o     (alu_rst_mu       ),
  .rf_dst_mu_o      (rf_dst_mu        ),
  .rf_we_mu_o       (rf_we_mu         )
);



  reg [31:0]  cnt_clk;
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      cnt_clk   <= 32'b0;
    end
    else begin
      cnt_clk   <= 32'd1 + cnt_clk;
    end
  end

  integer out_btb_file, out_btb_file_w_clk, out_file, out_file_w_clk;
  initial begin
    out_btb_file = $fopen("./btb_log.txt","w");
    out_btb_file_w_clk = $fopen("./btb_log_w_clk.txt","w");
    out_file = $fopen("./reg_log.txt","w");
    out_file_w_clk = $fopen("./reg_log_w_clk.txt","w");
  end


  always @(posedge clk) begin
    if(btb_upd_v_ex) begin
      $fwrite(out_btb_file, "%d, %d, %d, %04x, %04x, %01x, %d\n", 
                                      btb_upd_info_ex.update_bht,
                                      btb_upd_info_ex.inc_bht,
                                      btb_upd_info_ex.update_tgt,
                                      btb_upd_info_ex.tgt,
                                      btb_upd_info_ex.pc,
                                      btb_upd_info_ex.entryID,
                                      btb_upd_info_ex.insert_btb);
      $fwrite(out_btb_file_w_clk, "clk:%08x\n",cnt_clk);
    end
    
    // if(rf_we_lsu & |rf_dst_lsu) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_lsu, alu_rst_lsu);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_lsu, alu_rst_lsu, cnt_clk);
    // end
    // if(rf_we_mu & |rf_dst_mu) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_mu, alu_rst_mu);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_mu, alu_rst_mu, cnt_clk);
    // end
    // if(rf_we_ex & |rf_dst_ex) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_ex, alu_rst_ex);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_ex, alu_rst_ex, cnt_clk);
    // end
    // if(is_branch_ex & |rf_dst_ex) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_ex, cur_pc_ex + 4);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_ex, cur_pc_ex + 4, cnt_clk);
    // end
    // if(rf_we_d2 & |rf_dst_d2) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_d2, alu_rst_idu);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_d2, alu_rst_idu, cnt_clk);
    // end
    // if(~is_branch_ex & is_branch_d2 & |rf_dst_d2) begin
    //   $fwrite(out_file, "latched_rd: %08x, data:%08x\n", rf_dst_d2, cur_pc_d2 + 4);
    //   $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", rf_dst_d2, cur_pc_d2 + 4, cnt_clk);
    // end
    // if(cnt_clk == 32'hbd5d) begin
    //   $fclose(out_file);
    // end
  end

  //* for co-sim
  wb_entry_t wb_entry[31:0];
  reg [4:0] wb_entry_wr_ptr, wb_entry_rd_ptr;
  wire [4:0] wb_entry_wr_ptr_nxt = wb_entry_wr_ptr + 1;

  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      for(integer i=0; i<32; i=i+1)
        wb_entry[i].ready <= 1'b0;
      wb_entry_wr_ptr     <= '0;
    end
    else begin
      if(is_branch_ex0) begin
        if(|rf_dst_ex0) begin
          for(integer i=0; i<32; i=i+1) begin
            if(wb_entry[i].uid == uid_ex0) begin
              wb_entry[i].ready     <= 1'b1;
              wb_entry[i].rf_dst    <= rf_dst_ex0;
              wb_entry[i].rf_wdata  <= cur_pc_ex0 + 4;
            end
          end
        end
      end
      else if(is_branch_ex1) begin
        if(|rf_dst_ex1) begin
          for(integer i=0; i<32; i=i+1) begin
            if(wb_entry[i].uid == uid_ex1) begin
              wb_entry[i].ready     <= 1'b1;
              wb_entry[i].rf_dst    <= rf_dst_ex1;
              wb_entry[i].rf_wdata  <= cur_pc_ex1 + 4;
            end
          end
        end
      end
      else begin
        //* write uid at d2;
        if(uid_we_d2 | uid_ready_we_d2) begin
          if(|rf_dst_d2 & uid_ready_we_d2[0]) begin
            wb_entry_wr_ptr         <= wb_entry_wr_ptr + 1;
            for(integer i=0; i<32; i=i+1) begin
              if(i == wb_entry_wr_ptr) begin
                wb_entry[i].ready   <= 1'b1;
                wb_entry[i].rf_dst  <= rf_dst_d2;
                wb_entry[i].rf_wdata<= is_branch_d2? (cur_pc_d2 + 4): alu_rst_idu;
              end
            end
          end
          else if(|rf_dst_d2 & uid_ready_we_d2[1]) begin
            wb_entry_wr_ptr         <= uid_we_d2[0]? wb_entry_wr_ptr + 2: wb_entry_wr_ptr + 1;
            if(uid_we_d2[0] & (|uop_ctl_m0_d2.decoded_rd)) begin
              for(integer i=0; i<32; i=i+1) begin
                if(i == wb_entry_wr_ptr) begin
                  wb_entry[i].ready   <= 1'b0;
                  wb_entry[i].uid     <= uid_d2;
                end
                if(i == wb_entry_wr_ptr_nxt) begin
                  wb_entry[i].ready   <= 1'b1;
                  wb_entry[i].rf_dst  <= rf_dst_d2;
                  wb_entry[i].rf_wdata<= is_branch_d2? (cur_pc_d2 + 4): alu_rst_idu;
                end
              end
            end
            else begin
              for(integer i=0; i<32; i=i+1) begin
                if(i == wb_entry_wr_ptr) begin
                  wb_entry[i].ready   <= 1'b1;
                  wb_entry[i].rf_dst  <= rf_dst_d2;
                  wb_entry[i].rf_wdata<= is_branch_d2? (cur_pc_d2 + 4): alu_rst_idu;
                end
              end
            end
          end
          else if(uid_we_d2 == 2'b01 || uid_we_d2 == 2'b10) begin
            wb_entry_wr_ptr         <= wb_entry_wr_ptr + 1;
            for(integer i=0; i<32; i=i+1)
              if(i == wb_entry_wr_ptr) begin
                wb_entry[i].ready   <= 1'b0;
                wb_entry[i].uid     <= uid_d2;
              end
          end
          else if(uid_we_d2 == 2'b11) begin
            wb_entry_wr_ptr         <= wb_entry_wr_ptr + 2;
            for(integer i=0; i<32; i=i+1) begin
              if(i == wb_entry_wr_ptr_nxt) begin
                wb_entry[i].ready   <= 1'b0;
                wb_entry[i].uid     <= uid_d2+1;
              end
              if(i == wb_entry_wr_ptr) begin
                wb_entry[i].ready   <= 1'b0;
                wb_entry[i].uid     <= uid_d2;
              end
            end
          end
        end
        else begin
          if( (|uid_we_d2) & (|rf_dst_d2)) begin
            if(uid_we_d2 == 2'b01 || uid_we_d2 == 2'b10) begin
              wb_entry_wr_ptr         <= wb_entry_wr_ptr + 1;
              for(integer i=0; i<32; i=i+1) begin
                if(i == wb_entry_wr_ptr) begin
                  wb_entry[i].ready   <= 1'b0;
                  wb_entry[i].uid     <= uid_d2;
                end
              end
            end
            else begin
              wb_entry_wr_ptr         <= wb_entry_wr_ptr + 2;
              for(integer i=0; i<32; i=i+1) begin
                if(i == wb_entry_wr_ptr) begin
                  wb_entry[i].ready   <= 1'b0;
                  wb_entry[i].uid     <= uid_d2;
                end
                else if(i == wb_entry_wr_ptr_nxt) begin
                  wb_entry[i].ready   <= 1'b0;
                  wb_entry[i].uid     <= uid_d2 + 1;
                end
              end
            end
          end
        end
      end

      //* write data
      if(rf_we_lsu & |rf_dst_lsu) begin
        for(integer i=0; i<32; i=i+1) begin
          if(wb_entry[i].uid == uid_lsu) begin
            wb_entry[i].ready     <= 1'b1;
            wb_entry[i].rf_dst    <= rf_dst_lsu;
            wb_entry[i].rf_wdata  <= alu_rst_lsu;
          end
        end
      end
      if(rf_we_mu & |rf_dst_mu) begin
        for(integer i=0; i<32; i=i+1) begin
          if(wb_entry[i].uid == uid_mu) begin
            wb_entry[i].ready     <= 1'b1;
            wb_entry[i].rf_dst    <= rf_dst_mu;
            wb_entry[i].rf_wdata  <= alu_rst_mu;
          end
        end
      end
      if(rf_we_ex0 & |rf_dst_ex0) begin
        for(integer i=0; i<32; i=i+1) begin
          if(wb_entry[i].uid == uid_ex0) begin
            wb_entry[i].ready     <= 1'b1;
            wb_entry[i].rf_dst    <= rf_dst_ex0;
            wb_entry[i].rf_wdata  <= alu_rst_ex0;
          end
        end
      end
      if(rf_we_ex1 & |rf_dst_ex1) begin
        for(integer i=0; i<32; i=i+1) begin
          if(wb_entry[i].uid == uid_ex1) begin
            wb_entry[i].ready     <= 1'b1;
            wb_entry[i].rf_dst    <= rf_dst_ex1;
            wb_entry[i].rf_wdata  <= alu_rst_ex1;
          end
        end
      end
    end
  end

  wire        wb_ready = wb_entry[wb_entry_rd_ptr].ready;
  wire [4:0]  wb_rf_dst = wb_entry[wb_entry_rd_ptr].rf_dst;
  wire [31:0] wb_rf_wdata = wb_entry[wb_entry_rd_ptr].rf_wdata;

  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      wb_entry_rd_ptr     <= '0;
    end
    else begin
      if(wb_entry_rd_ptr != wb_entry_wr_ptr && wb_ready == 1'b1) begin
        wb_entry_rd_ptr   <= wb_entry_rd_ptr + 1;
        $fwrite(out_file, "latched_rd: %08x, data:%08x\n", wb_rf_dst, wb_rf_wdata);
        $fwrite(out_file_w_clk, "latched_rd: %08x, data:%08x, clk:%08x\n", wb_rf_dst, wb_rf_wdata, cnt_clk);
      end
    end
  end

endmodule