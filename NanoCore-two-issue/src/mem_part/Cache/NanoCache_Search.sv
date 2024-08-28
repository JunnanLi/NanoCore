/*
 *  Project:            NanoCore -- a RISCV-32MC SoC.
 *  Module name:        NanoCache_Search.
 *  Description:        cache of nano core.
 *  Last updated date:  2024.2.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */

// `ifdef WRITE_AFTER_READ

module NanoCache_Search #(
  parameter DATA_WIDTH = 32,
  parameter RDEN_WIDTH = 1
) (
  //* clk & reset;
  input   wire                        i_clk,
  input   wire                        i_rst_n,

  //* interface for PEs;
  input   wire                        i_cache_rden,
  input   wire  [RDEN_WIDTH-1:0]      i_cache_rden_v,
  input   wire                        i_cache_wren,
  input   wire  [31:0]                i_cache_addr,
  input   wire  [31:0]                i_cache_wdata,
  input   wire  [ 3:0]                i_cache_wstrb,
  output  wire  [DATA_WIDTH-1:0]      o_cache_rdata,
  output  wire                        o_cache_rvalid_ns,
  output  reg   [RDEN_WIDTH-1:0]      o_cache_rvalid,
  output  wire                        o_cache_gnt,

  //* interface for reading SRAM by cache;
  output  reg                         o_wb_wren,
  input   wire                        i_wb_gnt,
  output  reg                         o_miss_rden,
  output  reg                         o_miss_wren,
  output  reg   [31:0]                o_miss_addr,
  output  logic [7:0][31:0]           o_miss_wdata,
  input   wire                        i_miss_resp,
  input   wire                        i_upd_valid,
  input   wire  [7:0][31:0]           i_upd_rdata
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  reg   [`NUM_CACHE-1:0][7:0][31:0]   r_cached_data;
  reg   [`NUM_CACHE-1:0]              r_tag_valid, r_tag_dirty;
  reg   [`NUM_CACHE-1:0]              r_vic, r_to_wb;
  reg   [`NUM_CACHE-1:0][15:0]        r_tag_addr;
  logic [`NUM_CACHE-1:0]              w_hit;
  logic [7:0][31:0]                   l_miss_wdata;
  logic [7:0][31:0]                   l_wb_wdata;
  logic [15:0]                        l_wb_addr;
  logic                               l_wait_wb;
  reg                                 r_lock_gnt;
  reg                                 r_re_rden, r_re_wren, r_temp_rdwr;
  reg                                 r_wait_to_read, r_wait_to_rd_after_wr;
  reg                                 r_upd_valid_delay;
  logic [7:0][31:0]                   w_upd_rdata;
  reg   [31:0]                        q_cache_wdata, q_cache_addr;
  reg   [ 3:0]                        q_cache_wstrb;
  reg   [RDEN_WIDTH-1:0]              q_cache_rden;
  reg   [63:0]                        r_cache_rdata;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  assign o_cache_rdata = r_cache_rdata[DATA_WIDTH-1:0]; 
  assign o_miss_wdata = o_wb_wren? l_wb_wdata: l_miss_wdata;
  always_comb begin
    l_miss_wdata        = '0;
    l_wb_wdata          = '0;
    l_wb_addr           = '0;
    l_wait_wb           = '0;
    for(integer i=0; i<`NUM_CACHE; i=i+1) begin
      l_miss_wdata      = l_miss_wdata | {256{r_vic[i]}} & r_cached_data[i];
      l_wb_wdata        = l_wb_wdata | {256{r_to_wb[i]}} & r_cached_data[i];
      l_wb_addr         = l_wb_addr | {16{r_to_wb[i]}} & r_tag_addr[i];
      l_wait_wb         = l_wait_wb | r_to_wb[i] & r_tag_dirty[i] & r_tag_valid[i];
      w_hit[i]          = r_tag_valid[i]==1'b1 && r_tag_addr[i] == i_cache_addr[5+:16];
    end
  end
  logic [7:0][31:0] w_hit_data;
  always_comb begin
    w_hit_data          = '0;
    for(integer i=0; i<`NUM_CACHE; i=i+1) begin
      w_hit_data        = w_hit_data | {256{w_hit[i]}} & r_cached_data[i];
    end
  end
  logic w_miss_tag_dirty;
  logic [15:0]  w_miss_tag_addr;
  always_comb begin
    w_miss_tag_dirty    = '0;
    w_miss_tag_addr     = '0;
    for(integer i=0; i<`NUM_CACHE; i=i+1) begin
      w_miss_tag_dirty  = w_miss_tag_dirty | r_vic[i] & r_tag_dirty[i];
      w_miss_tag_addr   = w_miss_tag_addr  | {16{r_vic[i]}} & r_tag_addr[i];
    end
  end
  assign o_cache_gnt    = ~(o_miss_rden|o_miss_wren|r_wait_to_read) & r_lock_gnt;
  assign o_cache_rvalid_ns = i_cache_rden & (|w_hit);

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      o_cache_rvalid          <= '0;
      o_miss_rden             <= '0;
      o_miss_wren             <= '0;
      o_wb_wren               <= '0;

      r_tag_valid             <= '0;
      r_tag_dirty             <= '0;
      r_vic                   <= 1;
      r_to_wb                 <= 1;

      r_lock_gnt              <= 1'b1;
      r_re_rden               <= '0;
      r_re_wren               <= '0;
      r_temp_rdwr             <= '0;
      r_wait_to_read          <= '0;
      r_wait_to_rd_after_wr   <= '0;
      r_upd_valid_delay       <= '0;
    end else begin
      //* serach;
      r_upd_valid_delay       <= i_upd_valid;
      r_lock_gnt              <=  r_upd_valid_delay? 1'b1: 
                                  (o_miss_rden|o_miss_wren)? 1'b0: r_lock_gnt;

      o_cache_rvalid          <= '0;
      o_miss_rden             <= i_miss_resp? 1'b0: o_miss_rden;
      o_miss_wren             <= i_miss_resp? 1'b0: o_miss_wren;
      o_miss_addr             <= i_miss_resp? {5'b0,i_cache_addr[31:5]} : o_miss_addr;
      r_re_rden               <= 1'b0;
      r_re_wren               <= 1'b0;
      o_wb_wren               <= 1'b0;
      if(i_cache_rden == 1'b1 || r_re_rden == 1'b1) 
      begin
        // r_vic                 <= (|w_hit)? w_hit[0]: r_vic;
        if(|w_hit) begin
          // o_cache_rvalid      <= 1'b1;
          o_cache_rvalid      <= i_cache_rden_v;
          r_cache_rdata       <= i_cache_addr[2]? {2{w_hit_data[i_cache_addr[2+:3]]}}:
                                  {w_hit_data[i_cache_addr[2+:3]+1],w_hit_data[i_cache_addr[2+:3]]};
        end
        else begin
          o_cache_rvalid      <= '0;
          r_temp_rdwr         <= 1'b1;

          o_miss_wren         <= w_miss_tag_dirty;
          o_miss_addr         <= w_miss_tag_dirty? {16'b0,w_miss_tag_addr}: {5'b0,i_cache_addr[31:5]};
          o_miss_rden         <= ~w_miss_tag_dirty;
          r_wait_to_rd_after_wr  <= w_miss_tag_dirty;
          for(integer i=0; i<`NUM_CACHE; i=i+1)
            if(r_vic[i]) begin
              r_tag_addr[i]   <= i_cache_addr[5+:16];
              r_tag_dirty[i]  <= 1'b0;
            end
        end
      end
      else if(r_wait_to_read || r_wait_to_rd_after_wr & i_miss_resp) begin
        r_wait_to_read        <= 'b0;
        r_wait_to_rd_after_wr <= 'b0;
        
        o_cache_rvalid        <= '0;
        o_miss_rden           <= 1'b1;
        // if(r_vic == 1'd0)
        //   r_tag_addr[0]       <= i_cache_addr[5+:16];
        // else
        //   r_tag_addr[1]       <= i_cache_addr[5+:16];
      end
      else if(i_cache_wren == 1'b1 || r_re_wren == 1'b1) begin
        // r_vic                 <= (|w_hit)? w_hit[0]: r_vic;
        if(|w_hit) begin
          o_cache_rvalid      <= {RDEN_WIDTH{1'b1}};
          r_cache_rdata       <= {2{w_hit_data[i_cache_addr[2+:3]]}};
          for(integer idx=0; idx<`NUM_CACHE; idx=idx+1)
            if(w_hit[idx]) begin
              r_tag_dirty[idx]  <= 1'b1;
              for(integer i=0; i<8; i++) begin
                if(i== i_cache_addr[2+:3])
                  r_cached_data[idx][i] <= ({{8{i_cache_wstrb[3]}},{8{i_cache_wstrb[2]}},
                                            {8{i_cache_wstrb[1]}},{8{i_cache_wstrb[0]}}} & i_cache_wdata) |
                                          ({{8{~i_cache_wstrb[3]}},{8{~i_cache_wstrb[2]}},
                                            {8{~i_cache_wstrb[1]}},{8{~i_cache_wstrb[0]}}} & r_cached_data[idx][i]);
              end
            end
        end
        else begin
          o_cache_rvalid      <= 'b0;
          r_temp_rdwr         <= 1'b0;

          o_miss_wren         <= w_miss_tag_dirty;
          o_miss_addr         <= w_miss_tag_dirty? {16'b0,w_miss_tag_addr}: {5'b0,i_cache_addr[31:5]};
          o_miss_rden         <= ~w_miss_tag_dirty;
          r_wait_to_read      <= w_miss_tag_dirty;
          for(integer i=0; i<`NUM_CACHE; i=i+1)
            if(r_vic[i]) begin
              r_tag_addr[i]   <= i_cache_addr[5+:16];
              r_tag_dirty[i]  <= 1'b0;
            end
        end
      end
      else begin
        //* write back while ram port is free;
        if(~o_wb_wren) begin
          o_wb_wren           <= l_wait_wb;
          o_miss_addr         <= l_wb_addr;
        end
        if(~l_wait_wb) begin
          r_to_wb             <= {r_to_wb[`NUM_CACHE-2:0],r_to_wb[`NUM_CACHE-1]};
        end
        if(i_wb_gnt) begin
          for(integer i=0; i<`NUM_CACHE; i=i+1) begin
            if(r_to_wb[i] == 1'b1) begin
              r_tag_dirty[i]  <= '0;
            end
          end
        end
      end
    
      //* update
      if(i_upd_valid) begin
        // r_tag_addr          <= r_temp_addr; TODO,
        r_vic                 <= {r_vic[`NUM_CACHE-2:0],r_vic[`NUM_CACHE-1]};
      `ifdef WRITE_AFTER_READ
        r_re_rden             <= r_temp_rdwr;
        r_re_wren             <= ~r_temp_rdwr;  
      `else
        o_cache_rvalid        <= q_cache_rden;
        r_cache_rdata         <= q_cache_addr[2]? {2{w_upd_rdata[q_cache_addr[2+:3]]}}:
                                  {w_upd_rdata[q_cache_addr[2+:3]+1],w_upd_rdata[q_cache_addr[2+:3]]};
      `endif
        for(integer i=0; i<`NUM_CACHE; i=i+1) begin
          if(r_vic[i] == 1'b1) begin
            r_cached_data[i]  <= w_upd_rdata;
            r_tag_valid[i]    <= 1'b1;
            r_tag_dirty[i]    <= ~r_temp_rdwr;
          end
        end
      end
    end
  end

  always_comb begin
    for(integer i=0; i<8; i++) begin
    `ifndef WRITE_AFTER_READ
      if(i== i_cache_addr[2+:3])
        w_upd_rdata[i] = ({{8{q_cache_wstrb[3]}},{8{q_cache_wstrb[2]}},
                          {8{q_cache_wstrb[1]}},{8{q_cache_wstrb[0]}}} & q_cache_wdata) |
                         ({{8{~q_cache_wstrb[3]}},{8{~q_cache_wstrb[2]}},
                          {8{~q_cache_wstrb[1]}},{8{~q_cache_wstrb[0]}}} & i_upd_rdata[i]);
      else
        w_upd_rdata[i] = i_upd_rdata[i];
    `else
        w_upd_rdata[i] = i_upd_rdata[i];
    `endif
    end
  end

  always_ff @(posedge i_clk) begin
    if(o_cache_gnt) begin
      q_cache_wdata   <= i_cache_wdata;
      q_cache_wstrb   <= i_cache_wstrb;
      q_cache_addr    <= i_cache_addr;
      q_cache_rden    <= i_cache_rden_v | {RDEN_WIDTH{i_cache_wren}};
    end
  end

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* assert
  // initial begin
  //   assert (w_hit == 4'b0000 || w_hit == 4'b0001 || w_hit == 4'b0010 || w_hit == 4'b0100 || w_hit == 4'b1000 )
  //     else
  //       $error("w_hit in iCache: %x", w_hit);
  // end

endmodule
