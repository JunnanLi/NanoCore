/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Peri_Top.
 *  Description:        This module is used to connect PE with Periperals.
 *  Last updated date:  2024.02.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Space = 2;
 */

module Peri_Top(
  //* clock & resets
   input  wire                  i_pe_clk
  ,input  wire                  i_rst_n
  ,input  wire                  i_sys_clk
  //* UART
  ,input  wire                  i_uart_rx
  ,output wire                  o_uart_tx
  ,input  wire                  i_uart_cts
  //* Peri interface
  ,input  wire                  i_peri_rden 
  ,input  wire                  i_peri_wren 
  ,input  wire  [        31:0]  i_peri_addr 
  ,input  wire  [        31:0]  i_peri_wdata
  ,input  wire  [         3:0]  i_peri_wstrb
  ,output wire  [        31:0]  o_peri_rdata
  ,output wire                  o_peri_ready
  //* DMA, DRA, TODO,
  ,output wire  [`DRA:`DMA]       o_rden_2peri 
  ,output wire  [`DRA:`DMA]       o_wren_2peri 
  ,output wire             [31:0] o_addr_2peri 
  ,output wire             [31:0] o_wdata_2peri
  ,output wire             [ 3:0] o_wstrb_2peri
  ,input  wire  [`DRA:`DMA][31:0] i_rdata_2PBUS
  ,input  wire  [`DRA:`DMA]       i_ready_2PBUS
  ,input  wire  [`DRA:`DMA]       i_int_2PBUS
  //* irq interface
  ,output wire  [        31:0]  o_irq    
  ,input  wire                  i_irq_ack
  ,input  wire  [         4:0]  i_irq_id 
`ifdef UART_BY_PKT
  ,output wire                  o_uartPkt_valid
  ,output wire  [       133:0]  o_uartPkt
`endif
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* wire, used to connect UART, DMA, DRA;
  wire  [31:0]                  w_addr_peri;
  wire  [`NUM_PERI-1:0]         w_wren_peri;
  wire  [`NUM_PERI-1:0]         w_rden_peri;
  wire  [31:0]                  w_wdata_peri;
  wire  [3:0]                   w_wstrb_peri;
  wire  [`NUM_PERI-1:0][31:0]   w_rdata_peri;
  wire  [`NUM_PERI-1:0]         w_ready_peri;
  wire  [`NUM_PERI-1:0]         w_int_peri;
  wire                          w_time_int;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Periperal_Bus & Interrupt_Ctrl
  //====================================================================//
  Periperal_Bus Periperal_Bus (
    //* clk & rst_n;
    .i_clk              (i_pe_clk               ),
    .i_rst_n            (i_rst_n                ),
    //* peri interface;
    .i_peri_rden        (i_peri_rden            ),
    .i_peri_wren        (i_peri_wren            ),
    .i_peri_addr        (i_peri_addr            ),
    .i_peri_wdata       (i_peri_wdata           ),
    .i_peri_wstrb       (i_peri_wstrb           ),
    .o_peri_rdata       (o_peri_rdata           ),
    .o_peri_ready       (o_peri_ready           ),
    .o_peri_gnt         (                       ),
    //* conncet UART, DMA, DRA;
    .o_addr_2peri       (w_addr_peri            ),
    .o_wren_2peri       (w_wren_peri            ),
    .o_rden_2peri       (w_rden_peri            ),
    .o_wdata_2peri      (w_wdata_peri           ),
    .o_wstrb_2peri      (w_wstrb_peri           ),
    .i_rdata_2PBUS      (w_rdata_peri           ),
    .i_ready_2PBUS      (w_ready_peri           )
  );
  //* INT_CTRL;
  Interrupt_Ctrl Interrupt_Ctrl(
    .i_clk              (i_pe_clk               ),
    .i_rst_n            (i_rst_n                ),
    .i_irq              ({w_time_int,w_int_peri}),
    .o_irq              (o_irq                  ),
    .i_irq_ack          (i_irq_ack              ),
    .i_irq_id           (i_irq_id               )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   UART
  //====================================================================//
  UART_TOP UART_TOP(
    //* clk & rst_n;
    .i_clk              (i_pe_clk               ),
    .i_rst_n            (i_rst_n                ),
    .i_sys_clk          (i_sys_clk              ),
    //* uart recv/trans;
    .o_uart_tx          (o_uart_tx              ),
    .i_uart_rx          (i_uart_rx              ),
    .i_uart_cts         (i_uart_cts             ),
    //* peri interface;
    .i_addr_32b         (w_addr_peri            ),
    .i_wren             (w_wren_peri[`UART]     ),
    .i_rden             (w_rden_peri[`UART]     ),
    .i_din_32b          (w_wdata_peri           ),
    .o_dout_32b         (w_rdata_peri[`UART]    ),
    .o_dout_32b_valid   (w_ready_peri[`UART]    ),
    .o_interrupt        (w_int_peri[`UART]      )
  `ifdef UART_BY_PKT
    ,.o_uartPkt_valid   (o_uartPkt_valid        )
    ,.o_uartPkt         (o_uartPkt              )
  `endif
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  //====================================================================//
  //*   timer
  //====================================================================//
  CSR_TOP CSR_Top(
    //* clk & rst_n;
    .i_clk              (i_pe_clk               ),
    .i_rst_n            (i_rst_n                ),
    //* peri interface;
    .i_addr_32b         (w_addr_peri            ),
    .i_wren             (w_wren_peri[`CSR]      ),
    .i_rden             (w_rden_peri[`CSR]      ),
    .i_din_32b          (w_wdata_peri           ),
    .o_dout_32b         (w_rdata_peri[`CSR]     ),
    .o_dout_32b_valid   (w_ready_peri[`CSR]     ),
    .o_interrupt        (w_int_peri[`CSR]       ),
    .o_time_int         (w_time_int             )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* DRA & DMA
  assign w_int_peri[`DRA:`DMA]    = i_int_2PBUS;
  assign w_rdata_peri[`DRA:`DMA]  = i_rdata_2PBUS;
  assign w_ready_peri[`DRA:`DMA]  = i_ready_2PBUS;
  assign o_rden_2peri             = w_rden_peri[`DRA:`DMA];
  assign o_wren_2peri             = w_wren_peri[`DRA:`DMA];
  assign o_addr_2peri             = w_addr_peri;
  assign o_wdata_2peri            = w_wdata_peri;
  assign o_wstrb_2peri            = w_wstrb_peri[`DRA:`DMA];

endmodule    
