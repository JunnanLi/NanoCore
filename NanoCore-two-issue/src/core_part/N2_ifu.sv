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
  output  wire  [ 1:0]  instr_req_2b_o,
  output  wire  [31:0]  instr_addr_o,

`ifdef ENABLE_BP
  input   wire          btb_upd_v_i,
  input   btb_update_t  btb_upd_info_i,
  output  reg           btb_ctl_m0_v_o,
  output  btb_ctl_t     btb_ctl_m0_o,
  output  reg           btb_ctl_m1_v_o,
  output  btb_ctl_t     btb_ctl_m1_o,
  input   wire          sbp_upd_v_i,
  input   sbp_update_t  sbp_upd_i,
`endif

  output  reg   [ 2:0]  iq_prefetch_ptr,
  input   wire  [ 2:0]  iq_rd_ptr
);

  `ifdef ENABLE_BP
    logic [ 3:0]  bm_hit_m0, bm_jump_m0, bm_sbp_hit_m0,
                  bm_hit_m1, bm_jump_m1, bm_sbp_hit_m1;
    logic [15:0]  tgt_hit_m0, tgt_hit_m1, 
                  tgt_sbp_hit_m0, tgt_sbp_hit_m1;
    logic [ 1:0]  entryID_hit_m0, entryID_hit_m1;
  `endif

  reg   [31:0] reg_next_pc;
  wire  [ 2:0] iq_prefetch_ptr_inc1 = iq_prefetch_ptr + 1;
  wire  [ 2:0] iq_prefetch_ptr_inc2 = iq_prefetch_ptr + 2;
  wire  [ 2:0] iq_usedw = {iq_prefetch_ptr[2]^iq_rd_ptr[2],iq_prefetch_ptr} - {1'b0,iq_rd_ptr};
  wire  stall_prefetch  = iq_usedw[2];
  // wire  stall_prefetch  = (iq_rd_ptr[2] != iq_prefetch_ptr[2]) & 
  //                         (iq_prefetch_ptr[1] == 1'b1);
  reg   instr_req;
  assign instr_req_o    = ~flush_i & instr_req;
  assign instr_addr_o   = reg_next_pc;
  // assign instr_req_o    = flush_i | instr_req;
  // assign instr_addr_o   = flush_i? branch_pc_i: reg_next_pc;
  //* instr_req_2b_o is later than instr_req_o, has not been used in combinational logic
  assign instr_req_2b_o = {2{instr_req_o}} &
                          {~(instr_addr_o[2] | (|bm_jump_m0) | (|bm_sbp_hit_m0)),1'b1};

  always_ff @(posedge clk) begin
    reg_next_pc         <= reg_next_pc;
    instr_req           <= (instr_gnt_i? ~stall_prefetch: instr_req) | flush_i;
    iq_prefetch_ptr     <= (instr_gnt_i & instr_req_2b_o[1])? iq_prefetch_ptr_inc2:
                           (instr_gnt_i & instr_req_2b_o[0])? iq_prefetch_ptr_inc1: iq_prefetch_ptr;
    `ifdef ENABLE_BP
      btb_ctl_m0_v_o    <= instr_gnt_i & instr_req_2b_o[0];
      btb_ctl_m1_v_o    <= instr_gnt_i & instr_req_2b_o[1];
    `endif

    if (!resetn) begin
      reg_next_pc       <= PROGADDR_RESET - 4;
      iq_prefetch_ptr   <= '0;
      instr_req         <= '0;
      `ifdef ENABLE_BP
        btb_ctl_m0_v_o  <= '0;
        btb_ctl_m1_v_o  <= '0;
      `endif
    end else begin
      //* add 4/8;
      reg_next_pc       <= flush_i? branch_pc_i:
                          (stall_prefetch | ~instr_gnt_i)? reg_next_pc: 
      `ifdef ENABLE_BP
                            |bm_sbp_hit_m0? tgt_sbp_hit_m0:
                            |bm_jump_m0? tgt_hit_m0:
                            |bm_sbp_hit_m1? tgt_sbp_hit_m1:
                            |bm_jump_m1? tgt_hit_m1:
                            // |bm_sbp_hit? tgt_sbp_hit:
                            // |bm_jump? tgt_hit:
      `endif
                            reg_next_pc[2]? (reg_next_pc + 32'd4):
                            (reg_next_pc + 32'd8);
      `ifdef ENABLE_BP
        btb_ctl_m0_o.hit     <= ~instr_gnt_i? btb_ctl_m0_o.hit: |bm_hit_m0;
        btb_ctl_m0_o.sbp_hit <= ~instr_gnt_i? btb_ctl_m0_o.sbp_hit: |bm_sbp_hit_m0;
        btb_ctl_m0_o.jump    <= ~instr_gnt_i? btb_ctl_m0_o.jump:|bm_jump_m0;
        btb_ctl_m0_o.tgt     <= ~instr_gnt_i? btb_ctl_m0_o.tgt: tgt_hit_m0;
        btb_ctl_m0_o.pc      <= ~instr_gnt_i? btb_ctl_m0_o.pc:  instr_addr_o[15:0];
        btb_ctl_m0_o.entryID <= ~instr_gnt_i? btb_ctl_m0_o.entryID: entryID_hit_m0;

        btb_ctl_m1_o.hit     <= ~instr_gnt_i? btb_ctl_m1_o.hit: |bm_hit_m1;
        btb_ctl_m1_o.sbp_hit <= ~instr_gnt_i? btb_ctl_m1_o.sbp_hit: |bm_sbp_hit_m1;
        btb_ctl_m1_o.jump    <= ~instr_gnt_i? btb_ctl_m1_o.jump:|bm_jump_m1;
        btb_ctl_m1_o.tgt     <= ~instr_gnt_i? btb_ctl_m1_o.tgt: tgt_hit_m1;
        btb_ctl_m1_o.pc      <= ~instr_gnt_i? btb_ctl_m1_o.pc:  {instr_addr_o[15:3],3'b100};
        btb_ctl_m1_o.entryID <= ~instr_gnt_i? btb_ctl_m1_o.entryID: entryID_hit_m1;
      `endif
      //* jalr/bru;
      if(flush_i) begin
        // instr_req         <= 1'b1;
        // reg_next_pc       <= instr_gnt_i? (
        // `ifdef ENABLE_BP
        //                       |bm_sbp_hit_m0? tgt_sbp_hit_m0:
        //                       |bm_jump_m0? tgt_hit_m0:
        //                       |bm_sbp_hit_m1? tgt_sbp_hit_m1:
        //                       |bm_jump_m1? tgt_hit_m1:
        //                       // |bm_sbp_hit? tgt_sbp_hit:
        //                       // |bm_jump? tgt_hit:
        // `endif
        //                       branch_pc_i[2]? (branch_pc_i + 4):
        //                       (branch_pc_i + 8)): 
        //                       branch_pc_i;
        
        `ifdef ENABLE_BP
          btb_ctl_m0_o.hit     <= ~instr_gnt_i? '0: |bm_hit_m0;
          btb_ctl_m0_o.sbp_hit <= ~instr_gnt_i? '0: |bm_sbp_hit_m0;
          btb_ctl_m0_o.jump    <= ~instr_gnt_i? '0: |bm_jump_m0;
          btb_ctl_m0_o.tgt     <= ~instr_gnt_i? '0: tgt_hit_m0;
          btb_ctl_m0_o.pc      <= ~instr_gnt_i? branch_pc_i[15:0]:  instr_addr_o[15:0];
          btb_ctl_m0_o.entryID <= ~instr_gnt_i? '0: entryID_hit_m0;
          btb_ctl_m1_o.hit     <= ~instr_gnt_i? '0: |bm_hit_m1;
          btb_ctl_m1_o.sbp_hit <= ~instr_gnt_i? '0: |bm_sbp_hit_m1;
          btb_ctl_m1_o.jump    <= ~instr_gnt_i? '0: |bm_jump_m1;
          btb_ctl_m1_o.tgt     <= ~instr_gnt_i? '0: tgt_hit_m1;
          btb_ctl_m1_o.pc      <= ~instr_gnt_i? {branch_pc_i[15:3],3'b100}: {instr_addr_o[15:3],3'b100};
          btb_ctl_m1_o.entryID <= ~instr_gnt_i? '0: entryID_hit_m1;
        `endif
      end
    end
    reg_next_pc[1:0]    <= '0;
  end

  `ifdef ENABLE_BP
  
  //*        hit_info_layer0
  //*  hit_info_layer1[1]     [0]
  //*          entry[3] [2] [1] [0]

    btb_t       btb_entry[3:0];
    reg   [3:0] btb_freeID;
    reg         hit_info_layer0;
    reg   [1:0] hit_info_layer1;
  

    //* update btb;
    always_ff @(posedge clk or negedge resetn) begin
      if(~resetn) begin
        btb_freeID                <= 1;
        for(integer i=0; i<4; i=i+1)
          btb_entry[i].valid      <= '0;
      end else begin
        if(btb_upd_v_i) begin
          btb_freeID              <= {btb_freeID[2:0],btb_freeID[3]};
          //* add one entry;
          if(btb_upd_info_i.insert_btb) begin
            for(integer i=0; i<4; i=i+1) begin
              if(btb_freeID[i] == 1'b1) begin
                btb_entry[i].valid  <= 1;
                btb_entry[i].pc     <= btb_upd_info_i.pc;
                btb_entry[i].tgt    <= btb_upd_info_i.tgt;
                btb_entry[i].bht    <= 2'd1;
              end
            end
          end
          else begin
            for(integer i=0; i<4; i=i+1) begin
              if(i== btb_upd_info_i.entryID) begin
                btb_entry[i].tgt    <= btb_upd_info_i.update_tgt? 
                                        btb_upd_info_i.tgt: btb_entry[i].tgt;
                btb_entry[i].bht    <= btb_upd_info_i.update_bht? 
                                        (btb_upd_info_i.inc_bht? 
                                          {|btb_entry[i].bht,btb_entry[i].bht[1]|~btb_entry[i].bht[0]}:
                                          {&btb_entry[i].bht,btb_entry[i].bht[1]&~btb_entry[i].bht[0]}): 
                                            btb_entry[i].bht;
              end
            end
          end
        end
      end
    end

    // //* update btb;
    // always_ff @(posedge clk or negedge resetn) begin
    //   if(~resetn) begin
    //     for(integer i=0; i<4; i=i+1)
    //       btb_entry[i].valid <= '0;
    //     hit_info_layer0   <= '0;
    //     hit_info_layer1   <= '0;
    //   end else begin
    //     if(btb_upd_v_i) begin
    //       //* add one entry;
    //       if(btb_upd_info_i.insert_btb) begin
    //         (*full_case, parallel_case*)
    //         casez({hit_info_layer0,hit_info_layer1})
    //           3'b11?: begin
    //             btb_entry[3].valid  <= 1;
    //             btb_entry[3].pc     <= btb_upd_info_i.pc;
    //             btb_entry[3].tgt    <= btb_upd_info_i.tgt;
    //             btb_entry[3].bht    <= 2'd1;
    //             // btb_entry[0].bht <= 2'd2;
    //             hit_info_layer0     <= 1'b0;
    //             hit_info_layer1[1]  <= 1'b0;
    //           end
    //           3'b10?: begin
    //             btb_entry[2].valid  <= 1;
    //             btb_entry[2].pc     <= btb_upd_info_i.pc;
    //             btb_entry[2].tgt    <= btb_upd_info_i.tgt;
    //             btb_entry[2].bht    <= 2'd1;
    //             // btb_entry[2].bht <= 2'd2;
    //             hit_info_layer0     <= 1'b0;
    //             hit_info_layer1[1]  <= 1'b1;
    //           end
    //           3'b0?1: begin
    //             btb_entry[1].valid  <= 1;
    //             btb_entry[1].pc     <= btb_upd_info_i.pc;
    //             btb_entry[1].tgt    <= btb_upd_info_i.tgt;
    //             btb_entry[1].bht    <= 2'd1;
    //             // btb_entry[1].bht <= 2'd2;
    //             hit_info_layer0     <= 1'b1;
    //             hit_info_layer1[0]  <= 1'b0;
    //           end
    //           3'b0?0: begin
    //             btb_entry[0].valid  <= 1;
    //             btb_entry[0].pc     <= btb_upd_info_i.pc;
    //             btb_entry[0].tgt    <= btb_upd_info_i.tgt;
    //             btb_entry[0].bht    <= 2'd1;
    //             // btb_entry[0].bht <= 2'd2;
    //             hit_info_layer0     <= 1'b1;
    //             hit_info_layer1[0]  <= 1'b1;
    //           end
    //           default: begin
    //           end
    //         endcase
    //       end
    //       //* update one entry;
    //       else begin
    //         for(integer i=0; i<4; i=i+1) begin
    //           if(i== btb_upd_info_i.entryID) begin
    //             btb_entry[i].tgt    <= btb_upd_info_i.update_tgt? btb_upd_info_i.tgt: btb_entry[i].tgt;
    //             btb_entry[i].bht    <= btb_upd_info_i.update_bht? (btb_upd_info_i.inc_bht? {|btb_entry[i].bht,btb_entry[i].bht[1]|~btb_entry[i].bht[0]}:
    //                                                   {&btb_entry[i].bht,btb_entry[i].bht[1]&~btb_entry[i].bht[0]}): btb_entry[i].bht;
    //           end
    //         end
    //         (*full_case, parallel_case*)
    //         case(btb_upd_info_i.entryID)
    //           2'd0: begin hit_info_layer0 <= 1'b1; hit_info_layer1[0] <= 1'b1; end
    //           2'd1: begin hit_info_layer0 <= 1'b1; hit_info_layer1[0] <= 1'b0; end
    //           2'd2: begin hit_info_layer0 <= 1'b0; hit_info_layer1[0] <= 1'b1; end
    //           2'd3: begin hit_info_layer0 <= 1'b0; hit_info_layer1[0] <= 1'b0; end
    //         endcase
    //       end 
    //     end
    //   end
    // end

    //* lookup btb;
    always_comb begin
      for(integer i=0; i<4; i=i+1) begin
        bm_hit_m0[i]  = btb_entry[i].valid & 
                      (btb_entry[i].pc == instr_addr_o[15:0]);
      end
      for(integer i=0; i<4; i=i+1) begin
        bm_jump_m0[i] = btb_entry[i].valid & 
                      (btb_entry[i].pc == instr_addr_o[15:0]) &
                      btb_entry[i].bht[1];
      end
      for(integer i=0; i<4; i=i+1) begin
        bm_hit_m1[i]  = btb_entry[i].valid & 
                      (btb_entry[i].pc == {instr_addr_o[15:3],3'b100}) & ~instr_addr_o[2];
      end
      for(integer i=0; i<4; i=i+1) begin
        bm_jump_m1[i] = btb_entry[i].valid & 
                      (btb_entry[i].pc == {instr_addr_o[15:3],3'b100}) & ~instr_addr_o[2] &
                      btb_entry[i].bht[1];
      end
    end
    always_comb begin
      tgt_hit_m0  = '0;
      tgt_hit_m1  = '0;
      entryID_hit_m0 = '0;
      entryID_hit_m1 = '0;
      for(integer i=0; i<4; i=i+1) begin
        tgt_hit_m0   = tgt_hit_m0 | {16{bm_jump_m0[i]}} & btb_entry[i].tgt;
        tgt_hit_m1   = tgt_hit_m1 | {16{bm_jump_m1[i]}} & btb_entry[i].tgt;
        entryID_hit_m0 = entryID_hit_m0 | {2{bm_hit_m0[i]}} & i;
        entryID_hit_m1 = entryID_hit_m1 | {2{bm_hit_m1[i]}} & i;
      end
    end

    //* static branch predict, i.e., jal
    sbp_t sbp_entry[3:0];
    reg   [3:0] sbp_freeID;
    
    //* update sbp;
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

    //* lookup sbp;
    always_comb begin
      for(integer i=0; i<4; i=i+1) begin
        bm_sbp_hit_m0[i]  = sbp_entry[i].valid & 
                          (sbp_entry[i].pc == instr_addr_o[15:0]);
      end
      for(integer i=0; i<4; i=i+1) begin
        bm_sbp_hit_m1[i]  = sbp_entry[i].valid & 
                          (sbp_entry[i].pc == {instr_addr_o[15:3],3'b100}) & ~instr_addr_o[2];
      end
    end
    always_comb begin
      tgt_sbp_hit_m0  = '0;
      tgt_sbp_hit_m1  = '0;
      for(integer i=0; i<4; i=i+1) begin
        tgt_sbp_hit_m0= tgt_sbp_hit_m0 | {16{bm_sbp_hit_m0[i]}} & sbp_entry[i].tgt;
        tgt_sbp_hit_m1= tgt_sbp_hit_m1 | {16{bm_sbp_hit_m1[i]}} & sbp_entry[i].tgt;
      end
    end

    //* TODO, jalr

  `endif

endmodule