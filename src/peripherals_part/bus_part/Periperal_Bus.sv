/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Periperal_Bus.
 *  Description:        This module is used to connect core with 
 *                       configuration, pkt sram, can, and uart.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module Periperal_Bus(
  //* clk & rst_n
  input  wire                     i_clk,
  input  wire                     i_rst_n,
  //* peri interface with PEs;
  input  wire                     i_peri_rden,
  input  wire                     i_peri_wren,
  input  wire [            31:0]  i_peri_addr,
  input  wire [            31:0]  i_peri_wdata,
  input  wire [             3:0]  i_peri_wstrb,
  output logic                    o_peri_ready,
  output logic[            31:0]  o_peri_rdata,
  output wire                     o_peri_gnt,

  //* peri interface wit Peris;
  output logic[            31:0]  o_addr_2peri,
  output logic[   `NUM_PERI-1:0]  o_wren_2peri,
  output logic[   `NUM_PERI-1:0]  o_rden_2peri,
  output logic[            31:0]  o_wdata_2peri,
  output logic[             3:0]  o_wstrb_2peri,
  input       [   `NUM_PERI-1:0]  i_ready_2PBUS,
  input       [`NUM_PERI-1:0][31:0]  i_rdata_2PBUS
);


  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire        [2:0]               w_ready_2PBUS;
  wire        [2:0][       31:0]  w_rdata_2PBUS;
  generate if (`NUM_PERI<3) begin
    assign    w_ready_2PBUS[2:`NUM_PERI]    = 'b0;
    assign    w_rdata_2PBUS[2:`NUM_PERI]    = 'b0;
  end
  endgenerate
  assign      w_ready_2PBUS[`NUM_PERI-1:0]  = i_ready_2PBUS;
  assign      w_rdata_2PBUS[`NUM_PERI-1:0]  = i_rdata_2PBUS;
  //* TODO, currently do not care;
  assign      o_peri_gnt          = 1'b1;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Periral Bus
  //====================================================================//
  //* TODO, current bus is simple, just one stage;
  integer i_peri;
  // always @(posedge i_clk or negedge i_rst_n) begin
  //   if (!i_rst_n) begin
  //     //* Connected with PE;
  //     o_peri_ready                <= 1'b0;
  //     o_peri_rdata                <= 32'b0;

  //     //* Connected with Periperals;
  //     o_addr_2peri                <= 32'b0;
  //     o_wren_2peri                <= {`NUM_PERI{1'b0}};
  //     o_rden_2peri                <= {`NUM_PERI{1'b0}};
  //     o_wdata_2peri               <= 32'b0;
  //     o_wstrb_2peri               <= 4'b0;
  //   end
  //   else begin
  //     //* initilization
  //     o_wren_2peri                <= {`NUM_PERI{1'b0}};
  //     o_rden_2peri                <= {`NUM_PERI{1'b0}};
  //     o_addr_2peri                <= i_peri_addr;
  //     o_wdata_2peri               <= i_peri_wdata;
  //     o_wstrb_2peri               <= i_peri_wstrb;

  //     //* output rdata to PEs;
  //     o_peri_ready                <= |i_ready_2PBUS;
      
  //     //* NUM_PERI is 3
  //     case(w_ready_2PBUS[2:0])
  //       3'b001: o_peri_rdata      <= w_rdata_2PBUS[0];
  //       3'b010: o_peri_rdata      <= w_rdata_2PBUS[1];
  //       3'b100: o_peri_rdata      <= w_rdata_2PBUS[2];
  //       default:o_peri_rdata      <= 32'b0;
  //     endcase

  //     //* output addr/wdata to Peris;  
  //     case(i_peri_addr[19:16])
  //      `ifdef ENABLE_UART
  //         4'd1: begin //* UART;
  //           o_wren_2peri[`UART]   <= i_peri_wren;
  //           o_rden_2peri[`UART]   <= i_peri_rden;
  //         end
  //       `endif
  //       `ifdef ENABLE_UART
  //         4'd4: begin //* CSR;
  //           o_wren_2peri[`CSR]    <= i_peri_wren;
  //           o_rden_2peri[`CSR]    <= i_peri_rden;
  //         end
  //       `endif
  //       `ifdef ENABLE_DMA
  //         4'd7: begin //* DMA;
  //           o_wren_2peri[`DMA]    <= i_peri_wren;
  //           o_rden_2peri[`DMA]    <= i_peri_rden;
  //         end
  //       `endif
  //       `ifdef ENABLE_DRA
  //         4'd8: begin //* DRA;
  //           o_wren_2peri[`DRA]    <= i_peri_wren;
  //           o_rden_2peri[`DRA]    <= i_peri_rden;
  //         end
  //       `endif
  //         default: begin
  //           o_wren_2peri[`UART]   <= i_peri_wren;
  //           o_rden_2peri[`UART]   <= i_peri_rden;
  //         end
  //     endcase
  //   end
  // end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  always_comb begin
      //* initilization
      o_wren_2peri                = {`NUM_PERI{1'b0}};
      o_rden_2peri                = {`NUM_PERI{1'b0}};
      o_addr_2peri                = i_peri_addr;
      o_wdata_2peri               = i_peri_wdata;
      o_wstrb_2peri               = i_peri_wstrb;

      //* output rdata to PEs;
      o_peri_ready                = |i_ready_2PBUS;
      
      //* NUM_PERI is 3
      case(w_ready_2PBUS[2:0])
        3'b001: o_peri_rdata      = w_rdata_2PBUS[0];
        3'b010: o_peri_rdata      = w_rdata_2PBUS[1];
        3'b100: o_peri_rdata      = w_rdata_2PBUS[2];
        default:o_peri_rdata      = 32'b0;
      endcase

      //* output addr/wdata to Peris;  
      case(i_peri_addr[19:16])
       `ifdef ENABLE_UART
          4'd1: begin //* UART;
            o_wren_2peri[`UART]   = i_peri_wren;
            o_rden_2peri[`UART]   = i_peri_rden;
          end
        `endif
        `ifdef ENABLE_CSR
          4'd4: begin //* CSR;
            o_wren_2peri[`CSR]    = i_peri_wren;
            o_rden_2peri[`CSR]    = i_peri_rden;
          end
        `endif
        `ifdef ENABLE_DMA
          4'd7: begin //* DMA;
            o_wren_2peri[`DMA]    = i_peri_wren;
            o_rden_2peri[`DMA]    = i_peri_rden;
          end
        `endif
        `ifdef ENABLE_DRA
          4'd8: begin //* DRA;
            o_wren_2peri[`DRA]    = i_peri_wren;
            o_rden_2peri[`DRA]    = i_peri_rden;
          end
        `endif
          default: begin
            o_wren_2peri[`UART]   <= i_peri_wren;
            o_rden_2peri[`UART]   <= i_peri_rden;
          end
      endcase
  end


endmodule    
