/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        PE_ARRAY.
 *  Description:        This module is used to connect MultiCore_Top with 
 *                       SPI_Config, Pkt_Proc_Top, Peri_Top.
 *  Last updated date:  2022.09.20. (checked)
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2023 NUDT.
 *
 *  Noted:
 *    1) 134b pkt data definition: 
 *      [133:132] head tag, 2'b01 is head, 2'b10 is tail;
 *      [131:128] valid tag, 4'b1111 means sixteen 8b data is valid;
 *      [127:0]   pkt data, invalid part is padded with x;
 *    2) 168b pkt meta definition: 
 *      [167:152] OutportBM, InportBM;
 *      [151:144] PEBM (PE bitmap), means which PE to process this pkt;
 *      [143:128] BufId;
 *      [127:112] [127:122]: reserved;          [121]: mac lookup enable;
 *                [120]    : mac learn disable; [119]: to DMA; 
 *                [118]    : discard tag;       [117]: TTSE 1588-related; 
 *                [116]    : OSTC 1588-related; [115]: to gen TCP checksum;
 *                [114]    : to check checksum; 
 *                [113:112]: pkt type, i.e., 2’b11 is NACP, 2’b10 is PTP,
 *                                           2’b01 is TCP, 2'b00 is default;
 *      [111:96 ] FlowID;
 *      [95 :88 ] Priority;
 *      [87 :80 ] DMID;
 *      [76 :64 ] pkt length;
 *      [63 :0  ] timestamp;
 *    3) irq for cv32e40p: {irq_fast(Peri), 4'b0, irq_external, 3'b0,  
 *                            irq_timer, 3'b0, irq_software, 3'b0};
 *    4) Space = 2;
 *    5) Start one PE by another PE is no longer supported;
 */

  //====================================================================//
  //*   Connection Relationship                                         //
  //*  +-----------+                                +------------+      //
  //*  | PE_Config |--------------------------+     | CMCU_Debug |      //
  //*  +-----------+                          |     +------------+      //
  //*     |    | spi                          | Conf                    //
  //*     |    |   +----------+ <peri   +---------------+               //
  //* pkt |    +---| Peri_Top |---------| MultiCore_top |               //
  //*     |        +----------+ offset> +---------------+               //
  //*  +--------------+                       | DRA/DMA                 //
  //*  | Pkt_Proc_Top |-----------------------+                         //
  //*  +--------------+                                                 //
  //====================================================================//

