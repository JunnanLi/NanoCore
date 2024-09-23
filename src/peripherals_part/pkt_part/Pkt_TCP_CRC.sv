/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Pkt_TCP_CRC.
 *  Description:        This module is used to calc. tcp's checksum;
 *  Last updated date:  2024.07.26.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_TCP_CRC(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* calculate crc;
  ,(* mark_debug = "true"*)input  wire              i_data_valid
  ,(* mark_debug = "true"*)input  wire  [133:0]     i_data
  ,(* mark_debug = "true"*)output reg               o_data_valid
  ,(* mark_debug = "true"*)output reg   [133:0]     o_data
);

  
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//

  //* fifo;
  //* fifo_calc_pkt;
  reg                       rden_pkt;
  wire  [133:0]             dout_pkt;
  wire                      empty_pkt;
  
  //* fifo crc;
  (* mark_debug = "true"*)reg   [16:0]              din_crc;
  (* mark_debug = "true"*)reg                       rden_crc, wren_crc;
  (* mark_debug = "true"*)wire  [16:0]              dout_crc;
  wire                      empty_crc;

  //* temp;
  reg                       tag_to_calc_crc;
  reg   [31:0]              r_crcRst[7:0];  
  wire  [15:0]              w_bm_invalid_Byte;
  
  
  //* state;
  typedef enum logic [3:0] {idle, read_data_0, read_data_1, read_data_2, 
                            read_data_3, wait_pkt_tail, calc_crc_0, 
                            calc_crc_1, calc_crc_2, wait_crc} state_t;
  state_t state_calc, state_out;

  //* change 4b tag_valid to 16b bm_invalid;
  assign                    w_bm_invalid_Byte = 16'h7fff >> i_data[131:128];
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   calc crc
  //====================================================================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      wren_crc                    <= 1'b0;
      //* state
      state_calc                  <= idle;
    end
    else begin
      case(state_calc)
        idle: begin
          wren_crc                <= 1'b0;
          tag_to_calc_crc         <= 1'b0;
          if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01) begin
            state_calc            <= (i_data[31:16] == 16'h0800)? read_data_1: wait_pkt_tail;
            for(i=0; i<8; i=i+1) begin
              r_crcRst[i]         <= 32'b0;
            end
          end
          else begin
            state_calc            <= idle;
          end
        end
        read_data_1: begin
          tag_to_calc_crc         <= i_data[64+:8] == 8'h6;
          state_calc              <= read_data_2;
          //* add proto, len, ip_addr;
          r_crcRst[0]             <= 32'h6;
          r_crcRst[1]             <= {16'b0, i_data[127:112] - 16'd20};
          r_crcRst[2]             <= {16'b0, i_data[47:32]};
          r_crcRst[3]             <= {16'b0, i_data[31:16]};
          r_crcRst[4]             <= {16'b0, i_data[15:0]};
        end
        read_data_2: begin
          for(i=0; i<8; i=i+1) begin
            r_crcRst[i]           <= {16'b0,i_data[i*16+:16]} + r_crcRst[i];
          end
          state_calc              <= read_data_3;
        end
        read_data_3: begin
          for(i=0; i<6; i=i+1) begin
            r_crcRst[i]           <= {16'b0,{{8{~w_bm_invalid_Byte[i*2+1]}},{8{~w_bm_invalid_Byte[i*2]}}} & 
                                    i_data[i*16+:16]} + r_crcRst[i];
          end
          r_crcRst[7]             <= {16'b0,i_data[7*16+:16]} + r_crcRst[7];
          state_calc              <= (i_data[133:132] == 2'b10)? calc_crc_0: wait_pkt_tail;
        end
        wait_pkt_tail: begin
          for(i=0; i<8; i=i+1) begin
            r_crcRst[i]           <= {16'b0,{{8{~w_bm_invalid_Byte[i*2+1]}},{8{~w_bm_invalid_Byte[i*2]}}} & 
                                    i_data[i*16+:16]} + r_crcRst[i];
          end          
          state_calc              <= (i_data[133:132] == 2'b10)? calc_crc_0: wait_pkt_tail;
        end
        calc_crc_0: begin
          r_crcRst[0]             <= r_crcRst[0]+ r_crcRst[3]+ r_crcRst[6];
          r_crcRst[1]             <= r_crcRst[1]+ r_crcRst[4]+ r_crcRst[7];
          r_crcRst[2]             <= r_crcRst[2]+ r_crcRst[5];
          state_calc              <= calc_crc_1;
        end
        calc_crc_1: begin
          r_crcRst[0]             <= r_crcRst[0]+ r_crcRst[1]+ r_crcRst[2];
          state_calc              <= calc_crc_2;
        end
        calc_crc_2: begin
          r_crcRst[0]             <= r_crcRst[0][15:0]+ r_crcRst[0][31:16];
          state_calc              <= wait_crc;
        end
        wait_crc: begin
          if(r_crcRst[0][31:16] == 0) begin
            din_crc[15:0]         <= ~r_crcRst[0][15:0];
            din_crc[16]           <= tag_to_calc_crc;
            wren_crc              <= 1'b1;
            state_calc            <= idle;
          end
          else begin
            r_crcRst[0]           <= r_crcRst[0][15:0]+ r_crcRst[0][31:16];
            state_calc            <= wait_crc;
          end
        end
        default: begin
          state_calc              <= idle;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*  Output Pkt (calc)
  //====================================================================//
  reg [16:0]  temp_crc;
  (* mark_debug = "true"*) reg mismatch_tag;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* fifo;
      rden_crc                    <= 1'b0;
      rden_pkt                    <= 1'b0;
      //* output;
      o_data_valid                <= 1'b0;
      //* state;
      state_out                   <= idle;
      mismatch_tag                <= 1'b0;
    end else begin
      case(state_out)
        idle: begin
          rden_crc                <= 1'b0;
          o_data_valid            <= 1'b0;
          if(empty_crc == 1'b0) begin
            rden_pkt              <= 1'b1;
            rden_crc              <= 1'b1;
            state_out             <= read_data_0;
          end
          else begin
            state_out             <= idle;
          end
        end
        read_data_0: begin
          rden_crc                <= 1'b0;
          temp_crc                <= rden_crc? dout_crc: temp_crc;
          o_data_valid            <= 1'b1;
          o_data                  <= dout_pkt;
          state_out               <= (dout_pkt[133:132] == 2'b01)? read_data_1: read_data_0;
        end
        read_data_1: begin
          o_data_valid            <= 1'b1;
          o_data                  <= dout_pkt;
          state_out               <= read_data_2;
        end
        read_data_2: begin
          o_data_valid            <= 1'b1;
          o_data                  <= dout_pkt;
          state_out               <= read_data_3;
          rden_pkt                <= (dout_pkt[133:132] == 2'b10)? 1'b0: 1'b1;
          state_out               <= (dout_pkt[133:132] == 2'b10)? idle: read_data_3;
        end
        read_data_3: begin
          o_data_valid            <= 1'b1;
          o_data                  <= dout_pkt;
          o_data[111:96]          <= temp_crc[16]? temp_crc[15:0]: dout_pkt[111:96];
          mismatch_tag            <= temp_crc[16] & (temp_crc[15:0] != dout_pkt[111:96]);
          rden_pkt                <= (dout_pkt[133:132] == 2'b10)? 1'b0: 1'b1;
          state_out               <= (dout_pkt[133:132] == 2'b10)? idle: wait_pkt_tail;
        end
        wait_pkt_tail: begin
          o_data_valid            <= 1'b1;
          o_data                  <= dout_pkt;
          rden_pkt                <= (dout_pkt[133:132] == 2'b10)? 1'b0: 1'b1;
          state_out               <= (dout_pkt[133:132] == 2'b10)? idle: wait_pkt_tail;
        end
        default: begin
          state_out               <= idle;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  regfifo_17b_8 fifo_crc_calc (
    .clk                    (i_clk                    ),  //* input wire clk
    .srst                   (!i_rst_n                 ),  //* input wire srst
    .din                    (din_crc                  ),  //* input wire [31 : 0] din
    .wr_en                  (wren_crc                 ),  //* input wire wr_en
    .rd_en                  (rden_crc                 ),  //* input wire rd_en
    .dout                   (dout_crc                 ),  //* output wire [31 : 0] dout
    .full                   (                         ),  //* output wire full
    .empty                  (empty_crc                )   //* output wire empty
  );

  `ifdef XILINX_FIFO_RAM
    fifo_134b_512 fifo_pktDMA_calc (
      .clk                  (i_clk                    ),  // input wire clk
      .srst                 (!i_rst_n                 ),  // input wire srst
      .din                  (i_data                   ),  // input wire [133 : 0] din
      .wr_en                (i_data_valid             ),  // input wire wr_en
      .rd_en                (rden_pkt                 ),  // input wire rd_en
      .dout                 (dout_pkt                 ),  // output wire [133 : 0] dout
      .empty                (empty_pkt                )   // output wire empty
    );
  `else
    syncfifo fifo_pktDMA_calc (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_data                   ),  //* The Inport of data 
      .wrreq                (i_data_valid             ),  //* active-high
      .rdreq                (rden_pkt                 ),  //* active-high
      .q                    (dout_pkt                 ),  //* The output of data
      .empty                (empty_pkt                ),  //* Read domain empty
      .usedw                (                         ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktDMA_calc.width = 134,
              fifo_pktDMA_calc.depth = 7,
              fifo_pktDMA_calc.words = 128;

  `endif

endmodule