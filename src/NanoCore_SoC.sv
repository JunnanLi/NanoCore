/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        NanoCore_SoC.
 *  Description:        This module is used to connect MultiCore_Top with 
 *                       Pkt_Proc_Top, Peri_Top.
 *  Last updated date:  2024.02.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 *    1) 134b pkt data definition: 
 *      [133:132] head tag, 2'b11 is meta, 2'b01 is head, 2'b10 is tail;
 *      [131:128] valid tag, 4'b1111 means sixteen 8b data is valid;
 *      [127:  0] pkt data, invalid part is padded with x;
 *    2) 134b pkt meta definition: 
 *      [  7:  0] OutportBM;
 *      [ 15:  8] InportBM;
 *      [ 27: 16] pkt length;
 *      [ 31: 28] dst bitmap: {reserved, DRA, DMA, conf};
 *      [127: 32] reserved;
 *    3) irq for NanoCore: xxx;
 *    4) Space = 2;
 */

  //====================================================================//
  //*   Connection Relationship                                         //
  //*  +-----------+                                +------------+      //
  //*  | PE_Config |--------------------------+     | CMCU_Debug |      //
  //*  +-----------+                          |     +------------+      //
  //*     |                                   | Conf                    //
  //*     |        +----------+ <peri   +---------------+               //
  //* pkt |     ---| Peri_Top |---------| MultiCore_top |               //
  //*     |     |  +----------+         +---------------+               //
  //*  +--------------+                       | DRA/DMA                 //
  //*  | Pkt_Proc_Top |-----------------------+                         //
  //*  +--------------+                                                 //
  //====================================================================//

module NanoCore_SoC(
  //======================= clock & resets  ============================//
   input  wire              i_sys_clk
  ,input  wire              i_sys_rst_n
  ,input  wire              i_pe_clk
  ,input  wire              i_rst_n
  //======================= pkt             ============================//
  //* pkt[133:132]: 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
  ,input  wire [      47:0] i_pe_conf_mac
  ,input  wire              i_data_valid
  ,input  wire [     133:0] i_data  
  ,output wire              o_alf 
  ,output wire              o_data_valid
  ,output wire [     133:0] o_data
  ,input  wire              i_alf
  //======================= uart            ============================//
  ,input  wire              i_uart_rx
  ,output wire              o_uart_tx
  ,input  wire              i_uart_cts
  ,output wire              o_uart_rts
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* 1-1) Configure info: PE_Config <---> PE's instr/data ram;
  wire                      w_conf_rden, w_conf_wren;
  wire  [           15:0]   w_conf_addr;
  wire  [          127:0]   w_conf_wdata, w_conf_rdata;
  wire  [            3:0]   w_conf_en;  //* bitmap for 4 PEs;
  //* 2) left fo reset: CSR_Peri ---> AiPE;
  
  //* 3-1) Peripherals-related: PE <---> Peripherals Bus (PeriBus);
  wire                      w_peri_rden, w_peri_wren;
  wire  [            31:0]  w_peri_addr, w_peri_wdata;
  wire  [             3:0]  w_peri_wstrb;
  wire  [            31:0]  w_peri_rdata;
  wire                      w_peri_ready;
  wire                      w_peri_gnt;
  wire  [`DRA:`DMA]         w_rden_2peri, w_wren_2peri;
  wire             [ 31:0]  w_addr_2peri, w_wdata_2peri;
  wire             [  3:0]  w_wstrb_2peri;
  wire  [`DRA:`DMA][ 31:0]  w_rdata_2PBUS;
  wire  [`DRA:`DMA]         w_ready_2PBUS, w_int_2PBUS;
  //* 3-2) Peripherals-related: PeriBus <---> DMA, DRA;

  //* 3-3) Peripherals-related: {DRA, DMA} <---> Peri_Top;

  //* 3-4) left for customized logic of dDMA

  //* 4) Irq-related: PE <---> irq Bus (IrqBus);
  wire  [            31:0]  w_irq_bitmap;
  wire                      w_irq_ack;
  wire  [             4:0]  w_irq_id;

  //* 5) Special registers from/to CSR_Peri;
  //* start addresses of Instr/Data for 3 PEs;
  wire  [  `NUM_PE*32-1:0]  w_instr_offset_addr;
  wire  [  `NUM_PE*32-1:0]  w_data_offset_addr;
  //* to update system time by CMCU; 
  wire  [            64:0]  w_update_system_time; //* in format of {0_minus/add, ns_32b};
  wire                      w_update_valid;

  //* 6) DRA-related: PE's regs <---> DRA_Engine;
