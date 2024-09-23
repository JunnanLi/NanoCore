/*************************************************************/
//  Module name: N2_idu_predecode
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/07/11
//  Function outline: instruction pre-decode
/*************************************************************/

module N2_idu_predecode #(
  parameter [ 0:0] ENABLE_COUNTERS = 1,
  parameter [ 0:0] ENABLE_COUNTERS64 = 1
) (
  input   wire  [31:0]  instr_rdata_i,
  output  uop_ctl_t     uop_ctl
);


  //* pre-decode before write into iq;
  assign uop_ctl.opcode = instr_rdata_i;
  assign uop_ctl.instr_trap = !{uop_ctl.instr_lui, uop_ctl.instr_auipc, uop_ctl.instr_jal, uop_ctl.instr_jalr,
      uop_ctl.instr_beq, uop_ctl.instr_bne, uop_ctl.instr_blt, uop_ctl.instr_bge, uop_ctl.instr_bltu, uop_ctl.instr_bgeu,
      uop_ctl.instr_lb, uop_ctl.instr_lh, uop_ctl.instr_lw, uop_ctl.instr_lbu, uop_ctl.instr_lhu, uop_ctl.instr_sb, uop_ctl.instr_sh, uop_ctl.instr_sw,
      uop_ctl.instr_addi, uop_ctl.instr_slti, uop_ctl.instr_sltiu, uop_ctl.instr_xori, uop_ctl.instr_ori, uop_ctl.instr_andi, uop_ctl.instr_slli, uop_ctl.instr_srli, uop_ctl.instr_srai,
      uop_ctl.instr_add, uop_ctl.instr_sub, uop_ctl.instr_sll, uop_ctl.instr_slt, uop_ctl.instr_sltu, uop_ctl.instr_xor, uop_ctl.instr_srl, uop_ctl.instr_sra, uop_ctl.instr_or, uop_ctl.instr_and,
      uop_ctl.instr_mul, uop_ctl.instr_mulh, uop_ctl.instr_mulhsu, uop_ctl.instr_mulhu,
      uop_ctl.instr_div, uop_ctl.instr_divu, uop_ctl.instr_rem, uop_ctl.instr_remu,
      uop_ctl.instr_retirq, uop_ctl.instr_maskirq,
      uop_ctl.instr_rdcycle, uop_ctl.instr_rdcycleh, uop_ctl.instr_rdinstr, uop_ctl.instr_rdinstrh};

  assign uop_ctl.is_rdcycle_rdcycleh_rdinstr_rdinstrh = |{uop_ctl.instr_rdcycle, uop_ctl.instr_rdcycleh, uop_ctl.instr_rdinstr, uop_ctl.instr_rdinstrh};

  assign uop_ctl.instr_lui      = instr_rdata_i[6:0] == 7'b0110111;
  assign uop_ctl.instr_auipc    = instr_rdata_i[6:0] == 7'b0010111;
  assign uop_ctl.instr_jal      = instr_rdata_i[6:0] == 7'b1101111;
  assign uop_ctl.instr_jalr     = instr_rdata_i[6:0] == 7'b1100111 && instr_rdata_i[14:12] == 3'b000;
  assign uop_ctl.instr_retirq   = instr_rdata_i[6:0] == 7'b0001011 && instr_rdata_i[31:25] == 7'b0000010;
  assign uop_ctl.is_beq_bne_blt_bge_bltu_bgeu = instr_rdata_i[6:0] == 7'b1100011;
  assign uop_ctl.is_lb_lh_lw_lbu_lhu          = instr_rdata_i[6:0] == 7'b0000011;
  assign uop_ctl.is_sb_sh_sw                  = instr_rdata_i[6:0] == 7'b0100011;
  assign uop_ctl.is_alu_reg_imm               = instr_rdata_i[6:0] == 7'b0010011;
  assign uop_ctl.is_alu_reg_reg               = instr_rdata_i[6:0] == 7'b0110011;
  assign {uop_ctl.decoded_imm_j[31:20], uop_ctl.decoded_imm_j[10:1], uop_ctl.decoded_imm_j[11], uop_ctl.decoded_imm_j[19:12], uop_ctl.decoded_imm_j[0] } = $signed({{11{instr_rdata_i[31]}},instr_rdata_i[31:12], 1'b0});
  assign uop_ctl.decoded_rd     = instr_rdata_i[11:7];
  assign uop_ctl.decoded_rs1    = instr_rdata_i[19:15];
  assign uop_ctl.decoded_rs2    = instr_rdata_i[24:20];
  always_comb begin
    uop_ctl.is_lui_auipc_jal    = |{uop_ctl.instr_lui, uop_ctl.instr_auipc, uop_ctl.instr_jal};
    uop_ctl.is_lui_auipc_jal_jalr_addi_add_sub = |{uop_ctl.instr_lui, uop_ctl.instr_auipc, uop_ctl.instr_jal, uop_ctl.instr_jalr, uop_ctl.instr_addi, uop_ctl.instr_add, uop_ctl.instr_sub};
    uop_ctl.is_slti_blt_slt     = |{uop_ctl.instr_slti, uop_ctl.instr_blt, uop_ctl.instr_slt};
    uop_ctl.is_sltiu_bltu_sltu  = |{uop_ctl.instr_sltiu, uop_ctl.instr_bltu, uop_ctl.instr_sltu};
    uop_ctl.is_lbu_lhu_lw       = |{uop_ctl.instr_lbu, uop_ctl.instr_lhu, uop_ctl.instr_lw};
    uop_ctl.is_compare          = |{uop_ctl.is_beq_bne_blt_bge_bltu_bgeu, uop_ctl.instr_slti, uop_ctl.instr_slt, uop_ctl.instr_sltiu, uop_ctl.instr_sltu};
  end


  assign uop_ctl.instr_any_mul = |{uop_ctl.instr_mul, uop_ctl.instr_mulh, uop_ctl.instr_mulhsu, uop_ctl.instr_mulhu};
  assign uop_ctl.instr_any_mulh = |{uop_ctl.instr_mulh, uop_ctl.instr_mulhsu, uop_ctl.instr_mulhu};
  assign uop_ctl.instr_rs1_signed = |{uop_ctl.instr_mulh, uop_ctl.instr_mulhsu};
  assign uop_ctl.instr_rs2_signed = |{uop_ctl.instr_mulh};
  assign uop_ctl.instr_any_div_rem = |{uop_ctl.instr_div, uop_ctl.instr_divu, uop_ctl.instr_rem, uop_ctl.instr_remu};
  always_comb begin
    uop_ctl.instr_beq   = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b000;
    uop_ctl.instr_bne   = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b001;
    uop_ctl.instr_blt   = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b100;
    uop_ctl.instr_bge   = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b101;
    uop_ctl.instr_bltu  = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b110;
    uop_ctl.instr_bgeu  = uop_ctl.is_beq_bne_blt_bge_bltu_bgeu && instr_rdata_i[14:12] == 3'b111;

    uop_ctl.instr_lb    = uop_ctl.is_lb_lh_lw_lbu_lhu && instr_rdata_i[14:12] == 3'b000;
    uop_ctl.instr_lh    = uop_ctl.is_lb_lh_lw_lbu_lhu && instr_rdata_i[14:12] == 3'b001;
    uop_ctl.instr_lw    = uop_ctl.is_lb_lh_lw_lbu_lhu && instr_rdata_i[14:12] == 3'b010;
    uop_ctl.instr_lbu   = uop_ctl.is_lb_lh_lw_lbu_lhu && instr_rdata_i[14:12] == 3'b100;
    uop_ctl.instr_lhu   = uop_ctl.is_lb_lh_lw_lbu_lhu && instr_rdata_i[14:12] == 3'b101;

    uop_ctl.instr_sb    = uop_ctl.is_sb_sh_sw && instr_rdata_i[14:12] == 3'b000;
    uop_ctl.instr_sh    = uop_ctl.is_sb_sh_sw && instr_rdata_i[14:12] == 3'b001;
    uop_ctl.instr_sw    = uop_ctl.is_sb_sh_sw && instr_rdata_i[14:12] == 3'b010;

    uop_ctl.instr_addi  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b000;
    uop_ctl.instr_slti  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b010;
    uop_ctl.instr_sltiu = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b011;
    uop_ctl.instr_xori  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b100;
    uop_ctl.instr_ori   = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b110;
    uop_ctl.instr_andi  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b111;

    uop_ctl.instr_slli  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b001 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_srli  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_srai  = uop_ctl.is_alu_reg_imm && instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0100000;

    uop_ctl.instr_add   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b000 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_sub   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b000 && instr_rdata_i[31:25] == 7'b0100000;
    uop_ctl.instr_sll   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b001 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_slt   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b010 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_sltu  = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b011 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_xor   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b100 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_srl   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_sra   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0100000;
    uop_ctl.instr_or    = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b110 && instr_rdata_i[31:25] == 7'b0000000;
    uop_ctl.instr_and   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b111 && instr_rdata_i[31:25] == 7'b0000000;


    uop_ctl.instr_mul   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b000 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_mulh  = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b001 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_mulhsu= uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b010 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_mulhu = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b011 && instr_rdata_i[31:25] == 7'b0000001;

    uop_ctl.instr_div   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b100 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_divu  = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_rem   = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b110 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_remu  = uop_ctl.is_alu_reg_reg && instr_rdata_i[14:12] == 3'b111 && instr_rdata_i[31:25] == 7'b0000001;
    uop_ctl.instr_maskirq  = instr_rdata_i[6:0] == 7'b0001011 && instr_rdata_i[31:25] == 7'b0000011;


    uop_ctl.instr_rdcycle  = ((instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11000000000000000010) ||
                              (instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11000000000100000010)) && ENABLE_COUNTERS;
    uop_ctl.instr_rdcycleh = ((instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11001000000000000010) ||
                              (instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11001000000100000010)) && ENABLE_COUNTERS && ENABLE_COUNTERS64;
    uop_ctl.instr_rdinstr  =  (instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11000000001000000010) && ENABLE_COUNTERS;
    uop_ctl.instr_rdinstrh =  (instr_rdata_i[6:0] == 7'b1110011 && instr_rdata_i[31:12] == 'b11001000001000000010) && ENABLE_COUNTERS && ENABLE_COUNTERS64;

    uop_ctl.instr_ecall_ebreak = instr_rdata_i[6:0] == 7'b1110011 && !instr_rdata_i[31:21] && !instr_rdata_i[19:7];

    uop_ctl.is_slli_srli_srai = uop_ctl.is_alu_reg_imm && |{
      instr_rdata_i[14:12] == 3'b001 && instr_rdata_i[31:25] == 7'b0000000,
      instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0000000,
      instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0100000
    };

    uop_ctl.is_jalr_addi_slti_sltiu_xori_ori_andi = uop_ctl.instr_jalr || uop_ctl.is_alu_reg_imm && |{
      instr_rdata_i[14:12] == 3'b000,
      instr_rdata_i[14:12] == 3'b010,
      instr_rdata_i[14:12] == 3'b011,
      instr_rdata_i[14:12] == 3'b100,
      instr_rdata_i[14:12] == 3'b110,
      instr_rdata_i[14:12] == 3'b111
    };

    uop_ctl.is_sll_srl_sra = uop_ctl.is_alu_reg_reg && |{
      instr_rdata_i[14:12] == 3'b001 && instr_rdata_i[31:25] == 7'b0000000,
      instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0000000,
      instr_rdata_i[14:12] == 3'b101 && instr_rdata_i[31:25] == 7'b0100000
    };

    (* parallel_case *)
    case (1'b1)
      uop_ctl.instr_jal:
        uop_ctl.decoded_imm = uop_ctl.decoded_imm_j;
      |{uop_ctl.instr_lui, uop_ctl.instr_auipc}:
        uop_ctl.decoded_imm = instr_rdata_i[31:12] << 12;
      |{uop_ctl.instr_jalr, uop_ctl.is_lb_lh_lw_lbu_lhu, uop_ctl.is_alu_reg_imm}:
        uop_ctl.decoded_imm = $signed(instr_rdata_i[31:20]);
      uop_ctl.is_beq_bne_blt_bge_bltu_bgeu:
        uop_ctl.decoded_imm = $signed({instr_rdata_i[31], instr_rdata_i[7], instr_rdata_i[30:25], instr_rdata_i[11:8], 1'b0});
      uop_ctl.is_sb_sh_sw:
        uop_ctl.decoded_imm = $signed({instr_rdata_i[31:25], instr_rdata_i[11:7]});
      default:
        uop_ctl.decoded_imm = 1'bx;
    endcase
  end
endmodule