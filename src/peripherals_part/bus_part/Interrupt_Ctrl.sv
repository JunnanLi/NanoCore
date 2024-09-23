/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Interrupt_Ctrl.
 *  Description:        This module is used to contorl irqs from pkt 
 *                        sram, can, uart.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 */

module Interrupt_Ctrl(
  //* clk & rst_n;
  input  wire                     i_clk,
  input  wire                     i_rst_n,
  //* irq (bitmap);
  input  wire [  `NUM_PERI:0]     i_irq,    //* include irq_timer;
  output reg  [         31:0]     o_irq,
  //* irq_ack;
  input  wire                     i_irq_ack,
  input  wire [          4:0]     i_irq_id
);
  
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* TODO, irq ctrl is simple, just one stage;
  reg         [  `NUM_PERI:0]     irq_pre;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   interrupt ctrl
  //====================================================================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_irq                 <= 32'b0;
      irq_pre               <= {`NUM_PERI+1{1'b0}};
    end
    else begin
      o_irq                 <= o_irq;
      irq_pre               <= i_irq;
      `ifdef ENABLE_UART
        if(irq_pre[`UART] == 1'b0 && i_irq[`UART] == 1'b1)
          o_irq[`UART_IRQ]    <= 1'b1;
      `endif
      `ifdef ENABLE_DMA
        if(irq_pre[`DMA] == 1'b0 && i_irq[`DMA] == 1'b1)
          o_irq[`DMA_IRQ]     <= 1'b1;
      `endif
      `ifdef ENABLE_DRA
        if(irq_pre[`DRA] == 1'b0 && i_irq[`DRA] == 1'b1)
          o_irq[`DRA_IRQ]     <= 1'b1;
      `endif
      `ifdef ENABLE_CSR
        if(irq_pre[`NUM_PERI] == 1'b0 && i_irq[`NUM_PERI] == 1'b1)
          o_irq[`TIME_IRQ]    <= 1'b1;
      `endif

      for(i=0; i<32; i=i+1) begin
        if(i_irq_ack == 1'b1 && i_irq_id == i)
          o_irq[i]            <= 1'b0;
      end

    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule    
