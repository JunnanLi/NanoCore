/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DRA_Engine.
 *  Description:        This module is used to DRA packets.
 *  Last updated date:  2022.08.19.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module DRA_Engine(
   input  wire                      i_clk
  ,input  wire                      i_rst_n
  //* interface for recv/send pkt;
  ,input  wire                      i_data_valid
  ,input  wire  [         133:0]    i_data 
  ,output wire                      o_data_valid
  ,output wire  [         133:0]    o_data
  //* alf
  ,output wire                      o_alf_dra  

  //* interface for DRA;
  ,input  wire  [   `NUM_PE-1:0]    i_reg_rd      //* read req
  ,input  wire  [`NUM_PE*32-1:0]    i_reg_raddr   //* read addr;
  ,output wire  [         511:0]    o_reg_rdata   //* return read data;
  ,output wire  [   `NUM_PE-1:0]    o_reg_rvalid 
  ,output wire  [   `NUM_PE-1:0]    o_reg_rvalid_desp   //* upload received new pkt;
  ,input  wire  [   `NUM_PE-1:0]    i_reg_wr      //* write req;
  ,input  wire  [   `NUM_PE-1:0]    i_reg_wr_desp //* write desception;
  ,input  wire  [`NUM_PE*32-1:0]    i_reg_waddr   //* write addr;
  ,input  wire  [`NUM_PE*512-1:0]   i_reg_wdata   //* write data;
  ,input  wire  [`NUM_PE*32-1:0]    i_status      //* [0] (is '0') to recv next pkt;
  ,output wire  [`NUM_PE*32-1:0]    o_status      //* TODO, has not been used;
  //* interface for Peri;
  ,input  wire  [   `NUM_PE-1:0]    i_peri_rden
  ,input  wire  [   `NUM_PE-1:0]    i_peri_wren
  ,input  wire  [`NUM_PE*32-1:0]    i_peri_addr
  ,input  wire  [`NUM_PE*32-1:0]    i_peri_wdata
  ,input  wire  [ `NUM_PE*4-1:0]    i_peri_wstrb
  ,output wire  [`NUM_PE*32-1:0]    o_peri_rdata
  ,output wire  [   `NUM_PE-1:0]    o_peri_ready
  ,output wire  [   `NUM_PE-1:0]    o_peri_int

  //* debug;
  ,output wire                      d_dra_empty_pktRecv_1b 
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_despRecv_3b
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_despSend_3b
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_writeReq_3b
  ,output wire  [           9:0]    d_dra_usedw_pktRecv_10b
);
  
  //======================= internal reg/wire/param declarations =//
  //* fifo of pktRecv;
  wire       [            133:0]    w_dout_pktRecv;
  wire                              w_rden_pktRecv;
  wire                              w_empty_pktRecv;
  //* ram of pkt;
  wire                              w_wren_pktRAM_hw;
  wire       [             15:0]    w_addr_pktRAM_hw;
  wire       [            511:0]    w_din_pktRAM_hw;
  wire       [            511:0]    w_dout_pktRAM_hw;
  wire                              w_wren_pktRAM_core;
  wire       [            511:0]    w_din_pktRAM_core;
  wire       [             15:0]    w_addr_pktRAM_core;
  wire       [            511:0]    w_dout_pktRAM_core;
  //* fifo of despRecv;
  wire       [            127:0]    w_din_despRecv;
  wire       [      `NUM_PE-1:0]    w_wren_despRecv;
  wire       [      `NUM_PE-1:0]    w_rden_despRecv;
  wire       [  `NUM_PE*128-1:0]    w_dout_despRecv;
  wire       [      `NUM_PE-1:0]    w_empty_despRecv;
  //* fifo of despSend;
  wire       [  `NUM_PE*128-1:0]    w_din_despSend;
  wire       [      `NUM_PE-1:0]    w_wren_despSend;
  wire       [      `NUM_PE-1:0]    w_rden_despSend;
  wire       [  `NUM_PE*128-1:0]    w_dout_despSend;
  wire       [      `NUM_PE-1:0]    w_empty_despSend;
  //* fifo for writeReq;
  wire       [  `NUM_PE*528-1:0]    w_din_writeReq;
  wire       [      `NUM_PE-1:0]    w_wren_writeReq;
  wire       [      `NUM_PE-1:0]    w_rden_writeReq;
  wire       [  `NUM_PE*528-1:0]    w_dout_writeReq;
  wire       [      `NUM_PE-1:0]    w_empty_writeReq;
  //* reset/start dra;
  wire       [      `NUM_PE-1:0]    w_reset_dra;
  wire       [      `NUM_PE-1:0]    w_start_dra;
  //==============================================================//
    
  DRA_Central_Buffer DRA_Central_Buffer(
    .i_clk              (i_clk                ),
    .i_rst_n            (i_rst_n              ),
    //* pkt in;
    .i_pkt_valid        (i_data_valid         ),
    .i_pkt              (i_data               ),
    .o_alf_dra          (o_alf_dra            ),
    .i_start_en         (|w_start_dra         ),
    //* fifo of pktRecv;
    .o_empty_pktRecv    (w_empty_pktRecv      ),
    .i_rden_pktRecv     (w_rden_pktRecv       ),
    .o_dout_pktRecv     (w_dout_pktRecv       ),
    //* ram of pkt;
    .i_wren_pktRAM_hw   (w_wren_pktRAM_hw     ),
    .i_addr_pktRAM_hw   (w_addr_pktRAM_hw     ),
    .i_din_pktRAM_hw    (w_din_pktRAM_hw      ),
    .o_dout_pktRAM_hw   (w_dout_pktRAM_hw     ),
    .i_wren_pktRAM_core (w_wren_pktRAM_core   ),
    .i_din_pktRAM_core  (w_din_pktRAM_core    ),
    .i_addr_pktRAM_core (w_addr_pktRAM_core   ),
    .o_dout_pktRAM_core (w_dout_pktRAM_core   ),
    //* fifo of despRecv;
    .i_din_despRecv     (w_din_despRecv       ),
    .i_wren_despRecv    (w_wren_despRecv      ),
    .i_rden_despRecv    (w_rden_despRecv      ),
    .o_dout_despRecv    (w_dout_despRecv      ),
    .o_empty_despRecv   (w_empty_despRecv     ),
    //* fifo of despSend;
    .i_din_despSend     (w_din_despSend       ),
    .i_wren_despSend    (w_wren_despSend      ),
    .i_rden_despSend    (w_rden_despSend      ),
    .o_dout_despSend    (w_dout_despSend      ),
    .o_empty_despSend   (w_empty_despSend     ),
    //* fifo for writeReq;
    .i_din_writeReq     (w_din_writeReq       ),
    .i_wren_writeReq    (w_wren_writeReq      ),
    .i_rden_writeReq    (w_rden_writeReq      ),
    .o_dout_writeReq    (w_dout_writeReq      ),
    .o_empty_writeReq   (w_empty_writeReq     ),

    //* debug;
    .d_empty_pktRecv_1b (d_dra_empty_pktRecv_1b   ),
    .d_empty_despRecv_3b(d_dra_empty_despRecv_3b  ),
    .d_empty_despSend_3b(d_dra_empty_despSend_3b  ),
    .d_empty_writeReq_3b(d_dra_empty_writeReq_3b  ),
    .d_usedw_pktRecv_10b(d_dra_usedw_pktRecv_10b  )
  );

  DRA_Recv_Send_Pkt DRA_Recv_Send_Pkt(
    .i_clk              (i_clk                ),
    .i_rst_n            (i_rst_n              ),
    //* interface for receiving/sending pkt;
    .i_empty_pktRecv    (w_empty_pktRecv      ),
    .o_rden_pktRecv     (w_rden_pktRecv       ),
    .i_dout_pktRecv     (w_dout_pktRecv       ),
    .o_pkt_valid        (o_data_valid         ),
    .o_pkt              (o_data               ),
    //* interface for reading/writing pkt;
    .o_wren_pktRAM_hw   (w_wren_pktRAM_hw     ),
    .o_addr_pktRAM_hw   (w_addr_pktRAM_hw     ),
    .o_din_pktRAM_hw    (w_din_pktRAM_hw      ),
    .i_dout_pktRAM_hw   (w_dout_pktRAM_hw     ),
    //* interface for writing despRecv;
    .o_din_despRecv     (w_din_despRecv       ),
    .o_wren_despRecv    (w_wren_despRecv      ), 
    //* interface for reading despSend;
    .o_rden_despSend    (w_rden_despSend      ),
    .i_dout_despSend    (w_dout_despSend      ), 
    .i_empty_despSend   (w_empty_despSend     ),
    //* interface for writeReq;
    .i_empty_writeReq   (w_empty_writeReq     )  
  );

  DRA_Read_Write_Data DRA_Read_Write_Data(
    .i_clk              (i_clk                ),
    .i_rst_n            (i_rst_n              ),
    //* reset/start dra;
    .i_reset_en         (w_reset_dra          ),
    .i_start_en         (w_start_dra          ),
    //* interface for reading/writing data;
    .o_wren_pktRAM_core (w_wren_pktRAM_core   ),
    .o_addr_pktRAM_core (w_addr_pktRAM_core   ),
    .o_din_pktRAM_core  (w_din_pktRAM_core    ),
    .i_dout_pktRAM_core (w_dout_pktRAM_core   ),
    //* interface for reading despRecv;
    .o_rden_despRecv    (w_rden_despRecv      ), 
    .i_dout_despRecv    (w_dout_despRecv      ), 
    .i_empty_despRecv   (w_empty_despRecv     ), 
    //* interface for writing despSend;
    .o_din_despSend     (w_din_despSend       ), 
    .o_wren_despSend    (w_wren_despSend      ), 
    //* interface for writeReq;
    .o_din_writeReq     (w_din_writeReq       ), 
    .o_wren_writeReq    (w_wren_writeReq      ), 
    .o_rden_writeReq    (w_rden_writeReq      ), 
    .i_dout_writeReq    (w_dout_writeReq      ), 
    .i_empty_writeReq   (w_empty_writeReq     ), 
    //* interface for DRA;
    .i_reg_rd           (i_reg_rd             ), 
    .i_reg_raddr        (i_reg_raddr          ), 
    .o_reg_rdata        (o_reg_rdata          ), 
    .o_reg_rvalid       (o_reg_rvalid         ), 
    .o_reg_rvalid_desp  (o_reg_rvalid_desp    ), 
    .i_reg_wr           (i_reg_wr             ), 
    .i_reg_wr_desp      (i_reg_wr_desp        ), 
    .i_reg_waddr        (i_reg_waddr          ), 
    .i_reg_wdata        (i_reg_wdata          ), 
    .i_status           (i_status             ), 
    .o_status           (o_status             )
  );

  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe + 1) begin: dra_peri
      DRA_Peri DRA_Peri(
        .i_clk          (i_clk                    ),
        .i_rst_n        (i_rst_n                  ),
        //* reset/start dra;
        .o_reset_en     (w_reset_dra[i_pe]        ),
        .o_start_en     (w_start_dra[i_pe]        ),
        //* interface for Peri;
        .i_peri_rden    (i_peri_rden[i_pe]        ), 
        .i_peri_wren    (i_peri_wren[i_pe]        ), 
        .i_peri_addr    (i_peri_addr[i_pe*32+:32] ), 
        .i_peri_wdata   (i_peri_wdata[i_pe*32+:32]), 
        .i_peri_wstrb   (i_peri_wstrb[i_pe*4+:4]  ), 
        .o_peri_rdata   (o_peri_rdata[i_pe*32+:32]), 
        .o_peri_ready   (o_peri_ready[i_pe]       ), 
        .o_peri_int     (o_peri_int[i_pe]         )
      );
    end
  endgenerate

endmodule
