/*
 *  Project:            timelyRV_v0.1 -- a RISCV-32I SoC.
 *  Module name:        soc_runtime.
 *  Description:        Asynchronous recving packets.
 *  Last updated date:  2021.08.21.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) Since two packets will be merged into one while reading speed
 *        is slower than writing speed, we use [8](b) to distinguish,
 *        e.g., any two packets insert one data whose [8](b) is '0'.
 *
 */

`timescale 1ns / 1ps


module asyn_recv_packet(
  input               rst_n,
  input               gmii_rx_clk,
  input       [7:0]   gmii_rxd,
  input               gmii_rx_dv,
  input               gmii_rx_er,
  input               clk_125m,
  output  reg [7:0]   gmii_txd,
  output  reg         gmii_tx_en,
  output  reg         gmii_tx_er,
  output  reg [31:0]  cnt_pkt
);


reg         temp_gmii_rx_dv;
reg   [8:0] din_recv_fifo_9b;
reg         wren_recv_fifo_1b;
reg         rden_recv_fifo_1b;
wire  [8:0] dout_recv_fifo_9b; 
wire        empty_recv_fifo_1b;

//* write fifo;
always @(posedge gmii_rx_clk or negedge rst_n) begin
  if(!rst_n) begin
    din_recv_fifo_9b    <= 9'b0;
    wren_recv_fifo_1b   <= 1'b0;
    temp_gmii_rx_dv     <= 1'b0;
  end
  else begin
    temp_gmii_rx_dv     <= gmii_rx_dv;
    if(gmii_rx_dv == 1'b1) begin
      wren_recv_fifo_1b <= 1'b1;
      din_recv_fifo_9b  <= {1'b1,gmii_rxd};
    end
    else if(temp_gmii_rx_dv == 1'b1) begin
      wren_recv_fifo_1b <= 1'b1;
      din_recv_fifo_9b  <= 9'b0;
    end
    else begin
      wren_recv_fifo_1b <= 1'b0;
    end
  end
end

//* read fifo for recving packet;
reg   [1:0] state_rd;
localparam  IDLE_S              = 2'd0,
            DISCARD_PKT_HEAD_S  = 2'd1,
            WAIT_TAIL_S         = 2'd2;

always @(posedge clk_125m or negedge rst_n) begin
  if(!rst_n) begin
    gmii_tx_er              <= 1'b0;
    gmii_txd                <= 8'b0;
    gmii_tx_en              <= 1'b0;
    cnt_pkt                 <= 32'b0;
    rden_recv_fifo_1b       <= 1'b1;
    state_rd                <= IDLE_S;
  end
  else begin
    case(state_rd)
      IDLE_S: begin
        if(empty_recv_fifo_1b == 1'b0) begin
          cnt_pkt           <= cnt_pkt + 32'd1;
          rden_recv_fifo_1b <= 1'b1;
          `ifdef WITHOUT_FRAME_HEAD
            state_rd        <= WAIT_TAIL_S; 
          `else
            state_rd        <= DISCARD_PKT_HEAD_S; 
          `endif         
        end
        else begin
          rden_recv_fifo_1b <= 1'b0;
          state_rd          <= IDLE_S;
        end
      end
      DISCARD_PKT_HEAD_S: begin
        if(dout_recv_fifo_9b[7:0] == 8'hd5) begin
          state_rd          <= WAIT_TAIL_S;
        end
        else begin
          state_rd          <= DISCARD_PKT_HEAD_S;
        end
      end
      WAIT_TAIL_S: begin
        gmii_txd            <= dout_recv_fifo_9b[7:0];
        gmii_tx_en          <= dout_recv_fifo_9b[8];
        
        if(dout_recv_fifo_9b[8] == 1'b0) begin //* end of one packet;
          rden_recv_fifo_1b <= 1'b0;
          state_rd          <= IDLE_S;
        end
        else begin
          state_rd          <= WAIT_TAIL_S; 
        end
      end
      default: begin
        state_rd            <= IDLE_S;
      end
    endcase
      
  end
end

asfifo_9_1024 asfifo_recv_data(
  .rst(!rst_n),
  .wr_clk(gmii_rx_clk),
  .rd_clk(clk_125m),
  .din(din_recv_fifo_9b),
  .wr_en(wren_recv_fifo_1b),
  .rd_en(rden_recv_fifo_1b),
  .dout(dout_recv_fifo_9b),
  .full(),
  .empty(empty_recv_fifo_1b)
);


endmodule
