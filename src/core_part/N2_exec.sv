/*************************************************************/
//  Module name: N2_exec
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/24
//  Function outline: instruction execute unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_exec (
  input clk, resetn,
  input                 to_ex_v_i,
  input   wire  [7:0]   uid_d2_i,
  output  reg  [7:0]    uid_ex_o,

  output  reg   [regindex_bits-1:0] rf_dst_ex_o,
  input   uop_ctl_t     uop_ctl_i,
  
  input   wire  [31:0]  alu_op1_i,
  input   wire  [31:0]  alu_op2_i,
  output  reg   [31:0]  alu_rst_ex_o,
  output  reg           rf_we_ex_o,
  output  reg           is_branch_ex_o,
  output  reg   [31:0]  branch_pc_ex_o,
  
`ifdef ENABLE_BP
  output  reg           btb_upd_v_o,
  output  btb_t         btb_upd_info_o,
  input   btb_ctl_t     btb_ctl_i,
`endif

  input   wire  [31:0]  cur_pc_d2_i,
  output  reg   [31:0]  cur_pc_ex_o
);
  wire [regindex_bits-1:0] rf_dst_idu_i = uop_ctl_i.decoded_rd;

  wire [31:0] decoded_imm = uop_ctl_i.decoded_imm;
  wire        is_beq_bne_blt_bge_bltu_bgeu = uop_ctl_i.is_beq_bne_blt_bge_bltu_bgeu;
  wire        instr_jalr = uop_ctl_i.instr_jalr;
  wire        instr_sub = uop_ctl_i.instr_sub;
  wire        instr_sra = uop_ctl_i.instr_sra;
  wire        instr_srai = uop_ctl_i.instr_srai;
  wire        instr_beq = uop_ctl_i.instr_beq;
  wire        instr_bne = uop_ctl_i.instr_bne;
  wire        instr_bge = uop_ctl_i.instr_bge;
  wire        instr_bgeu = uop_ctl_i.instr_bgeu;
  wire        is_slti_blt_slt = uop_ctl_i.is_slti_blt_slt;
  wire        is_sltiu_bltu_sltu = uop_ctl_i.is_sltiu_bltu_sltu;
  wire        is_lui_auipc_jal_jalr_addi_add_sub = uop_ctl_i.is_lui_auipc_jal_jalr_addi_add_sub;
  wire        is_compare = uop_ctl_i.is_compare;
  wire        instr_xori = uop_ctl_i.instr_xori;
  wire        instr_xor = uop_ctl_i.instr_xor;
  wire        instr_ori = uop_ctl_i.instr_ori;
  wire        instr_or = uop_ctl_i.instr_or;
  wire        instr_andi = uop_ctl_i.instr_andi;
  wire        instr_and = uop_ctl_i.instr_and;
  wire        instr_sll = uop_ctl_i.instr_sll;
  wire        instr_slli = uop_ctl_i.instr_slli;
  wire        instr_srl = uop_ctl_i.instr_srl;
  wire        instr_srli = uop_ctl_i.instr_srli;

  reg [31:0] alu_out;
  reg alu_out_0, alu_out_0_q;

  reg [31:0] alu_add_sub;
  reg [31:0] alu_shl, alu_shr;
  reg alu_eq, alu_ltu, alu_lts;

  always_comb begin
    alu_add_sub = instr_sub ? alu_op1_i - alu_op2_i : alu_op1_i + alu_op2_i;
    alu_eq = alu_op1_i == alu_op2_i;
    alu_lts = $signed(alu_op1_i) < $signed(alu_op2_i);
    alu_ltu = alu_op1_i < alu_op2_i;
    alu_shl = alu_op1_i << alu_op2_i[4:0];
    alu_shr = $signed({instr_sra || instr_srai ? alu_op1_i[31] : 1'b0, alu_op1_i}) >>> alu_op2_i[4:0];
  end

  always_comb begin
    alu_out_0 = 'bx;
    (* parallel_case, full_case *)
    case (1'b1)
      instr_beq:
        alu_out_0 = alu_eq;
      instr_bne:
        alu_out_0 = !alu_eq;
      instr_bge:
        alu_out_0 = !alu_lts;
      instr_bgeu:
        alu_out_0 = !alu_ltu;
      is_slti_blt_slt:
        alu_out_0 = alu_lts;
      is_sltiu_bltu_sltu:
        alu_out_0 = alu_ltu;
    endcase

    alu_out = 'bx;
    (* parallel_case, full_case *)
    case (1'b1)
      is_lui_auipc_jal_jalr_addi_add_sub:
        alu_out = alu_add_sub;
      is_compare:
        alu_out = alu_out_0;
      instr_xori || instr_xor:
        alu_out = alu_op1_i ^ alu_op2_i;
      instr_ori || instr_or:
        alu_out = alu_op1_i | alu_op2_i;
      instr_andi || instr_and:
        alu_out = alu_op1_i & alu_op2_i;
      instr_sll || instr_slli:
        alu_out = alu_shl;
      instr_srl || instr_srli || instr_sra || instr_srai:
        alu_out = alu_shr;
    endcase

  end

  always_ff @(posedge clk) begin
    alu_out_0_q         <= alu_out_0;
    cur_pc_ex_o         <= cur_pc_d2_i;
    is_branch_ex_o      <= '0;
    rf_we_ex_o          <= 1'b0;
    uid_ex_o            <= uid_d2_i;
    if(!resetn) begin
      rf_we_ex_o        <= '0;
    end
    else if(to_ex_v_i) begin
      alu_rst_ex_o      <= cur_pc_d2_i + decoded_imm;
      branch_pc_ex_o    <= cur_pc_d2_i + decoded_imm;
      rf_dst_ex_o       <= rf_dst_idu_i;
      rf_we_ex_o        <= 1'b0;
      if (is_beq_bne_blt_bge_bltu_bgeu) begin
        rf_dst_ex_o     <= 0;
        `ifdef ENABLE_BP
          is_branch_ex_o  <= alu_out_0 ^ btb_ctl_i.jump;
          branch_pc_ex_o  <= alu_out_0? (cur_pc_d2_i + decoded_imm): (cur_pc_d2_i + 4);
        `else
          is_branch_ex_o  <= alu_out_0;
        `endif
      end 
      else if(instr_jalr) begin
        is_branch_ex_o  <= ~btb_ctl_i.jump | (alu_out != btb_ctl_i.tgt);
        branch_pc_ex_o  <= alu_out;
        rf_we_ex_o      <= btb_ctl_i.jump & (alu_out == btb_ctl_i.tgt);
        alu_rst_ex_o    <= cur_pc_d2_i + 4;
      end
      else begin
        alu_rst_ex_o    <= alu_out;
        branch_pc_ex_o  <= alu_out;
        is_branch_ex_o  <= 0;
        rf_we_ex_o      <= 1;
        // is_branch_ex_o  <= instr_jalr;
        // rf_we_ex_o      <= ~instr_jalr;
      end
    end
  end

  `ifdef ENABLE_BP
    wire  [15:0]  w_temp_tgt = cur_pc_d2_i + decoded_imm;
    always_ff@(posedge clk or negedge resetn) begin
      btb_upd_v_o                     <= 1'b0;
      btb_upd_info_o.is_jarl          <= 0;
      if(!resetn) begin
        btb_upd_v_o     <= '0;
      end
      else if(to_ex_v_i) begin
        if (is_beq_bne_blt_bge_bltu_bgeu) begin
          //* jump;
          if(alu_out_0) begin
            btb_upd_v_o               <= ~btb_ctl_i.jump | (w_temp_tgt != btb_ctl_i.tgt);
            btb_upd_info_o.valid      <= 1;
            btb_upd_info_o.pc         <= btb_ctl_i.pc;
            btb_upd_info_o.tgt        <= w_temp_tgt;
          end
          //* donot jump
          else begin
            btb_upd_v_o               <= btb_ctl_i.jump;
            btb_upd_info_o.pc         <= btb_ctl_i.pc;
            btb_upd_info_o.valid      <= 0;
            btb_upd_info_o.tgt        <= 0;
          end
        end
        else if(instr_jalr) begin
          btb_upd_v_o                 <= ~btb_ctl_i.jump | (alu_out != btb_ctl_i.tgt);
          btb_upd_info_o.is_jarl      <= 1;
          btb_upd_info_o.valid        <= 1;
          btb_upd_info_o.pc           <= btb_ctl_i.pc;
          btb_upd_info_o.tgt          <= alu_out;
        end 
      end
    end
  `endif

endmodule