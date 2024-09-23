/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        DMA_Engine.
 *  Description:        This module is used to dma packets.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module DMA_Engine(
   input  wire                    i_clk
  ,input  wire                    i_rst_n

  //* data to DMA;
  ,(* mark_debug = "true"*)input  wire                    i_data_valid
  ,(* mark_debug = "true"*)input  wire  [         133:0]  i_data
  ,output wire  [   `NUM_PE-1:0]  o_alf_dma
  //* data to output;
  ,output reg                     o_data_valid
  ,output reg   [         133:0]  o_data
  //* DMA (communicaiton with data SRAM);
  ,(* mark_debug = "true"*)output wire                    o_dma_rden
  ,(* mark_debug = "true"*)output wire                    o_dma_wren
  ,(* mark_debug = "true"*)output wire  [          31:0]  o_dma_addr
  ,(* mark_debug = "true"*)output wire  [         255:0]  o_dma_wdata
  ,(* mark_debug = "true"*)output wire  [           7:0]  o_dma_wstrb
  ,(* mark_debug = "true"*)output wire  [           7:0]  o_dma_winc
  ,(* mark_debug = "true"*)input  wire  [         255:0]  i_dma_rdata
  ,(* mark_debug = "true"*)input  wire                    i_dma_rvalid
  ,(* mark_debug = "true"*)input  wire                    i_dma_gnt
  //* configuration interface for DMA;
  ,input  wire  [ 31:0]     i_peri_addr
  ,input  wire              i_peri_wren
  ,input  wire              i_peri_rden
  ,input  wire  [ 31:0]     i_peri_wdata
  ,output wire  [ 31:0]     o_peri_rdata
  ,output wire              o_peri_ready
  ,output wire              o_peri_int
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* fifo;
  //* dmaWR for data to write to SRAM;
  wire                      w_rden_dmaWR;
  wire  [         133:0]    w_dout_dmaWR;
  wire                      w_empty_dmaWR;
  wire  [           9:0]    w_usedw_dmaWR;

  //* pBufWR for data to write to SRAM (pBuf addr);
  //* pBufRD for data to read from SRAM (pBuf addr);
  wire                      w_rden_pBufWR, w_rden_pBufRD, w_wren_pBufWR, w_wren_pBufRD;
  wire  [          47:0]    w_dout_pBufWR;
  wire  [          63:0]    w_dout_pBufRD;
  wire                      w_empty_pBufWR, w_empty_pBufRD;
  wire  [           9:0]    w_usedw_pBufRD;
  wire  [          47:0]    w_din_pBufWR;
  wire  [          63:0]    w_din_pBufRD;

  //* int for finishing writing/reading SRAM event;
  wire  [          31:0]    w_din_int;
  wire                      w_wren_int, w_rden_int;
  wire  [          31:0]    w_dout_int;
  wire                      w_empty_int;

  //* length;
  wire  [          15:0]    w_din_length;
  wire                      w_wren_length, w_rden_length;
  wire  [          15:0]    w_dout_length;
  wire                      w_empty_length;
  
  //* for output data;
  wire  [         133:0]    w_din_rdDMA;
  wire                      w_wren_rdDMA;
  reg                       r_rden_rdDMA;
  wire  [         133:0]    w_dout_rdDMA;
  wire                      w_empty_rdDMA;
  wire  [           8:0]    w_usedw_rdDMA;
  reg   [           3:0]    r_cnt_rdDMA;

  //* filter pkt;
  // wire                      w_filter_en;
  // wire                      w_filter_dmac_en;
  // wire                      w_filter_smac_en;
  // wire                      w_filter_type_en;
  // wire  [           7:0]    w_filter_dmac   ;
  // wire  [           7:0]    w_filter_smac   ;
  // wire  [           7:0]    w_filter_type   ;

  //* wait new pBufWR;
  wire                      w_wait_free_pBufWR;
  //* start_en, '1' is valid;
  wire                      w_start_en;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  assign w_wren_length  = i_data_valid == 1'b1 && i_data[133:132] == 2'b11;
  assign w_din_length   = {4'b0,i_data[16+:12]};

  //==============================================================//
  //*   DMA_Out_Data
  //==============================================================//
  wire    r_cnt_rdDMA_inc, r_cnt_rdDMA_dec;
  reg [1:0] r_cnt_pkt;    
  assign  r_cnt_rdDMA_inc = w_wren_rdDMA & (w_din_rdDMA[133:132] == 2'b10);
  assign  r_cnt_rdDMA_dec = r_rden_rdDMA & (!o_data_valid);
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      o_data_valid          <= 1'b0;
      r_rden_rdDMA          <= 1'b0;
      r_cnt_rdDMA           <= 4'b0;
    end
    else begin
      case({r_cnt_rdDMA_inc,r_cnt_rdDMA_dec})
        2'b00, 2'b11: r_cnt_rdDMA   <= r_cnt_rdDMA;
        2'b10:        r_cnt_rdDMA   <= r_cnt_rdDMA + 4'd1;
        2'b01:        r_cnt_rdDMA   <= r_cnt_rdDMA - 4'd1;
      endcase
    
      o_data_valid          <= r_rden_rdDMA;
      o_data                <= w_dout_rdDMA;
      if(r_cnt_rdDMA != 4'b0 && r_rden_rdDMA == 1'b0 && o_data_valid == 1'b0) begin
        r_rden_rdDMA        <= 1'b1;
        r_cnt_pkt           <= 2'b0;
      end
      else if(r_rden_rdDMA == 1'b1) begin
        r_cnt_pkt           <= r_cnt_pkt[1]? r_cnt_pkt : (r_cnt_pkt+2'd1);
        o_data[133:132]     <= (r_cnt_pkt == 2'b00)? 2'b11:
                                (r_cnt_pkt == 2'b01)? 2'b01: w_dout_rdDMA[133:132];

        if(w_dout_rdDMA[133:132] == 2'b10)
          r_rden_rdDMA      <= 1'b0;
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //*   DMA_Out_Data
  //==============================================================//
  DMA_Wr_Rd_DataRAM DMA_Wr_Rd_DataRam(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* pkt in;
    .i_empty_data           (w_empty_dmaWR            ),
    .o_data_rden            (w_rden_dmaWR             ),
    .i_data                 (w_dout_dmaWR             ),
    //* 134b data out;
    .o_din_rdDMA            (w_din_rdDMA              ),
    .o_wren_rdDMA           (w_wren_rdDMA             ),
    .i_usedw_rdDMA          (w_usedw_rdDMA            ),
    //* dma interface;
    .o_dma_rden             (o_dma_rden               ),
    .o_dma_wren             (o_dma_wren               ),
    .o_dma_addr             (o_dma_addr               ),
    .o_dma_wdata            (o_dma_wdata              ),
    .o_dma_wstrb            (o_dma_wstrb              ),
    .o_dma_winc             (o_dma_winc               ),
    .i_dma_rdata            (i_dma_rdata              ),
    .i_dma_rvalid           (i_dma_rvalid             ),
    .i_dma_gnt              (i_dma_gnt                ),
    //* pBuf in interface;
    .o_rden_pBufWR          (w_rden_pBufWR            ),
    .i_dout_pBufWR          (w_dout_pBufWR            ),
    .i_empty_pBufWR         (w_empty_pBufWR           ),
    .o_rden_pBufRD          (w_rden_pBufRD            ),
    .i_dout_pBufRD          (w_dout_pBufRD            ),
    .i_empty_pBufRD         (w_empty_pBufRD           ),
    .i_usedw_pBufRD         (w_usedw_pBufRD           ),
    //* wait free pBufWR;
    .o_wait_free_pBufWR     (w_wait_free_pBufWR       ),
    //* int out;
    .o_din_int              (w_din_int                ),
    .o_wren_int             (w_wren_int               )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //======================= DMA Peri       =======================//
  DMA_Peri DMA_Peri(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* periperal interface;
    .i_peri_rden            (i_peri_rden              ),
    .i_peri_wren            (i_peri_wren              ),
    .i_peri_addr            (i_peri_addr              ),
    .i_peri_wdata           (i_peri_wdata             ),
    .o_peri_rdata           (o_peri_rdata             ),
    .o_peri_ready           (o_peri_ready             ),
    .o_peri_int             (o_peri_int               ),
    //* pBuf out;
    .o_din_pBufWR           (w_din_pBufWR             ),
    .o_wren_pBufWR          (w_wren_pBufWR            ),
    .o_din_pBufRD           (w_din_pBufRD             ),
    .o_wren_pBufRD          (w_wren_pBufRD            ),
    //* int in;
    .o_rden_int             (w_rden_int               ),
    .i_dout_int             (w_dout_int               ),
    .i_empty_int            (w_empty_int              ),
    //* length out;
    .o_rden_length          (w_rden_length            ),
    .i_dout_length          (w_dout_length            ),
    .i_empty_length         (w_empty_length           )
    //* filter pkt;
    // ,.o_filter_en           (w_filter_en              )
    // ,.o_filter_dmac_en      (w_filter_dmac_en         )
    // ,.o_filter_smac_en      (w_filter_smac_en         )
    // ,.o_filter_type_en      (w_filter_type_en         )
    // ,.o_filter_dmac         (w_filter_dmac            )
    // ,.o_filter_smac         (w_filter_smac            )
    // ,.o_filter_type         (w_filter_type            )
    // //* wait free pBufWR;
    // ,.i_wait_free_pBufWR    (w_wait_free_pBufWR       )
    // //* start_en
    // ,.o_start_en            (w_start_en               )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //======================= reset        =======================//
  // DMA_Reset DMA_Reset(
  //   //* clk & rst_n;
  //   .i_clk                  (i_clk                    ),
  //   .i_rst_n                (i_rst_n                  ),
  //   //* reset dma req/resp;
  //   .i_resetDMA_req         (w_resetDMA_req[i_pe]     ),
  //   .i_state_DMA_out        (i_state_DMA_out[i_pe]    ),
  //   .o_resetDMA_resp        (w_resetDMA_resp[i_pe]    )
  // );
  //======================= reset        =======================//

  //==============================================================//
  //*   fifos
  //==============================================================//
  /** fifo used to buffer pBuf_wr*/
  regfifo_48b_8 fifo_pBufWR (
    .clk                (i_clk                    ),  //* input wire clk
    .srst               (!i_rst_n                 ),  //* input wire srst
    .din                (w_din_pBufWR             ),  //* input wire [47 : 0] din
    .wr_en              (w_wren_pBufWR            ),  //* input wire wr_en
    .rd_en              (w_rden_pBufWR            ),  //* input wire rd_en
    .dout               (w_dout_pBufWR            ),  //* output wire [47 : 0] dout
    .full               (                         ),  //* output wire full
    .empty              (w_empty_pBufWR           )   //* output wire empty
  );

  /** fifo used to buffer pBuf_rd, 16b_length, 32b_addr*/
  regfifo_64b_8 fifo_pBufRD (
    .clk                (i_clk                    ),  //* input wire clk
    .srst               (!i_rst_n                 ),  //* input wire srst
    .din                (w_din_pBufRD             ),  //* input wire [63 : 0] din
    .wr_en              (w_wren_pBufRD            ),  //* input wire wr_en
    .rd_en              (w_rden_pBufRD            ),  //* input wire rd_en
    .dout               (w_dout_pBufRD            ),  //* output wire [63 : 0] dout
    .full               (                         ),  //* output wire full
    .empty              (w_empty_pBufRD           ),  //* output wire empty
    .data_count         (w_usedw_pBufRD           )
  );

  /** fifo used to buffer interrupt, 1b_wr/rd, 32b_addr, '1' is wr*/ 
  regfifo_32b_4 fifo_int (
    .clk                (i_clk                    ),  //* input wire clk
    .srst               (!i_rst_n                 ),  //* input wire srst
    .din                (w_din_int                ),  //* input wire [31 : 0] din
    .wr_en              (w_wren_int               ),  //* input wire wr_en
    .rd_en              (w_rden_int               ),  //* input wire rd_en
    .dout               (w_dout_int               ),  //* output wire [31 : 0] dout
    .full               (                         ),  //* output wire full
    .empty              (w_empty_int              )   //* output wire empty
  );

  `ifdef XILINX_FIFO_RAM
    //* fifo used to buffer dma pkt;
    fifo_134b_512 fifo_dmaWR (
      .clk              (i_clk                    ),  //* input wire clk
      .srst             (!i_rst_n                 ),  //* input wire srst
      .din              (i_data                   ),  //* input wire [133 : 0] din
      .wr_en            (i_data_valid             ),  //* input wire wr_en
      .rd_en            (w_rden_dmaWR             ),  //* input wire rd_en
      .dout             (w_dout_dmaWR             ),  //* output wire [133 : 0] dout
      .full             (                         ),  //* output wire full
      .empty            (w_empty_dmaWR            ),  //* output wire empty
      .data_count       (w_usedw_dmaWR            )
    );

    /** fifo used to buffer pBuf_wr*/
    fifo_16b_512 fifo_length (
      .clk              (i_clk                    ),  //* input wire clk
      .srst             (!i_rst_n                 ),  //* input wire srst
      .din              (w_din_length             ),  //* input wire [16 : 0] din
      .wr_en            (w_wren_length            ),  //* input wire wr_en
      .rd_en            (w_rden_length            ),  //* input wire rd_en
      .dout             (w_dout_length            ),  //* output wire [16 : 0] dout
      .full             (                         ),  //* output wire full
      .empty            (w_empty_length           )   //* output wire empty
    );

    /** fifo used to output data*/
    fifo_134b_512 fifo_rdDMA ( 
      .clk              (i_clk                    ),  //* input wire clk
      .srst             (!i_rst_n                 ),  //* input wire srst
      .din              (w_din_rdDMA              ), //* input wire [133 : 0] din
      .wr_en            (w_wren_rdDMA             ),  //* input wire wr_en
      .rd_en            (r_rden_rdDMA             ),  //* input wire rd_en
      .dout             (w_dout_rdDMA             ),//* output wire [133 : 0] dout
      .full             (                         ),  //* output wire full
      .empty            (w_empty_rdDMA            ),  //* output wire empty
      .data_count       (w_usedw_rdDMA            )
    );
  `elsif SIM_FIFO_RAM
    //* fifo used to buffer dma pkt;
    syncfifo fifo_dmaWR (
      .clock            (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr             (!i_rst_n                 ),  //* Reset the all signal
      .data             (i_data                   ),  //* The Inport of data 
      .wrreq            (i_data_valid             ),  //* active-high
      .rdreq            (w_rden_dmaWR             ),  //* active-high
      .q                (w_dout_dmaWR             ),  //* The output of data
      .empty            (w_empty_dmaWR            ),  //* Read domain empty
      .usedw            (w_usedw_dmaWR[8:0]       ),  //* Usedword
      .full             (                         )   //* Full
    );
    defparam  fifo_dmaWR.width = 134,
              fifo_dmaWR.depth = 9,
              fifo_dmaWR.words = 512;
    assign w_usedw_dmaWR[9]    = 'b0;

    /** fifo used to buffer pBuf_wr*/
    syncfifo fifo_length (
      .clock            (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr             (!i_rst_n                 ),  //* Reset the all signal
      .data             (w_din_length             ),  //* The Inport of data 
      .wrreq            (w_wren_length            ),  //* active-high
      .rdreq            (w_rden_length            ),  //* active-high
      .q                (w_dout_length            ),  //* The output of data
      .empty            (w_empty_length           ),  //* Read domain empty
      .usedw            (                         ),  //* Usedword
      .full             (                         )   //* Full
    );
    defparam  fifo_length.width = 16,
              fifo_length.depth = 7,
              fifo_length.words = 128;

    /** fifo used to output data*/
    syncfifo fifo_rdDMA (
      .clock            (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr             (!i_rst_n                 ),  //* Reset the all signal
      .data             (w_din_rdDMA              ), //* The Inport of data 
      .wrreq            (w_wren_rdDMA             ),  //* active-high
      .rdreq            (r_rden_rdDMA             ),  //* active-high
      .q                (w_dout_rdDMA             ),//* The output of data
      .empty            (w_empty_rdDMA            ),  //* Read domain empty
      .usedw            (w_usedw_rdDMA            ),  //* Usedword
      .full             (                         )   //* Full
    );
    defparam  fifo_rdDMA.width = 134,
              fifo_rdDMA.depth = 9,
              fifo_rdDMA.words = 512;
  `endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* alf;
  assign o_alf_dma = w_usedw_dmaWR[9:0]   > 10'd400;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


endmodule
