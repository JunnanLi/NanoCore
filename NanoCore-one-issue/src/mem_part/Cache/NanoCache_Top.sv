/*
 *  Project:            NanoCore -- a RISCV-32MC SoC.
 *  Module name:        NanoCache_Top.
 *  Description:        cache of nano core.
 *  Last updated date:  2024.2.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 *  1) two 32b*8 cache lines, one for instr, another for data;
 *  2) adopt write-back;
 */

module NanoCache_Top (
  //* clk & reset;
  input   wire                        i_clk,
  input   wire                        i_rst_n,

  //* interface for PEs (instr.);
  input   wire  [`NUM_PE-1:0]         i_cache_rden,
  input   wire  [`NUM_PE-1:0]         i_cache_wren,
  input   wire  [`NUM_PE-1:0][31:0]   i_cache_addr,
  input   wire  [`NUM_PE-1:0][31:0]   i_cache_wdata,
  input   wire  [`NUM_PE-1:0][ 3:0]   i_cache_wstrb,
  output  wire  [`NUM_PE-1:0][31:0]   o_cache_rdata,
  output  wire  [`NUM_PE-1:0]         o_cache_rvalid,
  output  wire  [`NUM_PE-1:0]         o_cache_gnt,

  //* interface for reading SRAM by Icache;
  output  wire                        o_mm_rden,
  output  wire                        o_mm_wren,
  output  wire  [             31:0]   o_mm_addr,
  output  wire  [7:0][        31:0]   o_mm_wdata,
  input   wire  [7:0][        31:0]   i_mm_rdata,
  input   wire                        i_mm_rvalid,
  input   wire                        i_mm_gnt
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire  [`NUM_PE-1:0]                 w_miss_rden, w_miss_wren;
  wire  [`NUM_PE-1:0][31:0]           w_miss_addr;
  wire  [`NUM_PE-1:0][7:0][31:0]      w_miss_wdata;
  wire  [`NUM_PE-1:0]                 w_miss_resp, w_upd_valid;
  wire               [7:0][31:0]      w_upd_rdata;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  genvar gidx;
  generate
    for (gidx = 0; gidx < `NUM_PE; gidx=gidx+1) begin : icache_search_pes
      NanoCache_Search cache_search (
        .i_clk          (i_clk                  ),
        .i_rst_n        (i_rst_n                ),

        .i_cache_rden   (i_cache_rden[gidx]     ),
        .i_cache_addr   (i_cache_addr[gidx]     ),
        .i_cache_wren   (i_cache_wren[gidx]     ),
        .i_cache_wdata  (i_cache_wdata[gidx]    ),
        .i_cache_wstrb  (i_cache_wstrb[gidx]    ),
        .o_cache_rdata  (o_cache_rdata[gidx]    ),
        .o_cache_rvalid (o_cache_rvalid[gidx]   ),

        .o_miss_rden    (w_miss_rden[gidx]      ),
        .o_miss_wren    (w_miss_wren[gidx]      ),
        .o_miss_addr    (w_miss_addr[gidx]      ),
        .o_miss_wdata   (w_miss_wdata[gidx]     ),
        .i_miss_resp    (w_miss_resp[gidx]      ),
        .i_upd_valid    (w_upd_valid[gidx]      ),
        .i_upd_rdata    (w_upd_rdata            )
      );
    end
  endgenerate

  NanoCache_Update cache_update (
    .i_clk          (i_clk              ),
    .i_rst_n        (i_rst_n            ),

    .i_miss_rden    (w_miss_rden        ),
    .i_miss_wren    (w_miss_wren        ),
    .i_miss_addr    (w_miss_addr        ),
    .i_miss_wdata   (w_miss_wdata       ),
    .i_miss_resp    (w_miss_resp        ),

    .o_mm_rden      (o_mm_rden          ),
    .o_mm_wren      (o_mm_wren          ),
    .o_mm_addr      (o_mm_addr          ),
    .o_mm_wdata     (o_mm_wdata         ),
    .i_mm_gnt       (i_mm_gnt           ),
    .i_mm_rdata     (i_mm_rdata         ),
    .i_mm_rvalid    (i_mm_rvalid        ),

    .o_upd_valid    (w_upd_valid        ),
    .o_upd_rdata    (w_upd_rdata        )
  );

  assign o_cache_gnt = {`NUM_PE{1'b1}};
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule