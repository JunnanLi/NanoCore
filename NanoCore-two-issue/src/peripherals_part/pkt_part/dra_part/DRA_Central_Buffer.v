/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DRA_Central_Buffer.
 *  Description:        This module is used to buffer packets.
 *  Last updated date:  2022.08.18. (checked)
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module DRA_Central_Buffer(
   input  wire                        i_clk
  ,input  wire                        i_rst_n
  //* pkt in;
  ,input  wire                        i_pkt_valid
  ,input  wire  [             133:0]  i_pkt
  ,output wire                        o_alf_dra
  ,input  wire                        i_start_en
  //* fifo of pktRecv;
  ,output wire                        o_empty_pktRecv
  ,input  wire                        i_rden_pktRecv
  ,output wire  [             133:0]  o_dout_pktRecv
  //* ram of pkt;
  ,input  wire                        i_wren_pktRAM_hw
  ,input  wire  [              15:0]  i_addr_pktRAM_hw
  ,input  wire  [             511:0]  i_din_pktRAM_hw
  ,output wire  [             511:0]  o_dout_pktRAM_hw
  ,input  wire                        i_wren_pktRAM_core
  ,input  wire  [              15:0]  i_addr_pktRAM_core
  ,input  wire  [             511:0]  i_din_pktRAM_core
  ,output wire  [             511:0]  o_dout_pktRAM_core
  //* fifo of despRecv;
  ,input  wire  [             127:0]  i_din_despRecv
  ,input  wire  [       `NUM_PE-1:0]  i_wren_despRecv
  ,input  wire  [       `NUM_PE-1:0]  i_rden_despRecv
  ,output wire  [   `NUM_PE*128-1:0]  o_dout_despRecv
  ,output wire  [       `NUM_PE-1:0]  o_empty_despRecv
  //* fifo of despSend;
  ,input  wire  [   `NUM_PE*128-1:0]  i_din_despSend
  ,input  wire  [       `NUM_PE-1:0]  i_wren_despSend
  ,input  wire  [       `NUM_PE-1:0]  i_rden_despSend
  ,output wire  [   `NUM_PE*128-1:0]  o_dout_despSend
  ,output wire  [       `NUM_PE-1:0]  o_empty_despSend
  //* fifo for writeReq;
  ,input  wire  [   `NUM_PE*528-1:0]  i_din_writeReq
  ,input  wire  [       `NUM_PE-1:0]  i_wren_writeReq
  ,input  wire  [       `NUM_PE-1:0]  i_rden_writeReq
  ,output wire  [   `NUM_PE*528-1:0]  o_dout_writeReq
  ,output wire  [       `NUM_PE-1:0]  o_empty_writeReq

  //* debug;
  ,output wire                        d_empty_pktRecv_1b
  ,output wire  [       `NUM_PE-1:0]  d_empty_despRecv_3b
  ,output wire  [       `NUM_PE-1:0]  d_empty_despSend_3b
  ,output wire  [       `NUM_PE-1:0]  d_empty_writeReq_3b
  ,output wire  [               9:0]  d_usedw_pktRecv_10b
);

  //======================= internal reg/wire/param declarations =//
  //* fifo for receiving pkt;
  reg           [             133:0]  r_din_pktRecv;
  reg                                 r_wren_pktRecv;
  wire          [               9:0]  w_usedw_pktRecv;
  reg           [               1:0]  r_pre_head;
  //==============================================================//

  //======================= buffer pkt    ========================//
  //* recv & buffer pkt, TODO;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      // reset
      r_din_pktRecv         <= 134'b0;  //* fifo interface;
      r_wren_pktRecv        <= 1'b0;
      r_pre_head            <= 2'b0;
    end
    else begin
      r_din_pktRecv         <= i_pkt;
      r_pre_head            <= i_pkt[133:132];
      if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b11 && r_pre_head != 2'b11 &&
      // if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b11 && w_usedw_pktRecv < 9'd400 &&
        i_start_en == 1'b1) 
      begin
        r_wren_pktRecv      <= 1'b1;
      end
      else begin
        r_wren_pktRecv      <= r_wren_pktRecv & i_pkt_valid;
      end
    end
  end
  //==============================================================//

  //======================= fifos          =======================//
  //* fifo used to buffer recv pkt;
  `ifdef XILINX_FIFO_RAM
    fifo_134b_512 fifo_pktRecv (
      .clk        (i_clk                  ),   //* input wire clk
      .srst       (!i_rst_n               ),   //* input wire srst
      .din        (r_din_pktRecv          ),   //* input wire [133 : 0] din
      .wr_en      (r_wren_pktRecv         ),   //* input wire wr_en
      .rd_en      (i_rden_pktRecv         ),   //* input wire rd_en
      .dout       (o_dout_pktRecv         ),   //* output wire [133 : 0] dout
      .full       (                       ),   //* output wire full
      .empty      (o_empty_pktRecv        ),   //* output wire empty
      .data_count (w_usedw_pktRecv        )
    );
  `elsif SIM_FIFO_RAM
    //* fifo used to buffer dma pkt;
    syncfifo fifo_pktRecv (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (r_din_pktRecv            ),  //* The Inport of data 
      .wrreq                (r_wren_pktRecv           ),  //* active-high
      .rdreq                (i_rden_pktRecv           ),  //* active-high
      .q                    (o_dout_pktRecv           ),  //* The output of data
      .empty                (o_empty_pktRecv          ),  //* Read domain empty
      .usedw                (w_usedw_pktRecv[8:0]     ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktRecv.width = 134,
              fifo_pktRecv.depth = 9,
              fifo_pktRecv.words = 512;
    assign w_usedw_pktRecv[9] = 1'b0;
  `else
    SYNCFIFO_512x134 fifo_pktRecv (
      .clk        (i_clk                  ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr       (!i_rst_n               ),  //* Reset the all signal
      .data       (r_din_pktRecv          ),  //* The Inport of data 
      .wrreq      (r_wren_pktRecv         ),  //* active-high
      .rdreq      (i_rden_pktRecv         ),  //* active-high
      .q          (o_dout_pktRecv         ),  //* The output of data
      .rdempty    (o_empty_pktRecv        ),  //* Read domain empty
      .rdalempty  (                       ),  //* Read domain almost-empty
      .wrusedw    (w_usedw_pktRecv[8:0]   ),  //* Write-usedword
      .rdusedw    (                       )   //* Read-usedword
    );
    assign w_usedw_pktRecv[9] = 1'b0;
  `endif
  assign o_alf_dra            = (w_usedw_pktRecv > 10'd400);
  
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: fifo_dra
      `ifdef XILINX_FIFO_RAM
        //* fifo for receiving description;
        fifo_128b_512 fifo_despRecv (
          .clk    (i_clk                        ),  //* input wire clk
          .srst   (!i_rst_n                     ),  //* input wire srst
          .din    (i_din_despRecv               ),  //* input wire [31 : 0] din
          .wr_en  (i_wren_despRecv[i_pe]        ),  //* input wire wr_en
          .rd_en  (i_rden_despRecv[i_pe]        ),  //* input wire rd_en
          .dout   (o_dout_despRecv[i_pe*128+:128]), //* output wire [31 : 0] dout
          .full   (                             ),  //* output wire full
          .empty  (o_empty_despRecv[i_pe]       )   //* output wire empty
        );

        //* fifo for sending description;
        fifo_128b_512 fifo_despSend (
          .clk    (i_clk                        ),  //* input wire clk
          .srst   (!i_rst_n                     ),  //* input wire srst
          .din    (i_din_despSend[i_pe*128+:128]),  //* input wire [31 : 0] din
          .wr_en  (i_wren_despSend[i_pe]        ),  //* input wire wr_en
          .rd_en  (i_rden_despSend[i_pe]        ),  //* input wire rd_en
          .dout   (o_dout_despSend[i_pe*128+:128]),  //* output wire [31 : 0] dout
          .full   (                             ),  //* output wire full
          .empty  (o_empty_despSend[i_pe]       )   //* output wire empty
        );
      `elsif SIM_FIFO_RAM
        //* fifo used to buffer dma pkt;
        syncfifo fifo_despRecv (
          .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (i_din_despRecv           ),  //* The Inport of data 
          .wrreq                (i_wren_despRecv[i_pe]    ),  //* active-high
          .rdreq                (i_rden_despRecv[i_pe]    ),  //* active-high
          .q                    (o_dout_despRecv[i_pe]    ),  //* The output of data
          .empty                (o_empty_despRecv[i_pe]   ),  //* Read domain empty
          .usedw                (                         ),  //* Usedword
          .full                 (                         )   //* Full
        );
        defparam  fifo_despRecv.width = 128,
                  fifo_despRecv.depth = 9,
                  fifo_despRecv.words = 512;
        //* fifo used to buffer dma pkt;
        syncfifo fifo_despSend (
          .clock                (i_clk                          ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                       ),  //* Reset the all signal
          .data                 (i_din_despSend [i_pe*128+:128] ),  //* The Inport of data 
          .wrreq                (i_wren_despSend[i_pe]          ),  //* active-high
          .rdreq                (i_rden_despSend[i_pe]          ),  //* active-high
          .q                    (o_dout_despSend[i_pe]          ),  //* The output of data
          .empty                (o_empty_despSend[i_pe]         ),  //* Read domain empty
          .usedw                (                               ),  //* Usedword
          .full                 (                               )   //* Full
        );
        defparam  fifo_despSend.width = 128,
                  fifo_despSend.depth = 9,
                  fifo_despSend.words = 512;
      `else
        //* fifo for receiving description;
        SYNCFIFO_32x128 fifo_despRecv (
          .clk        (i_clk                  ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr       (!i_rst_n               ),  //* Reset the all signal
          .data       (i_din_despRecv         ),  //* The Inport of data 
          .wrreq      (i_wren_despRecv[i_pe]  ),  //* active-high
          .rdreq      (i_rden_despRecv[i_pe]  ),  //* active-high
          .q          (o_dout_despRecv[i_pe*128+:128] ),  //* The output of data
          .rdempty    (o_empty_despRecv[i_pe] ),  //* Read domain empty
          .rdalempty  (                       ),  //* Read domain almost-empty
          .wrusedw    (                       ),  //* Write-usedword
          .rdusedw    (                       )   //* Read-usedword
        );

        //* fifo for sending description;
        SYNCFIFO_32x128 fifo_despSend (
          .clk        (i_clk                  ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr       (!i_rst_n               ),  //* Reset the all signal
          .data       (i_din_despSend[i_pe*128+:128]),  //* The Inport of data 
          .wrreq      (i_wren_despSend[i_pe]  ),  //* active-high
          .rdreq      (i_rden_despSend[i_pe]  ),  //* active-high
          .q          (o_dout_despSend[i_pe*128+:128]), //* The output of data
          .rdempty    (o_empty_despSend[i_pe] ),  //* Read domain empty
          .rdalempty  (                       ),  //* Read domain almost-empty
          .wrusedw    (                       ),  //* Write-usedword
          .rdusedw    (                       )   //* Read-usedword
        );
      `endif
      
      regfifo_528b_4 fifo_writeReq (  //* 16b addr + 512b data;
        .clk    (i_clk                        ),  //* input wire clk
        .srst   (!i_rst_n                     ),  //* input wire srst
        .din    (i_din_writeReq[i_pe*528+:528]),  //* input wire [528 : 0] din
        .wr_en  (i_wren_writeReq[i_pe]        ),  //* input wire wr_en
        .rd_en  (i_rden_writeReq[i_pe]        ),  //* input wire rd_en
        .dout   (o_dout_writeReq[i_pe*528+:528]), //* output wire [528 : 0] dout
        .full   (                             ),  //* output wire full
        .empty  (o_empty_writeReq[i_pe]       )   //* output wire empty
      );
    end
  endgenerate 

  

  /** ram used to buffer recv/send pkt*/
  `ifdef XILINX_FIFO_RAM
    ram_512b_512 ram_pktRecv (
      .clka       (i_clk                  ),
      .wea        (i_wren_pktRAM_hw       ),
      .addra      (i_addr_pktRAM_hw[8:0]  ),
      .dina       (i_din_pktRAM_hw        ),
      .douta      (o_dout_pktRAM_hw       ),
      .clkb       (i_clk                  ),
      .web        (i_wren_pktRAM_core     ),
      .addrb      (i_addr_pktRAM_core[8:0]),
      .dinb       (i_din_pktRAM_core      ),
      .doutb      (o_dout_pktRAM_core     )
    );
  `elsif SIM_FIFO_RAM
    syncram ram_pktRecv(
      .address_a  (i_addr_pktRAM_hw[8:0]  ),
      .address_b  (i_addr_pktRAM_core[8:0]),
      .clock      (i_clk),
      .data_a     (i_din_pktRAM_hw        ),
      .data_b     (i_din_pktRAM_core      ),
      .rden_a     (1'b1                   ),
      .rden_b     (1'b1                   ),
      .wren_a     (i_wren_pktRAM_hw       ),
      .wren_b     (i_wren_pktRAM_core     ),
      .q_a        (o_dout_pktRAM_hw       ),
      .q_b        (o_dout_pktRAM_core     )
    );
    defparam  ram_pktRecv.width = 512,
              ram_pktRecv.depth = 9,
              ram_pktRecv.words = 512;
  `else
    dualportsram512x512 ram_pktRecv(
      .aclr       (~i_rst_n               ), //* asynchronous reset
      .clock      (i_clk                  ), //* port A & B: clock
      .rden_a     (!i_wren_pktRAM_hw      ), //* port A: read enable
      .wren_a     (i_wren_pktRAM_hw       ), //* port A: write enable
      .address_a  (i_addr_pktRAM_hw[8:0]  ), //* port A: address
      .data_a     (i_din_pktRAM_hw        ), //* port A: data input
      .q_a        (o_dout_pktRAM_hw       ), //* port A: data output
      .rden_b     (!i_wren_pktRAM_core    ), //* port B: read enable
      .wren_b     (i_wren_pktRAM_core     ), //* port B: write enable
      .address_b  (i_addr_pktRAM_core[8:0]), //* port B: address
      .data_b     (i_din_pktRAM_core      ), //* port B: data input
      .q_b        (o_dout_pktRAM_core     )  //* port B: data output
      );
  `endif
  //==============================================================//


  //* debug;
  assign d_empty_pktRecv_1b   = o_empty_pktRecv;
  assign d_empty_despRecv_3b  = o_empty_despRecv;
  assign d_empty_despSend_3b  = o_empty_despSend;
  assign d_empty_writeReq_3b  = o_empty_writeReq;
  assign d_usedw_pktRecv_10b  = w_usedw_pktRecv;

endmodule
