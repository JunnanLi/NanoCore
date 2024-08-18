/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Pkt_DMUX.
 *  Description:        This module is used to distribute received-packets.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */
// `define VCS
`timescale 1 ns / 1 ps

module Pkt_DMUX(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* interface for recv/send pkt;
  ,input  wire  [47:0]      i_pe_conf_mac
  ,input  wire              i_data_valid
  ,input  wire  [133:0]     i_data
  //* output;
  ,output reg               o_data_DMA_valid
  ,output reg   [133:0]     o_data_DMA 
  ,input  wire              i_alf_dma
`ifdef ENABLE_DRA
  ,output reg               o_data_DRA_valid
  ,output reg   [133:0]     o_data_DRA
  ,input  wire              i_alf_dra
`endif
  ,output wire              o_data_conf_valid
  ,output wire  [133:0]     o_data_conf
  ,output wire              o_alf
  //* config interface;
  ,output wire              o_conf_rden     //* configure interface
  ,output wire              o_conf_wren
  ,output wire  [ 15:0]     o_conf_addr
  ,output wire  [127:0]     o_conf_wdata
  ,input        [127:0]     i_conf_rdata
  ,output wire  [  3:0]     o_conf_en       //* '1' means configuring is valid;
);
  
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  reg                       r_to_dra, r_to_dma, r_to_conf;
  reg                       w_data_conf_valid;
  reg           [133:0]     w_data_conf;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   output to conf/dma/dra
  //====================================================================//
  always_ff @(posedge i_clk) begin
    `ifdef ENABLE_DRA
      r_to_dra              <= o_data_DRA_valid;
    `endif
    r_to_dma                <= o_data_DMA_valid;
    r_to_conf               <= w_data_conf_valid;
  end

  assign w_data_conf_valid  = (i_data[133:132] == 2'b11 && i_data[28] == 1'b1 || r_to_conf == 1'b1 ) && i_data_valid == 1'b1;
  assign o_data_DMA_valid   = (i_data[133:132] == 2'b11 && i_data[29] == 1'b1 && i_alf_dma == 1'b0 ||
                                r_to_dma == 1'b1 ) && i_data_valid == 1'b1;
  assign w_data_conf        = i_data;
  assign o_data_DMA         = i_data;
`ifdef ENABLE_DRA
  assign o_data_DRA_valid   = (i_data[133:132] == 2'b11 && i_data[30] == 1'b1 || r_to_dra == 1'b1 ) && i_data_valid == 1'b1;
  assign o_data_DRA         = i_data;
`endif  
  assign o_alf              = i_alf_dma |
`ifdef ENABLE_DRA
                              i_alf_dra;
`else
                              1'b1;
`endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  PE_Config PE_Config(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for recv/send pkt;
    .i_data_conf_valid      (w_data_conf_valid        ),
    .i_data_conf            (w_data_conf              ),
    .o_data_conf_valid      (o_data_conf_valid        ),
    .o_data_conf            (o_data_conf              ),
    //* to configure
    .o_conf_rden            (o_conf_rden              ),
    .o_conf_wren            (o_conf_wren              ),
    .o_conf_addr            (o_conf_addr              ),
    .o_conf_wdata           (o_conf_wdata             ),
    .i_conf_rdata           (i_conf_rdata             ),
    .o_conf_en              (o_conf_en                )
  );


endmodule