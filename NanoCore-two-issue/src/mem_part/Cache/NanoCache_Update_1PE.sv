/*
 *  Project:            NanoCore -- a RISCV-32MC SoC.
 *  Module name:        NanoCache_Update.
 *  Description:        cache of nano core.
 *  Last updated date:  2024.9.1.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */

module NanoCache_Update #(
  parameter                  BUFFER = 1
)(
  //* clk & reset;
  input   wire               i_clk,
  input   wire               i_rst_n,
  input   wire               i_flush,

  input   wire               i_miss_rden,
  input   wire               i_miss_wren,
  input   wire  [31:0]       i_miss_addr,
  input   wire  [7:0][31:0]  i_miss_wdata,
  input   wire  [7:0][ 3:0]  i_miss_wstrb,
  output  wire               o_miss_resp,

  //* interface for reading SRAM by Icache;
  output  wire                o_mm_rden,
  output  wire                o_mm_wren,
  output  wire  [7:0][31:0]   o_mm_wdata,
  output  wire  [7:0][ 3:0]   o_mm_wstrb,
  output  wire  [31:0]        o_mm_addr,
  input   wire                i_mm_gnt,
  input   wire  [7:0][31:0]   i_mm_rdata,
  input   wire                i_mm_rvalid,

  output  wire                o_upd_valid,
  output  wire  [7:0][31:0]   o_upd_rdata,
  output  wire                o_wr_finish
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  reg   [1:0]                 r_tag_read, r_tag_write;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  assign o_miss_resp  = i_miss_rden | i_miss_wren;
  assign o_upd_valid  = BUFFER? r_tag_read[1]: r_tag_read[0];
  assign o_wr_finish  = BUFFER? r_tag_write[1]: r_tag_write[0];
  assign o_upd_rdata  = i_mm_rdata;
  assign o_mm_wren    = i_miss_wren;
  assign o_mm_rden    = i_miss_rden;
  assign o_mm_wdata   = i_miss_wdata;
  assign o_mm_wstrb   = i_miss_wstrb;
  assign o_mm_addr    = i_miss_addr; 

  integer i;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      r_tag_read                <= '0;
      r_tag_write               <= '0;
    end else begin
      r_tag_read[0]             <= i_miss_rden & ~i_flush;
      r_tag_read[1]             <= r_tag_read[0] & ~i_flush;
      r_tag_write               <= {r_tag_write[0], i_miss_wren};
    end
  end


endmodule
