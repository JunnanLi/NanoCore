/*************************************************************/
//  Module name: N2_ifu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/21
//  Function outline: instruction fetch unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_ifu #(
  parameter [ 0:0] CATCH_MISALIGN = 1,
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [31:0] PROGADDR_IRQ = 32'b0
) (
  input                 clk, resetn,

  input                 flush_i,
  input   wire  [31:0]  branch_pc_i,
  input   wire          instr_gnt_i,
  output  wire          instr_req_o,
  output  wire  [31:0]  instr_addr_o,

`ifdef ENABLE_BP
  input   wire          btb_upd_v_i,
  input   btb_update_t  btb_upd_info_i,
  output  reg           btb_ctl_v_o,
  output  btb_ctl_t     btb_ctl_o,
  input   wire          sbp_upd_v_i,
  input   sbp_update_t  sbp_upd_i,
`endif

  output  reg   [2:0]   iq_prefetch_ptr,
  input   wire  [2:0]   iq_rd_ptr
);

  `ifdef ENABLE_BP
    logic [3:0]   bm_hit, bm_jump, bm_sbp_hit;
    logic [15:0]  tgt_hit, tgt_sbp_hit;
    logic [1:0]   entryID_hit;
  `endif

  reg   [31:0] reg_next_pc;
  wire  [2:0] iq_prefetch_ptr_next = iq_prefetch_ptr + 1;
  wire  stall_prefetch  = (iq_rd_ptr[2] != iq_prefetch_ptr[2]) & 
                          (iq_prefetch_ptr[1] == 1'b1);
  reg   instr_req;
  // assign instr_req_o    = instr_req & ~flush_i;
  // assign instr_addr_o   = reg_next_pc;
  //* TODO, read instr while meeting flush, not one clk later;
  assign instr_req_o    = flush_i | instr_req;
  assign instr_addr_o   = flush_i? branch_pc_i: reg_next_pc;

  always_ff @(posedge clk) begin
    reg_next_pc         <= reg_next_pc;
    instr_req           <= instr_gnt_i? ~stall_prefetch: instr_req;
    iq_prefetch_ptr     <= (instr_gnt_i & instr_req_o)? iq_prefetch_ptr_next: iq_prefetch_ptr;
    `ifdef ENABLE_BP
      btb_ctl_v_o       <= instr_gnt_i & instr_req_o;
    `endif

    if (!resetn) begin
      reg_next_pc       <= PROGADDR_RESET - 4;
      iq_prefetch_ptr   <= '0;
      instr_req         <= '0;
      `ifdef ENABLE_BP
        btb_ctl_v_o     <= '0;
      `endif
    end else begin
      //* add 4;
      reg_next_pc       <= (stall_prefetch | ~instr_gnt_i)? reg_next_pc: 
      `ifdef ENABLE_BP
                            |bm_jump? tgt_hit:
                            |bm_sbp_hit? tgt_sbp_hit:
      `endif
                            (reg_next_pc + 32'd4);
      `ifdef ENABLE_BP
        // btb_ctl_o.hit     <= (stall_prefetch | ~instr_gnt_i)? btb_ctl_o.hit: |bm_hit;
        // btb_ctl_o.jump    <= (stall_prefetch | ~instr_gnt_i)? btb_ctl_o.jump:|bm_jump;
        // btb_ctl_o.tgt     <= (stall_prefetch | ~instr_gnt_i)? btb_ctl_o.tgt: tgt_hit;
        // btb_ctl_o.pc      <= (stall_prefetch | ~instr_gnt_i)? btb_ctl_o.pc:  instr_addr_o[15:0];
        // btb_ctl_o.entryID <= (stall_prefetch | ~instr_gnt_i)? btb_ctl_o.entryID: entryID_hit;
        btb_ctl_o.hit     <= ~instr_gnt_i? btb_ctl_o.hit: |bm_hit;
        btb_ctl_o.sbp_hit <= ~instr_gnt_i? btb_ctl_o.sbp_hit: |bm_sbp_hit;
        btb_ctl_o.jump    <= ~instr_gnt_i? btb_ctl_o.jump:|bm_jump;
        btb_ctl_o.tgt     <= ~instr_gnt_i? btb_ctl_o.tgt: tgt_hit;
        btb_ctl_o.pc      <= ~instr_gnt_i? btb_ctl_o.pc:  instr_addr_o[15:0];
        btb_ctl_o.entryID <= ~instr_gnt_i? btb_ctl_o.entryID: entryID_hit;
      `endif
      //* jalr/bru;
      if(flush_i) begin
        instr_req         <= 1'b1;
        reg_next_pc       <= instr_gnt_i? (
        `ifdef ENABLE_BP
                              |bm_jump? tgt_hit:
                              |bm_sbp_hit? tgt_sbp_hit:
        `endif
                              (branch_pc_i + 4)): 
                              branch_pc_i;
        
        `ifdef ENABLE_BP

          btb_ctl_o.hit     <= ~instr_gnt_i? '0: |bm_hit;
          btb_ctl_o.sbp_hit <= ~instr_gnt_i? '0: |bm_sbp_hit;
          btb_ctl_o.jump    <= ~instr_gnt_i? '0: |bm_jump;
          btb_ctl_o.tgt     <= ~instr_gnt_i? '0: tgt_hit;
          btb_ctl_o.pc      <= ~instr_gnt_i? branch_pc_i:  instr_addr_o[15:0];
          btb_ctl_o.entryID <= ~instr_gnt_i? '0: entryID_hit;
          
          // btb_ctl_o.hit   <= 1'b0;
          // btb_ctl_o.pc    <= branch_pc_i;
        `endif
      end
    end
    reg_next_pc[1:0]    <= '0;
  end

  `ifdef ENABLE_BP
  
  //*        hit_info_layer0
  //*  hit_info_layer1[1]     [0]
  //*          entry[3] [2] [1] [0]

    btb_t btb_entry[3:0];
    reg         hit_info_layer0;
    reg   [1:0] hit_info_layer1;
  
    //* update;
    always_ff @(posedge clk or negedge resetn) begin
      if(~resetn) begin
        for(integer i=0; i<4; i=i+1)
          btb_entry[i].valid <= '0;
        hit_info_layer0   <= '0;
        hit_info_layer1   <= '0;
      end else begin
        if(btb_upd_v_i) begin
          //* add one entry;
          if(btb_upd_info_i.insert_btb) begin
            (*full_case, parallel_case*)
            casez({hit_info_layer0,hit_info_layer1})
              3'b11?: begin
                btb_entry[3].valid  <= 1;
                btb_entry[3].pc     <= btb_upd_info_i.pc;
                btb_entry[3].tgt    <= btb_upd_info_i.tgt;
                btb_entry[3].bht    <= 2'd1;
                // btb_entry[0].bht <= 2'd2;
                hit_info_layer0     <= 1'b0;
                hit_info_layer1[1]  <= 1'b0;
              end
              3'b10?: begin
                btb_entry[2].valid  <= 1;
                btb_entry[2].pc     <= btb_upd_info_i.pc;
                btb_entry[2].tgt    <= btb_upd_info_i.tgt;
                btb_entry[2].bht    <= 2'd1;
                // btb_entry[2].bht <= 2'd2;
                hit_info_layer0     <= 1'b0;
                hit_info_layer1[1]  <= 1'b1;
              end
              3'b0?1: begin
                btb_entry[1].valid  <= 1;
                btb_entry[1].pc     <= btb_upd_info_i.pc;
                btb_entry[1].tgt    <= btb_upd_info_i.tgt;
                btb_entry[1].bht    <= 2'd1;
                // btb_entry[1].bht <= 2'd2;
                hit_info_layer0     <= 1'b1;
                hit_info_layer1[0]  <= 1'b0;
              end
              3'b0?0: begin
                btb_entry[0].valid  <= 1;
                btb_entry[0].pc     <= btb_upd_info_i.pc;
                btb_entry[0].tgt    <= btb_upd_info_i.tgt;
                btb_entry[0].bht    <= 2'd1;
                // btb_entry[0].bht <= 2'd2;
                hit_info_layer0     <= 1'b1;
                hit_info_layer1[0]  <= 1'b1;
              end
              default: begin
              end
            endcase
          end
          //* update one entry;
          else begin
            for(integer i=0; i<4; i=i+1) begin
              if(i== btb_upd_info_i.entryID) begin
                btb_entry[i].tgt    <= btb_upd_info_i.update_tgt? btb_upd_info_i.tgt: btb_entry[i].tgt;
                btb_entry[i].bht    <= btb_upd_info_i.update_bht? (btb_upd_info_i.inc_bht? {|btb_entry[i].bht,btb_entry[i].bht[1]|~btb_entry[i].bht[0]}:
                                                      {&btb_entry[i].bht,btb_entry[i].bht[1]&~btb_entry[i].bht[0]}): btb_entry[i].bht;
              end
            end
            (*full_case, parallel_case*)
            case(btb_upd_info_i.entryID)
              2'd0: begin hit_info_layer0 <= 1'b1; hit_info_layer1[0] <= 1'b1; end
              2'd1: begin hit_info_layer0 <= 1'b1; hit_info_layer1[0] <= 1'b0; end
              2'd2: begin hit_info_layer0 <= 1'b0; hit_info_layer1[0] <= 1'b1; end
              2'd3: begin hit_info_layer0 <= 1'b0; hit_info_layer1[0] <= 1'b0; end
            endcase
          end 
        end
      end
    end

    //* lookup;
    always_comb begin
      for(integer i=0; i<4; i=i+1) begin
        bm_hit[i] = btb_entry[i].valid & 
                    (btb_entry[i].pc == instr_addr_o[15:0]);
      end
      for(integer i=0; i<4; i=i+1) begin
        bm_jump[i] = btb_entry[i].valid & 
                    (btb_entry[i].pc == instr_addr_o[15:0]) &
                    btb_entry[i].bht[1];
      end
    end
    always_comb begin
      tgt_hit     = '0;
      entryID_hit = '0;
      for(integer i=0; i<4; i=i+1) begin
        tgt_hit   = tgt_hit | {16{bm_jump[i]}} & btb_entry[i].tgt;
        entryID_hit = entryID_hit | {2{bm_hit[i]}} & i;
      end
    end

    //* static branch predict, i.e., jal
    sbp_t sbp_entry[3:0];
    reg   [3:0] sbp_freeID;
    
    //* update;
    always_ff @(posedge clk or negedge resetn) begin
      if(~resetn) begin
        sbp_freeID                <= 1;
        for(integer i=0; i<4; i=i+1)
          sbp_entry[i].valid      <= '0;
      end else begin
        if(sbp_upd_v_i) begin
          sbp_freeID              <= {sbp_freeID[2:0],sbp_freeID[3]};
          //* add one entry;
          for(integer i=0; i<4; i=i+1) begin
            if(sbp_freeID[i] == 1'b1) begin
              sbp_entry[i].valid  <= 1;
              sbp_entry[i].pc     <= sbp_upd_i.pc;
              sbp_entry[i].tgt    <= sbp_upd_i.tgt;
            end
          end
        end
      end
    end

    //* lookup;
    always_comb begin
      for(integer i=0; i<4; i=i+1) begin
        bm_sbp_hit[i] = sbp_entry[i].valid & 
                    (sbp_entry[i].pc == instr_addr_o[15:0]);
      end
    end
    always_comb begin
      tgt_sbp_hit     = '0;
      // entryID_sbp_hit = '0;
      for(integer i=0; i<4; i=i+1) begin
        tgt_sbp_hit   = tgt_sbp_hit | {16{bm_sbp_hit[i]}} & sbp_entry[i].tgt;
        // entryID_sbp_hit = entryID_sbp_hit | {2{bm_sbp_hit[i]}} & i;
      end
    end


  `endif

endmodule