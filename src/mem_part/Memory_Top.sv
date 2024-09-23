/*
 *  Project:            RvPipe -- a RISCV-32MC SoC.
 *  Module name:        MultiCore_Top.
 *  Description:        top module of Memory.
 *  Last updated date:  2024.2.20.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */

module Memory_Top (
  //* clk & reset;
  input   wire                    i_clk,
  input   wire                    i_rst_n,

  //* interface for configuration;
  input   wire                    i_conf_rden,    //* support read/write
  input   wire                    i_conf_wren,
  input   wire  [          31:0]  i_conf_addr,
  input   wire  [          31:0]  i_conf_wdata,
  output  wire  [          31:0]  o_conf_rdata,   //* rdata is valid after two clk;
  input   wire  [           3:0]  i_conf_en,      //* for 4 PEs;

  //* interface for PEs;
  input   wire  [   `NUM_PE-1:0]        i_mem_rden,
  input   wire  [   `NUM_PE-1:0][31:0]  i_mem_addr,
  input   wire  [   `NUM_PE-1:0]        i_mem_wren,
  input   wire  [   `NUM_PE-1:0][ 3:0]  i_mem_wstrb,
  input   wire  [   `NUM_PE-1:0][31:0]  i_mem_wdata,
  output  wire  [   `NUM_PE-1:0][31:0]  o_mem_rdata,
  output  wire  [   `NUM_PE-1:0]        o_mem_rvalid,
  output  wire  [   `NUM_PE-1:0]        o_mem_gnt,
  
  //* interface for DMA;
  input   wire                    i_dma_rden,
  input   wire                    i_dma_wren,
  input   wire  [          31:0]  i_dma_addr,
  input   wire  [         255:0]  i_dma_wdata,
  input   wire  [           7:0]  i_dma_wstrb,
  input   wire  [           7:0]  i_dma_winc,
  output  logic [         255:0]  o_dma_rdata,
  output  wire                    o_dma_rvalid,
  output  wire                    o_dma_gnt
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* interface for reading SRAM;
  wire  [ 7:0]                  w_conf_dma_rden;
  logic [ 7:0]                  w_conf_dma_wren;
  logic [ 7:0][       31:0]     w_conf_dma_addr;
  logic [ 7:0][       31:0]     w_conf_dma_wdata;
  wire  [ 7:0][       31:0]     w_conf_dma_rdata, w_conf_dma_rdata_in128b;
  wire                          w_mm_rden;
  wire                          w_mm_wren;
  wire  [             31:0]     w_mm_addr;
  wire  [ 7:0][       31:0]     w_mm_wdata;
  wire  [ 7:0][       31:0]     w_mm_rdata;
  wire                          w_mm_rvalid;
  reg   [ 7:0]                  temp_winc[1:0];
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  assign w_conf_dma_rden = {8{i_conf_rden | i_dma_rden}};
  // assign w_conf_dma_rdata_in128b[0] = (!temp_winc[1][0] | temp_winc[1][4])? w_conf_dma_rdata[0]: w_conf_dma_rdata[4];
  // assign w_conf_dma_rdata_in128b[1] = (!temp_winc[1][1] | temp_winc[1][5])? w_conf_dma_rdata[1]: w_conf_dma_rdata[5];
  // assign w_conf_dma_rdata_in128b[2] = (!temp_winc[1][2] | temp_winc[1][6])? w_conf_dma_rdata[2]: w_conf_dma_rdata[6];
  // assign w_conf_dma_rdata_in128b[3] = (!temp_winc[1][3] | temp_winc[1][7])? w_conf_dma_rdata[3]: w_conf_dma_rdata[7];
  // assign w_conf_dma_rdata_in128b[4] = (!temp_winc[1][0] | temp_winc[1][4])? w_conf_dma_rdata[4]: w_conf_dma_rdata[0];
  // assign w_conf_dma_rdata_in128b[5] = (!temp_winc[1][1] | temp_winc[1][5])? w_conf_dma_rdata[5]: w_conf_dma_rdata[1];
  // assign w_conf_dma_rdata_in128b[6] = (!temp_winc[1][2] | temp_winc[1][6])? w_conf_dma_rdata[6]: w_conf_dma_rdata[2];
  // assign w_conf_dma_rdata_in128b[7] = (!temp_winc[1][3] | temp_winc[1][7])? w_conf_dma_rdata[7]: w_conf_dma_rdata[3];
  assign w_conf_dma_rdata_in128b[0] = w_conf_dma_rdata[0];
  assign w_conf_dma_rdata_in128b[1] = w_conf_dma_rdata[1];
  assign w_conf_dma_rdata_in128b[2] = w_conf_dma_rdata[2];
  assign w_conf_dma_rdata_in128b[3] = w_conf_dma_rdata[3];
  assign w_conf_dma_rdata_in128b[4] = w_conf_dma_rdata[4];
  assign w_conf_dma_rdata_in128b[5] = w_conf_dma_rdata[5];
  assign w_conf_dma_rdata_in128b[6] = w_conf_dma_rdata[6];
  assign w_conf_dma_rdata_in128b[7] = w_conf_dma_rdata[7];
  always_comb begin
    for(integer idx=0; idx <8; idx=idx+1) begin
        w_conf_dma_wren[idx] = i_conf_wren & (i_conf_addr[2:0] == idx) | 
                                i_dma_wren & i_dma_wstrb[idx];
        w_conf_dma_addr[idx] = (i_conf_wren|i_conf_rden)? {3'b0,i_conf_addr[31:3]}: 
                                i_dma_winc[idx]? (i_dma_addr + 16'd1):
                                                  i_dma_addr;
        w_conf_dma_wdata[idx]= i_conf_wren? i_conf_wdata: i_dma_wdata[32*idx+:32];
        o_dma_rdata[32*idx+:32]= w_conf_dma_rdata_in128b[idx];
    end
  end
  assign o_conf_rdata = w_conf_dma_rdata[0];


  //====================================================================//
  //*   nano Cache
  //====================================================================//
  NanoCache_Top Cache_Top (
    //* clk & reset;
    .i_clk            (i_clk                      ),
    .i_rst_n          (i_rst_n                    ),

    //* interface for PEs
    .i_cache_rden     (i_mem_rden                 ),
    .i_cache_wren     (i_mem_wren                 ),
    .i_cache_addr     (i_mem_addr                 ),
    .i_cache_wdata    (i_mem_wdata                ),
    .i_cache_wstrb    (i_mem_wstrb                ),
    .o_cache_rdata    (o_mem_rdata                ),
    .o_cache_rvalid   (o_mem_rvalid               ),
    .o_cache_gnt      (o_mem_gnt                  ),

    //* interface for reading SRAM
    .o_mm_rden        (w_mm_rden                  ),
    .o_mm_wren        (w_mm_wren                  ),
    .o_mm_addr        (w_mm_addr                  ),
    .o_mm_wdata       (w_mm_wdata                 ),
    .i_mm_rdata       (w_mm_rdata                 ),
    .i_mm_rvalid      (w_mm_rvalid                ),
    .i_mm_gnt         (1'b1                       )
  );

  reg [1:0] temp_imm_rden, temp_dma_rden;
  assign w_mm_rvalid  = temp_imm_rden[1];
  assign o_dma_rvalid = temp_dma_rden[1];
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      temp_imm_rden   <= 2'b0;
      temp_dma_rden   <= 2'b0;
    end else begin
      temp_imm_rden   <= {temp_imm_rden[0],w_mm_rden};
      temp_dma_rden   <= {temp_dma_rden[0],i_dma_rden};
      temp_winc       <= {temp_winc[0], i_dma_winc};
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Instr/Data RAM
  //====================================================================//
  genvar i_ram;
  generate
    for (i_ram = 0; i_ram < 8; i_ram = i_ram+1) begin: gen_ram_mem
      SRAM_Wrapper mem_sram(
        .clk    (i_clk                          ),
        .rst_n  (i_rst_n                        ),
        .rda    (w_conf_dma_rden[i_ram]         ),
        .wea    (w_conf_dma_wren[i_ram]         ),  
        .addra  (w_conf_dma_addr[i_ram]         ),
        .dina   (w_conf_dma_wdata[i_ram]        ),
        .douta  (w_conf_dma_rdata[i_ram]        ),
        .rdb    (w_mm_rden                      ),
        .web    (w_mm_wren                      ),  
        .addrb  (w_mm_addr                      ),
        .dinb   (w_mm_wdata[i_ram]              ),
        .doutb  (w_mm_rdata[i_ram]              )
      );
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


endmodule