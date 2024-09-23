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
  input   wire          uop_ctl_v_ifu_i,
  input   uop_ctl_t     uop_ctl_ifu_i,
  output  wire          uop_ctl_v_d1_o,
  output  uop_ctl_t     uop_ctl_d1_o,
  output  reg           alu_op1_bypass_o,
  output  reg           alu_op2_bypass_o,
  output  reg   [31:0]  pc_d1_o,
  input   wire          flush_i,
  input   wire          is_branch_d2_i,
  input   wire          is_branch_ex_i,
  input   wire  [31:0]  branch_pc_i,
  output  reg           is_branch_d1_o,
  output  reg   [regindex_bits-1:0] rf_dst_d1_o,
  output  reg   [31:0]  branch_pc_d1_o,
  input   wire          irq_processing_i,
  output  reg           irq_processing_d1_o,
  input   wire  [4:0]   irq_offset_i,
  output  reg   [31:0]  irq_retPC_o,
  output  reg           irq_ack_o,
  output  reg   [4:0]   irq_id_o,

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
  output  btb_ctl_t     btb_ctl_d1_o,
  output  reg           sbp_upd_v_d1_o,
  output  sbp_update_t  sbp_upd_d1_o,
`endif

  output  reg   [63:0]  count_cycle,
  output  reg   [63:0]  count_instr
);

  wire          iq_not_empty, iq_bypass;
  reg   [2:0]   iq_wr_ptr, iq_rd_ptr;
  uop_ctl_t     uop_ctl_d0;
  reg   [31:0]  pc_d1_nxt;
  logic         stall_scb;
  reg           uop_ctl_v_d1;
  assign        uop_ctl_v_d1_o = uop_ctl_v_d1 & ~flush_i;
  always_ff @(posedge clk) begin
    is_branch_d1_o        <= '0;
    uop_ctl_v_d1          <= '0;
    uop_ctl_d1_o          <= '0;
    `ifndef ENABLE_BP
      pc_d1_o             <= pc_d1_nxt;
    `else
      sbp_upd_v_d1_o      <= '0;
    `endif
    irq_ack_o             <= 1'b0;
    alu_op1_bypass_o      <= ~scb[uop_ctl_d0.decoded_rs1].ready & scb[uop_ctl_d0.decoded_rs1].stage;
    alu_op2_bypass_o      <= ~scb[uop_ctl_d0.decoded_rs2].ready & scb[uop_ctl_d0.decoded_rs2].stage;
    irq_processing_d1_o   <= 1'b0;
    if(!resetn) begin
      pc_d1_nxt           <= PROGADDR_RESET;
      irq_processing_d1_o <= 1'b0;
      iq_rd_ptr           <= '0;
      uop_ctl_v_d1        <= '0;
      alu_op1_bypass_o    <= 1'b0;
      alu_op2_bypass_o    <= 1'b0;
    end
    else begin
      rf_dst_d1_o         <= uop_ctl_d0.decoded_rd;
      //* jalr/bru;
      if(flush_i) begin
        pc_d1_nxt         <= {branch_pc_i[31:2],2'b0};
      end
      //* decode;
      if (~stall_scb && (iq_not_empty |iq_bypass) && ~flush_i && ~is_branch_d1_o) begin
        uop_ctl_v_d1      <= 1'b1;
        uop_ctl_d1_o      <= uop_ctl_d0;
        pc_d1_nxt         <= pc_d1_nxt + 32'd4;
        count_instr       <= count_instr + 1;
        iq_rd_ptr         <= 3'd1 + iq_rd_ptr;
        //* for irq;
        if(!irq_processing_i & (|irq_offset_i)) begin
          `ifndef ENABLE_BP
            irq_retPC_o   <= pc_d1_nxt;
          `else
            irq_retPC_o   <= btb_ctl_d0.pc;
          `endif
          irq_ack_o       <= 1'b1;
          irq_id_o        <= irq_offset_i;
          irq_processing_d1_o <= 1'b1;
          branch_pc_d1_o  <= PROGADDR_IRQ + (irq_offset_i<<2);
          is_branch_d1_o  <= 1'b1;
          rf_dst_d1_o     <= '0;
        end
        else if (uop_ctl_d0.instr_jal) begin
          `ifndef ENABLE_BP
            branch_pc_d1_o    <= pc_d1_nxt + uop_ctl_d0.decoded_imm_j;
            is_branch_d1_o    <= 'b1;
          `else
            branch_pc_d1_o    <= btb_ctl_d0.pc + uop_ctl_d0.decoded_imm_j;
            //* update sbp
            sbp_upd_v_d1_o    <= 1'b1;
            sbp_upd_d1_o.pc   <= btb_ctl_d0.pc;
            sbp_upd_d1_o.tgt  <= btb_ctl_d0.pc + uop_ctl_d0.decoded_imm_j;
            is_branch_d1_o    <= ~btb_ctl_d0.sbp_hit;
          `endif
        end
      end
    end

    if(flush_i) begin
      iq_rd_ptr           <= iq_prefetch_ptr;
    end
  end


  //* fifo used to store pre-decoded instr;
  uop_ctl_t iq_entry[7:0];
  assign iq_rd_ptr_o = iq_rd_ptr;
  reg tag_wait_wr;
  assign iq_not_empty = ~tag_wait_wr & (iq_rd_ptr != iq_wr_ptr);
  assign iq_bypass = ~tag_wait_wr & (iq_rd_ptr == iq_wr_ptr) & uop_ctl_v_ifu_i;
  wire [2:0] iq_wr_ptr_nxt = 3'd1 + iq_wr_ptr;
  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      iq_wr_ptr         <= '0;
      tag_wait_wr       <= '0;
    end
    else begin
      tag_wait_wr       <= (iq_rd_ptr == iq_wr_ptr)? 1'b0: tag_wait_wr;
      //* write;
      if(uop_ctl_v_ifu_i) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if(idx == iq_wr_ptr)
            iq_entry[idx] <= uop_ctl_ifu_i;
          iq_wr_ptr     <= iq_wr_ptr_nxt;
        end
        if(iq_rd_ptr == iq_wr_ptr_nxt)
          tag_wait_wr   <= 1'b0;
      end
      //* wait new instr
      if(flush_i) begin
        tag_wait_wr     <= 1'b1;
      end
    end
  end

  always_comb begin
    case({iq_bypass,iq_rd_ptr})
      {1'b0,3'd0}: uop_ctl_d0 = iq_entry[0];
      {1'b0,3'd1}: uop_ctl_d0 = iq_entry[1];
      {1'b0,3'd2}: uop_ctl_d0 = iq_entry[2];
      {1'b0,3'd3}: uop_ctl_d0 = iq_entry[3];
      {1'b0,3'd4}: uop_ctl_d0 = iq_entry[4];
      {1'b0,3'd5}: uop_ctl_d0 = iq_entry[5];
      {1'b0,3'd6}: uop_ctl_d0 = iq_entry[6];
      {1'b0,3'd7}: uop_ctl_d0 = iq_entry[7];
      default:     uop_ctl_d0 = uop_ctl_ifu_i;     
    endcase
  end

  `ifdef ENABLE_BP
    //* fifo used to store pre-decoded instr;
    //* TODO, instr bypass fifo;
    btb_ctl_t bpiq_entry[7:0], btb_ctl_d0;
    wire [2:0] iq_prefetch_ptr_min1 = iq_prefetch_ptr-1;
    always_ff @(posedge clk) begin
      //* write;
      if(uop_ctl_v_ifu_i) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if(idx == iq_prefetch_ptr_min1)
            bpiq_entry[idx] <= btb_ctl_i;
        end
      end
      //* read;
      btb_ctl_d1_o          <= btb_ctl_d0;
      pc_d1_o               <= btb_ctl_d0.pc;
    end

    always_comb begin
      (*full_case, parallel_case*)
      case({iq_bypass,iq_rd_ptr})
        {1'b0,3'd0}: btb_ctl_d0 = bpiq_entry[0];
        {1'b0,3'd1}: btb_ctl_d0 = bpiq_entry[1];
        {1'b0,3'd2}: btb_ctl_d0 = bpiq_entry[2];
        {1'b0,3'd3}: btb_ctl_d0 = bpiq_entry[3];
        {1'b0,3'd4}: btb_ctl_d0 = bpiq_entry[4];
        {1'b0,3'd5}: btb_ctl_d0 = bpiq_entry[5];
        {1'b0,3'd6}: btb_ctl_d0 = bpiq_entry[6];
        {1'b0,3'd7}: btb_ctl_d0 = bpiq_entry[7];  
        default:     btb_ctl_d0 = btb_ctl_i; 
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
  reg   [31:0]  scb_ready_delay_1, scb_ready_delay_2, scb_ready_delay_3;
  reg   wait_lsu, wait_mu;  
  reg   [3:1] wait_lsu_delay;
  reg   [3:1] wait_mu_delay;
  always_comb begin
    stall_scb = wait_mu & (uop_ctl_d0.instr_any_div_rem) | 
                // wait_lsu & (uop_ctl_d0.is_sb_sh_sw | uop_ctl_d0.is_lb_lh_lw_lbu_lhu) | 
                lsu_stall_idu_i;
                // wait_mu;
    for(integer i=1; i<32; i=i+1) begin
      if(uop_ctl_d0.decoded_rs1 == i || uop_ctl_d0.decoded_rs2 == i)
        stall_scb = stall_scb | (~scb[i].ready & ~scb[i].stage[0]);
      if(uop_ctl_d0.decoded_rd == i)
        stall_scb = stall_scb | ~scb[i].ready;
    end
  end

  always_ff @(posedge clk or negedge resetn) begin
    scb_ready_delay_3   <= scb_ready_delay_2;
    scb_ready_delay_2   <= scb_ready_delay_1;
    wait_lsu_delay[3:1] <= {wait_lsu_delay[2:1],wait_lsu};
    wait_mu_delay[3:1]  <= {wait_mu_delay[2:1],wait_mu};
    for(integer i=0; i<32; i=i+1)
      scb_ready_delay_1[i] <= scb[i].ready;

    if(~resetn) begin
      for(integer i=0; i<32; i=i+1)
        scb[i].ready    <= 1'b1;
      wait_lsu          <= 1'b0;
      wait_mu           <= 1'b0;
    end 
    else begin
      //* clear prefetched instr;
      if(is_branch_d2_i) begin
        for(integer i=0; i<32; i=i+1)
          scb[i].ready  <= scb_ready_delay_2[i] | scb_ready_delay_1[i] | scb[i].ready;
        wait_lsu        <= wait_lsu_delay[2] & wait_lsu_delay[1] & wait_lsu;
        wait_mu         <= wait_mu_delay[2]  & wait_mu_delay[1]  & wait_mu;
      end
      if(is_branch_ex_i) begin
        for(integer i=0; i<32; i=i+1)
        scb[i].ready    <= scb_ready_delay_3[i] | scb_ready_delay_2[i] | scb_ready_delay_1[i] | scb[i].ready;
        wait_lsu        <= wait_lsu_delay[3] & wait_lsu_delay[2] & wait_lsu_delay[1] & wait_lsu;
        wait_mu         <= wait_mu_delay[3]  & wait_mu_delay[2]  & wait_mu_delay[1]  & wait_mu;
      end

      //* write register file;
      for(integer i=1; i<32; i=i+1)
        if(i == rf_dst_idu_i && rf_we_idu_i ||
            i == rf_dst_ex_i && rf_we_ex_i ||
            i == rf_dst_lsu_i && rf_we_lsu_i ||
            i == rf_dst_mu_i && rf_we_mu_i)
          scb[i].ready  <= 1'b1;
      

      for(integer i=1; i<32; i=i+1)
        scb[i].stage <= {1'b0,scb[i].stage[1]};

      if(~stall_scb && (iq_not_empty |iq_bypass) && ~flush_i && ~is_branch_d1_o && 
              (irq_processing_i || !irq_offset_i)) 
      begin
        for(integer i=1; i<32; i=i+1)
          if(i == uop_ctl_d0.decoded_rd) begin
            scb[i].ready  <= uop_ctl_d0.is_beq_bne_blt_bge_bltu_bgeu | uop_ctl_d0.is_sb_sh_sw;
            scb[i].stage[1] <= ~(uop_ctl_d0.is_beq_bne_blt_bge_bltu_bgeu | 
                                uop_ctl_d0.is_sb_sh_sw | uop_ctl_d0.is_lb_lh_lw_lbu_lhu |
                                uop_ctl_d0.instr_any_div_rem | uop_ctl_d0.instr_any_mul |
                                uop_ctl_d0.instr_maskirq | uop_ctl_d0.instr_retirq);
          end
        wait_lsu          <= uop_ctl_d0.is_sb_sh_sw | uop_ctl_d0.is_lb_lh_lw_lbu_lhu | wait_lsu;
        wait_mu           <= uop_ctl_d0.instr_any_div_rem | wait_mu;
      end
      if(lsu_finish_i)
        wait_lsu          <= 1'b0;
      if(mu_finish_i)
        wait_mu           <= 1'b0;
    end
  end

endmodule