/*************************************************************/
//  Module name: N2_idu_decode
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/07/06
//  Function outline: instruction decode unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_idu_decode #(
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [31:0] PROGADDR_IRQ = 32'b0
  )
(
  input clk, resetn,
  
  input   wire  [2:0]   iq_prefetch_ptr,
  output  wire  [2:0]   iq_rd_ptr_o,
  input   wire  [1:0]   uop_ctl_v_ifu_i,
  input   uop_ctl_t     uop_ctl_m0_ifu_i,
  input   uop_ctl_t     uop_ctl_m1_ifu_i,
  output  wire          uop_ctl_m0_v_d1_o,
  output  uop_ctl_t     uop_ctl_m0_d1_o,
  output  wire          uop_ctl_m1_v_d1_o,
  output  uop_ctl_t     uop_ctl_m1_d1_o,
  output  reg   [1:0][2:0] alu_op_bypass_m0_d1_o,
  output  reg   [1:0][2:0] alu_op_bypass_m1_d1_o,
  output  reg   [1:0][2:0] alu_op_bypass_m0_d2_o,
  output  reg   [1:0][2:0] alu_op_bypass_m1_d2_o,
  output  reg   [31:0]  pc_m0_d1_o,
  output  reg   [31:0]  pc_m1_d1_o,
  input   wire          flush_i,
  input   wire          is_branch_d2_i,
  input   wire          is_branch_ex_i,
  output  reg   [1:0]   is_branch_d1_o,           
  output  reg   [regindex_bits-1:0] rf_dst_d1_o,  //* only for instr0 (irq)
  output  reg   [31:0]  branch_pc_d1_o,           //* merged (instr0/1)
  input   wire          irq_processing_i,
  output  reg           irq_processing_d1_o,
  input   wire  [4:0]   irq_offset_i,
  output  reg   [31:0]  irq_retPC_o,
  output  reg           irq_ack_o,
  output  reg   [4:0]   irq_id_o,

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
  output  btb_ctl_t     btb_ctl_m0_d1_o,
  output  btb_ctl_t     btb_ctl_m1_d1_o,
  output  reg           btb_upd_v_d1_o,
  output  btb_t         btb_upd_d1_o,
`endif

  output  reg   [63:0]  count_cycle,
  output  reg   [63:0]  count_instr
);

  wire          iq_not_empty_m0, iq_bypass_m0,
                iq_not_empty_m1, iq_bypass_m1;
  reg   [2:0]   iq_wr_ptr, iq_rd_ptr;
  wire  [2:0]   iq_rd_ptr_nxt = iq_rd_ptr + 3'd1;
  uop_ctl_t     uop_ctl_m0_d0, uop_ctl_m1_d0;
  //* allow_instr1: no conflict between instr0 and instr1 
  logic         stall_scb_m0, stall_scb_m1, allow_instr1;
  reg           uop_ctl_m0_v_d1, uop_ctl_m1_v_d1;
  assign        uop_ctl_m0_v_d1_o = uop_ctl_m0_v_d1 & ~flush_i;
  assign        uop_ctl_m1_v_d1_o = uop_ctl_m1_v_d1 & ~flush_i;
  btb_ctl_t btb_ctl_m0_d0, btb_ctl_m1_d0;
  reg    [1:0][2:0]  alu_op_bypass_m0_2d2, alu_op_bypass_m1_2d2;
  always_ff @(posedge clk) begin
    is_branch_d1_o            <= '0;
    uop_ctl_m0_v_d1           <= '0;
    uop_ctl_m1_v_d1           <= '0;
    uop_ctl_m0_d1_o           <= '0;
    uop_ctl_m1_d1_o           <= '0;
    btb_upd_v_d1_o            <= '0;
    irq_ack_o                 <= 1'b0;
    alu_op_bypass_m0_d1_o[0]  <= {3{~scb[uop_ctl_m0_d0.decoded_rs1].ready & 
                                     scb[uop_ctl_m0_d0.decoded_rs1].stage[0]}} & 
                                  scb[uop_ctl_m0_d0.decoded_rs1].alu;
    alu_op_bypass_m0_d1_o[1]  <= {3{~scb[uop_ctl_m0_d0.decoded_rs2].ready & 
                                     scb[uop_ctl_m0_d0.decoded_rs2].stage[0]}} & 
                                  scb[uop_ctl_m0_d0.decoded_rs2].alu;
    alu_op_bypass_m1_d1_o[0]  <= {3{~scb[uop_ctl_m1_d0.decoded_rs1].ready & 
                                     scb[uop_ctl_m1_d0.decoded_rs1].stage[0]}} & 
                                  scb[uop_ctl_m1_d0.decoded_rs1].alu;
    alu_op_bypass_m1_d1_o[1]  <= {3{~scb[uop_ctl_m1_d0.decoded_rs2].ready & 
                                     scb[uop_ctl_m1_d0.decoded_rs2].stage[0]}} & 
                                  scb[uop_ctl_m1_d0.decoded_rs2].alu;
    alu_op_bypass_m0_2d2[0]   <= {3{~scb[uop_ctl_m0_d0.decoded_rs1].ready & 
                                     scb[uop_ctl_m0_d0.decoded_rs1].stage[1]}} & 
                                  scb[uop_ctl_m0_d0.decoded_rs1].alu;
    alu_op_bypass_m0_2d2[1]   <= {3{~scb[uop_ctl_m0_d0.decoded_rs2].ready & 
                                     scb[uop_ctl_m0_d0.decoded_rs2].stage[1]}} & 
                                  scb[uop_ctl_m0_d0.decoded_rs2].alu;
    alu_op_bypass_m1_2d2[0]   <= {3{~scb[uop_ctl_m1_d0.decoded_rs1].ready & 
                                     scb[uop_ctl_m1_d0.decoded_rs1].stage[1]}} & 
                                  scb[uop_ctl_m1_d0.decoded_rs1].alu;
    alu_op_bypass_m1_2d2[1]   <= {3{~scb[uop_ctl_m1_d0.decoded_rs2].ready & 
                                     scb[uop_ctl_m1_d0.decoded_rs2].stage[1]}} & 
                                  scb[uop_ctl_m1_d0.decoded_rs2].alu;
    alu_op_bypass_m0_d2_o[0]  <= uop_ctl_m0_d1_o.is_lui_auipc_jal? '0: alu_op_bypass_m0_2d2[0];
    alu_op_bypass_m0_d2_o[1]  <= uop_ctl_m0_d1_o.is_lui_auipc_jal |
                                  uop_ctl_m0_d1_o.is_jalr_addi_slti_sltiu_xori_ori_andi|
                                  uop_ctl_m0_d1_o.is_slli_srli_srai? '0: alu_op_bypass_m0_2d2[1];
    alu_op_bypass_m1_d2_o[0]  <= uop_ctl_m1_d1_o.is_lui_auipc_jal? '0: alu_op_bypass_m1_2d2[0];
    alu_op_bypass_m1_d2_o[1]  <= uop_ctl_m1_d1_o.is_lui_auipc_jal |
                                  uop_ctl_m1_d1_o.is_jalr_addi_slti_sltiu_xori_ori_andi|
                                  uop_ctl_m1_d1_o.is_slli_srli_srai? '0: alu_op_bypass_m1_2d2[1];
    irq_processing_d1_o       <= 1'b0;
    btb_upd_d1_o.is_jarl      <= 0;
    if(!resetn) begin
      irq_processing_d1_o     <= 1'b0;
      iq_rd_ptr               <= '0;
      uop_ctl_m0_v_d1         <= '0;
      uop_ctl_m1_v_d1         <= '0;
    end
    else begin
      rf_dst_d1_o             <= uop_ctl_m0_d0.decoded_rd;
      //* decode;
      if (~stall_scb_m0 && (iq_not_empty_m0 |iq_bypass_m0) && ~flush_i && ~(|is_branch_d1_o)) begin
        uop_ctl_m0_v_d1       <= 1'b1;
        uop_ctl_m0_d1_o       <= uop_ctl_m0_d0;
        count_instr[31:0]     <= count_instr[31:0] + 1;
        count_instr[63:32]    <= &count_instr[31:0]? (count_instr[63:32] + 1): count_instr[63:32];
        iq_rd_ptr             <= iq_rd_ptr + 3'd1;

        //* TODO!!!
        if(~stall_scb_m1 & (iq_not_empty_m1 | iq_bypass_m1) & allow_instr1) begin
          uop_ctl_m1_v_d1     <= 1'b1;
          uop_ctl_m1_d1_o     <= uop_ctl_m1_d0;
          count_instr[31:0]   <= count_instr + 2;
          count_instr[63:32]  <= &count_instr[31:1]? (count_instr[63:32] + 1): count_instr[63:32];
          iq_rd_ptr           <= iq_rd_ptr + 3'd2;
          if (uop_ctl_m1_d0.instr_jal) begin
            branch_pc_d1_o    <= btb_ctl_m1_d0.pc + uop_ctl_m1_d0.decoded_imm_j;
            //* update sbp
            btb_upd_v_d1_o    <= ~btb_ctl_m1_d0.jump | 
                                ((btb_ctl_m1_d0.pc + uop_ctl_m1_d0.decoded_imm_j)!=btb_ctl_m1_d0.tgt);
            btb_upd_d1_o.valid<= 1;
            btb_upd_d1_o.pc   <= btb_ctl_m1_d0.pc;
            btb_upd_d1_o.tgt  <= btb_ctl_m1_d0.pc + uop_ctl_m1_d0.decoded_imm_j;
            is_branch_d1_o[1] <= ~btb_ctl_m1_d0.jump | 
                                ((btb_ctl_m1_d0.pc + uop_ctl_m1_d0.decoded_imm_j)!=btb_ctl_m1_d0.tgt);;
          end
        end

        //* for irq;
        if(!irq_processing_i & (|irq_offset_i)) begin
          irq_retPC_o         <= btb_ctl_m0_d0.pc;
          irq_ack_o           <= 1'b1;
          irq_id_o            <= irq_offset_i;
          irq_processing_d1_o <= 1'b1;
          branch_pc_d1_o      <= PROGADDR_IRQ + (irq_offset_i<<2);
          is_branch_d1_o      <= 2'b1;
          rf_dst_d1_o         <= '0;
        end
        else if (uop_ctl_m0_d0.instr_jal) begin
          branch_pc_d1_o      <= btb_ctl_m0_d0.pc + uop_ctl_m0_d0.decoded_imm_j;
          //* update sbp
          btb_upd_v_d1_o      <= ~btb_ctl_m0_d0.jump| 
                                ((btb_ctl_m0_d0.pc + uop_ctl_m0_d0.decoded_imm_j)!=btb_ctl_m0_d0.tgt);
          btb_upd_d1_o.valid  <= 1;
          btb_upd_d1_o.pc     <= btb_ctl_m0_d0.pc;
          btb_upd_d1_o.tgt    <= btb_ctl_m0_d0.pc + uop_ctl_m0_d0.decoded_imm_j;
          is_branch_d1_o[0]   <= ~btb_ctl_m0_d0.jump| 
                                ((btb_ctl_m0_d0.pc + uop_ctl_m0_d0.decoded_imm_j)!=btb_ctl_m0_d0.tgt);
        end
      end
    end

    if(flush_i) begin
      iq_rd_ptr               <= iq_prefetch_ptr;
    end
  end

  //* allow_instr1
  wire no_data_conflict = uop_ctl_m1_d0.decoded_rs1 != uop_ctl_m0_d0.decoded_rd & 
                          uop_ctl_m1_d0.decoded_rs2 != uop_ctl_m0_d0.decoded_rd &
                          uop_ctl_m1_d0.decoded_rd  != uop_ctl_m0_d0.decoded_rd |
                          uop_ctl_m0_d0.decoded_rd  == 0;
  wire is_branch_instr0 = uop_ctl_m0_d0.instr_retirq | uop_ctl_m0_d0.instr_jal | uop_ctl_m0_d0.instr_jalr |
                          uop_ctl_m0_d0.is_beq_bne_blt_bge_bltu_bgeu;
  wire [2:0] bm_ex0, bm_ex1;
  assign bm_ex0 = { uop_ctl_m0_d0.is_rdcycle_rdcycleh_rdinstr_rdinstrh | uop_ctl_m0_d0.instr_maskirq |
                        uop_ctl_m0_d0.instr_retirq | uop_ctl_m0_d0.instr_jal,
                        uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu | uop_ctl_m0_d0.is_sb_sh_sw,
                        uop_ctl_m0_d0.instr_any_div_rem | uop_ctl_m0_d0.instr_any_mul};
  assign bm_ex1 = { uop_ctl_m1_d0.is_rdcycle_rdcycleh_rdinstr_rdinstrh | uop_ctl_m1_d0.instr_maskirq,
                        uop_ctl_m1_d0.instr_retirq | uop_ctl_m1_d0.instr_jal,
                        uop_ctl_m1_d0.is_lb_lh_lw_lbu_lhu | uop_ctl_m1_d0.is_sb_sh_sw,
                        uop_ctl_m1_d0.instr_any_div_rem | uop_ctl_m1_d0.instr_any_mul};
  wire no_ex_conflict   = ~(|(bm_ex0 & bm_ex1));
  assign allow_instr1   = no_data_conflict & no_ex_conflict & ~is_branch_instr0;

  //* fifo used to store pre-decoded instr;
  uop_ctl_t iq_entry[7:0];
  assign iq_rd_ptr_o = iq_rd_ptr;
  reg tag_wait_wr;
  assign iq_not_empty_m0 = ~tag_wait_wr & (iq_rd_ptr != iq_wr_ptr);
  assign iq_bypass_m0 = ~tag_wait_wr & (iq_rd_ptr == iq_wr_ptr) & uop_ctl_v_ifu_i[0];
  
  assign iq_not_empty_m1 = iq_not_empty_m0 & (iq_rd_ptr_nxt != iq_wr_ptr);
  assign iq_bypass_m1 = ~tag_wait_wr & ((iq_rd_ptr == iq_wr_ptr) & uop_ctl_v_ifu_i[1] |
                                            (iq_rd_ptr_nxt == iq_wr_ptr) & uop_ctl_v_ifu_i[0]);

  wire [2:0] iq_wr_ptr_inc1 = 3'd1 + iq_wr_ptr;
  wire [2:0] iq_wr_ptr_inc2 = 3'd2 + iq_wr_ptr;
  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      iq_wr_ptr         <= '0;
      tag_wait_wr       <= '0;
    end
    else begin
      tag_wait_wr       <= (iq_rd_ptr == iq_wr_ptr)? 1'b0: tag_wait_wr;
      //* write;
      if(uop_ctl_v_ifu_i[0]) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if((idx == iq_wr_ptr) & uop_ctl_v_ifu_i[0] |
             (idx == iq_wr_ptr_inc1) & uop_ctl_v_ifu_i[1])
              iq_entry[idx] <= (idx == iq_wr_ptr)? uop_ctl_m0_ifu_i: uop_ctl_m1_ifu_i;
        end
      end
      if(uop_ctl_v_ifu_i == 2'b1) begin
        iq_wr_ptr       <= iq_wr_ptr_inc1;
        if(iq_rd_ptr == iq_wr_ptr_inc1)
          tag_wait_wr   <= 1'b0;
      end
      else if(uop_ctl_v_ifu_i == 2'b11) begin
        iq_wr_ptr       <= iq_wr_ptr_inc2;
        if(iq_rd_ptr == iq_wr_ptr_inc2)
          tag_wait_wr   <= 1'b0;
      end
      //* wait new instr
      if(flush_i) begin
        tag_wait_wr     <= 1'b1;
      end
    end
  end

  always_comb begin
    case({iq_bypass_m0,iq_rd_ptr})
      {1'b0,3'd0}: uop_ctl_m0_d0 = iq_entry[0];
      {1'b0,3'd1}: uop_ctl_m0_d0 = iq_entry[1];
      {1'b0,3'd2}: uop_ctl_m0_d0 = iq_entry[2];
      {1'b0,3'd3}: uop_ctl_m0_d0 = iq_entry[3];
      {1'b0,3'd4}: uop_ctl_m0_d0 = iq_entry[4];
      {1'b0,3'd5}: uop_ctl_m0_d0 = iq_entry[5];
      {1'b0,3'd6}: uop_ctl_m0_d0 = iq_entry[6];
      {1'b0,3'd7}: uop_ctl_m0_d0 = iq_entry[7];
      default:     uop_ctl_m0_d0 = uop_ctl_m0_ifu_i;     
    endcase
    case({iq_bypass_m1,iq_rd_ptr_nxt})
      {1'b0,3'd0}: uop_ctl_m1_d0 = iq_entry[0];
      {1'b0,3'd1}: uop_ctl_m1_d0 = iq_entry[1];
      {1'b0,3'd2}: uop_ctl_m1_d0 = iq_entry[2];
      {1'b0,3'd3}: uop_ctl_m1_d0 = iq_entry[3];
      {1'b0,3'd4}: uop_ctl_m1_d0 = iq_entry[4];
      {1'b0,3'd5}: uop_ctl_m1_d0 = iq_entry[5];
      {1'b0,3'd6}: uop_ctl_m1_d0 = iq_entry[6];
      {1'b0,3'd7}: uop_ctl_m1_d0 = iq_entry[7];
      default:     uop_ctl_m1_d0 = (iq_rd_ptr == iq_wr_ptr)? uop_ctl_m1_ifu_i: uop_ctl_m0_ifu_i;     
    endcase
  end


  `ifdef ENABLE_BP
    //* fifo used to store pre-decoded instr;
    //* TODO, instr bypass fifo;
    btb_ctl_t bpiq_entry[7:0];
    wire [2:0] iq_prefetch_ptr_min1 = iq_prefetch_ptr-1;
    wire [2:0] iq_prefetch_ptr_min2 = iq_prefetch_ptr-2;
    always_ff @(posedge clk) begin
      //* write;
      if(uop_ctl_v_ifu_i == 2'b1) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if(idx == iq_prefetch_ptr_min1)
            bpiq_entry[idx] <= btb_ctl_m0_i;
        end
      end
      else if(uop_ctl_v_ifu_i == 2'b11) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if((idx == iq_prefetch_ptr_min1) & uop_ctl_v_ifu_i[0] |
             (idx == iq_prefetch_ptr_min2) & uop_ctl_v_ifu_i[1])
            bpiq_entry[idx] <= (idx == iq_prefetch_ptr_min2)? btb_ctl_m0_i: btb_ctl_m1_i;
        end
      end
      //* read;
      btb_ctl_m0_d1_o         <= btb_ctl_m0_d0;
      pc_m0_d1_o              <= btb_ctl_m0_d0.pc;
      btb_ctl_m1_d1_o         <= btb_ctl_m1_d0;
      pc_m1_d1_o              <= btb_ctl_m1_d0.pc;
    end

    always_comb begin
      (*full_case, parallel_case*)
      case({iq_bypass_m0,iq_rd_ptr})
        {1'b0,3'd0}: btb_ctl_m0_d0 = bpiq_entry[0];
        {1'b0,3'd1}: btb_ctl_m0_d0 = bpiq_entry[1];
        {1'b0,3'd2}: btb_ctl_m0_d0 = bpiq_entry[2];
        {1'b0,3'd3}: btb_ctl_m0_d0 = bpiq_entry[3];
        {1'b0,3'd4}: btb_ctl_m0_d0 = bpiq_entry[4];
        {1'b0,3'd5}: btb_ctl_m0_d0 = bpiq_entry[5];
        {1'b0,3'd6}: btb_ctl_m0_d0 = bpiq_entry[6];
        {1'b0,3'd7}: btb_ctl_m0_d0 = bpiq_entry[7];  
        default:     btb_ctl_m0_d0 = btb_ctl_m0_i; 
      endcase
      (*full_case, parallel_case*)
      case({iq_bypass_m1,iq_rd_ptr_nxt})
        {1'b0,3'd0}: btb_ctl_m1_d0 = bpiq_entry[0];
        {1'b0,3'd1}: btb_ctl_m1_d0 = bpiq_entry[1];
        {1'b0,3'd2}: btb_ctl_m1_d0 = bpiq_entry[2];
        {1'b0,3'd3}: btb_ctl_m1_d0 = bpiq_entry[3];
        {1'b0,3'd4}: btb_ctl_m1_d0 = bpiq_entry[4];
        {1'b0,3'd5}: btb_ctl_m1_d0 = bpiq_entry[5];
        {1'b0,3'd6}: btb_ctl_m1_d0 = bpiq_entry[6];
        {1'b0,3'd7}: btb_ctl_m1_d0 = bpiq_entry[7];  
        default:     btb_ctl_m1_d0 = (iq_rd_ptr == iq_wr_ptr)? btb_ctl_m1_i: btb_ctl_m0_i; 
      endcase
    end
  `endif

  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      count_cycle         <= '0;
    end
    else begin
      count_cycle[31:0]   <= 32'd1 + count_cycle[31:0];
      count_cycle[63:32]  <= (&count_cycle[31:0])? (32'd1 + count_cycle[63:32]): count_cycle[63:32];
    end
  end

  //* socreboard
  scoreboard_t scb[31:0];
  reg   [31:0]  scb_ready_delay_1, scb_ready_delay_2;
  reg   wait_lsu, wait_mu;
  reg   [2:1] wait_mu_delay;
  always_comb begin
    stall_scb_m0 = wait_mu & (uop_ctl_m0_d0.instr_any_div_rem) | lsu_stall_idu_i;
    for(integer i=1; i<32; i=i+1) begin
      if(uop_ctl_m0_d0.decoded_rs1 == i || uop_ctl_m0_d0.decoded_rs2 == i)
        stall_scb_m0 = stall_scb_m0 | (~scb[i].ready & ~scb[i].stage[0] &
                        (~scb[i].stage[1] | 
                          uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu |
                          uop_ctl_m0_d0.is_sb_sh_sw));
      if(uop_ctl_m0_d0.decoded_rd == i)
        // stall_scb_m0 = stall_scb_m0 | ~scb[i].ready;
        stall_scb_m0 = stall_scb_m0 | (~scb[i].ready & ((scb[i].stage[1:0] == 2'b0) |
                        uop_ctl_m0_d0.is_rdcycle_rdcycleh_rdinstr_rdinstrh | uop_ctl_m0_d0.instr_maskirq |
                        uop_ctl_m0_d0.instr_retirq | uop_ctl_m0_d0.instr_jal));
    end

    stall_scb_m1 = wait_mu & (uop_ctl_m1_d0.instr_any_div_rem) | lsu_stall_idu_i;
    for(integer i=1; i<32; i=i+1) begin
      if(uop_ctl_m1_d0.decoded_rs1 == i || uop_ctl_m1_d0.decoded_rs2 == i)
        // stall_scb_m1 = stall_scb_m1 | (~scb[i].ready & ~scb[i].stage[0]);
        stall_scb_m1 = stall_scb_m1 | (~scb[i].ready & ~scb[i].stage[0] &
                        (~scb[i].stage[1] | 
                          uop_ctl_m1_d0.is_lb_lh_lw_lbu_lhu |
                          uop_ctl_m1_d0.is_sb_sh_sw));
      if(uop_ctl_m1_d0.decoded_rd == i)
        stall_scb_m1 = stall_scb_m1 | ~scb[i].ready;
    end
  end

  always_ff @(posedge clk or negedge resetn) begin
    scb_ready_delay_2   <= scb_ready_delay_1;
    wait_mu_delay[2:1]  <= {wait_mu_delay[1],wait_mu};
    for(integer i=0; i<32; i=i+1)
      scb_ready_delay_1[i] <= scb[i].ready | scb[i].temp_ready;

    if(~resetn) begin
      for(integer i=0; i<32; i=i+1) begin
        scb[i].ready    <= 1'b1;
        scb[i].alu      <= 'b0;
        scb[i].stage    <= 'b0;
      end
      wait_mu           <= 1'b0;
    end 
    else begin
      //* clear prefetched instr;
      if(is_branch_d2_i) begin
        for(integer i=0; i<32; i=i+1)
          scb[i].ready  <= scb_ready_delay_1[i] | scb[i].ready | scb[i].temp_ready;
        wait_mu         <= wait_mu_delay[1] & wait_mu;
      end
      if(is_branch_ex_i) begin
        for(integer i=0; i<32; i=i+1)
          scb[i].ready  <= scb_ready_delay_2[i] | scb_ready_delay_1[i] | scb[i].ready | scb[i].temp_ready;
        wait_mu         <= wait_mu_delay[2] & wait_mu_delay[1] & wait_mu;
      end

      //* write register file;
      for(integer i=1; i<32; i=i+1)
        if( i == rf_dst_idu_i && rf_we_idu_i ||
            i == rf_dst_ex0_i && rf_we_ex0_i && (scb[i].stage == 3'b1 || flush_i) ||
            i == rf_dst_ex1_i && rf_we_ex1_i && (scb[i].stage == 3'b1 || flush_i) ||
            // i == rf_dst_lsu_i && rf_we_lsu_i && scb[i].stage == 3'b0 ||
            i == rf_dst_mu_i && rf_we_mu_i ||
            i == rf_dst_lsu_ns_i && rf_we_lsu_ns_i && (scb[i].stage == 3'b1 || flush_i))
          scb[i].ready  <= 1'b1;
      for(integer i=1; i<32; i=i+1)
        if( i == rf_dst_idu_i && rf_we_idu_i ||
            i == rf_dst_ex0_i && rf_we_ex0_i ||
            i == rf_dst_ex1_i && rf_we_ex1_i ||
            // i == rf_dst_lsu_i && rf_we_lsu_i ||
            i == rf_dst_mu_i && rf_we_mu_i ||
            i == rf_dst_lsu_ns_i && rf_we_lsu_ns_i)
          scb[i].temp_ready  <= 1'b1;
        else
          scb[i].temp_ready  <= 1'b0;

      for(integer i=1; i<32; i=i+1)
        scb[i].stage <= {1'b0,scb[i].stage[2:1]};

      if(~stall_scb_m0 && (iq_not_empty_m0 |iq_bypass_m0) && ~flush_i && ~(|is_branch_d1_o) && 
              (irq_processing_i || !irq_offset_i)) 
      begin
        for(integer i=1; i<32; i=i+1)
          if(i == uop_ctl_m0_d0.decoded_rd) begin
            if(~uop_ctl_m0_d0.is_beq_bne_blt_bge_bltu_bgeu & ~uop_ctl_m0_d0.is_sb_sh_sw) begin
              scb[i].ready  <= 1'b0;
              scb[i].stage[0] <= 1'b0;
              scb[i].alu      <= uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu? 4: 1;
            end
            scb[i].stage[1] <= ~(uop_ctl_m0_d0.is_beq_bne_blt_bge_bltu_bgeu | 
                                uop_ctl_m0_d0.is_sb_sh_sw | uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu |
                                uop_ctl_m0_d0.instr_any_div_rem | uop_ctl_m0_d0.instr_any_mul |
                                uop_ctl_m0_d0.instr_maskirq | uop_ctl_m0_d0.instr_retirq);
            scb[i].stage[2] <= uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu;
          end
        wait_mu             <= uop_ctl_m0_d0.instr_any_div_rem | wait_mu;
        
        if(~stall_scb_m1 & (iq_not_empty_m1 | iq_bypass_m1) & allow_instr1) begin
          for(integer i=1; i<32; i=i+1)
            if(i == uop_ctl_m0_d0.decoded_rd) begin
              if(~uop_ctl_m0_d0.is_beq_bne_blt_bge_bltu_bgeu & ~uop_ctl_m0_d0.is_sb_sh_sw) begin
                scb[i].ready  <= 1'b0;
                scb[i].stage[0] <= 1'b0;
                scb[i].alu      <= uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu? 4: 1;
              end
              scb[i].stage[1] <= ~(uop_ctl_m0_d0.is_beq_bne_blt_bge_bltu_bgeu | 
                                  uop_ctl_m0_d0.is_sb_sh_sw | uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu |
                                  uop_ctl_m0_d0.instr_any_div_rem | uop_ctl_m0_d0.instr_any_mul |
                                  uop_ctl_m0_d0.instr_maskirq | uop_ctl_m0_d0.instr_retirq);
              scb[i].stage[2] <= uop_ctl_m0_d0.is_lb_lh_lw_lbu_lhu;
            end
            else if(i == uop_ctl_m1_d0.decoded_rd) begin
              if(~uop_ctl_m1_d0.is_beq_bne_blt_bge_bltu_bgeu & ~uop_ctl_m1_d0.is_sb_sh_sw) begin
                scb[i].ready  <= 1'b0;
                scb[i].stage[0] <= 1'b0;
                scb[i].alu      <= uop_ctl_m1_d0.is_lb_lh_lw_lbu_lhu? 4: 2;
              end
              scb[i].stage[1] <= ~(uop_ctl_m1_d0.is_beq_bne_blt_bge_bltu_bgeu | 
                                  uop_ctl_m1_d0.is_sb_sh_sw | uop_ctl_m1_d0.is_lb_lh_lw_lbu_lhu |
                                  uop_ctl_m1_d0.instr_any_div_rem | uop_ctl_m1_d0.instr_any_mul |
                                  uop_ctl_m1_d0.instr_maskirq | uop_ctl_m1_d0.instr_retirq);
              scb[i].stage[2] <= uop_ctl_m1_d0.is_lb_lh_lw_lbu_lhu;
            end
          wait_mu             <= uop_ctl_m0_d0.instr_any_div_rem | uop_ctl_m1_d0.instr_any_div_rem | wait_mu;
        end
      end
      if(mu_finish_i)
        wait_mu           <= 1'b0;
    end
  end

endmodule