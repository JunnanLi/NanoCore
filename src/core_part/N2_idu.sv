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
  parameter [31:0] PROGADDR_IRQ = 32'b0
) (
  input                 clk, resetn,

  input   wire  [31:0]  cpuregs_rs1_m0,  //* read in d1;
  input   wire  [31:0]  cpuregs_rs2_m0,
  input   wire  [31:0]  cpuregs_rs1_m1,
  input   wire  [31:0]  cpuregs_rs2_m1,
  output  reg           rf_we_d2_o,
  output  reg   [regindex_bits-1:0] rf_dst_d2_o,
  output  logic [31:0]  alu_op1_2ex0_d2_o,
  output  logic [31:0]  alu_op2_2ex0_d2_o,
  output  logic [31:0]  alu_op1_2ex1_d2_o,
  output  logic [31:0]  alu_op2_2ex1_d2_o,
  output  logic [31:0]  alu_op1_2mu_d2_o,
  output  logic [31:0]  alu_op2_2mu_d2_o,
  output  logic [31:0]  alu_op1_2lsu_d2_o,
  output  logic [31:0]  alu_op2_2lsu_d2_o,
  output  reg   [31:0]  alu_rst_d2_o,   //* merged (instr0/1)
  input   wire          is_branch_ex_i,
  output  reg           is_branch_d2_o,
  output  reg   [31:0]  branch_pc_d2_o,
  
  input   wire  [ 2:0]  iq_prefetch_ptr,
  output  wire  [ 2:0]  iq_rd_ptr_o,
  input   wire  [ 1:0]  instr_ready_i,
  input   wire  [63:0]  instr_rdata_i,
  output  wire          uop_ctl_m0_v_d1_o, 
  output  uop_ctl_t     uop_ctl_m0_d1_o,
  output  wire          uop_ctl_m1_v_d1_o, 
  output  uop_ctl_t     uop_ctl_m1_d1_o,
  output  reg           uop_ctl_m0_v_d2_o, 
  output  reg           uop_ctl_m1_v_d2_o, 
  output  uop_ctl_t     uop_ctl_2ex0_d2_o,
  output  uop_ctl_t     uop_ctl_2ex1_d2_o,
  output  uop_ctl_t     uop_ctl_2lsu_d2_o,
  output  uop_ctl_t     uop_ctl_2mu_d2_o,
  output  uop_ctl_t     uop_ctl_m0_d2_o,
  output  uop_ctl_t     uop_ctl_m1_d2_o,
  output  wire  [1:0][2:0] alu_op_bypass_m0_d1_o,
  output  wire  [1:0][2:0] alu_op_bypass_m1_d1_o,

  output  reg   [31:0]  irq_mask_o,
  input   wire  [ 4:0]  irq_offset_i,
  output  wire  [31:0]  pc_m0_d1_o,
  output  wire  [31:0]  pc_m1_d1_o,
  output  wire  [31:0]  pc_d2_o,
  output  wire  [31:0]  pc_2ex_d2_o,
  output  reg   [31:0]  pc_m0_d2_o,
  output  reg   [31:0]  pc_m1_d2_o,
  output  wire          irq_ack_o,
  output  wire  [ 4:0]  irq_id_o,

  output  wire          to_ex0_v_o,
  output  wire          to_ex1_v_o,
  output  wire          to_ld_v_o,
  output  wire          to_st_v_o,
  output  wire          to_mu_v_o,
  output  wire  [1:0]   uid_we_d2_o,
  output  wire  [1:0]   uid_ready_we_d2_o,
  output  reg   [7:0]   uid_d2_o,
  output  wire  [7:0]   uid_2ex0_d2_o,
  output  wire  [7:0]   uid_2ex1_d2_o,
  output  wire  [7:0]   uid_2mu_d2_o,
  output  wire  [7:0]   uid_2lsu_d2_o,

  input   wire          rf_we_idu_i,
  input   wire          rf_we_ex0_i,
  input   wire          rf_we_ex1_i,
  input   wire          rf_we_lsu_i,
  input   wire          rf_we_mu_i,
  input   wire          rf_we_lsu_ns_i,
  input   wire  [regindex_bits-1:0] rf_dst_idu_i,
  input   wire  [regindex_bits-1:0] rf_dst_ex0_i,
  input   wire  [regindex_bits-1:0] rf_dst_ex1_i,
  input   wire  [regindex_bits-1:0] rf_dst_lsu_i,
  input   wire  [regindex_bits-1:0] rf_dst_mu_i,
  input   wire  [regindex_bits-1:0] rf_dst_lsu_ns_i,

  input   wire          lsu_finish_i,
  input   wire          mu_finish_i,
  input   wire          lsu_stall_idu_i,

`ifdef ENABLE_BP
  input   wire          btb_ctl_m0_v_i,
  input   btb_ctl_t     btb_ctl_m0_i,
  input   wire          btb_ctl_m1_v_i,
  input   btb_ctl_t     btb_ctl_m1_i,
  output  btb_ctl_t     btb_ctl_d2_o,
  output  wire          btb_upd_v_d1_o,
  output  btb_t         btb_upd_d1_o,
`endif
  input   wire  [31:0]  alu_rst_ex0_i,
  input   wire  [31:0]  alu_rst_ex1_i,
  input   wire  [31:0]  alu_rst_lsu_i,

  output  wire  [63:0]  count_instr_o,
  output  wire  [63:0]  count_cycle_o
);
  `ifdef ENABLE_BP
    btb_ctl_t           btb_ctl_m0_d1, btb_ctl_m1_d1;
    btb_ctl_t           btb_ctl_m0_d2, btb_ctl_m1_d2;
    always_ff @(posedge clk) begin
      btb_ctl_m0_d2     <= btb_ctl_m0_d1;
      btb_ctl_m1_d2     <= btb_ctl_m1_d1;
    end
  `endif

  reg   [31:0]  alu_op1_m0_d2, alu_op2_m0_d2,
                alu_op1_m1_d2, alu_op2_m1_d2;
  reg           ex_sel, mu_sel, lsu_sel;  //* select m0/m1;
  wire  [1:0][2:0] alu_op_bypass_m0_d2, alu_op_bypass_m1_d2;
  //* alu_op
  // assign alu_op1_2ex0_d2_o  = alu_op1_m0_d2;
  // assign alu_op2_2ex0_d2_o  = alu_op2_m0_d2;
  // assign alu_op1_2ex1_d2_o  = alu_op1_m1_d2;
  // assign alu_op2_2ex1_d2_o  = alu_op2_m1_d2;
  // assign alu_op1_2mu_d2_o   = mu_sel?  alu_op1_m1_d2 : alu_op1_m0_d2;
  // assign alu_op2_2mu_d2_o   = mu_sel?  alu_op2_m1_d2 : alu_op2_m0_d2;
  // assign alu_op1_2lsu_d2_o  = lsu_sel? alu_op1_m1_d2 : alu_op1_m0_d2;
  // assign alu_op2_2lsu_d2_o  = lsu_sel? alu_op2_m1_d2 : alu_op2_m0_d2;
