/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DRA_Recv_Send_Pkt.
 *  Description:        This module is used to recv & send packets.
 *  Last updated date:  2022.08.18.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module DRA_Recv_Send_Pkt(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* interface for receiving/sending pkt;
  ,input  wire                    i_empty_pktRecv
  ,output reg                     o_rden_pktRecv
  ,input  wire  [         133:0]  i_dout_pktRecv
  ,output reg                     o_pkt_valid
  ,output reg   [         133:0]  o_pkt  
  //* interface for reading/writing pkt;
  ,output reg                     o_wren_pktRAM_hw
  ,output reg   [          15:0]  o_addr_pktRAM_hw
  ,output reg   [         511:0]  o_din_pktRAM_hw
  ,input  wire  [         511:0]  i_dout_pktRAM_hw
  //* interface for writing despRecv;
  ,output reg   [         127:0]  o_din_despRecv
  ,output reg   [   `NUM_PE-1:0]  o_wren_despRecv
  //* interface for reading despSend;
  ,output reg   [   `NUM_PE-1:0]  o_rden_despSend
  ,input  wire  [`NUM_PE*128-1:0] i_dout_despSend
  ,input  wire  [   `NUM_PE-1:0]  i_empty_despSend
  //* interface for writeReq;
  ,input  wire  [   `NUM_PE-1:0]  i_empty_writeReq
);
  
  //======================= internal reg/wire/param declarations =//
  localparam    IDLE_S            = 4'd0,
                JUDGE_S           = 4'd1,
                WAIT_1_S          = 4'd2,
                READ_META_0_S     = 4'd3,
                READ_META_1_S     = 4'd4,
                READ_PKT_S        = 4'd5,
                SEND_PKT_S        = 4'd6,
                WAIT_END_S        = 4'd7,
                GET_FREE_BUF_S    = 4'd8;

  wire          [         127:0]  w_dout_despSend[2:0];
  assign        {w_dout_despSend[2],w_dout_despSend[1],
                    w_dout_despSend[0]}             = i_dout_despSend;

  //* temp registers; 
  reg           [          15:0]  r_send_length;
  reg           [           3:0]  r_freeAddr_p, r_toFreeAddr_p;
  reg           [           1:0]  r_cnt_pktData;
  reg           [          11:0]  bm_freeBuf;
  reg           [   `NUM_PE-1:0]  r_temp_wren_despRecv;
  reg           [           3:0]  state_arbi;
  reg           [         127:0]  r_temp_despSend;
  //==============================================================//
  
  //======================= reading/writing pkt ==================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      //* pktRecv/desp fifo interface;
      o_rden_pktRecv                    <= 1'b0;    
      o_wren_despRecv                   <= {`NUM_PE{1'b0}};
      r_temp_wren_despRecv              <= {`NUM_PE{1'b0}};
      r_temp_despSend                   <= 128'b0;
      o_din_despRecv                    <= 128'b0;
      o_rden_despSend                   <= {`NUM_PE{1'b0}};
      //* sram interface;
      o_addr_pktRAM_hw                  <= 16'b0;
      o_wren_pktRAM_hw                  <= 1'b0;
      o_din_pktRAM_hw                   <= 512'b0;
      //* length, used to output pkt;
      r_send_length                     <= 16'b0;
      //* temp Register;
      r_freeAddr_p                      <= 4'b0;
      r_toFreeAddr_p                    <= 4'b0;
      bm_freeBuf                        <= 12'b0;
      r_cnt_pktData                     <= 2'b0;
      state_arbi                        <= IDLE_S;
      //* output pkt;
      o_pkt_valid                       <= 1'b0;
      o_pkt                             <= 134'b0;
    end
    else begin
      case(state_arbi)
        IDLE_S: begin
          o_pkt_valid                   <= 1'b0;
          o_wren_pktRAM_hw              <= 1'b0;
          o_wren_despRecv               <= {`NUM_PE{1'b0}};
          o_rden_despSend               <= {`NUM_PE{1'b0}};
          o_addr_pktRAM_hw              <= 16'b0;
          
          //* write pkt to SRAM from fifo (recv);
          if((&bm_freeBuf) == 1'b0 && i_empty_pktRecv == 1'b0) begin //* read pktRecv;
            r_cnt_pktData               <= 2'b0;
            if((&bm_freeBuf[5:0]) == 1'b0) begin
              o_rden_pktRecv            <= 1'b1;
              (*full_case, parallel_case*)
              casex(bm_freeBuf[5:0])
                6'bxxxxx0: begin
                  r_freeAddr_p          <= 4'd0;
                  bm_freeBuf[0]         <= 1'b1;
                end
                6'bxxxx01: begin
                  r_freeAddr_p          <= 4'd1;
                  bm_freeBuf[1]         <= 1'b1;
                end
                6'bxxx011: begin
                  r_freeAddr_p          <= 4'd2;
                  bm_freeBuf[2]         <= 1'b1;
                end
                6'bxx0111: begin
                  r_freeAddr_p          <= 4'd3;
                  bm_freeBuf[3]         <= 1'b1;
                end
                6'bx01111: begin
                  r_freeAddr_p          <= 4'd4;
                  bm_freeBuf[4]         <= 1'b1;
                end
                6'b011111: begin
                  r_freeAddr_p          <= 4'd5;
                  bm_freeBuf[5]         <= 1'b1;
                end
              endcase
              state_arbi                <= READ_META_0_S;
            end
            else begin
              state_arbi                <= GET_FREE_BUF_S;
            end
          end
          //* output pkt by reading pkt from SRAM;
          else if(i_empty_despSend[0] == 1'b0 && i_empty_writeReq[0] == 1'b1) begin 
            o_rden_despSend             <= 3'b1;
            o_addr_pktRAM_hw            <= {7'b0,w_dout_despSend[0][123-:4],5'b0};
            r_send_length               <= w_dout_despSend[0][111-:16] - 16'd17;
            r_temp_wren_despRecv        <= w_dout_despSend[0][124+:`NUM_PE];
            r_temp_despSend             <= w_dout_despSend[0];
            state_arbi                  <= JUDGE_S;
          end
          else if(i_empty_despSend[1] == 1'b0 && i_empty_writeReq[1] == 1'b1) begin 
            o_rden_despSend             <= 3'b10;
            o_addr_pktRAM_hw            <= {7'b0,w_dout_despSend[1][123-:4],5'b0};
            r_send_length               <= w_dout_despSend[1][111-:16] - 16'd17;
            r_temp_wren_despRecv        <= w_dout_despSend[1][124+:`NUM_PE];
            r_temp_despSend             <= w_dout_despSend[1];
            state_arbi                  <= JUDGE_S;
          end
          else if(i_empty_despSend[2] == 1'b0 && i_empty_writeReq[2] == 1'b1) begin 
            o_rden_despSend             <= 3'b100;
            o_addr_pktRAM_hw            <= {7'b0,w_dout_despSend[2][123-:4],5'b0};
            r_send_length               <= w_dout_despSend[2][111-:16] - 16'd17;
            r_temp_wren_despRecv        <= w_dout_despSend[2][124+:`NUM_PE];
            r_temp_despSend             <= w_dout_despSend[2];
            state_arbi                  <= JUDGE_S;
          end
        end
        GET_FREE_BUF_S: begin
          (*full_case, parallel_case*)
          casex(bm_freeBuf[11:6])
            6'bxxxxx0: begin
              r_freeAddr_p    <= 4'd6;
              bm_freeBuf[6]   <= 1'b1;
            end
            6'bxxxx01: begin
              r_freeAddr_p    <= 4'd7;
              bm_freeBuf[7]   <= 1'b1;
            end
            6'bxxx011: begin
              r_freeAddr_p    <= 4'd8;
              bm_freeBuf[8]   <= 1'b1;
            end
            6'bxx0111: begin
              r_freeAddr_p    <= 4'd9;
              bm_freeBuf[9]   <= 1'b1;
            end
            6'bx01111: begin
              r_freeAddr_p    <= 4'd10;
              bm_freeBuf[10]  <= 1'b1;
            end
            6'b011111: begin
              r_freeAddr_p    <= 4'd11;
              bm_freeBuf[11]  <= 1'b1;
            end
            default: begin
              r_freeAddr_p    <= 4'd0;
              bm_freeBuf[0]   <= 1'b1;
            end
          endcase
          o_rden_pktRecv              <= 1'b1;
          state_arbi                  <= READ_META_0_S;
        end
        READ_META_0_S: begin
          //* get new 128b description;
          o_din_despRecv[127-:64]     <= {4'b0,r_freeAddr_p, 8'b0,    //* 16b addr;
                                          1'b0,i_dout_pktRecv[14:0],  //* 16b length;
                                          i_dout_pktRecv[95:88],8'h80,     //* 8b outport, 8b inport;
                                          i_dout_pktRecv[47:32]};     //* 16b flowid
          r_temp_wren_despRecv        <= i_dout_pktRecv[80+:`NUM_PE];
          //* save original metadata;
          // o_din_pktRAM_hw[128*3+:128] <= i_dout_pktRecv[127:0];
          state_arbi                  <= READ_META_1_S;
        end
        READ_META_1_S: begin
          o_din_despRecv[63:0]        <= i_dout_pktRecv[63:0];
          //* save original metadata;
          // o_din_pktRAM_hw[128*2+:128] <= i_dout_pktRecv[127:0];
          // o_wren_pktRAM_hw            <= 1'b1;
          o_addr_pktRAM_hw            <= {7'b0, r_freeAddr_p, 5'h1f};
          //* state;
          state_arbi                  <= READ_PKT_S;
        end
        READ_PKT_S: begin
          r_cnt_pktData               <= r_cnt_pktData + 2'd1;
          (*full_case, parallel_case*)
          case(r_cnt_pktData)
            2'd0: o_din_pktRAM_hw[128*3+:128] <= i_dout_pktRecv[127:0];
            2'd1: o_din_pktRAM_hw[128*2+:128] <= i_dout_pktRecv[127:0];
            2'd2: o_din_pktRAM_hw[128*1+:128] <= i_dout_pktRecv[127:0];
            2'd3: o_din_pktRAM_hw[128*0+:128] <= i_dout_pktRecv[127:0];
          endcase
          o_wren_pktRAM_hw            <= (r_cnt_pktData == 2'd3 || 
                                          i_dout_pktRecv[133:132] == 2'b10)? 1'b1: 1'b0;
          o_addr_pktRAM_hw            <= (r_cnt_pktData == 2'd3)? {o_addr_pktRAM_hw[15:5], 
                                          (o_addr_pktRAM_hw[4:0]+5'd1)}: o_addr_pktRAM_hw;
          
          //* write description after receiving one completed pkt;
          if(i_dout_pktRecv[133:132] == 2'b10) begin
            o_rden_pktRecv            <= 1'b0;
            //* distribute pkt;
            o_wren_despRecv           <= r_temp_wren_despRecv;
            o_addr_pktRAM_hw          <= {o_addr_pktRAM_hw[15:5], 
                                          (o_addr_pktRAM_hw[4:0]+5'd1)};
            state_arbi                <= IDLE_S;
          end
          else begin
            state_arbi                <= READ_PKT_S;
          end
        end
        JUDGE_S: begin
          o_rden_despSend             <= 3'b0;
          if(r_temp_despSend[127] == 1'b1) begin
            r_cnt_pktData             <= 2'd0;
            r_toFreeAddr_p            <= r_temp_despSend[123:120];
            state_arbi                <= WAIT_END_S;
          end
          else if(r_temp_wren_despRecv == 3'b0) begin
            o_pkt_valid               <= 1'b1;
            r_toFreeAddr_p            <= r_temp_despSend[123:120];
            state_arbi                <= WAIT_1_S;
          end
          else begin
            o_pkt_valid               <= 1'b0;
            o_wren_despRecv           <= r_temp_wren_despRecv;
            o_din_despRecv            <= {4'b0,r_temp_despSend[123:0]};
            state_arbi                <= IDLE_S;
          end
          //* reconstructe metadata;
          o_pkt                       <= {2'b11, 4'hf, 24'b0,       //* pad;
                                          r_temp_despSend[95:80],   //* inPort, outPort;
                                          8'b0, 16'b0, 16'b0,       //* PEBM, bufID, Ctrl;
                                          r_temp_despSend[79:64],   //* flowID;
                                          8'b0, 8'b0,               //* Priority, DMID;
                                          r_temp_despSend[111:96]}; //* length;
        end
        WAIT_1_S: begin
          //* reconstructe metadata;
          o_pkt                       <= {2'b11, 4'hf, 64'b0,       //* pad;
                                          r_temp_despSend[63:0]};   //* timestamp;
          o_pkt_valid                 <= 1'b1;
          state_arbi                  <= SEND_PKT_S;
        end
        SEND_PKT_S: begin
          r_cnt_pktData               <= 2'd0;
          o_pkt_valid                 <= 1'b1;
          o_pkt                       <= {2'b01,4'hf,i_dout_pktRAM_hw[128*3+:128]};
          state_arbi                  <= WAIT_END_S;
        end
        WAIT_END_S: begin
          r_cnt_pktData               <= r_cnt_pktData + 2'd1;
          o_addr_pktRAM_hw            <= (r_cnt_pktData == 2'b0)? (o_addr_pktRAM_hw + 9'd1):
                                            o_addr_pktRAM_hw;
          r_send_length               <= r_send_length - 16'd16;
          (*full_case, parallel_case*)
          case(r_cnt_pktData)
            2'd0: o_pkt[127:0]        <= i_dout_pktRAM_hw[128*2+:128];
            2'd1: o_pkt[127:0]        <= i_dout_pktRAM_hw[128*1+:128];
            2'd2: o_pkt[127:0]        <= i_dout_pktRAM_hw[128*0+:128];
            2'd3: o_pkt[127:0]        <= i_dout_pktRAM_hw[128*3+:128];
          endcase
          if(r_send_length[15:4] == 12'b0) begin
            o_pkt[133:128]            <= {2'b10,r_send_length[3:0]};
            state_arbi                <= IDLE_S;
            //* free bufferID;
            case(r_toFreeAddr_p)
              4'd0:   bm_freeBuf[0]   <= 1'b0;
              4'd1:   bm_freeBuf[1]   <= 1'b0;
              4'd2:   bm_freeBuf[2]   <= 1'b0;
              4'd3:   bm_freeBuf[3]   <= 1'b0;
              4'd4:   bm_freeBuf[4]   <= 1'b0;
              4'd5:   bm_freeBuf[5]   <= 1'b0;
              4'd6:   bm_freeBuf[6]   <= 1'b0;
              4'd7:   bm_freeBuf[7]   <= 1'b0;
              4'd8:   bm_freeBuf[8]   <= 1'b0;
              4'd9:   bm_freeBuf[9]   <= 1'b0;
              4'd10:  bm_freeBuf[10]  <= 1'b0;
              4'd11:  bm_freeBuf[11]  <= 1'b0;
              default: begin end
            endcase
          end
          else begin
            o_pkt[133:128]            <= {2'b00,4'hf};
          end
        end
        default: begin 
          state_arbi          <= IDLE_S;
        end
      endcase
    end
  end

  //* for test;
  reg [15:0] cnt_clk_maintain[11:0];
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      for (i = 0; i < 12; i = i+1)
        cnt_clk_maintain[i]   <= 16'b0;
    end
    else begin
      for (i = 0; i < 12; i = i+1) begin
        cnt_clk_maintain[i]   <= (bm_freeBuf[i] == 1'b1)? (16'd1 + cnt_clk_maintain[i]) : 16'b0;
      end
    end
  end

endmodule
