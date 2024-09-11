/*************************************************************/
//  Module name: N2_ifu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/21
//  Function outline: instruction fetch unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_ifu #(
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [31:0] PROGADDR_IRQ   = 32'b0,
  parameter        NUM_nBTB       = 4
) (
  input                 clk, resetn, resetn_soc,

  input                 flush_i,
  input   wire  [31:0]  branch_pc_i,
  input   wire          instr_gnt_i,
  output  wire          instr_req_o,
  output  wire  [ 1:0]  instr_req_2b_o,
  output  wire  [31:0]  instr_addr_o,
  output  wire          instr_prefetch_req_o,
  output  wire  [31:0]  instr_prefetch_addr_o,

`ifdef ENABLE_BP
  input   wire          btb_upd_v_ex_i,
  input   btb_t         btb_upd_ex_i,
  input   wire          btb_upd_v_d2_i,
  input   btb_t         btb_upd_d2_i,
  output  reg           btb_ctl_m0_v_o,
  output  btb_ctl_t     btb_ctl_m0_o,
  output  reg           btb_ctl_m1_v_o,
  output  btb_ctl_t     btb_ctl_m1_o,
  input   [15:0]        cpuregs_x1,
`endif

  (* mark_debug = "true"*)output  reg   [ 2:0]  iq_prefetch_ptr,
  (* mark_debug = "true"*)input   wire  [ 2:0]  iq_rd_ptr
);

  `ifdef ENABLE_BP
    logic [NUM_nBTB-1:0]  nanoBTB_jump_m1, nanoBTB_jump_m0, 
                          nanoBTB_update_d2, nanoBTB_update_ex;
    logic [15:0]          nanoBTB_tgt_m0, nanoBTB_tgt_m1, 
                          mBTB_tgt_m0, mBTB_tgt_m1;
    logic                 mBTB_jump_m0, mBTB_jump_m1;
    btb_t                 btb_rst_m0, btb_rst_m1;
  `endif


  reg   [31:0] reg_next_pc;
  wire  [ 2:0] iq_prefetch_ptr_inc1 = iq_prefetch_ptr + 1;
  wire  [ 2:0] iq_prefetch_ptr_inc2 = iq_prefetch_ptr + 2;
  (* mark_debug = "true"*)wire  [ 2:0] iq_usedw = {iq_prefetch_ptr[2]^iq_rd_ptr[2],iq_prefetch_ptr} - {1'b0,iq_rd_ptr};
  wire  stall_prefetch  = iq_usedw[2] & (instr_req_o | iq_usedw[1]);
  reg   instr_req;
  assign instr_req_o    = ~flush_i & instr_req;
  assign instr_addr_o   = reg_next_pc;
  //* instr_req_2b_o is later than instr_req_o, has not been used in combinational logic
  assign instr_req_2b_o = {2{instr_req_o}} &
                          {~(instr_addr_o[2] | (|nanoBTB_jump_m0) | (mBTB_jump_m0)),1'b1};

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
                            |nanoBTB_jump_m0? nanoBTB_tgt_m0:
                            |mBTB_jump_m0? mBTB_tgt_m0:
                            |nanoBTB_jump_m1? nanoBTB_tgt_m1:
                            |mBTB_jump_m1? mBTB_tgt_m1:
      `endif
                            reg_next_pc[2]? (reg_next_pc + 32'd4):
                            (reg_next_pc + 32'd8);
      `ifdef ENABLE_BP
        btb_ctl_m0_o.jump    <= ~instr_gnt_i? btb_ctl_m0_o.jump:|{nanoBTB_jump_m0,mBTB_jump_m0};
        btb_ctl_m0_o.tgt     <= ~instr_gnt_i? btb_ctl_m0_o.tgt: 
                                |nanoBTB_jump_m0? nanoBTB_tgt_m0: mBTB_tgt_m0;
        btb_ctl_m0_o.pc      <= ~instr_gnt_i? btb_ctl_m0_o.pc:  instr_addr_o[15:0];
        btb_ctl_m1_o.jump    <= ~instr_gnt_i? btb_ctl_m1_o.jump:|{nanoBTB_jump_m1,mBTB_jump_m1};
        btb_ctl_m1_o.tgt     <= ~instr_gnt_i? btb_ctl_m1_o.tgt: 
                                |nanoBTB_jump_m1? nanoBTB_tgt_m1: mBTB_tgt_m1;
        btb_ctl_m1_o.pc      <= ~instr_gnt_i? btb_ctl_m1_o.pc:  {instr_addr_o[15:3],3'b100};
      `endif
      // //* jalr/bru;
      // if(flush_i) begin
      //   `ifdef ENABLE_BP
      //     btb_ctl_m0_o.jump    <= 0;
      //     btb_ctl_m0_o.tgt     <= 0;
      //     btb_ctl_m0_o.pc      <= branch_pc_i[15:0];
      //     btb_ctl_m1_o.jump    <= 0;
      //     btb_ctl_m1_o.tgt     <= 0;
      //     btb_ctl_m1_o.pc      <= {branch_pc_i[15:3],3'b100};
      //     // btb_ctl_m0_o.jump    <= ~instr_gnt_i? '0: |nanoBTB_jump_m0;
      //     // btb_ctl_m0_o.tgt     <= ~instr_gnt_i? '0: nanoBTB_tgt_m0;
      //     // btb_ctl_m0_o.pc      <= ~instr_gnt_i? branch_pc_i[15:0]:  instr_addr_o[15:0];
      //     // btb_ctl_m1_o.jump    <= ~instr_gnt_i? '0: |nanoBTB_jump_m1;
      //     // btb_ctl_m1_o.tgt     <= ~instr_gnt_i? '0: nanoBTB_tgt_m1;
      //     // btb_ctl_m1_o.pc      <= ~instr_gnt_i? {branch_pc_i[15:3],3'b100}: {instr_addr_o[15:3],3'b100};
      //   `endif
      // end
    end
    reg_next_pc[1:0]    <= '0;
  end

  `ifdef ENABLE_BP
    btb_t                 btb_entry[NUM_nBTB-1:0];
    reg   [NUM_nBTB-1:0]  btb_freeID;
    wire  [NUM_nBTB-1:0]  btb_freeID_next = {btb_freeID[NUM_nBTB-2:0],btb_freeID[NUM_nBTB-1]};

    //* update nanoBTB;
    always_ff @(posedge clk or negedge resetn) begin
      if(~resetn) begin
        btb_freeID                <= 1;
        for(integer i=0; i<NUM_nBTB; i=i+1)
          btb_entry[i].valid      <= '0;
      end else begin
        (*parallel_case*)
        case({btb_upd_v_ex_i,|nanoBTB_update_ex,
          btb_upd_v_d2_i,|nanoBTB_update_d2 })
          4'b1100, 4'b0011, 4'b1111: begin
            for(integer i=0; i<NUM_nBTB; i=i+1)
              if(nanoBTB_update_ex[i] | nanoBTB_update_d2[i])
                btb_entry[i]      <= nanoBTB_update_ex[i]? btb_upd_ex_i: btb_upd_d2_i;
          end
          4'b1000, 4'b1011: begin
            btb_freeID            <= btb_freeID_next;
            for(integer i=0; i<NUM_nBTB; i=i+1)
              if(btb_freeID[i] | nanoBTB_update_d2[i])
                btb_entry[i]      <= btb_freeID[i]? btb_upd_ex_i: btb_upd_d2_i;
          end
          4'b0010, 4'b1110: begin
            btb_freeID            <= btb_freeID_next;
            for(integer i=0; i<NUM_nBTB; i=i+1)
              if(btb_freeID[i] | nanoBTB_update_ex[i])
                btb_entry[i]      <= btb_freeID[i]? btb_upd_d2_i: btb_upd_ex_i;
          end
          4'b1010: begin
            btb_freeID            <= {btb_freeID[NUM_nBTB-3:0],btb_freeID[NUM_nBTB-1-:2]};
            for(integer i=0; i<NUM_nBTB; i=i+1)
              if(btb_freeID[i] | btb_freeID_next[i])
                btb_entry[i]      <= btb_freeID_next[i]? btb_upd_d2_i: btb_upd_ex_i;
          end
          default: begin 
          end
        endcase
      end
    end

    //* lookup NanoBTB;
    always_comb begin
      for(integer i=0; i<NUM_nBTB; i=i+1) begin
        nanoBTB_jump_m1[i]  =  btb_entry[i].valid & ~instr_addr_o[2] &
                                (btb_entry[i].pc[15:2] == {instr_addr_o[15:3],1'b1});
        nanoBTB_jump_m0[i]  =  btb_entry[i].valid &
                                (btb_entry[i].pc[15:2] == instr_addr_o[15:2]);
      end
    end
    always_comb begin
      nanoBTB_tgt_m0    = '0;
      nanoBTB_tgt_m1    = '0;
      for(integer i=0; i<NUM_nBTB; i=i+1) begin
        nanoBTB_tgt_m0  = nanoBTB_tgt_m0 | {16{nanoBTB_jump_m0[i]}} & btb_entry[i].tgt;
        nanoBTB_tgt_m1  = nanoBTB_tgt_m1 | {16{nanoBTB_jump_m1[i]}} & btb_entry[i].tgt;
      end
    end
    always_comb begin
      for(integer i=0; i<NUM_nBTB; i=i+1) begin
        nanoBTB_update_ex[i] = (btb_entry[i].pc == btb_upd_ex_i.pc);
        nanoBTB_update_d2[i] = (btb_entry[i].pc == btb_upd_d2_i.pc);
      end
    end

    //* lookup btb
    always_comb begin
      mBTB_jump_m0 = (btb_rst_m0.pc == instr_addr_o[15:0]) & btb_rst_m0.valid |
                     (btb_rst_m1.pc == instr_addr_o[15:0]) & btb_rst_m1.valid;
      mBTB_jump_m1 = (btb_rst_m1.pc == {instr_addr_o[15:3],3'b100}) & btb_rst_m1.valid;
      mBTB_tgt_m0  = ((btb_rst_m0.pc == instr_addr_o[15:0]) & btb_rst_m0.valid)? 
                       ({16{~btb_rst_m0.is_jarl}} & btb_rst_m0.tgt | 
                        {16{ btb_rst_m0.is_jarl}} & cpuregs_x1): 
                       ({16{~btb_rst_m1.is_jarl}} & btb_rst_m1.tgt | 
                        {16{ btb_rst_m1.is_jarl}} & cpuregs_x1);
      mBTB_tgt_m1  = ({16{~btb_rst_m1.is_jarl}} & btb_rst_m1.tgt | 
                      {16{ btb_rst_m1.is_jarl}} & cpuregs_x1);
    end
    
    reg  [15:0] r_lookup_pc;
    wire [15:0] lookup_pc = flush_i? {branch_pc_i[15:3],3'b0}:
                            (~stall_prefetch & instr_gnt_i)? ({instr_addr_o[15:3],3'b0} + 8):
                              r_lookup_pc;
    always_ff @(posedge clk or posedge resetn) begin
      r_lookup_pc     <= lookup_pc;
      if(!resetn)
        r_lookup_pc   <= PROGADDR_RESET;
    end
    N2_ifu_btb N2_ifu_btb(
      .clk            (clk            ),
      .resetn         (resetn_soc     ),
      .lookup_pc_i    (lookup_pc      ),
      .btb_rst_m0_o   (btb_rst_m0     ),
      .btb_rst_m1_o   (btb_rst_m1     ),

      .btb_upd_v_ex_i (btb_upd_v_ex_i ),
      .btb_upd_ex_i   (btb_upd_ex_i   ),
      .btb_upd_v_d2_i (btb_upd_v_d2_i ),
      .btb_upd_d2_i   (btb_upd_d2_i   )
    );

  `endif

endmodule

module N2_ifu_btb #(
  parameter             NUM_mBTB = 512
) (
  input                 clk, resetn,

  input                 flush_i,
  input   wire  [15:0]  lookup_pc_i,
  output  btb_t         btb_rst_m0_o,
  output  btb_t         btb_rst_m1_o,

  input   wire          btb_upd_v_ex_i,
  input   btb_t         btb_upd_ex_i,
  input   wire          btb_upd_v_d2_i,
  input   btb_t         btb_upd_d2_i
);
  localparam DEPTH_mBTB = $clog2(NUM_mBTB);

// btb_t  mbtb_entry[NUM_mBTB-1:0];
wire   [15:0] lookup_pc_m1 = {lookup_pc_i[15:3],3'b100};

// always_ff @(posedge clk or negedge resetn) begin
//   btb_rst_m0_o  <=  mbtb_entry[lookup_pc_i[2+:DEPTH_mBTB]];
//   btb_rst_m1_o  <=  mbtb_entry[lookup_pc_m1[2+:DEPTH_mBTB]];
//   if(btb_upd_v_ex_i)
//     for(integer i=0; i<NUM_mBTB; i=i+1) begin
//       if(i == btb_upd_ex_i.pc[2+:DEPTH_mBTB]) begin
//           mbtb_entry[i] <= btb_upd_ex_i;
//       end
//     end
//   if(btb_upd_v_d2_i)
//     for(integer i=0; i<NUM_mBTB; i=i+1) begin
//       if(i == btb_upd_d2_i.pc[2+:DEPTH_mBTB]) begin
//           mbtb_entry[i] <= btb_upd_d2_i;
//       end
//     end
//   if(!resetn) begin
//     for(integer i=0; i<NUM_mBTB; i=i+1)
//       mbtb_entry[i].valid <= 0;
//   end
// end

  reg           wren_bank0, wren_bank1;
  reg   [33:0]  wdata_bank0, wdata_bank1;
  reg   [ 8:0]  addr_bank0, addr_bank1;
  reg           state_btb;
  localparam    IDLE_S  = 0,
                READY_S = 1;


  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      wren_bank0          <= 1'b0;
      wren_bank1          <= 1'b0;
      addr_bank1          <= '0;
      addr_bank0          <= '0;
      state_btb           <= IDLE_S;
    end
    else begin
      wren_bank0          <= btb_upd_v_ex_i & ~btb_upd_ex_i.pc[2] |
                              btb_upd_v_d2_i & ~btb_upd_d2_i.pc[2];
      wren_bank1          <= btb_upd_v_ex_i & btb_upd_ex_i.pc[2] |
                              btb_upd_v_d2_i & btb_upd_d2_i.pc[2];
      wdata_bank0         <= btb_upd_v_ex_i & ~btb_upd_ex_i.pc[2]? 
                             {btb_upd_ex_i.valid, btb_upd_ex_i.is_jarl, 
                              btb_upd_ex_i.pc, btb_upd_ex_i.tgt}: 
                             {btb_upd_d2_i.valid, btb_upd_d2_i.is_jarl, 
                              btb_upd_d2_i.pc, btb_upd_d2_i.tgt}; 
      wdata_bank1         <= btb_upd_v_ex_i & btb_upd_ex_i.pc[2]? 
                             {btb_upd_ex_i.valid, btb_upd_ex_i.is_jarl, 
                              btb_upd_ex_i.pc, btb_upd_ex_i.tgt}: 
                             {btb_upd_d2_i.valid, btb_upd_d2_i.is_jarl, 
                              btb_upd_d2_i.pc, btb_upd_d2_i.tgt}; 
      addr_bank0          <= btb_upd_v_ex_i & ~btb_upd_ex_i.pc[2]? 
                             btb_upd_ex_i.pc[3+:9]: btb_upd_d2_i.pc[3+:9];
      addr_bank1          <= btb_upd_v_ex_i & btb_upd_ex_i.pc[2]? 
                             btb_upd_ex_i.pc[3+:9]: btb_upd_d2_i.pc[3+:9];
      case(state_btb)
        IDLE_S: begin
          addr_bank0      <= addr_bank1 + 1;
          addr_bank1      <= addr_bank1 + 1;
          wren_bank0      <= 1;
          wren_bank1      <= 1;
          wdata_bank0     <= '0;
          wdata_bank1     <= '0;
          if(addr_bank0 == 9'h1ff) begin
            state_btb     <= READY_S;
          end
        end
        READY_S: begin
        end
        default: begin end
      endcase
    end
  end

  `ifdef XILINX_FIFO_RAM
    ram_34_512 btb_bank0(
      .clka   (clk                    ),
      .wea    (wren_bank0             ),
      .addra  (addr_bank0             ),
      .dina   (wdata_bank0            ),
      .douta  (                       ),
      .clkb   (clk                    ),
      .web    ('0                     ),
      .addrb  (lookup_pc_i[3+:9]      ),
      .dinb   ('0                     ),
      .doutb  ({btb_rst_m1_o.valid,
                btb_rst_m1_o.is_jarl,
                btb_rst_m1_o.pc,
                btb_rst_m1_o.tgt}     )
    );

    ram_34_512 btb_bank1(
      .clka   (clk                    ),
      .wea    (wren_bank1             ),
      .addra  (addr_bank0             ),
      .dina   (wdata_bank1            ),
      .douta  (                       ),
      .clkb   (clk                    ),
      .web    ('0                     ),
      .addrb  (lookup_pc_m1[3+:9]     ),
      .dinb   ('0                     ),
      .doutb  ({btb_rst_m0_o.valid,
                btb_rst_m0_o.is_jarl,
                btb_rst_m0_o.pc,
                btb_rst_m0_o.tgt}     )
    );
  `elsif SIM_FIFO_RAM
    syncram btb_bank0(
      .address_a  (addr_bank0             ),
      .address_b  (lookup_pc_i[3+:9]      ),
      .clock      (clk                    ),
      .data_a     (wdata_bank0            ),
      .data_b     ('0                     ),
      .rden_a     (                       ),
      .rden_b     (1'b1                   ),
      .wren_a     (wren_bank0             ),
      .wren_b     ('0                     ),
      .q_a        (                       ),
      .q_b        ({btb_rst_m0_o.valid,
                    btb_rst_m0_o.is_jarl,
                    btb_rst_m0_o.pc,
                    btb_rst_m0_o.tgt}     )
    );
    defparam  btb_bank0.BUFFER= 0,
              btb_bank0.width = 34,
              btb_bank0.depth = 9,
              btb_bank0.words = 512;
    syncram btb_bank1(
      .address_a  (addr_bank1             ),
      .address_b  (lookup_pc_m1[3+:9]     ),
      .clock      (clk                    ),
      .data_a     (wdata_bank1            ),
      .data_b     ('0                     ),
      .rden_a     (                       ),
      .rden_b     (1'b1                   ),
      .wren_a     (wren_bank1             ),
      .wren_b     ('0                     ),
      .q_a        (                       ),
      .q_b        ({btb_rst_m1_o.valid,
                    btb_rst_m1_o.is_jarl,
                    btb_rst_m1_o.pc,
                    btb_rst_m1_o.tgt}     )
    );
    defparam  btb_bank1.BUFFER= 0,
              btb_bank1.width = 34,
              btb_bank1.depth = 9,
              btb_bank1.words = 512;
  `endif

endmodule