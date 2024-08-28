/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Peri.
 *  Description:        This module is used to process Peri's access.
 *  Last updated date:  2022.06.16.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) address:
 *      a) 0x0: i_dout_int ({1'b1, i_dout_pBufWR[30:0]} / 
 *            {1'b0, i_dout_pBufRD[30:0]}), and '0x8000_0000' is empty;
 *      b) 0x1: i_dout_length (16b);
 *      c) 0x2: o_din_pBufWR[31:0]  (32b addr in Byte)
 *      d) 0x3: o_din_pBufWR[47:32] (16b length in Byte)
 *      e) 0x4: o_din_pBufRD[31:0]  (32b addr in Byte)
 *      f) 0x5: o_din_pBufRD[51:32] (4b unvalid_tag, 16b length in Byte)
 *      g) 0x6: cnt_recved_pkt (rd/wr by CPU);
 *      h) 0x7: o_start_en; (should write 0x1234 first);
 *      i) 0x8: o_filter_en (rd/wr by CPU);
 *      j) 0x9: o_filter_dmac_en, o_filter_smac_en, o_filter_type_en (rd/wr by CPU);
 *      k) 0x10:o_filter_dmac (rd/wr by CPU);
 *      l) 0x11:o_filter_smac (rd/wr by CPU);
 *      m) 0x12:o_filter_type (rd/wr by CPU);
 *      n) 0x13:i_wait_free_pBufWR (rd by CPU);
 */

`timescale 1 ns / 1 ps
    
module DMA_Peri(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* write pBuf;
  ,output reg               o_wren_pBufWR
  ,output reg   [47:0]      o_din_pBufWR
  ,output reg               o_wren_pBufRD
  ,output reg   [63:0]      o_din_pBufRD
  //* int in;
  ,output reg               o_rden_int
  ,input  wire  [31:0]      i_dout_int
  ,input  wire              i_empty_int
  //* length in;
  ,(* mark_debug = "true"*)output reg               o_rden_length
  ,(* mark_debug = "true"*)input  wire  [15:0]      i_dout_length
  ,(* mark_debug = "true"*)input  wire              i_empty_length
  //* filter pkt;
  ,output reg               o_filter_en
  ,output reg               o_filter_dmac_en
  ,output reg               o_filter_smac_en
  ,output reg               o_filter_type_en
  ,output reg   [7:0]       o_filter_dmac
  ,output reg   [7:0]       o_filter_smac
  ,output reg   [7:0]       o_filter_type
  //* wait free pBufWR;
  ,input  wire              i_wait_free_pBufWR 
  //* configuration interface for DMA;
  ,input  wire              i_peri_rden
  ,input  wire              i_peri_wren
  ,input  wire  [31:0]      i_peri_addr
  ,input  wire  [31:0]      i_peri_wdata
  ,output reg   [31:0]      o_peri_rdata
  ,output reg               o_peri_ready
  ,output wire              o_peri_int 
  //* o_back_pressure_en for receiving pkt;
  // ,output reg               o_back_pressure_en
  //* o_start_en for starting DMA;
  ,output reg               o_start_en
);

  assign  o_peri_int = ~i_empty_int;

  //======================= Configure pBuf =======================//
  //* write pbuf_wr/rd fifo; 
  reg   [7:0]   r_specReg_cnt_recvPkt; //* cnt of pkts finished dma;
  reg   [31:0]  r_din_pBufWR, r_din_pBufRD;
  reg   [15:0]  r_guard;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_peri_rdata              <= 32'b0;
      o_peri_ready              <= 1'b0;
      o_wren_pBufWR             <= 1'b0;
      o_din_pBufWR              <= 48'b0;
      o_wren_pBufRD             <= 1'b0;
      o_din_pBufRD              <= 64'b0;
      o_rden_int                <= 1'b0;
      o_rden_length             <= 1'b0;
      r_specReg_cnt_recvPkt     <= 8'b0;
      r_din_pBufWR              <= 32'b0;
      r_din_pBufRD              <= 32'b0;
      // o_back_pressure_en        <= 1'b0;
      o_start_en                <= 1'b0;
      r_guard                   <= 16'b0;
      //* filter
      o_filter_en               <= 1'b0;
      o_filter_dmac_en          <= 1'b0;
      o_filter_smac_en          <= 1'b0;
      o_filter_type_en          <= 1'b0;
      o_filter_dmac             <= 8'b0;
      o_filter_smac             <= 8'b0;
      o_filter_type             <= 8'b0;
    end 
    else begin
      o_peri_ready              <= i_peri_rden | i_peri_wren;
      //* read int or length;
      o_rden_int                <= (!i_empty_int) & i_peri_rden & (i_peri_addr[5:2] == 4'b0);
      o_rden_length             <= (!i_empty_length) & i_peri_rden & (i_peri_addr[5:2] == 4'd1);
      //* output o_peri_rdata;
      if(i_peri_rden == 1'b1) begin
        case(i_peri_addr[5:2])
          4'd0: o_peri_rdata    <= (i_empty_int == 1'b0)?     i_dout_int : 32'h80000000;
          4'd1: o_peri_rdata    <= (i_empty_length == 1'b0)?  {16'b0,i_dout_length}: 32'h80000000;
          4'd6: o_peri_rdata    <= {24'd0,r_specReg_cnt_recvPkt};
          4'd7: o_peri_rdata    <= {31'b0, o_start_en};
          4'd8: o_peri_rdata    <= {31'b0, o_filter_en};
          4'd9: o_peri_rdata    <= {29'b0, o_filter_dmac_en, o_filter_smac_en, o_filter_type_en};
          4'd10:o_peri_rdata    <= {24'b0, o_filter_dmac};
          4'd11:o_peri_rdata    <= {24'b0, o_filter_smac};
          4'd12:o_peri_rdata    <= {24'b0, o_filter_type};
          4'd13:o_peri_rdata    <= {31'b0, i_wait_free_pBufWR};
          default: o_peri_rdata <= 32'h80000000;
        endcase  
      end    
      
      //* write pbuf for DMA;
      o_wren_pBufWR             <= 1'b0;
      o_wren_pBufRD             <= 1'b0;
      if(i_peri_wren == 1'b1) begin
        r_guard                 <= 16'b0;
        case(i_peri_addr[5:2])
          4'd2: r_din_pBufWR    <= i_peri_wdata;
          4'd3: begin 
              o_wren_pBufWR     <= 1'b1;
              o_din_pBufWR      <= {r_din_pBufWR[15:0], i_peri_wdata};
          end
          4'd4: r_din_pBufRD    <= i_peri_wdata;
          4'd5: begin 
              o_wren_pBufRD     <= 1'b1;
              o_din_pBufRD      <= {r_din_pBufRD, i_peri_wdata};
          end
          4'd6: r_specReg_cnt_recvPkt <= i_peri_wdata[7:0];
          4'd7: begin
                r_guard         <= i_peri_wdata[15:0];
                o_start_en      <= (r_guard == 32'h1234)? i_peri_wdata[0]: o_start_en;
          end
          4'd8: o_filter_en     <= i_peri_wdata[0];
          4'd9: {o_filter_dmac_en, o_filter_smac_en, o_filter_type_en}  <= i_peri_wdata[2:0];
          4'd10:o_filter_dmac   <= i_peri_wdata[7:0];
          4'd11:o_filter_smac   <= i_peri_wdata[7:0];
          4'd12:o_filter_type   <= i_peri_wdata[7:0];
          default: begin 
          end
        endcase
      end
    end
  end

endmodule
