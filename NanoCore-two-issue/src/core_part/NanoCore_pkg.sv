/****************************************************/
//  Module name: ariane_pkg
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/05/23
//  Function outline: 
//  Note:
/****************************************************/

package NanoCore_pkg;

  localparam HEAD_WIDTH       = 512;  //* extract fields from pkt/meta head
  localparam integer regfile_size   = 32;
  localparam integer regindex_bits  = 5;

  //==============================================================//
  // conguration according user defination, DO NOT NEED TO MODIFY!!!
  //==============================================================//
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  typedef enum logic [3:0] {cpu_state_trap, cpu_state_fetch, cpu_state_ld_rs, cpu_state_exec, 
                            cpu_state_shift, cpu_state_stmem, cpu_state_ldmem, cpu_state_mul,
                            cpu_state_proc_irq} state_t;

  typedef struct packed {
    logic [31:0]  opcode;
  } iq_data_t;

  typedef struct packed {
    logic [31:0]  opcode;
    logic instr_lui;
    logic instr_auipc;
    logic instr_jal;
    logic instr_jalr;
    logic instr_beq;
    logic instr_bne;
    logic instr_blt;
    logic instr_bge;
    logic instr_bltu;
    logic instr_bgeu;
    logic instr_lb;
    logic instr_lh;
    logic instr_lw;
    logic instr_lbu;
    logic instr_lhu;
    logic instr_sb;
    logic instr_sh;
    logic instr_sw;
    logic instr_addi;
    logic instr_slti;
    logic instr_sltiu;
    logic instr_xori;
    logic instr_ori;
    logic instr_andi;
    logic instr_slli;
    logic instr_srli;
    logic instr_srai;
  // reg decoder_trigger_q;
    logic instr_add;
    logic instr_sub;
    logic instr_sll;
    logic instr_slt;
    logic instr_sltu;
    logic instr_xor;
    logic instr_srl;
    logic instr_sra;
    logic instr_or;
    logic instr_and;
    logic instr_rdcycle;
    logic instr_rdcycleh;
    logic instr_rdinstr;
    logic instr_rdinstrh;
    logic instr_ecall_ebreak;
    logic instr_mul;
    logic instr_mulh;
    logic instr_mulhsu;
    logic instr_mulhu;
    logic instr_any_mul;
    logic instr_any_mulh;
    logic instr_rs1_signed;
    logic instr_rs2_signed;
    logic instr_div;
    logic instr_divu;
    logic instr_rem;
    logic instr_remu;
    logic instr_any_div_rem;
    logic mul_div_valid_idu;
    logic mul_div_valid_mu;
    logic mul_div_valid;
    logic [3:0] mul_op;
    logic [3:0] div_op;
    logic mul_ready;
    logic div_ready;
    logic [31:0] mul_rd;
    logic [31:0] div_rd;
    logic instr_retirq;
    logic instr_maskirq;
    logic instr_trap;
    logic [regindex_bits-1:0] decoded_rd;
    logic [regindex_bits-1:0] decoded_rs1;
    logic [regindex_bits-1:0] decoded_rs2;
    logic [31:0] decoded_imm;
    logic [31:0] decoded_imm_j;
    logic is_lui_auipc_jal;
    logic is_lb_lh_lw_lbu_lhu;
    logic is_slli_srli_srai;
    logic is_jalr_addi_slti_sltiu_xori_ori_andi;
    logic is_sb_sh_sw;
    logic is_sll_srl_sra;
    logic is_lui_auipc_jal_jalr_addi_add_sub;
    logic is_slti_blt_slt;
    logic is_sltiu_bltu_sltu;
    logic is_beq_bne_blt_bge_bltu_bgeu;
    logic is_lbu_lhu_lw;
    logic is_alu_reg_imm;
    logic is_alu_reg_reg;
    logic is_compare;
    logic is_rdcycle_rdcycleh_rdinstr_rdinstrh;
    logic [31:0] waddr;
  } uop_ctl_t;

  typedef struct packed {
    logic ready;
    logic [7:0]   uid;
    logic [4:0]   rf_dst;
    logic [31:0]  rf_wdata;
  } wb_entry_t;

  typedef struct packed {
    logic ready;
    logic [1:0] stage;
    logic [2:0] alu; //* {lsu,ex1,ex0}
  } scoreboard_t;

  typedef struct packed {
    logic         valid;
    logic [15:0]  pc;
    logic [15:0]  tgt;
    logic [1:0]   bht;
  } btb_t;

  typedef struct packed {
    logic         update_bht;
    logic         inc_bht;
    logic         update_tgt;
    logic [15:0]  tgt;
    logic [15:0]  pc;
    logic [3:0]   entryID;
    logic         insert_btb;   //* update or insert;
  } btb_update_t;
  typedef struct packed {
    logic         hit;
    logic         sbp_hit;
    logic         jump;
    logic [15:0]  tgt;
    logic [15:0]   pc;
    logic [3:0]   entryID;
  } btb_ctl_t;

  //* sbp;
  typedef struct packed {
    logic         valid;
    logic [15:0]  pc;
    logic [15:0]  tgt;
  } sbp_t;
  typedef struct packed {
    logic [15:0]  tgt;
    logic [15:0]  pc;
  } sbp_update_t;

  typedef struct packed {
    logic [31:0]  addr;
    logic [1:0]   mem_wordsize;
    logic [31:0]  wdata;
    logic [3:0]   wstrb;
    logic         we;
    logic         is_lu;
    logic         is_lh;
    logic         is_lb;
    logic [regindex_bits-1:0] rf_dst;
    logic [7:0]   uid;
  } lsu_ctl_t;

  // typedef struct packed {
  //   //* extract
  //   logic [TYPE_NUM-1:0][TYPE_OFFSET_WIDTH-1:0]   type_offset;
  //   logic [KEY_FILED_NUM-1:0][0:0]                key_offset_v;
  //   logic [KEY_FILED_NUM-1:0][KEY_OFFSET_WIDTH-1:0]key_offset;
  //   logic [META_CANDI_NUM-1:0][REP_OFFSET_WIDTH:0]key_replaceOffset;
  //   logic [HEAD_SHIFT_WIDTH-1:0]                  headShift;
  //   logic [META_SHIFT_WIDTH-1:0]                  metaShift;
  //   //* data
  //   logic [HEAD_WIDTH+TAG_WIDTH-1:0]  head;
  //   logic [META_WIDTH+TAG_WIDTH-1:0]  meta;
  // } layer_info_t;

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

`ifdef DEBUGNETS
  `define FORMAL_KEEP (* keep *)
`else
  `define FORMAL_KEEP
`endif
`define assert(assert_expr) empty_statement

endpackage