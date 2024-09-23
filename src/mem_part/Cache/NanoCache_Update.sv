/*
 *  Project:            NanoCore -- a RISCV-32MC SoC.
 *  Module name:        NanoCache_Update.
 *  Description:        cache of nano core.
 *  Last updated date:  2024.2.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */

module NanoCache_Update (
  //* clk & reset;
  input   wire                            i_clk,
  input   wire                            i_rst_n,

  input   wire  [`NUM_PE-1:0]             i_miss_rden,
  input   wire  [`NUM_PE-1:0]             i_miss_wren,
  input   wire  [`NUM_PE-1:0][31:0]       i_miss_addr,
  input   wire  [`NUM_PE-1:0][7:0][31:0]  i_miss_wdata,
  output  wire  [`NUM_PE-1:0]             o_miss_resp,
  input   wire  [`NUM_PE-1:0]             i_wb_wren,
  output  wire  [`NUM_PE-1:0]             o_wb_gnt,

  //* interface for reading SRAM by Icache;
  output  reg                             o_mm_rden,
  output  reg                             o_mm_wren,
  output  reg   [7:0][31:0]               o_mm_wdata,
  output  reg   [31:0]                    o_mm_addr,
  input   wire                            i_mm_gnt,
  input   wire  [7:0][31:0]               i_mm_rdata,
  input   wire                            i_mm_rvalid,

  output  wire  [`NUM_PE-1:0]             o_upd_valid,
  output  wire  [7:0][31:0]               o_upd_rdata
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire  [3:0]                         w_req_mem, w_miss_resp, w_wbreq_mem, w_wb_gnt;
  reg   [3:0][`NUM_PE-1:0]            r_tag_read;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  generate if(`NUM_PE < 4)
    assign w_req_mem[3:`NUM_PE] = 'b0;
    assign w_wbreq_mem[3:`NUM_PE] = 'b0;
  endgenerate
  assign w_req_mem[`NUM_PE-1:0] = (i_miss_rden | i_miss_wren);
  assign w_wbreq_mem[`NUM_PE-1:0] = i_wb_wren;

  assign w_miss_resp = w_req_mem[0]? 4'b1:
                        w_req_mem[1]? 4'b10:
                        w_req_mem[2]? 4'b100:
                        w_req_mem[3]? 4'b1000: 4'b0;
  assign w_wb_gnt    = (|w_req_mem[3:0])? 4'b0:
                        w_wbreq_mem[0]? 4'b1:
                        w_wbreq_mem[1]? 4'b10:
                        w_wbreq_mem[2]? 4'b100:
                        w_wbreq_mem[3]? 4'b1000: 4'b0;
  assign o_miss_resp = w_miss_resp[`NUM_PE-1:0];
  assign o_wb_gnt    = w_wb_gnt[`NUM_PE-1:0];
  assign o_upd_valid = r_tag_read[1];
  assign o_upd_rdata = i_mm_rdata;

  always_comb begin
    o_mm_wren = |(w_miss_resp[`NUM_PE-1:0] & i_miss_wren | w_wb_gnt[`NUM_PE-1:0] & i_wb_wren);
    o_mm_rden = |(w_miss_resp[`NUM_PE-1:0] & i_miss_rden);
    o_mm_wdata= 'b0;
    o_mm_addr = 'b0;
    for(integer macro_i=0; macro_i<`NUM_PE; macro_i=macro_i+1)
      if(w_miss_resp[macro_i] == 1 || w_wb_gnt[macro_i] == 1) begin
        o_mm_wdata = o_mm_wdata | i_miss_wdata;
        o_mm_addr  = o_mm_addr  | i_miss_addr;
      end
  end

  integer i;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      for(i=0; i<4; i=i+1)
        r_tag_read[i]           <= 'b0;
    end else begin
      r_tag_read[0]             <= w_miss_resp[`NUM_PE-1:0] & i_miss_rden[`NUM_PE-1:0];
      for(i=1; i<4; i=i+1)
        r_tag_read[i]           <= r_tag_read[i-1];
    end
  end


endmodule