always_comb begin
  //* ex0
  (* parallel_case *)
  case(1'b1)
    alu_op_bypass_m0_d2[0][0]: alu_op1_2ex0_d2_o = alu_rst_ex0_i;
    alu_op_bypass_m0_d2[0][1]: alu_op1_2ex0_d2_o = alu_rst_ex1_i;
    alu_op_bypass_m0_d2[0][2]: alu_op1_2ex0_d2_o = alu_rst_lsu_i;
    default:                   alu_op1_2ex0_d2_o = alu_op1_m0_d2;
  endcase
  (* parallel_case *)
  case(1'b1)
    alu_op_bypass_m0_d2[1][0]: alu_op2_2ex0_d2_o = alu_rst_ex0_i;
    alu_op_bypass_m0_d2[1][1]: alu_op2_2ex0_d2_o = alu_rst_ex1_i;
    alu_op_bypass_m0_d2[1][2]: alu_op2_2ex0_d2_o = alu_rst_lsu_i;
    default:                   alu_op2_2ex0_d2_o = alu_op2_m0_d2;
  endcase
  //* ex1
  (* parallel_case *)
  case(1'b1)
    alu_op_bypass_m1_d2[0][0]: alu_op1_2ex1_d2_o = alu_rst_ex0_i;
    alu_op_bypass_m1_d2[0][1]: alu_op1_2ex1_d2_o = alu_rst_ex1_i;
    alu_op_bypass_m1_d2[0][2]: alu_op1_2ex1_d2_o = alu_rst_lsu_i;
    default:                   alu_op1_2ex1_d2_o = alu_op1_m1_d2;
  endcase
  (* parallel_case *)
  case(1'b1)
    alu_op_bypass_m1_d2[1][0]: alu_op2_2ex1_d2_o = alu_rst_ex0_i;
    alu_op_bypass_m1_d2[1][1]: alu_op2_2ex1_d2_o = alu_rst_ex1_i;
    alu_op_bypass_m1_d2[1][2]: alu_op2_2ex1_d2_o = alu_rst_lsu_i;
    default:                   alu_op2_2ex1_d2_o = alu_op2_m1_d2;
  endcase
  //* mu
  (* parallel_case *)
  case(1'b1)
    ~mu_sel & alu_op_bypass_m0_d2[0][0]: alu_op1_2mu_d2_o = alu_rst_ex0_i;
    ~mu_sel & alu_op_bypass_m0_d2[0][1]: alu_op1_2mu_d2_o = alu_rst_ex1_i;
    ~mu_sel & alu_op_bypass_m0_d2[0][2]: alu_op1_2mu_d2_o = alu_rst_lsu_i;
     mu_sel & alu_op_bypass_m1_d2[0][0]: alu_op1_2mu_d2_o = alu_rst_ex0_i;
     mu_sel & alu_op_bypass_m1_d2[0][1]: alu_op1_2mu_d2_o = alu_rst_ex1_i;
     mu_sel & alu_op_bypass_m1_d2[0][2]: alu_op1_2mu_d2_o = alu_rst_lsu_i;
    default:  alu_op1_2mu_d2_o = mu_sel?  alu_op1_m1_d2 : alu_op1_m0_d2;
  endcase
  (* parallel_case *)
  case(1'b1)
    ~mu_sel & alu_op_bypass_m0_d2[1][0]: alu_op2_2mu_d2_o = alu_rst_ex0_i;
    ~mu_sel & alu_op_bypass_m0_d2[1][1]: alu_op2_2mu_d2_o = alu_rst_ex1_i;
    ~mu_sel & alu_op_bypass_m0_d2[1][2]: alu_op2_2mu_d2_o = alu_rst_lsu_i;
     mu_sel & alu_op_bypass_m1_d2[1][0]: alu_op2_2mu_d2_o = alu_rst_ex0_i;
     mu_sel & alu_op_bypass_m1_d2[1][1]: alu_op2_2mu_d2_o = alu_rst_ex1_i;
     mu_sel & alu_op_bypass_m1_d2[1][2]: alu_op2_2mu_d2_o = alu_rst_lsu_i;
    default:  alu_op2_2mu_d2_o = mu_sel?  alu_op2_m1_d2 : alu_op2_m0_d2;
  endcase
  //* lsu
  (* parallel_case *)
  case(1'b1)
    ~lsu_sel & alu_op_bypass_m0_d2[0][0]: alu_op1_2lsu_d2_o = alu_rst_ex0_i;
    ~lsu_sel & alu_op_bypass_m0_d2[0][1]: alu_op1_2lsu_d2_o = alu_rst_ex1_i;
    ~lsu_sel & alu_op_bypass_m0_d2[0][2]: alu_op1_2lsu_d2_o = alu_rst_lsu_i;
     lsu_sel & alu_op_bypass_m1_d2[0][0]: alu_op1_2lsu_d2_o = alu_rst_ex0_i;
     lsu_sel & alu_op_bypass_m1_d2[0][1]: alu_op1_2lsu_d2_o = alu_rst_ex1_i;
     lsu_sel & alu_op_bypass_m1_d2[0][2]: alu_op1_2lsu_d2_o = alu_rst_lsu_i;
    default:  alu_op1_2lsu_d2_o = lsu_sel?  alu_op1_m1_d2 : alu_op1_m0_d2;
  endcase
  (* parallel_case *)
  case(1'b1)
    ~lsu_sel & alu_op_bypass_m0_d2[1][0]: alu_op2_2lsu_d2_o = alu_rst_ex0_i;
    ~lsu_sel & alu_op_bypass_m0_d2[1][1]: alu_op2_2lsu_d2_o = alu_rst_ex1_i;
    ~lsu_sel & alu_op_bypass_m0_d2[1][2]: alu_op2_2lsu_d2_o = alu_rst_lsu_i;
     lsu_sel & alu_op_bypass_m1_d2[1][0]: alu_op2_2lsu_d2_o = alu_rst_ex0_i;
     lsu_sel & alu_op_bypass_m1_d2[1][1]: alu_op2_2lsu_d2_o = alu_rst_ex1_i;
     lsu_sel & alu_op_bypass_m1_d2[1][2]: alu_op2_2lsu_d2_o = alu_rst_lsu_i;
    default:  alu_op2_2lsu_d2_o = lsu_sel?  alu_op2_m1_d2 : alu_op2_m0_d2;
  endcase
end

  //* uop_ctl
  assign uop_ctl_2ex0_d2_o  = uop_ctl_m0_d2_o;
  assign uop_ctl_2ex1_d2_o  = uop_ctl_m1_d2_o;
  assign uop_ctl_2mu_d2_o   = mu_sel?  uop_ctl_m1_d2_o : uop_ctl_m0_d2_o;
  assign uop_ctl_2lsu_d2_o  = lsu_sel? uop_ctl_m1_d2_o : uop_ctl_m0_d2_o;
  assign btb_ctl_d2_o       = ex_sel?  btb_ctl_m1_d2   : btb_ctl_m0_d2;
  assign pc_2ex_d2_o        = ex_sel?  pc_m1_d2_o      : pc_m0_d2_o;

  wire is_jal_m0_d1 = uop_ctl_m0_d1_o.instr_jal;
  wire is_jal_m1_d1 = uop_ctl_m1_d1_o.instr_jal;
  assign pc_d2_o    = uop_ctl_m0_d2_o.instr_jal? pc_m0_d2_o: pc_m1_d2_o;
  reg to_ex0_v, to_ex1_v, to_ld_v, to_st_v, to_mu_v;
  //* cancel current inst while meeting flush;
  wire flush = is_branch_d2_o | is_branch_ex_i;
  assign to_ex0_v_o= ~is_branch_ex_i & to_ex0_v;
  assign to_ex1_v_o= ~is_branch_ex_i & to_ex1_v;
  assign to_ld_v_o = ~is_branch_ex_i & to_ld_v;
  assign to_st_v_o = ~is_branch_ex_i & to_st_v;
  assign to_mu_v_o = ~is_branch_ex_i & to_mu_v;
  reg is_branch_ex_delay;
  //* irq
  wire irq_ack_d1;
  reg  irq_ack_d2;
  assign irq_ack_o = ~is_branch_ex_i & ~is_branch_ex_delay & irq_ack_d2;

  reg           irq_processing, irq_processing_delay1;
  wire          irq_processing_d1;
  wire  [31:0]  irq_retPC;
  wire  [ 1:0]  is_branch_d1_o;
  wire  [31:0]  branch_pc_d1_o;
  wire  [regindex_bits-1:0] rf_dst_d1;
  always_ff @(posedge clk or negedge resetn) begin
    //* d1 to d2
    irq_ack_d2          <= irq_ack_d1;
    pc_m0_d2_o          <= pc_m0_d1_o;
    pc_m1_d2_o          <= pc_m1_d1_o;
    uop_ctl_m0_d2_o     <= uop_ctl_m0_d1_o;
    uop_ctl_m1_d2_o     <= uop_ctl_m1_d1_o;
    uop_ctl_m0_d2_o.waddr <= uop_ctl_m0_d1_o.decoded_imm + cpuregs_rs1_m0;
    uop_ctl_m1_d2_o.waddr <= uop_ctl_m1_d1_o.decoded_imm + cpuregs_rs1_m1;
    is_branch_d2_o      <= (|is_branch_d1_o) & ~flush;
    branch_pc_d2_o      <= branch_pc_d1_o;
    uop_ctl_m0_v_d2_o   <= uop_ctl_m0_v_d1_o & ~flush & ~is_branch_d1_o[0] & ~is_jal_m0_d1;
    uop_ctl_m1_v_d2_o   <= uop_ctl_m1_v_d1_o & ~flush & ~is_branch_d1_o[1] & ~is_jal_m1_d1;
    rf_dst_d2_o         <= (uop_ctl_m1_v_d1_o & uop_ctl_m1_d1_o.instr_jal)? uop_ctl_m1_d1_o.decoded_rd: rf_dst_d1;
    is_branch_ex_delay  <= is_branch_ex_i;
    //* init
    rf_we_d2_o          <= '0;
    to_ex0_v            <= '0;
    to_ex1_v            <= '0;
    to_ld_v             <= '0;
    to_st_v             <= '0;
    to_mu_v             <= '0; 
    ex_sel              <= ~(uop_ctl_m0_d1_o.is_beq_bne_blt_bge_bltu_bgeu | uop_ctl_m0_d1_o.instr_jalr);
    mu_sel              <= '0; 
    lsu_sel             <= '0;
    irq_processing      <= is_branch_ex_i? irq_processing_delay1:
                            irq_processing_d1? 1'b1: irq_processing;
    irq_processing_delay1<= irq_processing;
    if(!resetn) begin
      irq_mask_o        <= '0;
      irq_processing    <= '0;
      uop_ctl_m0_v_d2_o <= '0;
      uop_ctl_m1_v_d2_o <= '0;
      to_ex0_v          <= '0;
      to_ex1_v          <= '0;
      to_ld_v           <= '0;
      to_st_v           <= '0;
      to_mu_v           <= '0;
      irq_ack_d2        <= '0;
    end
    else if(uop_ctl_m0_v_d1_o & ~is_branch_d2_o & ~is_branch_d1_o[0]) begin
      alu_op1_m0_d2     <= 'bx;
      alu_op2_m0_d2     <= 'bx;
      alu_op1_m1_d2     <= 'bx;
      alu_op2_m1_d2     <= 'bx;
      alu_rst_d2_o      <= 'bx;

      (* parallel_case *)
      case (1'b1)
        (CATCH_ILLINSN) && uop_ctl_m0_d1_o.instr_trap: begin
          `debug($display("EBREAK OR UNSUPPORTED INSN AT 0x%08x", pc_m0_d1_o);)
        end
        uop_ctl_m0_d1_o.instr_jal: begin
          rf_we_d2_o        <= 1;
          alu_rst_d2_o      <= pc_m0_d1_o + 4;
        end
        uop_ctl_m0_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
        uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
          (* parallel_case, full_case *)
          case (1'b1)
            uop_ctl_m0_d1_o.instr_rdcycle:   alu_rst_d2_o <= count_cycle_o[31:0];
            uop_ctl_m0_d1_o.instr_rdcycleh:  alu_rst_d2_o <= count_cycle_o[63:32];
            uop_ctl_m0_d1_o.instr_rdinstr:   alu_rst_d2_o <= count_instr_o[31:0];
            uop_ctl_m0_d1_o.instr_rdinstrh:  alu_rst_d2_o <= count_instr_o[63:32];
          endcase
          rf_we_d2_o        <= 1;
        end
        uop_ctl_m0_d1_o.is_lui_auipc_jal: begin
          alu_op1_m0_d2     <= uop_ctl_m0_d1_o.instr_lui ? 0 : pc_m0_d1_o;
          alu_op2_m0_d2     <= uop_ctl_m0_d1_o.decoded_imm;
        end
        uop_ctl_m0_d1_o.instr_retirq: begin
          is_branch_d2_o    <= 'b1;
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs1, cpuregs_rs1_m0);)
          branch_pc_d2_o    <= CATCH_MISALIGN ? (irq_retPC & 32'h fffffffe) : irq_retPC;
          irq_processing    <= 1'b0;
        end
        uop_ctl_m0_d1_o.instr_maskirq: begin
          rf_we_d2_o        <= 'b1;
          alu_rst_d2_o      <= irq_mask_o;
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs1, cpuregs_rs1_m0);)
          irq_mask_o        <= cpuregs_rs1_m0;
        end
        uop_ctl_m0_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_m0_d1_o.instr_trap: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs1, cpuregs_rs1_m0);)
          alu_op1_m0_d2     <= cpuregs_rs1_m0;
        end
        uop_ctl_m0_d1_o.is_jalr_addi_slti_sltiu_xori_ori_andi, uop_ctl_m0_d1_o.is_slli_srli_srai: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs1, cpuregs_rs1_m0);)
          alu_op1_m0_d2     <= cpuregs_rs1_m0;
          alu_op2_m0_d2     <= uop_ctl_m0_d1_o.is_slli_srli_srai? uop_ctl_m0_d1_o.decoded_rs2 : uop_ctl_m0_d1_o.decoded_imm;
        end
        default: begin
          `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs1, cpuregs_rs1_m0);)
          `debug($display("LD_RS2: %2d 0x%08x", uop_ctl_m0_d1_o.decoded_rs2, cpuregs_rs2_m0);)
          alu_op1_m0_d2     <= cpuregs_rs1_m0;
          alu_op2_m0_d2     <= cpuregs_rs2_m0;
        end
      endcase
      //* instr1
      if(uop_ctl_m1_v_d1_o & ~is_branch_d1_o[1]) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_m1_d1_o.instr_trap: begin
            `debug($display("EBREAK OR UNSUPPORTED INSN AT 0x%08x", pc_m1_d1_o);)
          end
          uop_ctl_m1_d1_o.instr_jal: begin
            rf_we_d2_o        <= 1;
            alu_rst_d2_o      <= pc_m1_d1_o + 4;
            rf_dst_d2_o       <= uop_ctl_m1_d1_o.decoded_rd;
          end
          uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
            (* parallel_case, full_case *)
            case (1'b1)
              uop_ctl_m1_d1_o.instr_rdcycle:   alu_rst_d2_o <= count_cycle_o[31:0];
              uop_ctl_m1_d1_o.instr_rdcycleh:  alu_rst_d2_o <= count_cycle_o[63:32];
              uop_ctl_m1_d1_o.instr_rdinstr:   alu_rst_d2_o <= count_instr_o[31:0];
              uop_ctl_m1_d1_o.instr_rdinstrh:  alu_rst_d2_o <= count_instr_o[63:32];
            endcase
            rf_we_d2_o        <= 1;
            rf_dst_d2_o       <= uop_ctl_m1_d1_o.decoded_rd;
          end
          uop_ctl_m1_d1_o.is_lui_auipc_jal: begin
            alu_op1_m1_d2     <= uop_ctl_m1_d1_o.instr_lui ? 0 : pc_m1_d1_o;
            alu_op2_m1_d2     <= uop_ctl_m1_d1_o.decoded_imm;
          end
          uop_ctl_m1_d1_o.instr_retirq: begin
            is_branch_d2_o    <= 'b1;
            `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs1, cpuregs_rs1_m1);)
            branch_pc_d2_o    <= CATCH_MISALIGN ? (irq_retPC & 32'h fffffffe) : irq_retPC;
            irq_processing    <= 1'b0;
          end
          uop_ctl_m1_d1_o.instr_maskirq: begin
            rf_we_d2_o        <= 'b1;
            rf_dst_d2_o       <= uop_ctl_m1_d1_o.decoded_rd;
            alu_rst_d2_o      <= irq_mask_o;
            `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs1, cpuregs_rs1_m1);)
            irq_mask_o        <= cpuregs_rs1_m1;
          end
          uop_ctl_m1_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_m1_d1_o.instr_trap: begin
            `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs1, cpuregs_rs1_m1);)
            alu_op1_m1_d2     <= cpuregs_rs1_m1;
          end
          uop_ctl_m1_d1_o.is_jalr_addi_slti_sltiu_xori_ori_andi, uop_ctl_m1_d1_o.is_slli_srli_srai: begin
            `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs1, cpuregs_rs1_m1);)
            alu_op1_m1_d2     <= cpuregs_rs1_m1;
            alu_op2_m1_d2     <= uop_ctl_m1_d1_o.is_slli_srli_srai? uop_ctl_m1_d1_o.decoded_rs2 : uop_ctl_m1_d1_o.decoded_imm;
          end
          default: begin
            `debug($display("LD_RS1: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs1, cpuregs_rs1_m1);)
            `debug($display("LD_RS2: %2d 0x%08x", uop_ctl_m1_d1_o.decoded_rs2, cpuregs_rs2_m1);)
            alu_op1_m1_d2     <= cpuregs_rs1_m1;
            alu_op2_m1_d2     <= cpuregs_rs2_m1;
          end
        endcase
      end

      if(uop_ctl_m0_v_d1_o & ~is_branch_d1_o[0]) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_m0_d1_o.instr_trap: begin
            //* TODO
          end
          uop_ctl_m0_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
          uop_ctl_m0_d1_o.instr_retirq,
          uop_ctl_m0_d1_o.instr_maskirq,
          uop_ctl_m0_d1_o.instr_jal: begin
          end
          uop_ctl_m0_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_m0_d1_o.instr_trap: to_ld_v <= 1'b1;
          uop_ctl_m0_d1_o.is_sb_sh_sw:                                        to_st_v <= 1'b1;
          uop_ctl_m0_d1_o.instr_any_div_rem | uop_ctl_m0_d1_o.instr_any_mul:  to_mu_v <= 1'b1;
          default:                                                            to_ex0_v<= 1'b1;
        endcase
      end
      //* instr1
      if(uop_ctl_m1_v_d1_o & ~is_branch_d1_o[1]) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_m1_d1_o.instr_trap: begin
            //* TODO
          end
          uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
          uop_ctl_m1_d1_o.instr_retirq,
          uop_ctl_m1_d1_o.instr_maskirq,
          uop_ctl_m1_d1_o.instr_jal: begin
          end
          uop_ctl_m1_d1_o.is_lb_lh_lw_lbu_lhu && !uop_ctl_m1_d1_o.instr_trap: begin 
            to_ld_v <= 1'b1;
            lsu_sel <= 1'b1;
          end
          uop_ctl_m1_d1_o.is_sb_sh_sw: begin
            to_st_v <= 1'b1;
            lsu_sel <= 1'b1;
          end
          uop_ctl_m1_d1_o.instr_any_div_rem | uop_ctl_m1_d1_o.instr_any_mul:  begin
            to_mu_v <= 1'b1;
            mu_sel  <= 1'b1;
          end
          default: begin
            to_ex1_v<= 1'b1;
          end
        endcase
      end
    end
  end

  //* update scb before write back register
  wire                      rf_we_ex0_ns  = to_ex0_v_o & ~uop_ctl_m0_d2_o.is_beq_bne_blt_bge_bltu_bgeu;
  wire  [regindex_bits-1:0] rf_dst_ex0_ns = uop_ctl_m0_d2_o.decoded_rd;
  wire                      rf_we_ex1_ns  = to_ex1_v_o & ~uop_ctl_m1_d2_o.is_beq_bne_blt_bge_bltu_bgeu;
  wire  [regindex_bits-1:0] rf_dst_ex1_ns = uop_ctl_m1_d2_o.decoded_rd;

  uop_ctl_t     uop_ctl_m0_ifu, uop_ctl_m1_ifu;
  N2_idu_predecode N2_idu_predecode_i0(
    .instr_rdata_i    (instr_rdata_i[31:0]  ),
    .uop_ctl          (uop_ctl_m0_ifu       )
  );
  N2_idu_predecode N2_idu_predecode_i1(
    .instr_rdata_i    (instr_rdata_i[63:32] ),
    .uop_ctl          (uop_ctl_m1_ifu       )
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
    .uop_ctl_m0_ifu_i (uop_ctl_m0_ifu   ),
    .uop_ctl_m1_ifu_i (uop_ctl_m1_ifu   ),
    .uop_ctl_m0_v_d1_o(uop_ctl_m0_v_d1_o),
    .uop_ctl_m0_d1_o  (uop_ctl_m0_d1_o  ),
    .uop_ctl_m1_v_d1_o(uop_ctl_m1_v_d1_o),
    .uop_ctl_m1_d1_o  (uop_ctl_m1_d1_o  ),
    .alu_op_bypass_m0_d1_o(alu_op_bypass_m0_d1_o),
    .alu_op_bypass_m1_d1_o(alu_op_bypass_m1_d1_o),
    .alu_op_bypass_m0_d2_o(alu_op_bypass_m0_d2  ),
    .alu_op_bypass_m1_d2_o(alu_op_bypass_m1_d2  ),
    .flush_i          (flush            ),
    .is_branch_d2_i   (is_branch_d2_o   ),
    .is_branch_ex_i   (is_branch_ex_i   ),

    .is_branch_d1_o   (is_branch_d1_o   ),
    .rf_dst_d1_o      (rf_dst_d1        ),
    .branch_pc_d1_o   (branch_pc_d1_o   ),
    .irq_processing_i (irq_processing   ),
    .irq_offset_i     (irq_offset_i     ),
    .pc_m0_d1_o       (pc_m0_d1_o       ),
    .pc_m1_d1_o       (pc_m1_d1_o       ),
    .irq_retPC_o      (irq_retPC        ),
    .irq_ack_o        (irq_ack_d1       ),
    .irq_id_o         (irq_id_o         ),
    .irq_processing_d1_o (irq_processing_d1 ),

    .rf_dst_idu_i     (rf_dst_idu_i     ),
    .rf_we_idu_i      (rf_we_idu_i      ),
    // .rf_dst_ex_i      (rf_dst_ex_i      ),
    // .rf_we_ex_i       (rf_we_ex_i       ),
    .rf_dst_ex0_i     (rf_dst_ex0_ns    ),
    .rf_we_ex0_i      (rf_we_ex0_ns     ),
    .rf_dst_ex1_i     (rf_dst_ex1_ns    ),
    .rf_we_ex1_i      (rf_we_ex1_ns     ),
    .rf_dst_lsu_i     (rf_dst_lsu_i     ),
    .rf_dst_lsu_ns_i  (rf_dst_lsu_ns_i  ),
    .rf_we_lsu_ns_i   (rf_we_lsu_ns_i   ),
    .rf_we_lsu_i      (rf_we_lsu_i      ),
    .rf_dst_mu_i      (rf_dst_mu_i      ),
    .rf_we_mu_i       (rf_we_mu_i       ),
    .lsu_finish_i     (lsu_finish_i     ),
    .mu_finish_i      (mu_finish_i      ),
    .lsu_stall_idu_i  (lsu_stall_idu_i  ),

  `ifdef ENABLE_BP
    .btb_ctl_m0_v_i   (btb_ctl_m0_v_i   ),
    .btb_ctl_m0_i     (btb_ctl_m0_i     ),
    .btb_ctl_m1_v_i   (btb_ctl_m1_v_i   ),
    .btb_ctl_m1_i     (btb_ctl_m1_i     ),
    .btb_ctl_m0_d1_o  (btb_ctl_m0_d1    ),
    .btb_ctl_m1_d1_o  (btb_ctl_m1_d1    ),
    .btb_upd_v_d1_o   (btb_upd_v_d1_o   ),
    .btb_upd_d1_o     (btb_upd_d1_o     ),
  `endif

    .count_cycle      (count_cycle_o    ),
    .count_instr      (count_instr_o    )
  );

  assign uid_2ex0_d2_o  = uid_d2_o;
  assign uid_2ex1_d2_o  = uid_d2_o + uid_we_d2_o[0]|uid_ready_we_d2_o[0];
  assign uid_2mu_d2_o   = mu_sel? (uid_d2_o + uid_we_d2_o[0]|uid_ready_we_d2_o[0]) : uid_d2_o;
  assign uid_2lsu_d2_o  = lsu_sel?(uid_d2_o + uid_we_d2_o[0]|uid_ready_we_d2_o[0]) : uid_d2_o;
  reg [1:0] uid_we_d2, uid_ready_we_d2;
  assign uid_we_d2_o    = uid_we_d2 & {2{~is_branch_ex_i}};
  assign uid_ready_we_d2_o = uid_ready_we_d2 & {2{~is_branch_ex_i}};
  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      uid_we_d2         <= '0;
      uid_ready_we_d2   <= '0;
      uid_d2_o          <= 8'b0;
    end
    else begin
      if(uop_ctl_m1_v_d2_o)       uid_d2_o <= uid_d2_o + 2;
      else if(uop_ctl_m0_v_d2_o)  uid_d2_o <= uid_d2_o + 1;
      uid_we_d2           <= '0;
      uid_ready_we_d2[0]  <= uop_ctl_m0_v_d1_o & ~is_branch_d2_o &
                                (uop_ctl_m0_d1_o.instr_jal | 
                                uop_ctl_m0_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh |
                                uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh |
                                uop_ctl_m0_d1_o.instr_retirq |
                                uop_ctl_m0_d1_o.instr_maskirq);
      uid_ready_we_d2[1]  <= uop_ctl_m1_v_d1_o & ~is_branch_d2_o &
                                uop_ctl_m1_d1_o.instr_jal | 
                                uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh |
                                uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh |
                                uop_ctl_m1_d1_o.instr_maskirq;

      if(uop_ctl_m0_v_d1_o & ~is_branch_d2_o & ~is_branch_d1_o[0] & ~is_jal_m0_d1) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_m0_d1_o.instr_trap: begin
            //* TODO
          end
          uop_ctl_m0_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
          uop_ctl_m0_d1_o.instr_retirq,
          uop_ctl_m0_d1_o.instr_maskirq: begin
          end
          default: uid_we_d2[0]  <= ~uop_ctl_m0_d1_o.is_sb_sh_sw & ~uop_ctl_m0_d1_o.is_beq_bne_blt_bge_bltu_bgeu &
                                    |uop_ctl_m0_d1_o.decoded_rd;
        endcase
      end
      if(uop_ctl_m1_v_d1_o & ~is_branch_d2_o & ~is_branch_d1_o[1] & ~is_jal_m1_d1) begin
        (* parallel_case *)
        case (1'b1)
          (CATCH_ILLINSN) && uop_ctl_m1_d1_o.instr_trap: begin
            //* TODO
          end
          uop_ctl_m1_d1_o.is_rdcycle_rdcycleh_rdinstr_rdinstrh,
          uop_ctl_m1_d1_o.instr_retirq,
          uop_ctl_m1_d1_o.instr_maskirq: begin
          end
          default: uid_we_d2[1]  <= ~uop_ctl_m1_d1_o.is_sb_sh_sw & ~uop_ctl_m1_d1_o.is_beq_bne_blt_bge_bltu_bgeu &
                                    |uop_ctl_m1_d1_o.decoded_rd;
        endcase
      end
    end
  end

endmodule