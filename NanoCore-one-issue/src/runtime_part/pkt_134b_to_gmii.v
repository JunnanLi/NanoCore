/*
 *  Project:            timelyRV_v0.1 -- a RISCV-32I SoC.
 *  Module name:        pkt_134b_to_gmii.
 *  Description:        Divide 134b pkt into sixteen 8b gmii data.
 *  Last updated date:  2021.07.22.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) 134b pkt data definition: 
 *      [133:132] head tag, 2'b01 is head, 2'b10 is tail;
 *      [131:128] valid tag, 4'b1111 means sixteen 8b data is valid;
 *      [127:0]   pkt data, invalid part is padded with 0;
 *
 */

`timescale 1ns / 1ps

module pkt_134b_to_gmii(
  input                   rst_n,
  input                   clk,
  input                   pkt_data_valid,
  input         [133:0]   pkt_data,
  output  reg   [7:0]     gmii_data,
  output  reg             gmii_data_valid,
  output  reg   [31:0]    cnt_pkt
);

//* fifo;
(* mark_debug = "true"*)reg           rden_pkt;
(* mark_debug = "true"*)wire          empty_pkt;
(* mark_debug = "true"*)wire  [133:0] dout_pkt;

(* mark_debug = "true"*)reg   [1:0]   head_tag;
reg   [7:0]   pkt_tag[15:0];
reg   [3:0]   cnt_valid, cnt_gmii;
(* mark_debug = "true"*)reg   [15:0]  cnt_total_gmii;
reg   [2:0]   cnt_pktHead;
(* mark_debug = "true"*)reg   [3:0]   state_div;
reg   [3:0]   cnt_wait_clk;
localparam    IDLE_S        = 4'd0,
              PAD_PKT_TAG_S = 4'd1,
              READ_PKT      = 4'd2,
              TRANS_PKT_S   = 4'd3,
              PAD_TO_64B_S  = 4'd4,
              WAIT_S        = 4'd5;

integer i;
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    gmii_data_valid <= 1'b0;
    gmii_data       <= 8'b0;
    
    cnt_pkt         <= 32'b0;
    rden_pkt        <= 1'b0;
    cnt_gmii        <= 4'd0;
    cnt_total_gmii  <= 16'b0;
    cnt_wait_clk    <= 4'b0;
    cnt_pktHead     <= 3'b0;
    head_tag        <= 2'b0;
    for(i=0; i<16; i=i+1) begin
      pkt_tag[i]    <= 8'b0;
    end
    
    state_div       <= IDLE_S;
  end
  else begin
    cnt_gmii              <= 4'd1 + cnt_gmii;
    case(state_div)
      IDLE_S: begin
        rden_pkt          <= 1'b0;
        cnt_total_gmii    <= 16'b0;
        if(empty_pkt == 1'b0) begin
          cnt_pkt         <= cnt_pkt + 32'd1;
          `ifdef WITHOUT_FRAME_HEAD
            rden_pkt      <= 1'b1;
            state_div     <= READ_PKT;
          `else
            cnt_pktHead   <= 3'b0;
            state_div     <= PAD_PKT_TAG_S;
          `endif
        end
      end
      PAD_PKT_TAG_S: begin
        cnt_pktHead       <= cnt_pktHead + 3'd1;
        if(cnt_pktHead == 3'd7) begin
          gmii_data       <= 8'hd5;
          rden_pkt        <= 1'b1;
          state_div       <= READ_PKT;
        end
        else begin
          gmii_data       <= 8'h55;
        end
        gmii_data_valid   <= 1'b1;
      end
      READ_PKT: begin
        rden_pkt          <= 1'b0;
        {head_tag,cnt_valid,pkt_tag[0],pkt_tag[1],pkt_tag[2],
          pkt_tag[3],pkt_tag[4],pkt_tag[5],pkt_tag[6],pkt_tag[7],
          pkt_tag[8],pkt_tag[9],pkt_tag[10],pkt_tag[11],
          pkt_tag[12],pkt_tag[13],pkt_tag[14],pkt_tag[15]} <= dout_pkt[127:0];
        head_tag          <= dout_pkt[133:132];
        cnt_valid         <= dout_pkt[131:128];
        cnt_gmii          <= 4'd0;
        cnt_total_gmii    <= cnt_total_gmii + 16'd1;

        gmii_data_valid   <= 1'b1;
        gmii_data         <= dout_pkt[127:120];
        state_div         <= TRANS_PKT_S;
      end
      TRANS_PKT_S: begin
        (* full_case, parallel_case *)
        case(cnt_gmii)
          4'd0: gmii_data <= pkt_tag[1];
          4'd1: gmii_data <= pkt_tag[2];
          4'd2: gmii_data <= pkt_tag[3];
          4'd3: gmii_data <= pkt_tag[4];
          4'd4: gmii_data <= pkt_tag[5];
          4'd5: gmii_data <= pkt_tag[6];
          4'd6: gmii_data <= pkt_tag[7];
          4'd7: gmii_data <= pkt_tag[8];
          4'd8: gmii_data <= pkt_tag[9];
          4'd9: gmii_data <= pkt_tag[10];
          4'd10: gmii_data<= pkt_tag[11];
          4'd11: gmii_data<= pkt_tag[12];
          4'd12: gmii_data<= pkt_tag[13];
          4'd13: gmii_data<= pkt_tag[14];
          4'd14: gmii_data<= pkt_tag[15];
          4'd15: gmii_data<= pkt_tag[0];
        endcase
        
        cnt_gmii          <= cnt_gmii + 4'd1;
        cnt_total_gmii    <= cnt_total_gmii + 16'd1;
        cnt_valid         <= cnt_valid - 4'd1;
        gmii_data_valid   <= 1'b1;
        if(cnt_valid == 4'd0 && head_tag == 2'b10) begin
          
          if(cnt_total_gmii < 16'd60) begin
            gmii_data_valid <= 1'b1;
            gmii_data       <= 8'b0;
            state_div       <= PAD_TO_64B_S;
          end
          else begin
            gmii_data_valid <= 1'b0;
            cnt_wait_clk    <= 4'd0;
            state_div       <= WAIT_S;
          end
        end
        else if(cnt_valid == 4'd1 && head_tag != 2'b10) begin
          rden_pkt        <= 1'b1;
          state_div       <= READ_PKT;
        end
      end
      PAD_TO_64B_S: begin
        cnt_total_gmii    <= cnt_total_gmii + 16'd1;
        gmii_data_valid   <= 1'b1;
        if(cnt_total_gmii == 16'd60) begin
          gmii_data_valid <= 1'b0;
          cnt_wait_clk    <= 4'd0;
          state_div       <= WAIT_S;
        end
      end
      WAIT_S: begin
        cnt_wait_clk      <= 4'd1 + cnt_wait_clk;
        if(cnt_wait_clk == 4'd11) state_div <= IDLE_S;
        else                      state_div <= WAIT_S;
      end
      default: begin
        state_div         <= IDLE_S;
      end
    endcase
    
  end
end




fifo_134b_512 fifo_pkt (
  .clk    (clk),              // input wire clk
  .srst   (!rst_n),           // input wire srst
  .din    (pkt_data),         // input wire [133 : 0] din
  .wr_en  (pkt_data_valid),   // input wire wr_en
  .rd_en  (rden_pkt),         // input wire rd_en
  .dout   (dout_pkt),         // output wire [133 : 0] dout
  .full   (),                 // output wire full
  .empty  (empty_pkt)         // output wire empty
);



endmodule
