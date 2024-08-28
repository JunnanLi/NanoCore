/*
 *  Project:            timelyRV_v0.1 -- a RISCV-32I SoC.
 *  Module name:        soc_runtime.
 *  Description:        Top Module of soc_runtime.
 *  Last updated date:  2021.12.03.
 *
 *  Copyright (C) 2021-2023 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) rgmii2gmii & gmii_rx2rgmii are processed by language templates;
 *    2) rgmii_rx is constrained by set_input_delay "-2.0 ~ -0.7";
 *    3) 134b pkt data definition: 
 *      [133:132] head tag, 2'b01 is head, 2'b10 is tail;
 *      [131:128] valid tag, 4'b1111 means sixteen 8b data is valid;
 *      [127:0]   pkt data, invalid part is padded with 0;
 *    4) the riscv-32i core is a simplified picoRV32;
 *
 */

`timescale 1ns / 1ps

module soc_runtime(
  //* system input, clk;
  input                 clk_125m,
  input                 sys_rst_n,
  input                 i_pe_clk,
  //* rgmii port;
  input         [3:0]   rgmii_rd,
  input                 rgmii_rx_ctl,
  input                 rgmii_rxc,
  output  wire  [3:0]   rgmii_td,
  output  wire          rgmii_tx_ctl,
  output  wire          rgmii_txc,
  //* uart rx/tx
  output  wire          pktData_valid_gmii,
  output  wire  [133:0] pktData_gmii,
  output  wire  [15:0]  pkt_length_gmii,
  input   wire          ready_in,
  input                 pktData_valid_um,
  input         [133:0] pktData_um
);

  //* Connected wire;
  //* Data Flow: gmii_rx - > asfifo_recv -> checkCRC -> gmii2pkt -> UM -> 
  //*   pkt2gmii -> calCRC -> gmii_tx;
  //* Noted: riscv core is initialized in the UM module;
  //* checkCRC & modifyPKT & calCRC;
  wire          gmiiEr_checkCRC, gmiiEr_calCRC, gmiiEr_modifyPKT;
  wire  [7:0]   gmiiTxd_checkCRC, gmiiTxd_calCRC, gmiiTxd_modifyPKT;
  wire          gmiiEn_checkCRC, gmiiEn_calCRC, gmiiEn_modifyPKT;

  //* gmii_rx -> asfifo_recv
  wire          gmiiRclk_rgmii;
  wire  [7:0]   gmiiRxd_rgmii;
  wire          gmiiEn_rgmii;
  wire          gmiiEr_rgmii;

  //* gmii2pkt -> UM -> pkt2gmii -> calCRC;
  wire  [7:0]   gmii_txd_pkt;
  wire          gmii_tx_en_pkt;

  //* asfifo_recv -> checkCRC;
  wire  [7:0]   gmiiRxd_asfifo;
  wire          gmiiEn_asfifo;
  wire          gmiiEr_asfifo;

  //* cnt, haven't been used;
  (* mark_debug = "true"*)wire  [31:0]  cntPkt_asynRecvPkt, cntPkt_gmii2pkt, cntPkt_pkt2gmii;
  
  //*************** sub-modules ***************//   
  //* format transform between gmii with rgmii;
  util_gmii_to_rgmii rgmii2gmii(
    .rst_n(sys_rst_n),
    .rgmii_rd(rgmii_rd),            // input---|
    .rgmii_rx_ctl(rgmii_rx_ctl),    // input   |--+
    .rgmii_rxc(rgmii_rxc),          // input---|  |
                                    //            |
    .gmii_rx_clk(gmiiRclk_rgmii),   // output--|  |
    .gmii_rxd(gmiiRxd_rgmii),       // output  |<-+
    .gmii_rx_dv(gmiiEn_rgmii),      // output  |
    .gmii_rx_er(gmiiEr_rgmii),      // output--|
    
    .rgmii_txc(rgmii_txc),          // output--|
    .rgmii_td(rgmii_td),            // output  |<-+
    .rgmii_tx_ctl(rgmii_tx_ctl),    // output--|  |
                                    //            |
    .gmii_tx_clk(clk_125m),         // input---|  |
    .gmii_txd(gmiiTxd_calCRC),      // input   |--+
    .gmii_tx_en(gmiiEn_calCRC),     // input   |
    .gmii_tx_er(1'b0)               // input---|
  );


  //* asynchronous recving packets:
  //*   1) discard frame's head tag;  
  //*   2) record recv time;
  asyn_recv_packet asyn_recv_packet_inst (
    .rst_n(sys_rst_n),
    .gmii_rx_clk(gmiiRclk_rgmii),
    .gmii_rxd(gmiiRxd_rgmii),
    .gmii_rx_dv(gmiiEn_rgmii),
    .gmii_rx_er(gmiiEr_rgmii),
    .clk_125m(clk_125m),
    .gmii_txd(gmiiRxd_asfifo),
    .gmii_tx_en(gmiiEn_asfifo),
    .gmii_tx_er(gmiiEr_asfifo),
    .cnt_pkt(cntPkt_asynRecvPkt)
  );
  
  //* check CRC of received packets:
  //*   1) discard CRC;
  //*   2) check CRC, TO DO...;
  gmii_crc_check checkCRC(
    .rst_n(sys_rst_n),
    .clk(clk_125m),
    .gmii_dv_i(gmiiEn_asfifo),
    .gmii_er_i(gmiiEr_asfifo),
    .gmii_data_i(gmiiRxd_asfifo),
    
    .gmii_en_o(gmiiEn_checkCRC),
    .gmii_er_o(gmiiEr_checkCRC),
    .gmii_data_o(gmiiTxd_checkCRC)
  );
  
  //* gen 134b data;
  //*   1) accumulate sixteen 8b-data to one 128b data;
  //*   2) gen 128b (64b is used) metadata;
  gmii_to_134b_pkt gmii2pkt(
    .rst_n              (sys_rst_n            ),
    .clk                (clk_125m             ),
    .i_pe_clk           (i_pe_clk             ),
    .gmii_data          (gmiiTxd_checkCRC     ),
    .gmii_data_valid    (gmiiEn_checkCRC      ),
    .pkt_data           (pktData_gmii         ),
    .pkt_data_valid     (pktData_valid_gmii   ),
    .pkt_length         (pkt_length_gmii      ),
    .ready_in           (ready_in             ),
    .cnt_pkt            (cntPkt_gmii2pkt      )
  );

  //* um;

  //* gen 8b gmii;
  pkt_134b_to_gmii pkt2gmii(
    .rst_n(sys_rst_n),
    .clk(clk_125m),
    .pkt_data_valid(pktData_valid_um),
    .pkt_data(pktData_um),
    .gmii_data(gmii_txd_pkt),
    .gmii_data_valid(gmii_tx_en_pkt),
    .cnt_pkt(cntPkt_pkt2gmii)
  );
  
  //* add output time for PTP packets;
  assign gmiiEn_modifyPKT = gmii_tx_en_pkt;
  assign gmiiEr_modifyPKT = 1'b0;
  assign gmiiTxd_modifyPKT = gmii_txd_pkt;
  /* test_modify_packet modifyPkt(
    .rst_n(sys_rst_n),
    .clk(clk_125m),
    .gmii_dv_i(gmiiEn_checkCRC[i_rgmii]),
    .gmii_er_i(gmiiEr_checkCRC[i_rgmii]),
    .gmii_data_i(gmiiTxd_checkCRC[i_rgmii]),
    
    .gmii_en_o(gmiiEn_modifyPKT[i_rgmii]),
    .gmii_er_o(gmiiEr_modifyPKT[i_rgmii]),
    .gmii_data_o(gmiiTxd_modifyPKT[i_rgmii])
  ); */
  
  //* calculate CRC of received packets;
  gmii_crc_calculate calCRC(
    .rst_n(sys_rst_n),
    .clk(clk_125m),
    .gmii_dv_i(gmiiEn_modifyPKT),
    .gmii_er_i(gmiiEr_modifyPKT),
    .gmii_data_i(gmiiTxd_modifyPKT),
    
    .gmii_en_o(gmiiEn_calCRC),
    .gmii_er_o(gmiiEr_calCRC),
    .gmii_data_o(gmiiTxd_calCRC)
  );
  

endmodule
