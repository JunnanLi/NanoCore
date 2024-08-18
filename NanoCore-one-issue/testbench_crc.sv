/*
 *  Project:            timelyRV_v1.4.x -- a RISCV-32IMC SoC.
 *  Module name:        Testbench.
 *  Description:        Testbench of timelyRV_SoC_hardware.
 *  Last updated date:  2022.10.10.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1ns/1ps
module Testbench_wrapper(
);


`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpMDA();
    $vcdpluson;
    $vcdplusmemon;
  end
`endif
  // localparam  DATA_0             = 128'ha41a3ac1d5059c56368529b708004560,
  //             DATA_1             = 128'h00c6166b40002c06bd64a3b1127dc0a8,
  //             DATA_2             = 128'h032c01bbadd6ec2adaaa8db373b95018,
  //             DATA_3             = 128'h03c454f9000016030300660200006203,
  //             DATA_4             = 128'h0366a3bc4adcf5541f17dd20615b47e6,
  //             DATA_5             = 128'hc5ba543b263311371c098cafd1aa8882,
  //             DATA_6             = 128'h6a20ef45ce99c48336266311de3e70fc,
  //             DATA_7             = 128'h7215eb3453de2f67bc6d3c9b0d064d72,
  //             DATA_8             = 128'h6976c02f00001aff010001000010000b,
  //             DATA_9             = 128'h000908687474702f312e31000b000201,
  //             DATA_10            = 128'h00140303000101160303002800000000,
  //             DATA_11            = 128'h0000000023bab5beb432abf95148e402,
  //             DATA_12            = 128'hb158eedce1bd15267a6b7b54eb0e4d83,
  //             DATA_13            = 128'h32348887111111111111111111111111;

  localparam  DATA_0             = 128'h04421aa8239f000a3500010208004500,
              DATA_1             = 128'h002c00000000ff06379fc0a801c8c0a8,
              DATA_2             = 128'h0114c00113890000196d000000006002,
              DATA_3             = 128'h2238000000000204058c000011111111;

  localparam  ARP_0             = 128'hffff_ffff_ffff_000b_3601_0203_0806_0001,
              ARP_1             = 128'h0800_0604_0001_000b_3601_0203_c0a8_030a,
              ARP_2             = 128'h0000_0000_0000_c0a8_0364_0000_0000_0000,
              ARP_3             = 128'h0000_0000_0000_0000_0000_0000_7374_7576;

  reg               clk,rst_n;
  reg               r_pktIn_valid;
  reg   [133:0]     r_pktIn;
  wire              w_pktOut_valid, w_pktData_valid_gmii;
  wire  [133:0]     w_pktOut, w_pktData_gmii;


  assign w_pktData_valid_gmii   = r_pktIn_valid;
  assign w_pktData_gmii         = r_pktIn;

  Pkt_TCP_CRC Pkt_TCP_CRC(
  .i_clk        (clk),
  .i_rst_n      (rst_n),
  .i_data_valid (w_pktData_valid_gmii),
  .i_data       (w_pktData_gmii),
  .o_data_valid (),
  .o_data       ()
);


  initial begin
    rst_n = 1;
    #2  rst_n = 0;
    #10 rst_n = 1;
  end
  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end
  initial begin
  `ifndef SIM_PKT_IO
    #400000 $finish;
  `endif
  end
  

  initial begin
    r_pktIn_valid = '0;
    r_pktIn = '0;
    #100 begin
      r_pktIn_valid = 1;
      r_pktIn = {2'b01,4'hf,DATA_0};
    end
    #2 r_pktIn = {2'b0,4'hf,DATA_1};
    #2 r_pktIn = {2'b0,4'hf,DATA_2};
    #2 r_pktIn = {2'b10,4'hb,DATA_3};
    // #2 r_pktIn = {2'b0,4'hf,DATA_3};
    // #2 r_pktIn = {2'b0,4'hf,DATA_4};
    // #2 r_pktIn = {2'b0,4'hf,DATA_5};
    // #2 r_pktIn = {2'b0,4'hf,DATA_6};
    // #2 r_pktIn = {2'b0,4'hf,DATA_7};
    // #2 r_pktIn = {2'b0,4'hf,DATA_8};
    // #2 r_pktIn = {2'b0,4'hf,DATA_9};
    // #2 r_pktIn = {2'b0,4'hf,DATA_10};
    // #2 r_pktIn = {2'b0,4'hf,DATA_11};
    // #2 r_pktIn = {2'b0,4'hf,DATA_12};
    // #2 r_pktIn = {2'b10,4'h3,DATA_13};
    #2 r_pktIn_valid = 0;
  end


endmodule