`ifdef ENABLE_DRA  
  wire                      w_reg_rd;           //* to read data from DRA engine;
  wire  [            31:0]  w_reg_raddr;        //* addr to read (from PE);
  wire  [           511:0]  w_reg_rdata;        //* return read data from DRA engine;
  wire                      w_reg_rvalid;       //* return recv data from DRA engine;
  wire                      w_reg_rvalid_desp;  //* return recv desp from DRA engine;
  wire                      w_reg_wr, w_reg_wr_desp;
  wire  [            31:0]  w_reg_waddr;        //* addr to write (from PE);
  wire  [           511:0]  w_reg_wdata;        //* wdata from PE;
  wire  [            31:0]  w_status_2core, w_status_2pktMem;
`endif
  //* 7) DMA-related: PE's data ram <---> DMA_Engine;
  wire                      w_dma_rden;         //* to read/write data SRAM;
  wire                      w_dma_wren;
  wire  [            31:0]  w_dma_addr;
  wire  [           255:0]  w_dma_wdata;
  wire  [             7:0]  w_dma_wstrb;
  wire  [             7:0]  w_dma_winc;
  wire  [           255:0]  w_dma_rdata;        //* return read result from data SRAM;
  wire                      w_dma_rvalid;
  wire                      w_dma_gnt;          //* allow to read/write next data;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

`ifdef ENABLE_DRA
  //* DRA;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_rd            //* read req;
  ,output   wire  [  `NUM_PE*32-1:0]  o_reg_raddr         //* read addr;
  ,input    wire  [           511:0]  i_reg_rdata         //* read respond;
  ,input    wire  [     `NUM_PE-1:0]  i_reg_rvalid        //* read pkt's data;
  ,input    wire  [     `NUM_PE-1:0]  i_reg_rvalid_desp   //* read description;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_wr            //* write data req;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_wr_desp       //* write description req;
  ,output   wire  [  `NUM_PE*32-1:0]  o_reg_waddr         //* write addr;
  ,output   wire  [ `NUM_PE*512-1:0]  o_reg_wdata         //* write data/description;
  ,input    wire  [  `NUM_PE*32-1:0]  i_status            //* cpu status;
  ,output   wire  [  `NUM_PE*32-1:0]  o_status            //* nic status;
`endif
`ifdef UART_BY_PKT
  wire                      w_uartPkt_valid;
  wire   [          133:0]  w_uartPkt;
