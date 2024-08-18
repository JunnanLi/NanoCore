/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Pkt_DMUX.
 *  Description:        This module is a MUX for received-packets.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_MUX(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* interface for recv DRA/DMA pkt;
`ifdef ENABLE_DRA
  ,input  wire              i_data_DRA_valid
  ,input  wire  [ 133:0]    i_data_DRA
`endif
  ,input  wire              i_data_DMA_valid
  ,input  wire  [ 133:0]    i_data_DMA
  ,input  wire              i_data_conf_valid
  ,input  wire  [ 133:0]    i_data_conf   
  //* output pkt & meta; 
  ,(* mark_debug = "true"*)output reg               o_data_valid
  ,output reg   [ 133:0]    o_data
`ifdef UART_BY_PKT
  ,input  wire              i_uartPkt_valid
  ,input  wire  [ 133:0]    i_uartPkt
`endif  
);
  
  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* state;
  typedef enum logic [3:0] {IDLE_S, WAIT_END_S, WAIT_DMA_END_S,
                            WAIT_UART_END_S} state_t;
  (* mark_debug = "true"*)state_t state_dmux;
`ifdef UART_BY_PKT
  //* for fifo;
  reg                       r_rden_uartPkt, r_rden_dmaPkt;
  wire  [         133:0]    w_dout_uartPkt, w_dout_dmaPkt;
  reg   [           3:0]    r_cnt_uartPkt;
  wire                      w_inc_uartPkt, w_dec_uartPkt, w_empty_dmaPkt;
`endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//  

  //==============================================================//
  //   dma_data/dra_data -> o_data
  //==============================================================//
  //* read dma_fifo;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* fifo;
      //* output
      o_data_valid                  <= 1'b0;
      state_dmux                    <= IDLE_S;
    `ifdef UART_BY_PKT
      r_rden_dmaPkt                 <= 1'b0;
      r_rden_uartPkt                <= 1'b0;
    `endif 
    end 
    else begin

      //* output pkt from dma/dra/conf;
      case(state_dmux)
        IDLE_S: begin
          o_data_valid              <= 1'b0;
          if(i_data_conf_valid) begin
            o_data                  <= i_data_conf;
            o_data_valid            <= 1'b1;
            state_dmux              <= WAIT_END_S;
          end
      `ifndef UART_BY_PKT
          else if(i_data_DMA_valid) begin
            state_dmux              <= WAIT_END_S;
          end
        `ifdef ENABLE_DRA
          else if(i_data_DRA_valid) begin
            state_dmux              <= WAIT_END_S;
          end
        `endif
      `else
          else if(!w_empty_dmaPkt) begin
            r_rden_dmaPkt           <= 1'b1;
            state_dmux              <= WAIT_DMA_END_S;
          end
          else if(r_cnt_uartPkt != 4'b0) begin
            r_rden_uartPkt          <= 1'b1;
            state_dmux              <= WAIT_UART_END_S;
          end
      `endif
          else begin
            state_dmux              <= IDLE_S;
          end
        end
        WAIT_END_S: begin
          o_data_valid              <= i_data_conf_valid | 
                                      `ifdef ENABLE_DRA
                                        i_data_DRA_valid |
                                      `endif
                                        i_data_DMA_valid;
          o_data                    <= i_data_conf_valid? i_data_conf:
                                      `ifdef ENABLE_DRA
                                        i_data_DRA_valid? i_data_DRA:
                                      `endif
                                        i_data_DMA;
          if(o_data[133:132] == 2'b10 && o_data_valid == 1'b1)
            state_dmux              <= IDLE_S;
          else
            state_dmux              <= WAIT_END_S;
        end
      `ifdef UART_BY_PKT
        WAIT_DMA_END_S: begin
          o_data_valid              <= r_rden_dmaPkt;
          o_data                    <= w_dout_dmaPkt;
          if(w_dout_dmaPkt[133:132] == 2'b10) begin
            r_rden_dmaPkt           <= 1'b0;
            state_dmux              <= IDLE_S;
          end
        end
        WAIT_UART_END_S: begin
          o_data_valid              <= r_rden_uartPkt;
          o_data                    <= w_dout_uartPkt;
          if(w_dout_uartPkt[133:132] == 2'b10) begin
            r_rden_uartPkt          <= 1'b0;
            state_dmux              <= IDLE_S;
          end
        end
      `endif
        default: begin
          state_dmux                <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

`ifdef UART_BY_PKT
  assign w_inc_uartPkt = i_uartPkt_valid & (i_uartPkt[133:132] == 2'b10);
  assign w_dec_uartPkt = r_rden_uartPkt & (w_dout_uartPkt[133:132] == 2'b10);
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_cnt_uartPkt                 <= 4'b0;
    end 
    else begin
      case({w_inc_uartPkt, w_dec_uartPkt})
        2'b10:    r_cnt_uartPkt     <= r_cnt_uartPkt + 4'd1;
        2'b01:    r_cnt_uartPkt     <= r_cnt_uartPkt - 4'd1;
        default:  r_cnt_uartPkt     <= r_cnt_uartPkt;
      endcase
    end
  end

  `ifdef XILINX_FIFO_RAM
    //* fifo used to buffer dma's pkt;
    fifo_134b_512 fifo_dmaPkt (
      .clk              (i_clk                    ),  //* input wire clk
      .srst             (!i_rst_n                 ),  //* input wire srst
      .din              (i_data_DMA               ),  //* input wire [133 : 0] din
      .wr_en            (i_data_DMA_valid & 
                          (i_data_DMA[133:132] != 2'b11) ),  //* input wire wr_en
      .rd_en            (r_rden_dmaPkt            ),  //* input wire rd_en
      .dout             (w_dout_dmaPkt            ),  //* output wire [133 : 0] dout
      .full             (                         ),  //* output wire full
      .empty            (w_empty_dmaPkt           )   //* output wire empty
    );
    //* fifo used to buffer uart;
    fifo_134b_512 fifo_uartPkt (
      .clk              (i_clk                    ),  //* input wire clk
      .srst             (!i_rst_n                 ),  //* input wire srst
      .din              (i_uartPkt                ),  //* input wire [133 : 0] din
      .wr_en            (i_uartPkt_valid          ),  //* input wire wr_en
      .rd_en            (r_rden_uartPkt           ),  //* input wire rd_en
      .dout             (w_dout_uartPkt           ),  //* output wire [133 : 0] dout
      .full             (                         ),  //* output wire full
      .empty            (                         )   //* output wire empty
    );
  `elsif SIM_FIFO_RAM
    //* fifo used to buffer dma's pkt;
    syncfifo fifo_dmaPkt (
      .clock            (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr             (!i_rst_n                 ),  //* Reset the all signal
      .data             (i_data_DMA               ),  //* The Inport of data 
      .wrreq            (i_data_DMA_valid         ),  //* active-high
      .rdreq            (r_rden_dmaPkt            ),  //* active-high
      .q                (w_dout_dmaPkt            ),  //* The output of data
      .empty            (w_empty_dmaPkt           ),  //* Read domain empty
      .usedw            (                         ),  //* Usedword
      .full             (                         )   //* Full
    );
    defparam  fifo_dmaPkt.width = 134,
              fifo_dmaPkt.depth = 9,
              fifo_dmaPkt.words = 512;
    //* fifo used to buffer uart's pkt;
    syncfifo fifo_uartPkt (
      .clock            (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr             (!i_rst_n                 ),  //* Reset the all signal
      .data             (i_uartPkt                ),  //* The Inport of data 
      .wrreq            (i_uartPkt_valid          ),  //* active-high
      .rdreq            (r_rden_uartPkt           ),  //* active-high
      .q                (w_dout_uartPkt           ),  //* The output of data
      .empty            (                         ),  //* Read domain empty
      .usedw            (                         ),  //* Usedword
      .full             (                         )   //* Full
    );
    defparam  fifo_uartPkt.width = 134,
              fifo_uartPkt.depth = 9,
              fifo_uartPkt.words = 512;
  `endif
`endif

endmodule