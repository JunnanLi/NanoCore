/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Gen_Baud_Rate.
 *  Description:        generating clk for sampling rx/tx data. 
 *  Last updated date:  2021.11.20.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module Gen_Baud_Rate(
  input  wire               i_clk,
  input  wire               i_rst_n,
  output wire               o_rxclk_en,
  output wire               o_txclk_en
);

  //======================= internal reg/wire/param declarations =//
  localparam  CLK_HZ        = 125000000,
              BAUD_RATE     = 115200, //* 115200, 9600
              RX_ACC_MAX    = CLK_HZ / (BAUD_RATE * 16),
              TX_ACC_MAX    = CLK_HZ / BAUD_RATE,
              RX_ACC_WIDTH  = 12,
              TX_ACC_WIDTH  = 16;

  reg         [11:0]        r_rx_acc;
  reg         [15:0]        r_tx_acc;
  //==============================================================//

  //======================= generate baudrate ====================//
  assign o_rxclk_en         = (r_rx_acc == 12'd0);
  assign o_txclk_en         = (r_tx_acc == 16'd0);

  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      r_rx_acc              <= 12'd0;
      r_tx_acc              <= 16'd0;
    end
    else begin
      //* rx;
      if(r_rx_acc == RX_ACC_MAX) begin
        r_rx_acc            <= 12'd0;
      end
      else begin
        r_rx_acc            <= r_rx_acc + 12'd1;
      end
      //* tx;
      if(r_tx_acc == TX_ACC_MAX) begin
        r_tx_acc            <= 16'd0;
      end
      else begin
        r_tx_acc            <= r_tx_acc + 16'd1;
      end
    end
  end
  //==============================================================//

endmodule
