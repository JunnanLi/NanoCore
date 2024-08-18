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
  input   wire          data_ready_i,
  input   wire  [31:0]  data_rdata_i,

  input   wire          instr_gnt_i,
  output  wire          instr_req_o,
  output  wire  [31:0]  instr_addr_o,
  input   wire          instr_ready_i,
  input   wire  [31:0]  instr_rdata_i,

  input         [31:0]  i_irq,
  output  wire          o_irq_ack,
  output  wire  [4:0]   o_irq_id
);

  wire  [63:0]  count_cycle, count_instr;
  wire  [31:0]  reg_pc_d1, cur_pc_d2, cur_pc_ex;
  wire  [31:0]  alu_op1_idu, alu_op2_idu;
  wire  [31:0]  alu_rst_idu, alu_rst_ex, alu_rst_lsu, alu_rst_mu;
  wire  [31:0]  branch_pc_d1, branch_pc_d2, branch_pc_ex;

  //* iq point
  wire  [ 2:0]  iq_prefetch_ptr, iq_rd_ptr;

  reg   [31:0]  cpuregs [0:regfile_size-1];

  uop_ctl_t uop_ctl_idu_d1, uop_ctl_idu;

  wire div_ready;
  
  wire is_branch_d2, is_branch_ex;
  wire flush = is_branch_d2 | is_branch_ex;
  logic [31:0]  branch_pc;
  always_comb begin
    casez({is_branch_d2,is_branch_ex})
    // casez({is_branch_d1,is_branch_d2,is_branch_ex})
      2'b?1: branch_pc   = branch_pc_ex & ~1;
      2'b10: branch_pc   = branch_pc_d2 & ~1;
      default: branch_pc = '0;
    endcase
  end

  wire                      rf_we_d2, rf_we_ex, rf_we_lsu, rf_we_mu;
  wire  [regindex_bits-1:0] rf_dst_d2, rf_dst_ex, rf_dst_lsu, rf_dst_mu;
  reg   [31:0]  cpuregs_rs1,cpuregs_rs2;

  //* write rf
  always_ff @(posedge clk) begin
    for(integer i=1; i<32; i=i+1) begin
      cpuregs[i] <= (~is_branch_ex && rf_we_d2 &&     rf_dst_d2 == i)?  alu_rst_idu:
                    (~is_branch_ex && is_branch_d2 && rf_dst_d2 == i)? (cur_pc_d2 + 4):
                    (~is_branch_ex && rf_we_ex &&     rf_dst_ex == i)?  alu_rst_ex:
                    (is_branch_ex &&                  rf_dst_ex == i)? (cur_pc_ex + 4):
                    (rf_we_lsu &&                     rf_dst_lsu == i)? alu_rst_lsu:
                    (rf_we_mu &&                      rf_dst_mu == i)?  alu_rst_mu: cpuregs[i];
    end
  end

  //* read rf at d1;
  wire alu_op1_bypass_d1, alu_op2_bypass_d1;
  always_comb begin
    cpuregs_rs1 = alu_op1_bypass_d1? alu_rst_ex : 
                  (uop_ctl_idu_d1.decoded_rs1 ? cpuregs[uop_ctl_idu_d1.decoded_rs1] : 'b0);
    cpuregs_rs2 = alu_op2_bypass_d1? alu_rst_ex : 
                  (uop_ctl_idu_d1.decoded_rs2 ? cpuregs[uop_ctl_idu_d1.decoded_rs2] : 'b0);
  end

  always_ff @(posedge clk) begin
    trap <= 'b0;
  end

  wire to_ex_v, to_ld_v, to_st_v, to_mu_v;
  wire  [7:0]   uid_d2, uid_ex, uid_mu, uid_lsu;
  wire          uid_we_d2;
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
  wire          btb_upd_v_ex;
  btb_update_t  btb_upd_info_ex;
  wire          btb_ctl_v_ifu;
  btb_ctl_t     btb_ctl_ifu, btb_ctl_d2;
  wire          sbp_upd_v_d1;
  sbp_update_t  sbp_upd_d1;
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
    .instr_addr_o     (instr_addr_o     ),
  `ifdef ENABLE_BP  
    .btb_upd_v_i      (btb_upd_v_ex     ),
    .btb_upd_info_i   (btb_upd_info_ex  ),
    .btb_ctl_v_o      (btb_ctl_v_ifu    ),
    .btb_ctl_o        (btb_ctl_ifu      ),
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

    .cpuregs_rs1      (cpuregs_rs1      ),
    .cpuregs_rs2      (cpuregs_rs2      ),
    .rf_we_d2_o       (rf_we_d2         ),
    .rf_dst_d2_o      (rf_dst_d2        ),
    .alu_op1_d2_o     (alu_op1_idu      ),
    .alu_op2_d2_o     (alu_op2_idu      ),
    .alu_rst_d2_o     (alu_rst_idu      ),
    .branch_pc_i      (branch_pc        ),
    .is_branch_d2_o   (is_branch_d2     ),
    .branch_pc_d2_o   (branch_pc_d2     ),
    .uid_we_d2_o      (uid_we_d2        ),
    .uid_d2_o         (uid_d2           ),

    .pc_d2_o          (cur_pc_d2        ),
    .pc_d1_o          (reg_pc_d1        ),
    .irq_mask_o       (irq_mask         ),

    .iq_prefetch_ptr  (iq_prefetch_ptr  ),
    .iq_rd_ptr_o      (iq_rd_ptr        ),
    .uop_ctl_d1_o     (uop_ctl_idu_d1   ),
    .uop_ctl_d2_o     (uop_ctl_idu      ),
    .alu_op1_bypass_o (alu_op1_bypass_d1),
    .alu_op2_bypass_o (alu_op2_bypass_d1),
    .instr_ready_i    (instr_ready_i    ),
    .instr_rdata_i    (instr_rdata_i    ),
    .is_branch_ex_i   (is_branch_ex     ),

    .to_ex_v_o        (to_ex_v          ),
    .to_ld_v_o        (to_ld_v          ),
    .to_st_v_o        (to_st_v          ),
    .to_mu_v_o        (to_mu_v          ),

    .irq_offset_i     (irq_offset       ),
    .irq_ack_o        (o_irq_ack        ),
    .irq_id_o         (o_irq_id         ),

    .rf_dst_idu_i     (rf_dst_d2        ),
    .rf_we_idu_i      (rf_we_d2 | is_branch_d2    ),
    .rf_dst_ex_i      (rf_dst_ex        ),
    .rf_we_ex_i       (rf_we_ex | is_branch_ex    ),
    .rf_dst_lsu_i     (rf_dst_lsu       ),
    .rf_we_lsu_i      (rf_we_lsu        ),
    .rf_dst_mu_i      (rf_dst_mu        ),
    .rf_we_mu_i       (rf_we_mu         ),
    .lsu_finish_i     (data_ready_i     ),
    .mu_finish_i      (div_ready        ),
    .lsu_stall_idu_i  (lsu_stall_idu    ),

  `ifdef ENABLE_BP
    .btb_ctl_v_i      (btb_ctl_v_ifu    ),
    .btb_ctl_i        (btb_ctl_ifu      ),
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
) N2_exec(
  .clk              (clk              ),
  .resetn           (resetn           ),
  .to_ex_v_i        (to_ex_v          ),
  .uid_d2_i         (uid_d2           ),
  .uid_ex_o         (uid_ex           ),

  .rf_dst_idu_i     (rf_dst_d2        ),
  .rf_dst_ex_o      (rf_dst_ex        ),
  .uop_ctl_i        (uop_ctl_idu      ),
  .alu_op1_i        (alu_op1_idu      ),
  .alu_op2_i        (alu_op2_idu      ),
  .alu_rst_ex_o     (alu_rst_ex       ),
  .rf_we_ex_o       (rf_we_ex         ),
  .is_branch_ex_o   (is_branch_ex     ),
  .branch_pc_ex_o   (branch_pc_ex     ),

`ifdef ENABLE_BP  
  .btb_upd_v_o      (btb_upd_v_ex     ),
  .btb_upd_info_o   (btb_upd_info_ex  ),
  .btb_ctl_i        (btb_ctl_d2       ),
`endif

  .cur_pc_d2_i      (cur_pc_d2        ),
  .cur_pc_ex_o      (cur_pc_ex        )
);

N2_lsu N2_lsu(
  .clk              (clk              ),
  .resetn           (resetn           ),
  .to_ld_v_i        (to_ld_v          ),
  .to_st_v_i        (to_st_v          ),
  .uid_d2_i         (uid_d2           ),
  .uid_lsu_o        (uid_lsu          ),

  .alu_op1_i        (alu_op1_idu      ),
  .alu_op2_i        (alu_op2_idu      ),
  .alu_rst_o        (alu_rst_lsu      ),
  .rf_dst_idu_i     (rf_dst_d2        ),
  .rf_dst_lsu_o     (rf_dst_lsu       ),
  .data_gnt_i       (data_gnt_i       ),
  .data_req_o       (data_req_o       ),
  .data_we_o        (data_we_o        ),
  .data_addr_o      (data_addr_o      ),
  .data_wstrb_o     (data_wstrb_o     ),
  .data_wdata_o     (data_wdata_o     ),
  .data_ready_i     (data_ready_i     ),
  .data_rdata_i     (data_rdata_i     ),
  
  .instr_sb_i       (uop_ctl_idu.instr_sb         ),
  .instr_sh_i       (uop_ctl_idu.instr_sh         ),
  .instr_sw_i       (uop_ctl_idu.instr_sw         ),
  .instr_lb_i       (uop_ctl_idu.instr_lb         ),
  .instr_lh_i       (uop_ctl_idu.instr_lh         ),
  .instr_lw_i       (uop_ctl_idu.instr_lw         ),
  .instr_lbu_i      (uop_ctl_idu.instr_lbu        ),
  .instr_lhu_i      (uop_ctl_idu.instr_lhu        ),
  .is_lbu_lhu_lw_i  (uop_ctl_idu.is_lbu_lhu_lw    ),
  .decoded_imm_i    (uop_ctl_idu.decoded_imm      ),
  .rf_we_lsu_o      (rf_we_lsu        ),
  .lsu_stall_idu_o  (lsu_stall_idu    )
);

N2_mu N2_mu (
  .clk              (clk              ),
  .resetn           (resetn           ),

  .mul_op_i         ({uop_ctl_idu.instr_mul, 
                      uop_ctl_idu.instr_mulh, 
                      uop_ctl_idu.instr_mulhsu, 
                      uop_ctl_idu.instr_mulhu}),
  .div_op_i         ({uop_ctl_idu.instr_div, 
                      uop_ctl_idu.instr_divu, 
                      uop_ctl_idu.instr_rem, 
                      uop_ctl_idu.instr_remu}),
  .mu_rs1_i         (alu_op1_idu      ),
  .mu_rs2_i         (alu_op2_idu      ),
  .div_ready_o      (div_ready        ),

  .mul_div_v        (to_mu_v          ),
  .uid_d2_i         (uid_d2           ),
  .uid_mu_o         (uid_mu           ),
  .alu_rst_mu_o     (alu_rst_mu       ),
  .rf_dst_idu_i     (rf_dst_d2        ),
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

  integer out_instr_file, out_instr_file_w_clk, out_file, out_file_w_clk;
  initial begin
    out_instr_file = $fopen("./instr_log.txt","w");
    out_instr_file_w_clk = $fopen("./instr_log_w_clk.txt","w");
    out_file = $fopen("./reg_log.txt","w");
    out_file_w_clk = $fopen("./reg_log_w_clk.txt","w");
  end

  always @(posedge clk) begin
    // if(instr_req_o & instr_gnt_i) begin
    //   $fwrite(out_instr_file, "addr: %08x\n", instr_addr_o);
    //   $fwrite(out_instr_file_w_clk, "addr: %08x, clk:%08x\n", instr_addr_o, cnt_clk);
    // end
    
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

  reg tag;
  always_ff @(posedge clk or negedge resetn) begin
              tag <= ( uid_we_d2 & (|rf_dst_d2));
    if(!resetn) begin
      for(integer i=0; i<32; i=i+1)
        wb_entry[i].ready <= 1'b0;
      wb_entry_wr_ptr     <= '0;
    end
    else begin
      if(is_branch_ex) begin
        if(|rf_dst_ex) begin
          for(integer i=0; i<32; i=i+1) begin
            if(wb_entry[i].uid == uid_ex) begin
              wb_entry[i].ready     <= 1'b1;
              wb_entry[i].rf_dst    <= rf_dst_ex;
              wb_entry[i].rf_wdata  <= cur_pc_ex + 4;
            end
          end
        end
      end
      else begin
        //* write uid at d2;
        if(is_branch_d2 | rf_we_d2) begin
          if(|rf_dst_d2) begin
            wb_entry_wr_ptr         <= wb_entry_wr_ptr + 1;
            for(integer i=0; i<32; i=i+1) begin
              if(i == wb_entry_wr_ptr) begin
                wb_entry[i].ready   <= 1'b1;
                wb_entry[i].rf_dst  <= rf_dst_d2;
                wb_entry[i].rf_wdata<= is_branch_d2? (cur_pc_d2 + 4): alu_rst_idu;
              end
            end
          end
        end
        else begin
          if( uid_we_d2 & (|rf_dst_d2)) begin
            wb_entry_wr_ptr         <= wb_entry_wr_ptr + 1;
            for(integer i=0; i<32; i=i+1) begin
              if(i == wb_entry_wr_ptr) begin
                wb_entry[i].ready   <= 1'b0;
                wb_entry[i].uid     <= uid_d2;
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
      if(rf_we_ex & |rf_dst_ex) begin
        for(integer i=0; i<32; i=i+1) begin
          if(wb_entry[i].uid == uid_ex) begin
            wb_entry[i].ready     <= 1'b1;
            wb_entry[i].rf_dst    <= rf_dst_ex;
            wb_entry[i].rf_wdata  <= alu_rst_ex;
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