`endif

  //====================================================================//
  //*   MultiCore_top
  //====================================================================//
  MultiCore_Top MultiCore_Top(
    .i_clk                  (i_pe_clk                     ),
    .i_rst_n                (i_rst_n                      ),
    //* conf instr/data mem, connected with CMCU_Config;
    .i_conf_rden            (w_conf_rden                  ),
    .i_conf_wren            (w_conf_wren                  ),
    .i_conf_addr            (w_conf_addr                  ),
    .i_conf_wdata           (w_conf_wdata                 ),
    .o_conf_rdata           (w_conf_rdata                 ),
    .i_conf_en              (w_conf_en                    ),
    //* to peri, connected with Peri_Top;
    .o_peri_rden            (w_peri_rden                  ),
    .o_peri_wren            (w_peri_wren                  ),
    .o_peri_addr            (w_peri_addr                  ),
    .o_peri_wdata           (w_peri_wdata                 ),
    .o_peri_wstrb           (w_peri_wstrb                 ),
    .i_peri_rdata           (w_peri_rdata                 ),
    .i_peri_ready           (w_peri_ready                 ),
    .i_peri_gnt             (1'b1                         ), 
    //* irq;
    .i_irq_bitmap           (w_irq_bitmap                 ),
    .o_irq_ack              (w_irq_ack                    ),
    .o_irq_id               (w_irq_id                     ),
    //* DRA, connected with Pkt_Proc;
    `ifdef ENABLE_DRA
      .o_reg_rd             (w_reg_rd                     ),
      .o_reg_raddr          (w_reg_raddr                  ),
      .i_reg_rdata          (w_reg_rdata                  ),
      .i_reg_rvalid         (w_reg_rvalid                 ),
      .i_reg_rvalid_desp    (w_reg_rvalid_desp            ),
      .o_reg_wr             (w_reg_wr                     ),
      .o_reg_wr_desp        (w_reg_wr_desp                ),
      .o_reg_waddr          (w_reg_waddr                  ),
      .o_reg_wdata          (w_reg_wdata                  ),
      .i_status             (w_status_2core               ),
      .o_status             (w_status_2pktMem             ),
    `endif
    //* DMA;
    .i_dma_rden             (w_dma_rden                   ),
    .i_dma_wren             (w_dma_wren                   ),
    .i_dma_addr             (w_dma_addr                   ),
    .i_dma_wdata            (w_dma_wdata                  ),
    .i_dma_winc             (w_dma_winc                   ),
    .i_dma_wstrb            (w_dma_wstrb                  ),
    .o_dma_rdata            (w_dma_rdata                  ),
    .o_dma_rvalid           (w_dma_rvalid                 ),
    .o_dma_gnt              (w_dma_gnt                    )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Peri_Top  
  //====================================================================//
  //* peri/irq bus, include UARTs, DMA;
  Peri_Top Peri_Top(
    //* clk & rst_n;
    .i_pe_clk               (i_pe_clk                     ),
    .i_rst_n                (i_rst_n                      ),
    .i_sys_clk              (i_sys_clk                    ),
    //* UART
    .o_uart_tx              (o_uart_tx                    ),
    .i_uart_rx              (i_uart_rx                    ),
    .i_uart_cts             (i_uart_cts                   ),
    //* Peri interface, connected with MultiCore;
    .i_peri_rden            (w_peri_rden                  ),
    .i_peri_wren            (w_peri_wren                  ),
    .i_peri_addr            (w_peri_addr                  ),
    .i_peri_wdata           (w_peri_wdata                 ),
    .i_peri_wstrb           (w_peri_wstrb                 ),
    .o_peri_rdata           (w_peri_rdata                 ),
    .o_peri_ready           (w_peri_ready                 ),
    //* DMA, DRA, connected with MultiCore & Pkt_Proc;
    .o_rden_2peri           (w_rden_2peri                 ),
    .o_wren_2peri           (w_wren_2peri                 ),
    .o_addr_2peri           (w_addr_2peri                 ),
    .o_wdata_2peri          (w_wdata_2peri                ),
    .o_wstrb_2peri          (w_wstrb_2peri                ),
    .i_rdata_2PBUS          (w_rdata_2PBUS                ),
    .i_ready_2PBUS          (w_ready_2PBUS                ),
    .i_int_2PBUS            (w_int_2PBUS                  ),
    //* irq interface (for 3 PEs)
    .o_irq                  (w_irq_bitmap                 ),
    .i_irq_ack              (w_irq_ack                    ),
    .i_irq_id               (w_irq_id                     )
  `ifdef UART_BY_PKT
    ,.o_uartPkt_valid       (w_uartPkt_valid              )
    ,.o_uartPkt             (w_uartPkt                    )
  `endif
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Pkt_Proc_Top
  //====================================================================//
  Pkt_Proc_Top Pkt_Proc_Top(
    //* clk & rst_n;
    .i_clk                  (i_pe_clk                     ),
    .i_rst_n                (i_rst_n                      ),
    //* pkt interface
    .i_pe_conf_mac          (i_pe_conf_mac                ),
    .i_data_valid           (i_data_valid                 ),
    .i_data                 (i_data                       ),
    .o_data_valid           (o_data_valid                 ),
    .o_data                 (o_data                       ),
    //* ready
    .o_alf                  (o_alf                        ),
    .i_alf                  (i_alf                        ),
    //* Peri interface (DMA, DRA), TODO,
    .i_peri_rden            (w_rden_2peri[`DRA:`DMA]      ),
    .i_peri_wren            (w_wren_2peri[`DRA:`DMA]      ),
    .i_peri_addr            (w_addr_2peri                 ),
    .i_peri_wdata           (w_wdata_2peri                ),
    .o_peri_rdata           (w_rdata_2PBUS[`DRA:`DMA]     ),
    .o_peri_ready           (w_ready_2PBUS[`DRA:`DMA]     ),
    .o_peri_int             (w_int_2PBUS[`DRA:`DMA]       ),
    
    //* DRA interface;
    `ifdef DRA_EN
      .i_reg_rd             (w_reg_rd                     ),
      .i_reg_raddr          (w_reg_raddr                  ),
      .o_reg_rdata          (w_reg_rdata                  ),
      .o_reg_rvalid         (w_reg_rvalid                 ),
      .o_reg_rvalid_desp    (w_reg_rvalid_desp            ),
      .i_reg_wr             (w_reg_wr                     ),
      .i_reg_wr_desp        (w_reg_wr_desp                ),
      .i_reg_waddr          (w_reg_waddr                  ),
      .i_reg_wdata          (w_reg_wdata                  ),
      .i_status             (w_status_2pktMem             ),
      .o_status             (w_status_2core               ),
    `endif
    //* DMA interface;
    .o_dma_rden             (w_dma_rden                   ),
    .o_dma_wren             (w_dma_wren                   ),
    .o_dma_addr             (w_dma_addr                   ),
    .o_dma_wdata            (w_dma_wdata                  ),
    .o_dma_winc             (w_dma_winc                   ),
    .o_dma_wstrb            (w_dma_wstrb                  ),
    .i_dma_rdata            (w_dma_rdata                  ),
    .i_dma_rvalid           (w_dma_rvalid                 ),
    .i_dma_gnt              (w_dma_gnt                    ),
    //* configure output, connected with MultiCore;
    .o_conf_rden            (w_conf_rden                  ),
    .o_conf_wren            (w_conf_wren                  ),
    .o_conf_addr            (w_conf_addr                  ),
    .o_conf_wdata           (w_conf_wdata                 ),
    .i_conf_rdata           (w_conf_rdata                 ),
    .o_conf_en              (w_conf_en                    )
  `ifdef UART_BY_PKT
    ,.i_uartPkt_valid       (w_uartPkt_valid              )
    ,.i_uartPkt             (w_uartPkt                    )
  `endif
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   for uart, host can send to fpga anytime;
  //====================================================================//
  assign  o_uart_rts = 'b0;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  // reg                   r_peri_ready;
  // assign w_peri_ready = r_peri_ready;
  // assign w_peri_rdata = 'b0;
  // always_ff @(posedge i_pe_clk) begin
  //   r_peri_ready          <= w_peri_wren | w_peri_rden;
  //     if(r_peri_ready == 1'b0 && w_peri_wren == 1'b1) begin
  //       $write("%c", w_peri_wdata[7:0]);
  //       $fflush();
  //       // $display("%c",mem_wdata[7:0]);
  //     end
  // end
      

endmodule    
