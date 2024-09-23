/*
 *  Project:            timelyRV_v0.1 -- a RISCV-32I SoC.
 *  Module name:        gmii_crc_check.
 *  Description:        check CRC.
 *  Last updated date:  2021.07.22.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */


`timescale 1ns/1ps
module gmii_crc_check(
  input               rst_n,
  input               clk,
  input  wire         gmii_dv_i, 
  input  wire         gmii_er_i, 
  input  wire  [7:0]  gmii_data_i, 
  
  output reg          gmii_en_o, 
  output reg          gmii_er_o, 
  output reg   [7:0]  gmii_data_o
);

reg       temp_gmii_dv[3:0];
reg       temp_gmii_er[3:0];
reg [7:0] temp_gmii_data[3:0];
reg       tag;

integer i;

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    for(i=0;i<4;i=i+1) begin
      temp_gmii_dv[i]   <= 1'b0;
      temp_gmii_er[i]   <= 1'b0;
      temp_gmii_data[i] <= 8'b0;
    end
    tag                 <= 1'b0;
    gmii_en_o           <= 1'b0;
    gmii_er_o           <= 1'b0;
    gmii_data_o         <= 8'b0;
  end
  else begin
    tag                 <= gmii_dv_i;
  
    temp_gmii_dv[0]     <= gmii_dv_i;
    temp_gmii_er[0]     <= gmii_er_i;
    temp_gmii_data[0]   <= gmii_data_i;
    for(i=1;i<4;i=i+1) begin
      temp_gmii_dv[i]   <= temp_gmii_dv[i-1];
      temp_gmii_er[i]   <= temp_gmii_er[i-1];
      temp_gmii_data[i] <= temp_gmii_data[i-1];
    end
    
    gmii_en_o           <= gmii_dv_i&temp_gmii_dv[3];
    gmii_er_o           <= temp_gmii_er[3];
    gmii_data_o         <= temp_gmii_data[3];
  end
end

endmodule
