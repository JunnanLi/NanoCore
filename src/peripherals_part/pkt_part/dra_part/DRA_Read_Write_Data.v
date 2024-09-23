/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DRA_Read_Write_Data.
 *  Description:        This module is used to Modify packets.
 *  Last updated date:  2022.08.19.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module DRA_Read_Write_Data(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* reset/start dra;
  ,input  wire  [          2:0]   i_reset_en
  ,input  wire  [          2:0]   i_start_en
  //* interface for reading/writing data;
  ,output reg                     o_wren_pktRAM_core
  ,output reg   [         15:0]   o_addr_pktRAM_core
  ,output reg   [        511:0]   o_din_pktRAM_core
  ,input  wire  [        511:0]   i_dout_pktRAM_core
  //* interface for reading despRecv;
  ,output reg   [          2:0]   o_rden_despRecv
  ,input  wire  [    128*3-1:0]   i_dout_despRecv
  ,input  wire  [          2:0]   i_empty_despRecv
  //* interface for writing despSend;
  ,output wire  [    128*3-1:0]   o_din_despSend
  ,output reg   [          2:0]   o_wren_despSend
  //* interface for writeReq;
  ,output wire  [    528*3-1:0]   o_din_writeReq
  ,output reg   [          2:0]   o_wren_writeReq
  ,output reg   [          2:0]   o_rden_writeReq
  ,input  wire  [    528*3-1:0]   i_dout_writeReq
  ,input  wire  [          2:0]   i_empty_writeReq
  //* interface for DRA;
  ,input  wire  [          2:0]   i_reg_rd      //* read req
  ,input  wire  [         95:0]   i_reg_raddr   //* read addr;
  ,output reg   [        511:0]   o_reg_rdata   //* return read data;
  ,output reg   [          2:0]   o_reg_rvalid 
  ,output reg   [          2:0]   o_reg_rvalid_desp   //* upload received new pkt;
  ,input  wire  [          2:0]   i_reg_wr      //* write req;
  ,input  wire  [          2:0]   i_reg_wr_desp //* write desception;
  ,input  wire  [         95:0]   i_reg_waddr   //* write addr;
  ,input  wire  [    512*3-1:0]   i_reg_wdata   //* write data;
  ,input  wire  [         95:0]   i_status      //* [0] (is '0') to recv next pkt;
  ,output wire  [         95:0]   o_status      //* TODO, has not been used;
);
  
  //======================= internal reg/wire/param declarations =//
  wire  [31:0]  w_cpu_status[2:0];
  reg   [31:0]  r_hw_status[2:0];
  assign        {w_cpu_status[2], w_cpu_status[1], w_cpu_status[0]} = i_status;
  assign        o_status            = {r_hw_status[2], r_hw_status[1], r_hw_status[0]};
                                        
  wire  [527:0] w_dout_writeReq[2:0];
  reg   [527:0] r_din_writeReq[2:0];
  assign        {w_dout_writeReq[2], w_dout_writeReq[1], w_dout_writeReq[0]} = i_dout_writeReq;
  assign        o_din_writeReq      = {r_din_writeReq[2], r_din_writeReq[1], r_din_writeReq[0]};
                                        
  reg   [127:0] r_din_despSend[2:0];
  assign        o_din_despSend      = {r_din_despSend[2], r_din_despSend[1], r_din_despSend[0]};
                                        

  wire  [31:0]  w_reg_waddr[2:0];
  wire  [511:0] w_reg_wdata[2:0];
  assign        {w_reg_waddr[2], w_reg_waddr[1], w_reg_waddr[0]} = i_reg_waddr;
  assign        {w_reg_wdata[2], w_reg_wdata[1], w_reg_wdata[0]} = i_reg_wdata;

  localparam    STATUS_READ_DATA    = 31;
  localparam    STATUS_WRITE_DATA   = 30;
  localparam    STATUS_RECV_PKT     = 29;
  localparam    STATUS_SEND_PKT     = 28;
  localparam    STATUS_REPLACE_DATA = 27;

  localparam    IDLE_S              = 4'd0,
                WAIT_1_S            = 4'd1,
                WAIT_2_S            = 4'd2,
                WAIT_3_S            = 4'd3,
                WR_PKT_S            = 4'd4,
                WR_DESP_S           = 4'd6,
                READ_REQ_S          = 4'd7,
                READ_PKT_S          = 4'd8,
                SEND_PKT_S          = 4'd9,
                WAIT_END_S          = 4'd10;
  reg   [3:0]   state_core;
  reg   [2:0]   r_cpuID;    //* to check which PE's status;
  reg           tag_desp;   //* distanguish uploading 512b_data or 512b_data & 128b_desp.
  //==============================================================//

  //======================= Write & Read PktRAM ==================//
  //* SRAM (port b) arbitration, i.e., DRA (Direct Register Access); 
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      //* output signals;
      o_reg_rdata               <= 512'b0;
      o_reg_rvalid              <= 3'b0;
      o_reg_rvalid_desp         <= 3'b0;
      //* internal status;
      r_cpuID                   <= 3'b0;
      tag_desp                  <= 1'b0;
      state_core                <= IDLE_S;
      //* SRAM interface (port b);
      o_addr_pktRAM_core        <= 16'b0;
      o_wren_pktRAM_core        <= 1'b0;
      o_din_pktRAM_core         <= 512'b0;
      //* desp fifo interface;
      o_rden_despRecv           <= 3'b0;
      o_wren_despSend           <= 3'b0;
      //* write back fifo (from cpu) interface;
      o_wren_writeReq           <= 3'b0;
      o_rden_writeReq           <= 3'b0;
      //* temp
      for(i=0; i<3; i=i+1) begin
        r_hw_status[i]          <= 32'b0;
        r_din_despSend[i]       <= 128'b0;
        r_din_writeReq[i]       <= 528'b0;
      end 
    end
    else begin
      for(i=0; i<3; i=i+1) begin
        r_hw_status[i]          <= r_hw_status[i];
      end
      case(state_core)
        IDLE_S: begin
          o_rden_despRecv       <= 3'b0;
          o_reg_rvalid_desp     <= 3'b0;
          o_reg_rvalid          <= 3'b0;
          o_wren_pktRAM_core    <= 1'b0;

          //* upload next pkt to mem_recv;
          if( (w_cpu_status[0][0] == 1'b0 && i_empty_despRecv[0] == 1'b0 && i_start_en[0] == 1'b1) ||
              (w_cpu_status[1][0] == 1'b0 && i_empty_despRecv[1] == 1'b0 && i_start_en[1] == 1'b1) ||
              (w_cpu_status[2][0] == 1'b0 && i_empty_despRecv[2] == 1'b0 && i_start_en[2] == 1'b1) ) 
          begin
            o_addr_pktRAM_core  <= (w_cpu_status[0][0] == 1'b0 && i_empty_despRecv[0] == 1'b0 &&
                                    i_start_en[0]    == 1'b1)? {7'b0,i_dout_despRecv[123-:4],5'b0}:
                                   (w_cpu_status[1][0] == 1'b0 && i_empty_despRecv[1] == 1'b0 &&
                                    i_start_en[1]    == 1'b1)? {7'b0,i_dout_despRecv[251-:4],5'b0}:
                                      {7'b0,i_dout_despRecv[379-:4],5'b0};
            r_cpuID             <= (w_cpu_status[0][0] == 1'b0 && i_empty_despRecv[0] == 1'b0 &&
                                      i_start_en[0]    == 1'b1)? 3'b1:
                                   (w_cpu_status[1][0] == 1'b0 && i_empty_despRecv[1] == 1'b0 &&
                                      i_start_en[1]    == 1'b1)? 3'b10: 3'b100;
            tag_desp            <= 1'b1;
            state_core          <= WAIT_1_S;
          end
          //* upload 4*128b_data to mem_rf3;
          else if(|i_reg_rd == 1'b1) begin
            tag_desp            <= 1'b0;
            state_core          <= WAIT_1_S;

            //* for NUM_PE = 3, TODO,;
            r_hw_status[0][STATUS_READ_DATA]  <= 1'b0;
            r_hw_status[1][STATUS_READ_DATA]  <= 1'b0;
            r_hw_status[2][STATUS_READ_DATA]  <= 1'b0;
            casex(i_reg_rd)
              3'bxx1: begin
                r_cpuID                       <= 3'b001;
                o_addr_pktRAM_core            <= i_reg_raddr[0+:16];
              end
              3'bx10: begin
                r_cpuID                       <= 3'b010;
                o_addr_pktRAM_core            <= i_reg_raddr[32*1+:16];
              end
              3'b100: begin
                r_cpuID                       <= 3'b100;
                o_addr_pktRAM_core            <= i_reg_raddr[32*2+:16];
              end
            endcase
          end
          //* wirte back 4*128b data to SRAM;
          else if(&i_empty_writeReq == 1'b0) begin
            casex(i_empty_writeReq)
              3'bxx0: begin
                r_cpuID                       <= 3'b001;
                o_rden_writeReq               <= 3'b001;            
              end
              3'bx01: begin
                r_cpuID                       <= 3'b010;
                o_rden_writeReq               <= 3'b010;
              end
              3'b011: begin
                r_cpuID                       <= 3'b100;
                o_rden_writeReq               <= 3'b100;
              end
            endcase
            state_core          <= READ_REQ_S;
          end
        end
        WAIT_1_S: begin
            state_core          <= WAIT_2_S;
        end
        WAIT_2_S: begin
            state_core          <= WR_PKT_S;
        end
        WR_PKT_S: begin
          for(i=0; i<3; i=i+1) begin
            o_reg_rvalid_desp[i]  <= (r_cpuID[i] == 1'b1)? tag_desp: 1'b0;
            o_reg_rvalid[i]       <= (r_cpuID[i] == 1'b1)? !tag_desp: 1'b0;
            r_hw_status[i][STATUS_READ_DATA]  <= 1'b1;
          end
          o_reg_rdata           <= i_dout_pktRAM_core;
          state_core            <= (tag_desp == 1'b1)? WR_DESP_S: IDLE_S;
        end
        WR_DESP_S: begin
          o_rden_despRecv       <= r_cpuID;
          //* metadata;
          o_reg_rdata[0+:128]   <= (r_cpuID[0] == 1'b1)?  i_dout_despRecv[    0+:128]:
                                    (r_cpuID[1] == 1'b1)? i_dout_despRecv[  128+:128]:
                                                          i_dout_despRecv[2*128+:128];
          o_reg_rdata[511:128]  <= 384'b0;
          state_core            <= WAIT_3_S;
        end
        WAIT_3_S: begin
          o_rden_despRecv       <= 3'b0;
          o_reg_rvalid_desp     <= 3'b0;
          o_reg_rvalid          <= 3'b0;
          state_core            <= IDLE_S;
        end
        READ_REQ_S: begin
          o_rden_writeReq       <= 3'b0;
          o_wren_pktRAM_core    <= 1'b1;
          {o_addr_pktRAM_core, 
            o_din_pktRAM_core}  <= (r_cpuID[0] == 1'b1)? w_dout_writeReq[0]:
                                    (r_cpuID[1] == 1'b1)? w_dout_writeReq[1]:
                                      w_dout_writeReq[2];
          state_core            <= IDLE_S;
        end
        default: begin
          state_core            <= IDLE_S;
        end
      endcase

      //* write desp & req;
      for(i=0; i<3; i=i+1) begin
        o_wren_despSend[i]      <= i_reg_wr_desp[i];
        r_din_despSend[i]       <= w_reg_wdata[i][0+:128];  //* {16b_addr, 16b_length};
        o_wren_writeReq[i]      <= i_reg_wr[i];
        r_din_writeReq[i]       <= {w_reg_waddr[i][15:0], w_reg_wdata[i]};
        r_hw_status[i][STATUS_WRITE_DATA]   <= !o_wren_writeReq[i];
        r_hw_status[i][STATUS_SEND_PKT]     <= !o_wren_despSend[i];

        r_hw_status[i][STATUS_REPLACE_DATA] <= 1'b1;  //* TODO
        r_hw_status[i][STATUS_RECV_PKT]     <= 1'b1;  //* TODO
      end
      
    end
  end
  //==============================================================//

endmodule
