/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        Pkt_Proc_Top.
 *  Description:        This module is used to process pkt (DMA & DRA). 
 *  Last updated date:  2024.02.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Space = 2;
 */

module Pkt_Proc_Top(
  //* clock & rst_n;
   input  wire                      i_clk    
  ,input  wire                      i_rst_n     
  //* To/From CPI, TODO
  ,input  wire  [         47:0]     i_pe_conf_mac
  ,input  wire                      i_data_valid
  ,input  wire  [        133:0]     i_data
  ,output wire                      o_data_valid
  ,output wire  [        133:0]     o_data
  //* config interface;
  ,output wire                      o_conf_rden     //* configure interface
  ,output wire                      o_conf_wren
  ,output wire  [         15:0]     o_conf_addr
  ,output wire  [        127:0]     o_conf_wdata
  ,input        [        127:0]     i_conf_rdata
  ,output wire  [          3:0]     o_conf_en       //* '1' means configuring is valid;
  //* Peri interface (DRA, DMA), TODO,
  ,input  wire             [ 31:0]  i_peri_addr
  ,input  wire  [`DRA:`DMA]         i_peri_wren
  ,input  wire  [`DRA:`DMA]         i_peri_rden
  ,input  wire             [ 31:0]  i_peri_wdata
  ,output wire  [`DRA:`DMA][ 31:0]  o_peri_rdata
  ,output wire  [`DRA:`DMA]         o_peri_ready
  ,output wire  [`DRA:`DMA]         o_peri_int
`ifdef ENABLE_DRA  
  //* DRA interface, TODO;
  ,input  wire                      i_reg_rd   
  ,input  wire  [         31:0]     i_reg_raddr
  ,output wire  [        511:0]     o_reg_rdata      
  ,output wire                      o_reg_rvalid     
  ,output wire                      o_reg_rvalid_desp
  ,input  wire                      i_reg_wr     
  ,input  wire                      i_reg_wr_desp
  ,input  wire  [         31:0]     i_reg_waddr  
  ,input  wire  [        511:0]     i_reg_wdata  
  ,input  wire  [         31:0]     i_status     
  ,output wire  [         31:0]     o_status   
`endif
  //* DMA interface;
  ,output wire                      o_dma_rden 
  ,output wire                      o_dma_wren 
  ,output wire  [         31:0]     o_dma_addr 
  ,output wire  [        255:0]     o_dma_wdata
  ,output wire  [          7:0]     o_dma_wstrb
  ,output wire  [          7:0]     o_dma_winc
  ,input  wire  [        255:0]     i_dma_rdata
  ,input  wire                      i_dma_rvalid
  ,input  wire                      i_dma_gnt
  //* ready;
  ,output wire                      o_alf
  ,input  wire                      i_alf
`ifdef UART_BY_PKT
  ,input  wire                      i_uartPkt_valid
  ,input  wire  [       133:0]      i_uartPkt
`endif  
);
  
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire          [133:0]             w_data_to_dma, w_data_from_dma, w_data_from_conf;
  wire          [133:0]             w_data_to_dra, w_data_from_dra;
  wire                              w_data_to_dma_valid, w_data_from_dma_valid, w_data_from_conf_valid;
  wire                              w_data_to_dra_valid, w_data_from_dra_valid;
  wire                              w_data_from_crc_valid;
  wire          [133:0]             w_data_from_crc;
  //* alf;
  wire          [`NUM_PE-1:0]       w_alf_dma;
`ifdef ENABLE_DRA
  wire                              w_alf_dra;
`endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Dispatch recv pkt
  //====================================================================//
  Pkt_DMUX Pkt_DMUX(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for recv/send pkt;
    .i_pe_conf_mac          (i_pe_conf_mac            ),
    .i_data_valid           (i_data_valid             ),
    .i_data                 (i_data                   ),
  `ifdef ENABLE_DRA  
    //* to DRA
    .o_data_DRA_valid       (w_data_to_dra_valid      ),
    .o_data_DRA             (w_data_to_dra            ),
    .i_alf_dra              (w_alf_dra                ),
  `endif
    //* to DMA
    .o_data_DMA_valid       (w_data_to_dma_valid      ),
    .o_data_DMA             (w_data_to_dma            ),
    .i_alf_dma              (w_alf_dma                ),
    .o_alf                  (o_alf                    ),
    //* conf respond
    .o_data_conf_valid      (w_data_from_conf_valid   ),
    .o_data_conf            (w_data_from_conf         ),
    //* to configure
    .o_conf_rden            (o_conf_rden              ),
    .o_conf_wren            (o_conf_wren              ),
    .o_conf_addr            (o_conf_addr              ),
    .o_conf_wdata           (o_conf_wdata             ),
    .i_conf_rdata           (i_conf_rdata             ),
    .o_conf_en              (o_conf_en                )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
   
  Pkt_MUX Pkt_MUX(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for recv/send pkt;
  `ifdef ENABLE_DRA
    .i_data_DRA_valid       ('b0                      ),
    .i_data_DRA             ('b0                      ),
  `endif
    //* to DMA
  `ifndef ENABLE_CKSUM  
    .i_data_DMA_valid       (w_data_from_dma_valid    ),
    .i_data_DMA             (w_data_from_dma          ),
  `else
    .i_data_DMA_valid       (w_data_from_crc_valid    ),
    .i_data_DMA             (w_data_from_crc          ),
  `endif
    .i_data_conf_valid      (w_data_from_conf_valid   ),
    .i_data_conf            (w_data_from_conf         ),
    //* output;
    .o_data_valid           (o_data_valid             ),
    .o_data                 (o_data                   )
  `ifdef UART_BY_PKT
    ,.i_uartPkt_valid       (i_uartPkt_valid          )
    ,.i_uartPkt             (i_uartPkt                )
  `endif
  );

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  `ifdef DRA_EN
    DRA_Engine DRA_Engine(
      .i_clk                  (i_clk                    ),
      .i_rst_n                (i_rst_n                  ),
      //* interface for recv/send pkt;
      .i_data_valid           (w_data_to_dra_valid      ),
      .i_data                 (w_data_to_dra            ),
      .o_data_valid           (w_data_from_dra_valid    ),
      .o_data                 (w_data_from_dra          ),
      //* alf;
      .o_alf_dra              (w_alf_dra                ),
      //* DRA;
      .i_reg_rd               (i_reg_rd                 ),
      .i_reg_raddr            (i_reg_raddr              ),
      .o_reg_rdata            (o_reg_rdata              ),
      .o_reg_rvalid           (o_reg_rvalid             ),
      .o_reg_rvalid_desp      (o_reg_rvalid_desp        ),
      .i_reg_wr               (i_reg_wr                 ),
      .i_reg_wr_desp          (i_reg_wr_desp            ),
      .i_reg_waddr            (i_reg_waddr              ),
      .i_reg_wdata            (i_reg_wdata              ),
      .i_status               (i_status                 ),
      .o_status               (o_status                 ),
      //* peri interface;
      .i_peri_rden            (i_peri_rden[`DRA]        ),
      .i_peri_wren            (i_peri_wren[`DRA]        ),
      .i_peri_addr            (i_peri_addr              ),
      .i_peri_wdata           (i_peri_wdata             ),
      .o_peri_rdata           (o_peri_rdata[`DRA]       ),
      .o_peri_ready           (o_peri_ready[`DRA]       ),
      .o_peri_int             (o_peri_int[`DRA]         )
    );
  `endif


  // assign w_data_from_dma_valid  = 'b0;
  // assign w_data_from_dma        = 'b0;
  // assign w_alf_dma              = 'b0;
  // assign o_dma_rden             = 'b0;
  // assign o_dma_wren             = 'b0;
  // assign o_data_valid = w_data_from_dma_valid;
  // assign o_data = w_data_from_dma;
  DMA_Engine DMA_Engine(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* pkt in & out;
    .i_data_valid           (w_data_to_dma_valid      ),
    .i_data                 (w_data_to_dma            ),
    .o_data_valid           (w_data_from_dma_valid    ),
    .o_data                 (w_data_from_dma          ),
    //* alf;
    .o_alf_dma              (w_alf_dma                ),
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
    //* peri interface;
    .i_peri_rden            (i_peri_rden[`DMA]        ),
    .i_peri_wren            (i_peri_wren[`DMA]        ),
    .i_peri_addr            (i_peri_addr              ),
    .i_peri_wdata           (i_peri_wdata             ),
    .o_peri_rdata           (o_peri_rdata[`DMA]       ),
    .o_peri_ready           (o_peri_ready[`DMA]       ),
    .o_peri_int             (o_peri_int[`DMA]         )
  );

`ifdef ENABLE_CKSUM
  Pkt_TCP_CRC Pkt_TCP_CRC(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    .i_data_valid           (w_data_from_dma_valid    ),
    .i_data                 (w_data_from_dma          ),
    .o_data_valid           (w_data_from_crc_valid    ),
    .o_data                 (w_data_from_crc          )
  );
`endif

endmodule    
