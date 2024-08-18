/*
 *  Project:            RvPipe -- a RISCV-32MC SoC.
 *  Module name:        MultiCore_Top.
 *  Description:        top module of multi-core.
 *  Last updated date:  2024.2.19.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */
 
  //====================================================================//
  //*   Connection Relationship                                         //
  //*                        instr/data_resp ->   +---------------+     //
  //*         +-----------------------------------| +-----------+ |     //
  //*         |      <- instr/data_req            | | NanoCore  | |     //
  //*         |                                   | +-----------+ |     //
  //*  +------------+                             | +-----------+ |     //
  //*  | Memory_Top |-----------------+           | | NanoCore  | |     //
  //*  +------------+     <- config   |           | +-----------+ |     //
  //*      |                          |           | +-----------+ |     //
  //*      | <>DMA_req/resp           |           | | NanoCore  | |     //
  //*      |                          |           | +-----------+ |     //
  //*      |                          |           | +-----------+ |     //
  //*  +---------+              +----------+      | | NanoCore  | |     //
  //*  |   DMA   |--------------| Pkt_Proc |      | +-----------+ |     //
  //*  +---------+     resp>    +----------+      +---------------+     //
  //====================================================================//

 `timescale 1 ns / 1 ps

module MultiCore_Top(
  //* clk & rst_n
   input    wire                      i_clk
  ,input    wire                      i_rst_n
  //* interface for configuring memory
  ,input    wire                      i_conf_rden
  ,input    wire                      i_conf_wren
  ,input    wire  [            15:0]  i_conf_addr
  ,input    wire  [           127:0]  i_conf_wdata
  ,output   wire  [           127:0]  o_conf_rdata
  ,input    wire  [             3:0]  i_conf_en           //* for 4 PEs;
  //* interface for peripheral
  ,output   wire                      o_peri_rden
  ,output   wire                      o_peri_wren
  ,output   wire  [            31:0]  o_peri_addr
  ,output   wire  [            31:0]  o_peri_wdata
  ,output   wire  [             3:0]  o_peri_wstrb
  ,input    wire  [            31:0]  i_peri_rdata
  ,input    wire                      i_peri_ready
  ,input    wire                      i_peri_gnt          //* allow next access;
  //* irq;
  ,input    wire  [            31:0]  i_irq_bitmap
  ,output   wire                      o_irq_ack
  ,output   wire  [             4:0]  o_irq_id
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
  //* DMA;
  ,input    wire                      i_dma_rden
  ,input    wire                      i_dma_wren
  ,input    wire  [            31:0]  i_dma_addr
  ,input    wire  [           255:0]  i_dma_wdata
  ,input    wire  [             7:0]  i_dma_wstrb
  ,input    wire  [             7:0]  i_dma_winc
  ,output   wire  [           255:0]  o_dma_rdata
  ,output   wire                      o_dma_rvalid
  ,output   wire                      o_dma_gnt           //* allow next access;
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* 1) Mem flow: PE(w_instr_xxx_pe) <---> memory;
  //* to connect instr/data memory, similar to SRAM interface;
  wire  [`NUM_PE-1:0]       w_data_gnt;
  wire  [`NUM_PE-1:0]       w_data_req;
  wire  [`NUM_PE-1:0]       w_data_we;
  wire  [`NUM_PE-1:0][31:0] w_data_addr;
  wire  [`NUM_PE-1:0][ 3:0] w_data_wstrb;
  wire  [`NUM_PE-1:0][31:0] w_data_wdata;
  wire  [`NUM_PE-1:0]       w_data_valid;
  wire  [`NUM_PE-1:0][31:0] w_data_rdata;
  wire  [`NUM_PE-1:0]       w_instr_req;
  wire  [`NUM_PE-1:0]       w_instr_gnt;
  wire  [`NUM_PE-1:0][31:0] w_instr_addr;
  wire  [`NUM_PE-1:0]       w_instr_valid;
  wire  [`NUM_PE-1:0][31:0] w_instr_rdata;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   NanoCore
  //====================================================================//
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe + 1) begin: gen_nanocore
      //* instance of NanoCore;
      if(i_pe == 0) begin
        NanoCore_Wrapper #(
          .COREID             (i_pe                         )
        ) NanoCore_Wrapper(
          //* clk & rst_n;
          .i_clk              (i_clk                        ),
          .i_rst_n            (i_rst_n&~i_conf_en[i_pe]     ),
          //* mem access interface;
          .data_gnt_i         (w_data_gnt[i_pe]             ),
          .data_req_o         (w_data_req[i_pe]             ),
          .data_we_o          (w_data_we[i_pe]              ),
          .data_addr_o        (w_data_addr[i_pe]            ),
          .data_wstrb_o       (w_data_wstrb[i_pe]           ),
          .data_wdata_o       (w_data_wdata[i_pe]           ),
          .data_valid_i       (w_data_valid[i_pe]           ),
          .data_rdata_i       (w_data_rdata[i_pe]           ),
          .instr_gnt_i        (w_instr_gnt[i_pe]            ),
          .instr_req_o        (w_instr_req[i_pe]            ),
          .instr_addr_o       (w_instr_addr[i_pe]           ),
          .instr_valid_i      (w_instr_valid[i_pe]          ),
          .instr_rdata_i      (w_instr_rdata[i_pe]          ),
          //* peri access interface;
          .o_peri_rden        (o_peri_rden                  ),
          .o_peri_wren        (o_peri_wren                  ),
          .o_peri_addr        (o_peri_addr                  ),
          .o_peri_wdata       (o_peri_wdata                 ),
          .o_peri_wstrb       (o_peri_wstrb                 ),
          .i_peri_rdata       (i_peri_rdata                 ),
          .i_peri_ready       (i_peri_ready                 ),
          .i_peri_gnt         (i_peri_gnt                   ),
          //* irq interface;
          .i_irq_bitmap       (i_irq_bitmap                 ),
          .o_irq_ack          (o_irq_ack                    ),
          .o_irq_id           (o_irq_id                     )
        `ifdef ENABLE_DRA  
          //* DRA interface;
          ,.o_reg_rd          (o_reg_rd[i_pe]               ),
          .o_reg_raddr        (o_reg_raddr[i_pe*32+:32]     ),
          .i_reg_rdata        (i_reg_rdata                  ),
          .i_reg_rvalid       (i_reg_rvalid[i_pe]           ),
          .i_reg_rvalid_desp  (i_reg_rvalid_desp[i_pe]      ),
          .o_reg_wr           (o_reg_wr[i_pe]               ),
          .o_reg_wr_desp      (o_reg_wr_desp[i_pe]          ),
          .o_reg_waddr        (o_reg_waddr[i_pe*32+:32]     ),
          .o_reg_wdata        (o_reg_wdata[i_pe*512+:512]   ),
          .i_status           (i_status[i_pe*32+:32]        ),
          .o_status           (o_status[i_pe*32+:32]        )
        `endif
        );
      end
      else begin
        NanoCore_Wrapper #(
          .COREID             (i_pe                         )
        ) NanoCore_Wrapper(
          //* clk & rst_n;
          .i_clk              (i_clk                        ),
          .i_rst_n            (i_rst_n&~i_conf_en[i_pe]     ),
          //* mem access interface;
          .data_gnt_i         (w_data_gnt[i_pe]             ),
          .data_req_o         (w_data_req[i_pe]             ),
          .data_we_o          (w_data_we[i_pe]              ),
          .data_addr_o        (w_data_addr[i_pe]            ),
          .data_wstrb_o       (w_data_wstrb[i_pe]           ),
          .data_wdata_o       (w_data_wdata[i_pe]           ),
          .data_valid_i       (w_data_valid[i_pe]           ),
          .data_rdata_i       (w_data_rdata[i_pe]           ),
          .instr_gnt_i        (w_instr_gnt[i_pe]            ),
          .instr_req_o        (w_instr_req[i_pe]            ),
          .instr_addr_o       (w_instr_addr[i_pe]           ),
          .instr_valid_i      (w_instr_valid[i_pe]          ),
          .instr_rdata_i      (w_instr_rdata[i_pe]          ),
          //* peri access interface;
          .i_peri_rdata       ('b0                          ),
          .i_peri_ready       ('b0                          ),
          .i_peri_gnt         ('b0                          ),
          //* irq interface;
          .i_irq_bitmap       ('b0                          )
        `ifdef ENABLE_DRA  
          //* DRA interface;
          ,.o_reg_rd          (o_reg_rd[i_pe]               ),
          .o_reg_raddr        (o_reg_raddr[i_pe*32+:32]     ),
          .i_reg_rdata        (i_reg_rdata                  ),
          .i_reg_rvalid       (i_reg_rvalid[i_pe]           ),
          .i_reg_rvalid_desp  (i_reg_rvalid_desp[i_pe]      ),
          .o_reg_wr           (o_reg_wr[i_pe]               ),
          .o_reg_wr_desp      (o_reg_wr_desp[i_pe]          ),
          .o_reg_waddr        (o_reg_waddr[i_pe*32+:32]     ),
          .o_reg_wdata        (o_reg_wdata[i_pe*512+:512]   ),
          .i_status           (i_status[i_pe*32+:32]        ),
          .o_status           (o_status[i_pe*32+:32]        )
        `endif
        );
      end
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
 

  //====================================================================//
  //*   MEM Part
  //====================================================================//
  //* this handles read to RAM and memory mapped pseudo peripherals
  Memory_Top Memory_Top(
    //* clk & rst_n;
    .i_clk                  (i_clk                        ),
    .i_rst_n                (i_rst_n                      ),
    //* config interface;
    .i_conf_rden            (i_conf_rden                  ),
    .i_conf_wren            (i_conf_wren                  ),
    .i_conf_addr            (i_conf_addr                  ),
    .i_conf_wdata           (i_conf_wdata                 ),
    .o_conf_rdata           (o_conf_rdata                 ),
    .i_conf_en              (i_conf_en                    ),
    //* mem access interface;
    .o_data_gnt             (w_data_gnt                   ),
    .i_data_req             (w_data_req                   ),
    .i_data_we              (w_data_we                    ),
    .i_data_addr            (w_data_addr                  ),
    .i_data_wstrb           (w_data_wstrb                 ),
    .i_data_wdata           (w_data_wdata                 ),
    .o_data_valid           (w_data_valid                 ),
    .o_data_rdata           (w_data_rdata                 ),
    .o_instr_gnt            (w_instr_gnt                  ),
    .i_instr_req            (w_instr_req                  ),
    .i_instr_addr           (w_instr_addr                 ),
    .o_instr_valid          (w_instr_valid                ),
    .o_instr_rdata          (w_instr_rdata                ),
    //* DMA interface;
    .i_dma_rden             (i_dma_rden                   ),
    .i_dma_wren             (i_dma_wren                   ),
    .i_dma_addr             (i_dma_addr                   ),
    .i_dma_wdata            (i_dma_wdata                  ),
    .i_dma_wstrb            (i_dma_wstrb                  ),
    .i_dma_winc             (i_dma_winc                   ),
    .o_dma_rdata            (o_dma_rdata                  ),
    .o_dma_rvalid           (o_dma_rvalid                 ),
    .o_dma_gnt              (o_dma_gnt                    )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  // reg [31:0]  cnt_clk;
  // always @(posedge i_clk or negedge i_rst_n) begin
  //   if(!i_rst_n) begin
  //     cnt_clk   <= 32'b0;
  //   end
  //   else begin
  //     cnt_clk   <= 32'd1 + cnt_clk;
  //   end
  // end

  // integer out_file;
  // initial begin
  //   out_file = $fopen("F:/share_with_ubuntu/inst_log_cmp.txt","w");
  // end

  // always @(posedge i_clk) begin
  //   if(w_instr_req[0] == 1'b1) begin
  //     $fwrite(out_file, "addr: %08x\n", w_instr_addr[31:0]);
  //   end
  //   if(cnt_clk == 32'hbd5d) begin
  //     $fclose(out_file);
  //   end
  // end


endmodule

