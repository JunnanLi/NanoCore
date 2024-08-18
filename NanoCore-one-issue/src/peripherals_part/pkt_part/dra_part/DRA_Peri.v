/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Peri.
 *  Description:        This module is used to process Peri's access.
 *  Last updated date:  2022.06.16. (checked)
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module DRA_Peri(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* reset/start dra;
  ,output reg               o_reset_en
  ,output reg               o_start_en
  //* configuration interface for DRA;
  ,input  wire              i_peri_rden
  ,input  wire              i_peri_wren
  ,input  wire  [31:0]      i_peri_addr
  ,input  wire  [31:0]      i_peri_wdata
  ,input  wire  [3:0]       i_peri_wstrb
  ,output reg   [31:0]      o_peri_rdata
  ,output reg               o_peri_ready
  ,output wire              o_peri_int 
);

  assign  o_peri_int        = 1'b0;

  //======================= Configure      =======================//
  integer                   i_pe;
  reg           [15:0]      r_guard;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_guard               <= 16'b0;
      o_reset_en            <= 1'b0;
      o_start_en            <= 1'b0;
      o_peri_ready          <= 1'b0;
      o_peri_rdata          <= 32'b0;
    end 
    else begin
      o_peri_ready          <= i_peri_rden | i_peri_wren;
      //* output o_peri_rdata;
      if(i_peri_rden == 1'b1) begin
        case(i_peri_addr[3:2])
          2'd1:     o_peri_rdata  <= {31'b0, o_start_en};
          2'd2:     o_peri_rdata  <= {31'b0, o_reset_en};
          default:  o_peri_rdata  <= 32'hffffffff;
        endcase  
      end    
      
      if(i_peri_wren == 1'b1) begin
        case(i_peri_addr[3:2])
          2'd0:     r_guard       <= i_peri_wdata[15:0];
          2'd1:     o_start_en    <= (r_guard == 16'h1234)? i_peri_wdata[0]: o_start_en;
          2'd2:     o_reset_en    <= (r_guard == 16'h1234)? i_peri_wdata[0]: o_reset_en;
          default:  begin 
          end
        endcase
      end
    end
  end
  //==============================================================//

endmodule
