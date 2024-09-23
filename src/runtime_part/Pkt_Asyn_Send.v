/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_Asyn_Send.
 *  Description:        This module is used to send packets.
 *  Last updated date:  2022.07.22.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_Asyn_Send(
   input  wire              i_sys_clk
  ,input  wire              i_pe_clk
  ,input  wire              i_rst_n
  //* interface for recv/send pkt;
  ,input  wire              i_data_valid
  ,input  wire  [133:0]     i_data 
  //* TODO
  ,output reg               o_data_valid
  ,output reg   [133:0]     o_data
);

  //======================= internal reg/wire/param declarations =//
  //* asyn proc;
  reg                       r_rden_asfifo;
  wire          [133:0]     w_dout_asfifo;
  wire                      w_empty_asfifo;
  reg                       r_rden_meta_asfifo;
  wire                      w_empty_meta_asfifo, w_wren_meta_asfifo;
  
  //* state;
  reg                       state_send;
  localparam                IDLE_S        = 1'd0,
                            SEND_DATA_S   = 1'd1;
  assign                    w_wren_meta_asfifo = (i_data_valid == 1'b1 && i_data[133:132] == 2'b10);
  //==============================================================//

  //======================= Read Pkt From AsFIFO =================//
  always @(posedge i_sys_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* read send fifo;
      r_rden_asfifo         <= 1'b0;
      r_rden_meta_asfifo    <= 1'b0;
      //* data & pkt;
      o_data                <= 134'b0;
      o_data_valid          <= 1'b0;
      //* state;
      state_send            <= IDLE_S;
    end 
    else begin
      case(state_send)
        IDLE_S: begin
          o_data_valid          <= 1'b0;
          if(w_empty_meta_asfifo == 1'b0) begin
            r_rden_asfifo       <= 1'b1;
            r_rden_meta_asfifo  <= 1'b1;
            state_send          <= SEND_DATA_S;
          end
        end
        SEND_DATA_S: begin
          //* data;
          o_data_valid          <= 1'b1;
          o_data                <= w_dout_asfifo;
          r_rden_meta_asfifo    <= 1'b0;
          
          //* judge tail;
          if(w_dout_asfifo[133:132] == 2'b10) begin
            r_rden_asfifo       <= 1'b0;
            state_send          <= IDLE_S;
          end
          else begin
            state_send          <= SEND_DATA_S;
          end
        end
      endcase
    end
  end
  //==============================================================//

    asfifo_134_512 asfifo_send_data(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_pe_clk             ),
      .rd_clk                 (i_sys_clk            ),
      .din                    (i_data               ),
      .wr_en                  (i_data_valid         ),
      .rd_en                  (r_rden_asfifo        ),
      .dout                   (w_dout_asfifo        ),
      .full                   (                     ),
      .empty                  (w_empty_asfifo       )
    );

    asfifo_1b_512 asfifo_send_valid(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_pe_clk             ),
      .rd_clk                 (i_sys_clk            ),
      .din                    (1'b1                 ),
      .wr_en                  (w_wren_meta_asfifo   ),
      .rd_en                  (r_rden_meta_asfifo   ),
      .dout                   (                     ),
      .full                   (                     ),
      .empty                  (w_empty_meta_asfifo  )
    );

endmodule