module PE_ARRAY(
  //======================= clock & resets  ============================//
   input  wire              i_sys_clk
  ,input  wire              i_sys_rst_n
  ,input  wire              i_pe_clk
  ,input  wire              i_rst_n
  ,input  wire              i_spi_clk
  //======================= pkt from/to CPI ============================//
  //* pkt[133:132]: 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
  ,input  wire [      47:0] i_pe_conf_mac
  ,input  wire              i_data_valid
  ,input  wire [     133:0] i_data    
  ,input  wire              i_meta_valid
  ,input  wire [     167:0] i_meta  
  ,output wire              o_alf 
  //* pkt to CPI, TODO,
  ,output wire              o_data_valid
  ,output wire [     133:0] o_data
  ,output wire              o_meta_valid
  ,output wire [     167:0] o_meta
  ,input  wire              i_alf
  //======================= Conf from/to CMCU ==========================//
  `ifdef CMCU
    //* configure by localbus (cmcu);
    ,input  wire            i_cs_conf       //* active low
    ,input  wire            i_wr_rd_conf    //* 0:read 1:write
    ,input  wire [    19:0] i_address_conf
    ,input  wire [    31:0] i_data_in_conf
    ,output wire            o_ack_n_conf
    ,output wire [    31:0] o_data_out_conf
    //* debug by localbus (cmcu);
    ,input  wire            i_cs_debug      //* active low
    ,input  wire            i_wr_rd_debug   //* 0:read 1:write
    ,input  wire [    19:0] i_address_debug
    ,input  wire [    31:0] i_data_in_debug
    ,output wire            o_ack_n_debug
    ,output wire [    31:0] o_data_out_debug
  `endif
  //======================= uart            ============================//
  ,input  wire              i_uart_rx
  ,output wire              o_uart_tx
  ,input  wire              i_uart_cts
  ,output wire              o_uart_rts
  //======================= SPI             ============================//
  `ifdef SPI_EN
    ,output wire            o_spi_clk 
    ,output wire            o_spi_csn 
    ,output wire            o_spi_mosi
    ,input  wire            i_spi_miso
    //* command;
    ,input  wire            i_command_wr 
    ,input  wire  [   63:0] i_command    
    ,output wire            o_command_alf
    ,output wire            o_command_wr 
    ,output wire  [   63:0] o_command    
    ,input  wire            i_command_alf
    //* debug signals
    ,output wire            o_finish_inilization
    ,output wire            o_error_inilization
  `endif
  //======================= GPIO            ============================//
  `ifdef GPIO_EN
    ,input  wire  [   15:0] i_gpio
    ,output wire  [   15:0] o_gpio
    ,output wire  [   15:0] o_gpio_en       //* '1' is output;
  `endif
  //======================= system_time     ============================//
  ,output   wire  [   63:0] o_system_time
  //======================= Pads            ============================//
  ,output   wire            o_second_pulse  
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* 1-1) Configure info: PE_Config <---> PE's instr/data ram;
  wire                      w_conf_rden, w_conf_wren;
  wire  [           31:0]   w_conf_addr, w_conf_wdata;
  wire  [           31:0]   w_conf_rdata;
  wire  [            3:0]   w_conf_en;  //* bitmap for 4 PEs;
  //* 1-2) Configure info: PE_Config <---> SPI_PERI (Flash);
  `ifdef SPI_EN
    wire                    w_conf_wren_spi;
    wire  [         31:0]   w_conf_addr_spi;
    wire  [         31:0]   w_conf_wdata_spi;
    wire  [          3:0]   w_conf_en_spi;            //* bitmap for 4 PEs;
  `endif
  //* 1-3) Configure info: Pkt_Proc_Top <---> PE_Config (bypass CMCU)
  wire                      w_data_conf_valid_from_net;
  wire  [           133:0]  w_data_conf_from_net      ;
  wire                      w_data_conf_valid_to_net  ;
  wire  [           133:0]  w_data_conf_to_net        ;

  //* 2) left fo reset: CSR_Peri ---> AiPE;
  
  //* 3-1) Peripherals-related: 4 PEs <---> Peripherals Bus (PeriBus);
  //* NUM_PE_T is the total count of PEs, e.g., 4 PEs or 3 PEs + 1 AiPE;
  wire  [   `NUM_PE_T-1:0]  w_peri_rden, w_peri_wren;
  wire  [`NUM_PE_T*32-1:0]  w_peri_addr, w_peri_wdata;
  wire  [ `NUM_PE_T*4-1:0]  w_peri_wstrb;
  wire  [`NUM_PE_T*32-1:0]  w_peri_rdata;
  wire  [   `NUM_PE_T-1:0]  w_peri_ready;
  wire  [   `NUM_PE_T-1:0]  w_peri_gnt;
  //* 3-2) Peripherals-related: PeriBus <---> DMA, DRA, dDMA;
  //* NUM_PERI_OUT is peris outside of Peri_Top, i.e., DMA, DRA, dDMA;
  wire  [              `NUM_PE*32-1:0]  w_addr_2peri;
  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  w_wren_2peri;
  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  w_rden_2peri;
  wire  [              `NUM_PE*32-1:0]  w_wdata_2peri;
  wire  [               `NUM_PE*4-1:0]  w_wstrb_2peri;
  wire  [`NUM_PE*`NUM_PERI_OUT*32-1:0]  w_rdata_2PBUS;
  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  w_ready_2PBUS;
  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  w_int_2PBUS;
  //* 3-3) Peripherals-related: {DRA, DMA} <---> Peri_Top;
  wire  [   `NUM_PE*2-1:0]  w_wren_2peri_pktProc ;
  wire  [   `NUM_PE*2-1:0]  w_rden_2peri_pktProc ;
  wire  [`NUM_PE*2*32-1:0]  w_rdata_2PBUS_pktProc;
  wire  [   `NUM_PE*2-1:0]  w_ready_2PBUS_pktProc;
  wire  [   `NUM_PE*2-1:0]  w_int_2PBUS_pktProc  ;
  //* 3-4) left for customized logic of dDMA

  genvar i_pe;
  generate 
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe + 1) begin: peri_connect
      //* to write {DRA, DMA} = wren_2peri;
      assign {w_wren_2peri_pktProc[i_pe*2+:2]} = 
                    w_wren_2peri[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT];
      //* to read {DRA, DMA} = wren_2peri;
      assign {w_rden_2peri_pktProc[i_pe*2+:2]} = 
                    w_rden_2peri[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT];
      //* to get data from {DRA, DMA};
      assign w_rdata_2PBUS[i_pe*`NUM_PERI_OUT*32+:`NUM_PERI_OUT*32] = 
                    {w_rdata_2PBUS_pktProc[i_pe*64+:64]};
      //* to get ready from {DRA, DMA};
      assign w_ready_2PBUS[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT]       = 
                    {w_ready_2PBUS_pktProc[i_pe*2+:2]};
      //* to get int from {DRA, DMA};
      assign w_int_2PBUS[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT]         = 
                    {w_int_2PBUS_pktProc[i_pe*2+:2]};
    end
  endgenerate

  //* 4) Irq-related: 1/2/3/4 PEs <---> irq Bus (IrqBus);
  wire  [  `NUM_PE*32-1:0]  w_irq_bitmap;
  wire  [     `NUM_PE-1:0]  w_irq_ack;
  wire  [   `NUM_PE*5-1:0]  w_irq_id;

  //* 5) Special registers from/to CSR_Peri;
  //* start addresses of Instr/Data for 3 PEs;
  wire  [  `NUM_PE*32-1:0]  w_instr_offset_addr;
  wire  [  `NUM_PE*32-1:0]  w_data_offset_addr;
  //* to update system time by CMCU; 
  wire  [            64:0]  w_update_system_time; //* in format of {0_minus/add, ns_32b};
  wire                      w_update_valid;

  //* 6) DRA-related: PE's regs <---> DRA_Engine;
  wire  [     `NUM_PE-1:0]  w_reg_rd;           //* to read data from DRA engine;
  wire  [  `NUM_PE*32-1:0]  w_reg_raddr;        //* addr to read (from PE);
  wire  [           511:0]  w_reg_rdata;        //* return read data from DRA engine;
  wire  [     `NUM_PE-1:0]  w_reg_rvalid;       //* return recv data from DRA engine;
  wire  [     `NUM_PE-1:0]  w_reg_rvalid_desp;  //* return recv desp from DRA engine;
  wire  [     `NUM_PE-1:0]  w_reg_wr, w_reg_wr_desp;
  wire  [  `NUM_PE*32-1:0]  w_reg_waddr;        //* addr to write (from PE);
  wire  [ `NUM_PE*512-1:0]  w_reg_wdata;        //* wdata from PE;
  wire  [  `NUM_PE*32-1:0]  w_status_2core, w_status_2pktMem;

  //* 7) DMA-related: PE's data ram <---> DMA_Engine;
  wire  [     `NUM_PE-1:0]  w_dma_rden;         //* to read/write data SRAM;
  wire  [     `NUM_PE-1:0]  w_dma_wren;
  wire  [  `NUM_PE*32-1:0]  w_dma_addr;
  wire  [  `NUM_PE*32-1:0]  w_dma_wdata;
  wire  [  `NUM_PE*32-1:0]  w_dma_rdata;        //* return read result from data SRAM;
  wire  [     `NUM_PE-1:0]  w_dma_rvalid;
  wire  [     `NUM_PE-1:0]  w_dma_gnt;          //* allow to read/write next data;

  //=====================//
  //* 8) debugs signals;
  //=====================//
    //* dDMA;
    wire                      d_dDMA_tag_start_dDMA_1b;
    wire                      d_dDMA_tag_resp_dDMA_1b ;
    wire  [            31:0]  d_dDMA_addr_RAM_32b     ;
    wire  [            15:0]  d_dDMA_len_RAM_16b      ;
    wire  [            31:0]  d_dDMA_addr_RAM_AIPE_32b;
    wire  [            15:0]  d_dDMA_len_RAM_AIPE_16b ;
    wire                      d_dDMA_dir_1b           ;
    wire  [             3:0]  d_dDMA_cnt_pe0_rd_4b    ;
    wire  [             3:0]  d_dDMA_cnt_pe0_wr_4b    ;
    wire  [             3:0]  d_dDMA_cnt_pe1_rd_4b    ;
    wire  [             3:0]  d_dDMA_cnt_pe1_wr_4b    ;
    wire  [             3:0]  d_dDMA_cnt_pe2_rd_4b    ;
    wire  [             3:0]  d_dDMA_cnt_pe2_wr_4b    ;
    wire  [             3:0]  d_dDMA_state_dDMA_4b    ;
    wire  [             3:0]  d_dDMA_cnt_int_4b       ;
    //* csr;
    wire  [             3:0]  d_csr_cnt_pe0_wr_4b     ;
    wire  [             3:0]  d_csr_cnt_pe1_wr_4b     ;
    wire  [             3:0]  d_csr_cnt_pe2_wr_4b     ;
    wire  [             3:0]  d_csr_cnt_pe0_rd_4b     ;
    wire  [             3:0]  d_csr_cnt_pe1_rd_4b     ;
    wire  [             3:0]  d_csr_cnt_pe2_rd_4b     ;
    wire  [            31:0]  d_csr_pe0_instr_offsetAddr_32b ;
    wire  [            31:0]  d_csr_pe1_instr_offsetAddr_32b ;
    wire  [            31:0]  d_csr_pe2_instr_offsetAddr_32b ;
    wire  [            31:0]  d_csr_pe0_data_offsetAddr_32b  ;
    wire  [            31:0]  d_csr_pe1_data_offsetAddr_32b  ;
    wire  [            31:0]  d_csr_pe2_data_offsetAddr_32b  ;
    wire  [             2:0]  d_csr_guard_3b          ;       
    wire  [             3:0]  d_csr_cnt_pe0_int_4b    ;       
    wire  [             3:0]  d_csr_cnt_pe1_int_4b    ; 
    wire  [             3:0]  d_csr_cnt_pe2_int_4b    ;
    wire  [             3:0]  d_csr_start_en_4b       ;      
    //* gpio;
    wire                      d_gpio_en_1b            ;
    wire  [            15:0]  d_gpio_data_ctrl_16b    ;
    wire  [            15:0]  d_gpio_bm_int_16b       ;
    wire  [            15:0]  d_gpio_bm_clear_16b     ;
    wire  [            15:0]  d_gpio_pos_neg_16b      ;
    wire  [            15:0]  d_gpio_dir_16b          ;
    wire  [            15:0]  d_gpio_recvData_16b     ;
    wire  [            15:0]  d_gpio_sendData_16b     ;
    wire  [             3:0]  d_gpio_cnt_pe0_wr_4b    ;
    wire  [             3:0]  d_gpio_cnt_pe1_wr_4b    ;
    wire  [             3:0]  d_gpio_cnt_pe2_wr_4b    ;
    wire  [             3:0]  d_gpio_cnt_pe0_rd_4b    ;
    wire  [             3:0]  d_gpio_cnt_pe1_rd_4b    ;
    wire  [             3:0]  d_gpio_cnt_pe2_rd_4b    ;
    wire  [             3:0]  d_gpio_cnt_int_4b       ;
    //* csram;
    wire  [             3:0]  d_csram_cnt_pe0_wr_4b   ;
    wire  [             3:0]  d_csram_cnt_pe1_wr_4b   ;
    wire  [             3:0]  d_csram_cnt_pe2_wr_4b   ;
    wire  [             3:0]  d_csram_cnt_pe0_rd_4b   ;
    wire  [             3:0]  d_csram_cnt_pe1_rd_4b   ;
    wire  [             3:0]  d_csram_cnt_pe2_rd_4b   ;
    //* spi;
    wire  [             3:0]  d_spi_state_read_4b;
    wire  [             3:0]  d_spi_state_spi_4b ;
    wire  [             3:0]  d_spi_state_resp_4b;
    wire  [             3:0]  d_spi_cnt_pe0_rd_4b;
    wire  [             3:0]  d_spi_cnt_pe1_rd_4b;
    wire  [             3:0]  d_spi_cnt_pe2_rd_4b;
    wire  [             3:0]  d_spi_cnt_pe0_wr_4b;
    wire  [             3:0]  d_spi_cnt_pe1_wr_4b;
    wire  [             3:0]  d_spi_cnt_pe2_wr_4b;
    wire  [             0:0]  d_spi_empty_spi_1b ;
    wire  [             6:0]  d_spi_usedw_spi_7b ;
    //* uart;
    wire  [            26:0]  d_uart_usedw_rx_27b;
    wire  [            35:0]  d_uart_usedw_tx_36b;
    wire  [            11:0]  d_uart_cnt_rd_12b;
    wire  [            11:0]  d_uart_cnt_wr_12b;
    //* ready & int (Peri/irq);
    wire  [             3:0]  d_periTop_peri_ready_4b ;
    wire  [             8:0]  d_periTop_pe0_int_9b    ;
    wire  [             8:0]  d_periTop_pe1_int_9b    ;
    wire  [             8:0]  d_periTop_pe2_int_9b    ;

    //* pkt_distribute
    wire  [             3:0]  d_AsynRev_inc_pkt_4b    ;
    wire  [             3:0]  d_PktMUX_state_mux_4b   ;
    wire                      d_PktMUX_inc_dra_pkt_1b ;
    wire                      d_PktMUX_inc_dma_pkt_1b ;
    wire                      d_PktMUX_inc_conf_pkt_1b;
    wire  [             6:0]  d_PktMUX_usedw_pktDMA_7b;
    wire  [             6:0]  d_PktMUX_usedw_pktDRA_7b;
    wire  [             6:0]  d_PktMUX_usedw_conf_7b  ;
    //* dma;
    wire  [             2:0]  d_dmaDist_inc_pkt_3b    ;
    wire                      d_dmaDist_state_dist_1b ;
    wire  [             3:0]  d_dmaOut_state_out_4b   ;
    wire  [             2:0]  d_dma_alf_dma_3b        ;
    wire  [             2:0]  d_dma_empty_dmaWR_3b    ;
    wire  [            29:0]  d_dma_usedw_dmaWR_30b   ;
    wire  [             2:0]  d_dma_empty_pBufWR_3b   ;
    wire  [             2:0]  d_dma_empty_pBufRD_3b   ;
    wire  [            29:0]  d_dma_usedw_pBufRD_30b  ;
    wire  [             2:0]  d_dma_empty_int_3b      ;
    wire  [             2:0]  d_dma_empty_length_3b   ;
    wire  [             2:0]  d_dma_empty_low16b_3b   ;
    wire  [             2:0]  d_dma_empty_high16b_3b  ;
    //* dra;
    wire                      d_dra_empty_pktRecv_1b ;
    wire  [             2:0]  d_dra_empty_despRecv_3b;
    wire  [             2:0]  d_dra_empty_despSend_3b;
    wire  [             2:0]  d_dra_empty_writeReq_3b;
    wire  [             9:0]  d_dra_usedw_pktRecv_10b;

    //* multicore
    wire  [            31:0]  d_pc_0, d_pc_1, d_pc_2;
    wire  [            31:0]  d_pe0_reg_value_32b;
    wire  [            31:0]  d_pe1_reg_value_32b;
    wire  [            31:0]  d_pe2_reg_value_32b;
    wire  [             5:0]  d_pe0_reg_id_6b;
    wire  [             5:0]  d_pe1_reg_id_6b;
    wire  [             5:0]  d_pe2_reg_id_6b;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

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
    .i_peri_gnt             ({`NUM_PE_T{1'b1}}            ), 
    //* irq;
    .i_irq_bitmap           (w_irq_bitmap                 ),
    .o_irq_ack              (w_irq_ack                    ),
    .o_irq_id               (w_irq_id                     ),
    //* DRA, connected with Pkt_Proc;
    `ifdef DRA_EN
      .o_reg_rd               (w_reg_rd                     ),
      .o_reg_raddr            (w_reg_raddr                  ),
      .i_reg_rdata            (w_reg_rdata                  ),
      .i_reg_rvalid           (w_reg_rvalid                 ),
      .i_reg_rvalid_desp      (w_reg_rvalid_desp            ),
      .o_reg_wr               (w_reg_wr                     ),
      .o_reg_wr_desp          (w_reg_wr_desp                ),
      .o_reg_waddr            (w_reg_waddr                  ),
      .o_reg_wdata            (w_reg_wdata                  ),
      .i_status               (w_status_2core               ),
      .o_status               (w_status_2pktMem             ),
    `else
      .o_reg_rd               (                             ),
      .o_reg_raddr            (                             ),
      .i_reg_rdata            ('b0                          ),
      .i_reg_rvalid           ('b0                          ),
      .i_reg_rvalid_desp      ('b0                          ),
      .o_reg_wr               (                             ),
      .o_reg_wr_desp          (                             ),
      .o_reg_waddr            (                             ),
      .o_reg_wdata            (                             ),
      .i_status               ('b0                          ),
      .o_status               (                             ),
    `endif
    //* DMA;
    .i_dma_rden             (w_dma_rden                   ),
    .i_dma_wren             (w_dma_wren                   ),
    .i_dma_addr             (w_dma_addr                   ),
    .i_dma_wdata            (w_dma_wdata                  ),
    .o_dma_rdata            (w_dma_rdata                  ),
    .o_dma_rvalid           (w_dma_rvalid                 ),
    .o_dma_gnt              (w_dma_gnt                    ),
    //* debug;
    .d_pc_0                 (d_pc_0                       ),
    .d_pc_1                 (d_pc_1                       ),
    .d_pc_2                 (d_pc_2                       ),
    .d_i_reg_id_18b         ({d_pe2_reg_id_6b,
                              d_pe1_reg_id_6b,   d_pe0_reg_id_6b}),
    .d_reg_value_96b        ({d_pe2_reg_value_32b, 
                              d_pe1_reg_value_32b, d_pe0_reg_value_32b})
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   SPI_Config & Network_Config
  //====================================================================//
    PE_Config PE_Config(
      .i_clk                (i_pe_clk                     ),
      .i_rst_n              (i_rst_n                      ),
      `ifdef CMCU
        //* configure input, connected with LOCAL_PARSER (cmcu);
        .i_cs                 (i_cs_conf                    ),
        .i_wr_rd              (i_wr_rd_conf                 ),
        .i_address            (i_address_conf               ),
        .i_data_in            (i_data_in_conf               ),
        .o_ack_n              (o_ack_n_conf                 ),
        .o_data_out           (o_data_out_conf              ),
      `else
        //* configure input, connected with LOCAL_PARSER (cmcu);
        .i_cs                 (1'b1                         ),
        .i_wr_rd              (1'b0                         ),
        .i_address            ('b0                          ),
        .i_data_in            ('b0                          ),
        .o_ack_n              (                             ),
        .o_data_out           (                             ),
      `endif
        //* ethernet's type is 0x9005;
        .i_data_conf_valid    (w_data_conf_valid_from_net   ),
        .i_data_conf          (w_data_conf_from_net         ),
        .o_data_conf_valid    (w_data_conf_valid_to_net     ),
        .o_data_conf          (w_data_conf_to_net           ),
      `ifdef SPI_EN
        //* configure by flash (spi);
        .i_conf_wren_spi      (w_conf_wren_spi              ),
        .i_conf_addr_spi      (w_conf_addr_spi              ),
        .i_conf_wdata_spi     (w_conf_wdata_spi             ),
        .i_conf_en_spi        (w_conf_en_spi                ),
        .i_finish_inilization (o_finish_inilization         ),
      `else
        //* configure by flash (spi);
        .i_conf_wren_spi      (1'b0                         ),
        .i_conf_addr_spi      (32'b0                        ),
        .i_conf_wdata_spi     (32'b0                        ),
        .i_conf_en_spi        (4'hf                         ),
        .i_finish_inilization (1'b1                         ),
      `endif
      //* configure output, connected with MultiCore;
      .o_conf_rden          (w_conf_rden                  ),
      .o_conf_wren          (w_conf_wren                  ),
      .o_conf_addr          (w_conf_addr                  ),
      .o_conf_wdata         (w_conf_wdata                 ),
      .i_conf_rdata         (w_conf_rdata                 ),
      .o_conf_en            (w_conf_en                    ),
      //* to update system_time by localbus;
      .o_update_valid       (w_update_valid               ),
      .o_update_system_time (w_update_system_time         )
    );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Debug
  //====================================================================//
  `ifdef CMCU
    CMCU_Debug CMCU_Debug(
      .i_clk                          (i_pe_clk                       ),
      .i_rst_n                        (i_rst_n                        ),
      //* configure input, connected with LOCAL_PARSER;
      .i_cs                           (i_cs_debug                     ),
      .i_wr_rd                        (i_wr_rd_debug                  ),
      .i_address                      (i_address_debug                ),
      .i_data_in                      (i_data_in_debug                ),
      .o_ack_n                        (o_ack_n_debug                  ),
      .o_data_out                     (o_data_out_debug               ),
      //* debug signals;
      //============== Peri              =============================//
      //* dDMA;
      .d_dDMA_tag_start_dDMA_1b       (d_dDMA_tag_start_dDMA_1b       ),
      .d_dDMA_tag_resp_dDMA_1b        (d_dDMA_tag_resp_dDMA_1b        ),
      .d_dDMA_addr_RAM_32b            (d_dDMA_addr_RAM_32b            ),    
      .d_dDMA_len_RAM_16b             (d_dDMA_len_RAM_16b             ),     
      .d_dDMA_addr_RAM_AIPE_32b       (d_dDMA_addr_RAM_AIPE_32b       ),
      .d_dDMA_len_RAM_AIPE_16b        (d_dDMA_len_RAM_AIPE_16b        ),
      .d_dDMA_dir_1b                  (d_dDMA_dir_1b                  ),
      .d_dDMA_cnt_pe0_rd_4b           (d_dDMA_cnt_pe0_rd_4b           ),
      .d_dDMA_cnt_pe0_wr_4b           (d_dDMA_cnt_pe0_wr_4b           ),
      .d_dDMA_cnt_pe1_rd_4b           (d_dDMA_cnt_pe1_rd_4b           ),
      .d_dDMA_cnt_pe1_wr_4b           (d_dDMA_cnt_pe1_wr_4b           ),
      .d_dDMA_cnt_pe2_rd_4b           (d_dDMA_cnt_pe2_rd_4b           ),
      .d_dDMA_cnt_pe2_wr_4b           (d_dDMA_cnt_pe2_wr_4b           ),
      .d_dDMA_state_dDMA_4b           (d_dDMA_state_dDMA_4b           ),
      .d_dDMA_cnt_int_4b              (d_dDMA_cnt_int_4b              ),
      //* csr;
      .d_csr_cnt_pe0_wr_4b            (d_csr_cnt_pe0_wr_4b            ),
      .d_csr_cnt_pe1_wr_4b            (d_csr_cnt_pe1_wr_4b            ),
      .d_csr_cnt_pe2_wr_4b            (d_csr_cnt_pe2_wr_4b            ),
      .d_csr_cnt_pe0_rd_4b            (d_csr_cnt_pe0_rd_4b            ),
      .d_csr_cnt_pe1_rd_4b            (d_csr_cnt_pe1_rd_4b            ),
      .d_csr_cnt_pe2_rd_4b            (d_csr_cnt_pe2_rd_4b            ),
      .d_csr_pe0_instr_offsetAddr_32b (d_csr_pe0_instr_offsetAddr_32b ),
      .d_csr_pe1_instr_offsetAddr_32b (d_csr_pe1_instr_offsetAddr_32b ),
      .d_csr_pe2_instr_offsetAddr_32b (d_csr_pe2_instr_offsetAddr_32b ),
      .d_csr_pe0_data_offsetAddr_32b  (d_csr_pe0_data_offsetAddr_32b  ),
      .d_csr_pe1_data_offsetAddr_32b  (d_csr_pe1_data_offsetAddr_32b  ),
      .d_csr_pe2_data_offsetAddr_32b  (d_csr_pe2_data_offsetAddr_32b  ),
      .d_csr_guard_3b                 (d_csr_guard_3b                 ),
      .d_csr_cnt_pe0_int_4b           (d_csr_cnt_pe0_int_4b           ),
      .d_csr_cnt_pe1_int_4b           (d_csr_cnt_pe1_int_4b           ),
      .d_csr_cnt_pe2_int_4b           (d_csr_cnt_pe2_int_4b           ),
      .d_csr_start_en_4b              (d_csr_start_en_4b              ),
      //* gpio;
      .d_gpio_en_1b                   (d_gpio_en_1b                   ),
      .d_gpio_data_ctrl_16b           (d_gpio_data_ctrl_16b           ),
      .d_gpio_bm_int_16b              (d_gpio_bm_int_16b              ),
      .d_gpio_bm_clear_16b            (d_gpio_bm_clear_16b            ),
      .d_gpio_pos_neg_16b             (d_gpio_pos_neg_16b             ),
      .d_gpio_dir_16b                 (d_gpio_dir_16b                 ),
      .d_gpio_recvData_16b            (d_gpio_recvData_16b            ),
      .d_gpio_sendData_16b            (d_gpio_sendData_16b            ),
      .d_gpio_cnt_pe0_wr_4b           (d_gpio_cnt_pe0_wr_4b           ),
      .d_gpio_cnt_pe1_wr_4b           (d_gpio_cnt_pe1_wr_4b           ),
      .d_gpio_cnt_pe2_wr_4b           (d_gpio_cnt_pe2_wr_4b           ),
      .d_gpio_cnt_pe0_rd_4b           (d_gpio_cnt_pe0_rd_4b           ),
      .d_gpio_cnt_pe1_rd_4b           (d_gpio_cnt_pe1_rd_4b           ),
      .d_gpio_cnt_pe2_rd_4b           (d_gpio_cnt_pe2_rd_4b           ),
      .d_gpio_cnt_int_4b              (d_gpio_cnt_int_4b              ),
      //* csram;
      .d_csram_cnt_pe0_wr_4b          (d_csram_cnt_pe0_wr_4b          ),
      .d_csram_cnt_pe1_wr_4b          (d_csram_cnt_pe1_wr_4b          ),
      .d_csram_cnt_pe2_wr_4b          (d_csram_cnt_pe2_wr_4b          ),
      .d_csram_cnt_pe0_rd_4b          (d_csram_cnt_pe0_rd_4b          ),
      .d_csram_cnt_pe1_rd_4b          (d_csram_cnt_pe1_rd_4b          ),
      .d_csram_cnt_pe2_rd_4b          (d_csram_cnt_pe2_rd_4b          ),
      //* spi;
      .d_spi_state_read_4b            (d_spi_state_read_4b            ),
      .d_spi_state_spi_4b             (d_spi_state_spi_4b             ),              
      .d_spi_state_resp_4b            (d_spi_state_resp_4b            ),
      .d_spi_cnt_pe0_rd_4b            (d_spi_cnt_pe0_rd_4b            ),
      .d_spi_cnt_pe1_rd_4b            (d_spi_cnt_pe1_rd_4b            ),
      .d_spi_cnt_pe2_rd_4b            (d_spi_cnt_pe2_rd_4b            ),
      .d_spi_cnt_pe0_wr_4b            (d_spi_cnt_pe0_wr_4b            ),
      .d_spi_cnt_pe1_wr_4b            (d_spi_cnt_pe1_wr_4b            ),
      .d_spi_cnt_pe2_wr_4b            (d_spi_cnt_pe2_wr_4b            ),
      .d_spi_empty_spi_1b             (d_spi_empty_spi_1b             ),              
      .d_spi_usedw_spi_7b             (d_spi_usedw_spi_7b             ),
      //* uart;
      .d_uart_usedw_rx_27b            ('b0                            ),
      .d_uart_usedw_tx_36b            ('b0                            ),
      .d_uart_cnt_rd_12b              ('b0                            ),
      .d_uart_cnt_wr_12b              ('b0                            ),
      //* ready * irq;
      .d_periTop_peri_ready_4b        (d_periTop_peri_ready_4b        ),
      .d_periTop_pe0_int_9b           (d_periTop_pe0_int_9b           ),
      .d_periTop_pe1_int_9b           (d_periTop_pe1_int_9b           ),
      .d_periTop_pe2_int_9b           (d_periTop_pe2_int_9b           ),
      //============== Pkt_Proc          =============================//
      //* Pkt_Distribute;
      .d_AsynRev_inc_pkt_4b           (d_AsynRev_inc_pkt_4b           ),
      .d_PktMUX_state_mux_4b          (d_PktMUX_state_mux_4b          ),
      .d_PktMUX_inc_dra_pkt_1b        (d_PktMUX_inc_dra_pkt_1b        ),
      .d_PktMUX_inc_dma_pkt_1b        (d_PktMUX_inc_dma_pkt_1b        ),
      .d_PktMUX_inc_conf_pkt_1b       (d_PktMUX_inc_conf_pkt_1b       ),
      .d_PktMUX_usedw_pktDMA_7b       (d_PktMUX_usedw_pktDMA_7b       ),
      .d_PktMUX_usedw_pktDRA_7b       (d_PktMUX_usedw_pktDRA_7b       ),
      .d_PktMUX_usedw_conf_7b         (d_PktMUX_usedw_conf_7b         ),
      //* debug_dma
      .d_dmaDist_inc_pkt_3b           (d_dmaDist_inc_pkt_3b           ),
      .d_dmaDist_state_dist_1b        (d_dmaDist_state_dist_1b        ),
      .d_dmaOut_state_out_4b          (d_dmaOut_state_out_4b          ),
      .d_dma_alf_dma_3b               (d_dma_alf_dma_3b               ),
      .d_dma_empty_dmaWR_3b           (d_dma_empty_dmaWR_3b           ),
      .d_dma_usedw_dmaWR_30b          (d_dma_usedw_dmaWR_30b          ),
      .d_dma_empty_pBufWR_3b          (d_dma_empty_pBufWR_3b          ),
      .d_dma_empty_pBufRD_3b          (d_dma_empty_pBufRD_3b          ),
      .d_dma_usedw_pBufRD_30b         (d_dma_usedw_pBufRD_30b         ),
      .d_dma_empty_int_3b             (d_dma_empty_int_3b             ),
      .d_dma_empty_length_3b          (d_dma_empty_length_3b          ),
      .d_dma_empty_low16b_3b          (d_dma_empty_low16b_3b          ),
      .d_dma_empty_high16b_3b         (d_dma_empty_high16b_3b         ),
      //* debug_dra
      .d_dra_empty_pktRecv_1b         (d_dra_empty_pktRecv_1b         ),
      .d_dra_empty_despRecv_3b        (d_dra_empty_despRecv_3b        ),
      .d_dra_empty_despSend_3b        (d_dra_empty_despSend_3b        ),
      .d_dra_empty_writeReq_3b        (d_dra_empty_writeReq_3b        ),
      .d_dra_usedw_pktRecv_10b        (d_dra_usedw_pktRecv_10b        ),
      //* multi_core
      .d_pc_0                         (d_pc_0                         ),
      .d_pc_1                         (d_pc_1                         ),
      .d_pc_2                         (d_pc_2                         ),
      .d_o_pe2_reg_id_6b              (d_pe2_reg_id_6b                ),
      .d_o_pe1_reg_id_6b              (d_pe1_reg_id_6b                ),
      .d_o_pe0_reg_id_6b              (d_pe0_reg_id_6b                ),
      .d_pe2_reg_value_32b            (d_pe2_reg_value_32b            ),
      .d_pe1_reg_value_32b            (d_pe1_reg_value_32b            ),
      .d_pe0_reg_value_32b            (d_pe0_reg_value_32b            )
    );
  `else
    assign  d_pe0_reg_id_6b   = 6'b0;
    assign  d_pe1_reg_id_6b   = 6'b0;
    assign  d_pe2_reg_id_6b   = 6'b0;
  `endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Peri_Top  
  //====================================================================//
  //* peri/irq bus, include UARTs, SPI, GPIO, CSR, CSRAM, DMA, dDMA;
  Peri_Top Peri_Top(
    //* clk & rst_n;
    .i_pe_clk               (i_pe_clk                     ),
    .i_rst_n                (i_rst_n                      ),
    .i_spi_clk              (i_spi_clk                    ),
    .i_sys_clk              (i_sys_clk                    ),
    .i_sys_rst_n            (i_sys_rst_n                  ),
    //* UART
    .o_uart_tx              (o_uart_tx                    ),
    .i_uart_rx              (i_uart_rx                    ),
    .i_uart_cts             (i_uart_cts                   ),
    //* GPIO
    `ifdef GPIO_EN
      .i_gpio               (i_gpio                       ),
      .o_gpio               (o_gpio                       ),
      .o_gpio_en            (o_gpio_en                    ),
    `endif
    //* SPI
    `ifdef SPI_EN
      .o_spi_clk            (o_spi_clk                    ), 
      .o_spi_csn            (o_spi_csn                    ), 
      .o_spi_mosi           (o_spi_mosi                   ), 
      .i_spi_miso           (i_spi_miso                   ), 
      //* inilization by flash (spi);
      .o_conf_wren_spi      (w_conf_wren_spi              ),
      .o_conf_addr_spi      (w_conf_addr_spi              ),
      .o_conf_wdata_spi     (w_conf_wdata_spi             ),
      .o_conf_en_spi        (w_conf_en_spi                ),
      .o_finish_inilization (o_finish_inilization         ),
      .o_error_inilization  (o_error_inilization          ),
    `endif
    `ifdef CMCU
      //* command;
      .i_command_wr         (i_command_wr                 ),
      .i_command            (i_command                    ),
      .o_command_alf        (o_command_alf                ),
      .o_command_wr         (o_command_wr                 ),
      .o_command            (o_command                    ),
      .i_command_alf        (i_command_alf                ),
    `endif
    //* dDMA, DMA, DRA, connected with MultiCore & Pkt_Proc;
    .o_addr_2peri           (w_addr_2peri                 ),
    .o_wren_2peri           (w_wren_2peri                 ),
    .o_rden_2peri           (w_rden_2peri                 ),
    .o_wdata_2peri          (w_wdata_2peri                ),
    .o_wstrb_2peri          (w_wstrb_2peri                ),
    .i_rdata_2PBUS          (w_rdata_2PBUS                ),
    .i_ready_2PBUS          (w_ready_2PBUS                ),
    .i_int_2PBUS            (w_int_2PBUS                  ),
    //* Peri interface (for 4 PEs), connected with MultiCore;
    .i_peri_rden            (w_peri_rden                  ),
    .i_peri_wren            (w_peri_wren                  ),
    .i_peri_addr            (w_peri_addr                  ),
    .i_peri_wdata           (w_peri_wdata                 ),
    .i_peri_wstrb           (w_peri_wstrb                 ),
    .o_peri_rdata           (w_peri_rdata                 ),
    .o_peri_ready           (w_peri_ready                 ),
    //* irq interface (for 3 PEs)
    .o_irq                  (w_irq_bitmap                 ),
    .i_irq_ack              (w_irq_ack                    ),
    .i_irq_id               (w_irq_id                     ),
    //* system_time;
    .i_update_valid         (w_update_valid               ),
    .i_update_system_time   (w_update_system_time         ),
    .o_system_time          (o_system_time                ),
    .o_second_pulse         (o_second_pulse               ),
    //* debugs;
      //* csr;
      .d_csr_cnt_pe0_wr_4b            (d_csr_cnt_pe0_wr_4b            ),
      .d_csr_cnt_pe1_wr_4b            (d_csr_cnt_pe1_wr_4b            ),
      .d_csr_cnt_pe2_wr_4b            (d_csr_cnt_pe2_wr_4b            ),
      .d_csr_cnt_pe0_rd_4b            (d_csr_cnt_pe0_rd_4b            ),
      .d_csr_cnt_pe1_rd_4b            (d_csr_cnt_pe1_rd_4b            ),
      .d_csr_cnt_pe2_rd_4b            (d_csr_cnt_pe2_rd_4b            ),
      .d_csr_pe0_instr_offsetAddr_32b (d_csr_pe0_instr_offsetAddr_32b ),
      .d_csr_pe1_instr_offsetAddr_32b (d_csr_pe1_instr_offsetAddr_32b ),
      .d_csr_pe2_instr_offsetAddr_32b (d_csr_pe2_instr_offsetAddr_32b ),
      .d_csr_pe0_data_offsetAddr_32b  (d_csr_pe0_data_offsetAddr_32b  ),
      .d_csr_pe1_data_offsetAddr_32b  (d_csr_pe1_data_offsetAddr_32b  ),
      .d_csr_pe2_data_offsetAddr_32b  (d_csr_pe2_data_offsetAddr_32b  ),
      .d_csr_guard_3b                 (d_csr_guard_3b                 ),
      .d_csr_cnt_pe0_int_4b           (d_csr_cnt_pe0_int_4b           ),
      .d_csr_cnt_pe1_int_4b           (d_csr_cnt_pe1_int_4b           ),
      .d_csr_cnt_pe2_int_4b           (d_csr_cnt_pe2_int_4b           ),
      .d_csr_start_en_4b              (d_csr_start_en_4b              ),
      //* gpio
      .d_gpio_en_1b                   (d_gpio_en_1b                   ),
      .d_gpio_data_ctrl_16b           (d_gpio_data_ctrl_16b           ),
      .d_gpio_bm_int_16b              (d_gpio_bm_int_16b              ),
      .d_gpio_bm_clear_16b            (d_gpio_bm_clear_16b            ),
      .d_gpio_pos_neg_16b             (d_gpio_pos_neg_16b             ),
      .d_gpio_dir_16b                 (d_gpio_dir_16b                 ),
      .d_gpio_recvData_16b            (d_gpio_recvData_16b            ),
      .d_gpio_sendData_16b            (d_gpio_sendData_16b            ),
      .d_gpio_cnt_pe0_wr_4b           (d_gpio_cnt_pe0_wr_4b           ),
      .d_gpio_cnt_pe1_wr_4b           (d_gpio_cnt_pe1_wr_4b           ),
      .d_gpio_cnt_pe2_wr_4b           (d_gpio_cnt_pe2_wr_4b           ),
      .d_gpio_cnt_pe0_rd_4b           (d_gpio_cnt_pe0_rd_4b           ),
      .d_gpio_cnt_pe1_rd_4b           (d_gpio_cnt_pe1_rd_4b           ),
      .d_gpio_cnt_pe2_rd_4b           (d_gpio_cnt_pe2_rd_4b           ),
      .d_gpio_cnt_int_4b              (d_gpio_cnt_int_4b              ),
      //* csram;
      .d_csram_cnt_pe0_wr_4b          (d_csram_cnt_pe0_wr_4b          ),
      .d_csram_cnt_pe1_wr_4b          (d_csram_cnt_pe1_wr_4b          ),
      .d_csram_cnt_pe2_wr_4b          (d_csram_cnt_pe2_wr_4b          ),
      .d_csram_cnt_pe0_rd_4b          (d_csram_cnt_pe0_rd_4b          ),
      .d_csram_cnt_pe1_rd_4b          (d_csram_cnt_pe1_rd_4b          ),
      .d_csram_cnt_pe2_rd_4b          (d_csram_cnt_pe2_rd_4b          ),
      //* spi;
      .d_spi_state_read_4b            (d_spi_state_read_4b            ),
      .d_spi_state_spi_4b             (d_spi_state_spi_4b             ),              
      .d_spi_state_resp_4b            (d_spi_state_resp_4b            ),
      .d_spi_cnt_pe0_rd_4b            (d_spi_cnt_pe0_rd_4b            ),
      .d_spi_cnt_pe1_rd_4b            (d_spi_cnt_pe1_rd_4b            ),
      .d_spi_cnt_pe2_rd_4b            (d_spi_cnt_pe2_rd_4b            ),
      .d_spi_cnt_pe0_wr_4b            (d_spi_cnt_pe0_wr_4b            ),
      .d_spi_cnt_pe1_wr_4b            (d_spi_cnt_pe1_wr_4b            ),
      .d_spi_cnt_pe2_wr_4b            (d_spi_cnt_pe2_wr_4b            ),
      .d_spi_empty_spi_1b             (d_spi_empty_spi_1b             ),              
      .d_spi_usedw_spi_7b             (d_spi_usedw_spi_7b             ),
      //* ready * irq;
      .d_peri_ready_4b                (d_periTop_peri_ready_4b        ),
      .d_pe0_int_9b                   (d_periTop_pe0_int_9b           ),
      .d_pe1_int_9b                   (d_periTop_pe1_int_9b           ),
      .d_pe2_int_9b                   (d_periTop_pe2_int_9b           )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Pkt_Proc_Top
  //====================================================================//
  Pkt_Proc_Top Pkt_Proc_Top(
    //* clk & rst_n;
    .i_pe_clk               (i_pe_clk                     ),
    .i_rst_n                (i_rst_n                      ),
    //* To/From CPI, TODO
    .i_pe_conf_mac          (i_pe_conf_mac                ),
    .i_data_valid           (i_data_valid                 ),
    .i_data                 (i_data                       ),
    .o_data_valid           (o_data_valid                 ),
    .o_data                 (o_data                       ),
    .i_meta_valid           (i_meta_valid                 ),
    .i_meta                 (i_meta                       ),
    .o_meta_valid           (o_meta_valid                 ),
    .o_meta                 (o_meta                       ),
    //* ready
    .o_alf                  (o_alf                        ),
    .i_alf                  (i_alf                        ),
    //* for network configuration
    .o_data_conf_valid      (w_data_conf_valid_from_net   ),
    .o_data_conf            (w_data_conf_from_net         ),
    .i_data_conf_valid      (w_data_conf_valid_to_net     ),
    .i_data_conf            (w_data_conf_to_net           ),
    //* Peri interface (DMA, DRA)
    .i_peri_rden            (w_rden_2peri_pktProc         ),
    .i_peri_wren            (w_wren_2peri_pktProc         ),
    .i_peri_addr            (w_addr_2peri                 ),
    .i_peri_wdata           (w_wdata_2peri                ),
    .i_peri_wstrb           (w_wstrb_2peri                ),
    .o_peri_rdata           (w_rdata_2PBUS_pktProc        ),
    .o_peri_ready           (w_ready_2PBUS_pktProc        ),
    .o_peri_int             (w_int_2PBUS_pktProc          ),
    //* DRA interface;
    `ifdef DRA_EN
      .i_reg_rd               (w_reg_rd                     ),
      .i_reg_raddr            (w_reg_raddr                  ),
      .o_reg_rdata            (w_reg_rdata                  ),
      .o_reg_rvalid           (w_reg_rvalid                 ),
      .o_reg_rvalid_desp      (w_reg_rvalid_desp            ),
      .i_reg_wr               (w_reg_wr                     ),
      .i_reg_wr_desp          (w_reg_wr_desp                ),
      .i_reg_waddr            (w_reg_waddr                  ),
      .i_reg_wdata            (w_reg_wdata                  ),
      .i_status               (w_status_2pktMem             ),
      .o_status               (w_status_2core               ),
    `else
      .i_reg_rd               ('b0                          ),
      .i_reg_raddr            ('b0                          ),
      .o_reg_rdata            (                             ),
      .o_reg_rvalid           (                             ),
      .o_reg_rvalid_desp      (                             ),
      .i_reg_wr               ('b0                          ),
      .i_reg_wr_desp          ('b0                          ),
      .i_reg_waddr            ('b0                          ),
      .i_reg_wdata            ('b0                          ),
      .i_status               ('b0                          ),
      .o_status               (                             ),
    `endif

    //* DMA interface;
    .o_dma_rden             (w_dma_rden                   ),
    .o_dma_wren             (w_dma_wren                   ),
    .o_dma_addr             (w_dma_addr                   ),
    .o_dma_wdata            (w_dma_wdata                  ),
    .i_dma_rdata            (w_dma_rdata                  ),
    .i_dma_rvalid           (w_dma_rvalid                 ),
    .i_dma_gnt              (w_dma_gnt                    ),

    //* debug_pktDistribute;
      .d_AsynRev_inc_pkt_4b     (d_AsynRev_inc_pkt_4b       ),
      .d_PktMUX_state_mux_4b    (d_PktMUX_state_mux_4b      ),
      .d_PktMUX_inc_dra_pkt_1b  (d_PktMUX_inc_dra_pkt_1b    ),
      .d_PktMUX_inc_dma_pkt_1b  (d_PktMUX_inc_dma_pkt_1b    ),
      .d_PktMUX_inc_conf_pkt_1b (d_PktMUX_inc_conf_pkt_1b   ),
      .d_PktMUX_usedw_pktDMA_7b (d_PktMUX_usedw_pktDMA_7b   ),
      .d_PktMUX_usedw_pktDRA_7b (d_PktMUX_usedw_pktDRA_7b   ),
      .d_PktMUX_usedw_conf_7b   (d_PktMUX_usedw_conf_7b     ),
      //* debug_dma
      .d_dmaDist_inc_pkt_3b     (d_dmaDist_inc_pkt_3b       ),
      .d_dmaDist_state_dist_1b  (d_dmaDist_state_dist_1b    ),
      .d_dmaOut_state_out_4b    (d_dmaOut_state_out_4b      ),
      .d_dma_alf_dma_3b         (d_dma_alf_dma_3b           ),
      .d_dma_empty_dmaWR_3b     (d_dma_empty_dmaWR_3b       ),
      .d_dma_usedw_dmaWR_30b    (d_dma_usedw_dmaWR_30b      ),
      .d_dma_empty_pBufWR_3b    (d_dma_empty_pBufWR_3b      ),
      .d_dma_empty_pBufRD_3b    (d_dma_empty_pBufRD_3b      ),
      .d_dma_usedw_pBufRD_30b   (d_dma_usedw_pBufRD_30b     ),
      .d_dma_empty_int_3b       (d_dma_empty_int_3b         ),
      .d_dma_empty_length_3b    (d_dma_empty_length_3b      ),
      .d_dma_empty_low16b_3b    (d_dma_empty_low16b_3b      ),
      .d_dma_empty_high16b_3b   (d_dma_empty_high16b_3b     ),
      //* debug_dra;
      .d_dra_empty_pktRecv_1b (d_dra_empty_pktRecv_1b       ),
      .d_dra_empty_despRecv_3b(d_dra_empty_despRecv_3b      ),
      .d_dra_empty_despSend_3b(d_dra_empty_despSend_3b      ),
      .d_dra_empty_writeReq_3b(d_dra_empty_writeReq_3b      ),
      .d_dra_usedw_pktRecv_10b(d_dra_usedw_pktRecv_10b      )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   for uart, host can send to fpga anytime;
  //====================================================================//
  assign  o_uart_rts = 'b0;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule    
