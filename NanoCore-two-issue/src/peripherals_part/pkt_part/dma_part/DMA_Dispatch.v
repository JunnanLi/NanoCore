/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Dispatch.
 *  Description:        This module is used to dispatch packets.
 *  Last updated date:  2022.06.16.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module DMA_Dispatch(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* pkt in & out;
  ,input  wire                    i_pkt_valid
  ,input  wire  [         133:0]  i_pkt
  ,output reg   [   `NUM_PE-1:0]  o_pkt_valid
  ,output reg   [         133:0]  o_pkt
  ,input  wire  [`NUM_PE*10-1:0]  i_usedw_dmaWR
  //* length out;
  ,output reg   [          15:0]  o_din_length
  ,output reg   [   `NUM_PE-1:0]  o_wren_length
  //* filter pkt;
  ,input  wire  [   `NUM_PE-1:0]  i_filter_en
  ,input  wire  [   `NUM_PE-1:0]  i_filter_dmac_en
  ,input  wire  [   `NUM_PE-1:0]  i_filter_smac_en
  ,input  wire  [   `NUM_PE-1:0]  i_filter_type_en
  ,input  wire  [ `NUM_PE*8-1:0]  i_filter_dmac
  ,input  wire  [ `NUM_PE*8-1:0]  i_filter_smac
  ,input  wire  [ `NUM_PE*8-1:0]  i_filter_type
  //* i_start_en
  ,input  wire  [   `NUM_PE-1:0]  i_start_en
  //* debug;
  ,output wire  [           2:0]  d_inc_pkt_3b
  ,output wire                    d_state_dist_1b
);

  //==============================================================//
  //  w_ready
  //==============================================================//
  wire          [   `NUM_PE-1:0]  w_ready;
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe=i_pe+1) begin: dma_ready
      assign w_ready[i_pe]      = i_usedw_dmaWR[i_pe*10+:10] <= 10'd28;
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  calc legth & dispatch pkt   
  //==============================================================//
  reg         state_distribute;
  localparam  IDLE_S            = 1'b0,
              WAIT_END_S        = 1'b1;

  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_din_length              <= 16'b0;
      o_wren_length             <= {`NUM_PE{1'b0}};
      o_pkt                     <= 134'b0;
      o_pkt_valid               <= {`NUM_PE{1'b0}};
      state_distribute          <= IDLE_S;
    end else begin
      //* write dmaWR fifo;
      o_pkt                     <= i_pkt;
      
      case (state_distribute)
        IDLE_S: begin
          o_pkt_valid           <= 3'b0;
          o_wren_length         <= 3'b0;
          if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b11) begin
            o_pkt_valid         <= i_pkt[82:80] & w_ready & i_start_en;
            //* filter pkt to PE_0, PE_1 or PE_2;
            for(i = 0; i < `NUM_PE; i = i + 1) begin
              if(i_filter_en[i] == 1'b1 && 
                ( (i_pkt[127:120] == 8'hff) ||  //* broadcast;
                  (i_filter_dmac_en[i] == 1'b1 && i_filter_dmac[i*8+:8] == i_pkt[120+:8]) || //* dmac;
                  (i_filter_smac_en[i] == 1'b1 && i_filter_smac[i*8+:8] == i_pkt[112+:8]) || //* smac;
                  (i_filter_type_en[i] == 1'b1 && i_filter_type[i*8+:8] == i_pkt[104+:8])    //* type;
                ))
              begin
                o_pkt_valid[i]  <= w_ready[i];
              end
            end

            //* claculate length by myself;
            // o_din_length        <= {1'b0,i_pkt[14:0]} + 16'd32;
            o_din_length        <= 16'd17;
            state_distribute    <= WAIT_END_S;
          end
          else begin
            state_distribute    <= IDLE_S;
          end
        end
        WAIT_END_S: begin
          o_wren_length         <= {`NUM_PE{1'b0}};
          //* write length after receiving one completed pkt, always send to port_0, TODO,;
          if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b10) begin
            o_wren_length       <= o_pkt_valid;
            state_distribute    <= IDLE_S;
            o_din_length        <= i_pkt[131:128] + o_din_length;
          end
          else begin
            o_din_length        <= 16'd16 + o_din_length;
            state_distribute    <= WAIT_END_S;
          end
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  //* debug;
  assign      d_state_dist_1b   = state_distribute;
  assign      d_inc_pkt_3b[0]   = (o_pkt_valid[0] == 1'b1 && o_pkt[133:132] == 2'b10);
  assign      d_inc_pkt_3b[1]   = (o_pkt_valid[1] == 1'b1 && o_pkt[133:132] == 2'b10);
  assign      d_inc_pkt_3b[2]   = (o_pkt_valid[2] == 1'b1 && o_pkt[133:132] == 2'b10);

endmodule
