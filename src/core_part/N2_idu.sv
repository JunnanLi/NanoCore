/*************************************************************/
//  Module name: N2_idu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/21
//  Function outline: instruction decode unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_idu #(
  parameter [ 0:0] CATCH_MISALIGN = 1,
  parameter [ 0:0] CATCH_ILLINSN = 1,
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [31:0] PROGADDR_IRQ = 32'b0,
  parameter [ 0:0] TWO_CYCLE_ALU = 0,
  parameter [ 0:0] TWO_CYCLE_COMPARE = 0
) (
  input                 clk, resetn,

  input   wire  [31:0]  cpuregs_rs1,  //* read in d1;
  input   wire  [31:0]  cpuregs_rs2,
  output  reg           rf_we_d2_o,
  output  reg   [regindex_bits-1:0] rf_dst_d2_o,
  output  reg   [31:0]  alu_op1_d2_o,
  output  reg   [31:0]  alu_op2_d2_o,
  output  reg   [31:0]  alu_rst_d2_o,
  input   wire          is_branch_ex_i,
  input   wire  [31:0]  branch_pc_i,
  output  reg           is_branch_d2_o,
  output  reg   [31:0]  branch_pc_d2_o,
  
  input   wire  [2:0]   iq_prefetch_ptr,
  output  wire  [2:0]   iq_rd_ptr_o,
  input   wire          instr_ready_i,
  input   wire  [31:0]  instr_rdata_i,
  output  reg           uop_ctl_v_d1_o, 
  output  uop_ctl_t     uop_ctl_d1_o,
  output  reg           uop_ctl_v_d2_o, 
  output  uop_ctl_t     uop_ctl_d2_o,
  output  wire          alu_op1_bypass_o,
  output  wire          alu_op2_bypass_o,

  output  reg   [31:0]  irq_mask_o,
  input   wire  [4:0]   irq_offset_i,
  output  wire  [31:0]  pc_d1_o,
  output  reg   [31:0]  pc_d2_o,
  output  wire          irq_ack_o,
  output  wire  [4:0]   irq_id_o,

  output  wire          to_ex_v_o,
  output  wire          to_ld_v_o,
  output  wire          to_st_v_o,
  output  wire          to_mu_v_o,
  output  reg           uid_we_d2_o,
  output  reg   [7:0]   uid_d2_o,

  input   wire          rf_we_idu_i,
  input   wire          rf_we_ex_i,
  input   wire          rf_we_lsu_i,
  input   wire          rf_we_mu_i,
  input   wire  [regindex_bits-1:0] rf_dst_idu_i,
  input   wire  [regindex_bits-1:0] rf_dst_ex_i,
  input   wire  [regindex_bits-1:0] rf_dst_lsu_i,
  input   wire  [regindex_bits-1:0] rf_dst_mu_i,

  input   wire          lsu_finish_i,
  input   wire          mu_finish_i,
  input   wire          lsu_stall_idu_i,

`ifdef ENABLE_BP
  input   wire          btb_ctl_v_i,
  input   btb_ctl_t     btb_ctl_i,
  output  btb_ctl_t     btb_ctl_d2_o,
  output  wire          sbp_upd_v_d1_o,
  output  sbp_update_t  sbp_upd_d1_o,
`endif

  output  wire  [63:0]  count_instr_o,
  output  wire  [63:0]  count_cycle_o
);
  `ifdef ENABLE_BP
    btb_ctl_t           btb_ctl_d1;
    always_ff @(posedge clk) begin
      btb_ctl_d2_o      <= btb_ctl_d1;
    end
  `endif


  wire is_jal_d1 = uop_ctl_d1_o.instr_jal;
  reg to_ex_v, to_ld_v, to_st_v, to_mu_v;
  //* cancel current inst while meeting flush;
  wire flush = is_branch_d2_o | is_branch_ex_i;
  assign to_ex_v_o = ~flush & to_ex_v;
  assign to_ld_v_o = ~flush & to_ld_v;
  assign to_st_v_o = ~flush & to_st_v;
  assign to_mu_v_o = ~flush & to_mu_v;
  reg irq_ack_d2;
  wire irq_ack_d1;
  assign irq_ack_o = ~is_branch_ex_i & irq_ack_d2;

  reg           irq_processing, irq_processing_delay1;
  wire          irq_processing_d1;
  wire  [31:0]  irq_retPC;
  wire          is_branch_d1_o;
  wire  [31:0]  branch_pc_d1_o;
  wire  [regindex_bits-1:0] rf_dst_d1;
  always_ff @(posedge clk or negedge resetn) begin
    irq_ack_d2          <= irq_ack_d1;
    pc_d2_o             <= pc_d1_o;
    uop_ctl_d2_o        <= uop_ctl_d1_o;
    is_branch_d2_o      <= is_branch_d1_o & ~flush;
    branch_pc_d2_o      <= branch_pc_d1_o;
    rf_we_d2_o          <= '0;
    uop_ctl_v_d2_o      <= uop_ctl_v_d1_o & ~flush & ~is_branch_d1_o & ~is_jal_d1;
    to_ex_v             <= '0;
    to_ld_v             <= '0;
    to_st_v             <= '0;
    to_mu_v             <= '0; 
    irq_processing      <= is_branch_ex_i? irq_processing_delay1:
                            irq_processing_d1? 1'b1: irq_processing;
    irq_processing_delay1<= irq_processing;
    rf_dst_d2_o         <= rf_dst_d1;
    if(!resetn) begin
      irq_mask_o        <= '0;
      irq_processing    <= '0;
      uop_ctl_v_d2_o    <= '0;
      to_ex_v           <= '0;
      to_ld_v           <= '0;
      to_st_v           <= '0;
      to_mu_v           <= '0;
      irq_ack_d2        <= '0;
    end
    else if(uop_ctl_v_d1_o & ~is_branch_d2_o & ~is_branch_d1_o) begin
      alu_op1_d2_o      <= 'bx;
      alu_op2_d2_o      <= 'bx;
      alu_rst_d2_o      <= 'bx;

      (* parallel_case *)
      case (1'b1)
        (CATCH_ILLINSN) && uop_ctl_d1_o.instr_trap: begin
          `debug($display("EBREAK OR UNSUPPORTED INSN AT 0x%08x", pc_d1_o);)
        end
        uop_ctl_d1_o.instr_jal: begin
          rf_we_d2_o        <= 1;
          alu_rst_d2_o      <= pc_d1_o + 4;
        end
        uop_ctl_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
          (* parallel_case, full_case *)
          case (1'b1)
            uop_ctl_d1_o.instr_rdcycle:   alu_rst_d2_o <= count_cycle_o[31:0];
            uop_ctl_d1_o.instr_rdcycleh:  alu_rst_d2_o <= count_cycle_o[63:32];
            uop_ctl_d1_o.instr_rdinstr:   alu_rst_d2_o <= count_instr_o[31:0];
            uop_ctl_d1_o.instr_rdinstrh:  alu_rst_d2_o <= count_instr_o[63:32];
          endcase
          rf_we_d2_o        <= 1;
        end
        uop_ctl_d1_o.is_lui_auipc_jal: begin
          alu_op1_d2_o      <= uop_ctl_d1_o.instr_lui ? 0 : pc_d1_o;
          alu_op2_d2_o      <= uop_ctl_d1_o.decoded_imm;
        end
        uop_ctl_d1_o.instr_retirq: begin
          is_branch_d2_o    <= 'b1;
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_d1_o.decoded_rs1, cpuregs_rs1);)
          branch_pc_d2_o    <= CATCH_MISALIGN ? (irq_retPC & 32'h fffffffe) : irq_retPC;
          irq_processing    <= 1'b0;
        end
        uop_ctl_d1_o.instr_maskirq: begin
          rf_we_d2_o        <= 'b1;
          alu_rst_d2_o      <= irq_mask_o;
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_d1_o.decoded_rs1, cpuregs_rs1);)
          irq_mask_o        <= cpuregs_rs1;
        end
        uop_ctl_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_d1_o.instr_trap: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_d1_o.decoded_rs1, cpuregs_rs1);)
          alu_op1_d2_o      <= cpuregs_rs1;
        end
        uop_ctl_d1_o.is_jalr_addi_slti_sltiu_xori_ori_andi, uop_ctl_d1_o.is_slli_srli_srai: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_d1_o.decoded_rs1, cpuregs_rs1);)
          alu_op1_d2_o      <= cpuregs_rs1;
          alu_op2_d2_o      <= uop_ctl_d1_o.is_slli_srli_srai? uop_ctl_d1_o.decoded_rs2 : uop_ctl_d1_o.decoded_imm;
        end
        default: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_d1_o.decoded_rs1, cpuregs_rs1);)
          `debug($display("LD_RS2: %2d 0x%08x", uop_ctl_d1_o.decoded_rs2, cpuregs_rs2);)
          alu_op1_d2_o      <= cpuregs_rs1;
          alu_op2_d2_o      <= cpuregs_rs2;
        end
      endcase
    
      (* parallel_case *)
      case (1'b1)
        (CATCH_ILLINSN) && uop_ctl_d1_o.instr_trap: begin
          //* TODO
        end
        uop_ctl_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
        uop_ctl_d1_o.instr_retirq,
        uop_ctl_d1_o.instr_maskirq,
        uop_ctl_d1_o.instr_jal: begin
        end
        uop_ctl_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_d1_o.instr_trap: to_ld_v <= 1'b1;
        uop_ctl_d1_o.is_sb_sh_sw:                                     to_st_v <= 1'b1;
        uop_ctl_d1_o.instr_any_div_rem | uop_ctl_d1_o.instr_any_mul:  to_mu_v <= 1'b1;
        default:                                                      to_ex_v <= 1'b1;
      endcase
    end
  end

  //* update scb before write back register
  wire                      rf_we_ex_ns = to_ex_v_o & ~uop_ctl_d2_o.is_beq_bne_blt_bge_bltu_bgeu;
  wire  [regindex_bits-1:0] rf_dst_ex_ns = rf_dst_d2_o;

  uop_ctl_t     uop_ctl_ifu;
  N2_idu_predecode N2_idu_predecode(
    .instr_rdata_i    (instr_rdata_i    ),
    .uop_ctl          (uop_ctl_ifu      )
  );

  N2_idu_decode #(
    .PROGADDR_RESET   (PROGADDR_RESET   ),
    .PROGADDR_IRQ     (PROGADDR_IRQ     )
  ) N2_idu_decode (
    .clk              (clk              ),
    .resetn           (resetn           ),
    .iq_prefetch_ptr  (iq_prefetch_ptr  ),
    .iq_rd_ptr_o      (iq_rd_ptr_o      ),
    .uop_ctl_v_ifu_i  (instr_ready_i    ),
    .uop_ctl_ifu_i    (uop_ctl_ifu      ),
    .uop_ctl_v_d1_o   (uop_ctl_v_d1_o   ),
    .uop_ctl_d1_o     (uop_ctl_d1_o     ),
    .alu_op1_bypass_o (alu_op1_bypass_o ),
    .alu_op2_bypass_o (alu_op2_bypass_o ),
    .flush_i          (flush            ),
    .is_branch_d2_i   (is_branch_d2_o   ),
    .is_branch_ex_i   (is_branch_ex_i   ),

    .branch_pc_i      (branch_pc_i      ),
    .is_branch_d1_o   (is_branch_d1_o   ),
    .rf_dst_d1_o      (rf_dst_d1        ),
    .branch_pc_d1_o   (branch_pc_d1_o   ),
    .irq_processing_i (irq_processing   ),
    .irq_offset_i     (irq_offset_i     ),
    .pc_d1_o          (pc_d1_o          ),
    .irq_retPC_o      (irq_retPC        ),
    .irq_ack_o        (irq_ack_d1       ),
    .irq_id_o         (irq_id_o         ),
    .irq_processing_d1_o (irq_processing_d1 ),

    .rf_dst_idu_i     (rf_dst_idu_i     ),
    .rf_we_idu_i      (rf_we_idu_i      ),
    // .rf_dst_ex_i      (rf_dst_ex_i      ),
    // .rf_we_ex_i       (rf_we_ex_i       ),
    .rf_dst_ex_i      (rf_dst_ex_ns     ),
    .rf_we_ex_i       (rf_we_ex_ns      ),
    .rf_dst_lsu_i     (rf_dst_lsu_i     ),
    .rf_we_lsu_i      (rf_we_lsu_i      ),
    .rf_dst_mu_i      (rf_dst_mu_i      ),
    .rf_we_mu_i       (rf_we_mu_i       ),
    .lsu_finish_i     (lsu_finish_i     ),
    .mu_finish_i      (mu_finish_i      ),
    .lsu_stall_idu_i  (lsu_stall_idu_i  ),

  `ifdef ENABLE_BP
    .btb_ctl_v_i      (btb_ctl_v_i      ),
    .btb_ctl_i        (btb_ctl_i        ),
    .btb_ctl_d1_o     (btb_ctl_d1       ),
    .sbp_upd_v_d1_o   (sbp_upd_v_d1_o   ),
    .sbp_upd_d1_o     (sbp_upd_d1_o     ),
  `endif

    .count_cycle      (count_cycle_o    ),
    .count_instr      (count_instr_o    )
  );


  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      uid_we_d2_o       <= 1'b0;
      uid_d2_o          <= 8'b0;
    end
    else begin
      if(uop_ctl_v_d2_o) begin
        uid_d2_o        <= uid_d2_o + 1;
      end
      uid_we_d2_o       <= 1'b0;
      if(uop_ctl_v_d1_o & ~is_branch_d2_o & ~is_branch_d1_o & ~is_jal_d1) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_d1_o.instr_trap: begin
            //* TODO
          end
          uop_ctl_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
          uop_ctl_d1_o.instr_retirq,
          uop_ctl_d1_o.instr_maskirq: begin
          end
          default: uid_we_d2_o  <= ~uop_ctl_d1_o.is_sb_sh_sw & ~uop_ctl_d1_o.is_beq_bne_blt_bge_bltu_bgeu;
        endcase
      end
    end
  end

endmodule