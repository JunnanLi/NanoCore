/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        UART_TOP.
 *  Description:        top module of uart.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module UART_TOP (
  //* clk & rst_n;
   input  wire              i_clk
  ,input  wire              i_rst_n
  ,input  wire              i_sys_clk
  //* uart recv/trans;
  ,output wire              o_uart_tx
  ,input  wire              i_uart_rx
  ,input  wire              i_uart_cts
  //* peri & irq;
  ,input  wire  [ 31:0]     i_addr_32b
  ,input  wire              i_wren
  ,input  wire              i_rden
  ,input  wire  [ 31:0]     i_din_32b
  ,output wire  [ 31:0]     o_dout_32b
  ,output wire              o_dout_32b_valid
  ,output wire              o_interrupt
`ifdef UART_BY_PKT
  ,output wire              o_uartPkt_valid
  ,output wire  [133:0]     o_uartPkt
`endif
);

  //==============================================================//
  //  internal reg/wire/param declarations
  //==============================================================//
  //* clk for sampling rx/tx;
  wire                      w_rxclk_en, w_txclk_en;
  //* data and valid signals;
  wire                      w_uart_dataTx_valid, w_uart_dataRx_valid;
  wire          [  7:0]     w_uart_dataTx, w_uart_dataRx;
  wire                      w_uart_tx_busy;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  Gen_Baud_Rate 
  //==============================================================//
  //* gen rx/tx sample clk;
  Gen_Baud_Rate Gen_Baud_Rate(
    .i_clk                  (i_sys_clk              ),
    .i_rst_n                (i_rst_n                ),
    .o_rxclk_en             (w_rxclk_en             ),
    .o_txclk_en             (w_txclk_en             )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  UART_Transmitter
  //==============================================================//
  //* 8b din -> 1b tx;
  UART_Trans UART_Trans(
    .i_clk                  (i_sys_clk              ),
    .i_rst_n                (i_rst_n                ),
    .i_din_8b               (w_uart_dataTx          ),
    .i_wren                 (w_uart_dataTx_valid    ),
    .i_clken                (w_txclk_en             ),
    .o_tx                   (o_uart_tx              ),
    .o_tx_busy              (w_uart_tx_busy         )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  UART_Receiver
  //==============================================================//
  //* 1b rx -> 8b dout;
  UART_Recv UART_Recv(
    .i_clk                  (i_sys_clk              ),
    .i_rst_n                (i_rst_n                ),
    .i_clken                (w_rxclk_en             ),
    .o_dout_8b              (w_uart_dataRx          ),
    .o_dout_valid           (w_uart_dataRx_valid    ),
    .i_rx                   (i_uart_rx              )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  UART_Controller
  //==============================================================//
  UART_Ctrl UART_Ctrl(
    //* clk & reset;
    .i_clk                  (i_clk                  ),
    .i_rst_n                (i_rst_n                ),
    .i_sys_clk              (i_sys_clk              ),
    //* peri interface;
    .i_addr_32b             (i_addr_32b             ),
    .i_wren                 (i_wren                 ),
    .i_rden                 (i_rden                 ),
    .i_din_32b              (i_din_32b              ),
    .o_dout_32b             (o_dout_32b             ),
    .o_dout_32b_valid       (o_dout_32b_valid       ),
    .o_interrupt            (o_interrupt            ),
    //* uart recv/send;
    .i_din_8b               (w_uart_dataRx          ),
    .i_din_valid            (w_uart_dataRx_valid    ),
    .o_dout_8b              (w_uart_dataTx          ),
    .o_dout_valid           (w_uart_dataTx_valid    ),
    .i_tx_busy              (w_uart_tx_busy|i_uart_cts)
  `ifdef UART_BY_PKT
    ,.o_uartPkt_valid       (o_uartPkt_valid        )
    ,.o_uartPkt             (o_uartPkt              )
  `endif
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
