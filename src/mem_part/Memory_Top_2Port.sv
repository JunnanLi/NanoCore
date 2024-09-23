/*************************************************************/
//  Module name: Memory_Top
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/28
//  Function outline: sram-based memory
/*************************************************************/

module Memory_Top (
  //* clk & reset;
  input   wire                    i_clk,
  input   wire                    i_rst_n,
  input   wire                    i_flush,

  //* interface for configuration;
  input   wire                    i_conf_rden,    //* support read/write
  input   wire                    i_conf_wren,
  input   wire  [          15:0]  i_conf_addr,
  input   wire  [         127:0]  i_conf_wdata,
  output  wire  [         127:0]  o_conf_rdata,   //* rdata is valid after two clk;
  input   wire  [           3:0]  i_conf_en,      //* for 4 PEs;
  
  output  wire                    o_data_gnt   ,
  input   wire                    i_data_req   ,
  input   wire                    i_data_we    ,
  input   wire  [          31:0]  i_data_addr  ,
  input   wire  [           3:0]  i_data_wstrb ,
  input   wire  [          31:0]  i_data_wdata ,
  output  wire                    o_data_valid ,
  output  wire  [          31:0]  o_data_rdata ,
  output  wire                    o_instr_gnt  ,
  input   wire                    i_instr_req  ,
  input   wire  [           1:0]  i_instr_req_2b,
  input   wire  [          31:0]  i_instr_addr ,
  output  wire  [           1:0]  o_instr_valid,
  output  wire  [          63:0]  o_instr_rdata,
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
  wire  [ 7:0]                  w_conf_dma_rden, w_conf_rden_instr;
  logic [ 7:0]                  w_conf_dma_wren, w_conf_wren_instr;
  logic [ 7:0][       31:0]     w_conf_dma_addr, w_conf_addr_instr;
  logic [ 7:0][       31:0]     w_conf_dma_wdata,w_conf_wdata_instr;
  wire  [ 7:0][       31:0]     w_conf_dma_rdata, w_conf_rdata_instr, w_conf_dma_rdata_in128b;
  wire                          w_mm_rden_instr, w_mm_rden_data;
  wire                          w_mm_wren_data;
  wire  [             31:0]     w_mm_addr_instr, w_mm_addr_data;
  wire  [ 7:0][       31:0]     w_mm_wdata_data;
  wire  [ 7:0][        3:0]     w_mm_wstrb_data;
  wire  [ 7:0][       31:0]     w_mm_rdata_instr, w_mm_rdata_data;
  wire                          w_mm_rvalid_instr, w_mm_rvalid_data;
  reg   [ 7:0]                  temp_winc;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  assign w_conf_dma_rden = {8{i_conf_rden | i_dma_rden}};
  assign w_conf_rden_instr = {8{i_conf_rden}};
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
    for(integer idx=0; idx <4; idx=idx+1) begin
        //* data conf & dma
        w_conf_dma_wren[idx] = i_conf_wren & ~i_conf_addr[2] & i_conf_addr[`MEM_TAG] | 
                                i_dma_wren & i_dma_wstrb[idx];
        w_conf_dma_addr[idx] = (i_conf_wren|i_conf_rden)? {19'b0,i_conf_addr[15:3]}: 
                                i_dma_winc[idx]? (i_dma_addr + 16'd1):
                                                  i_dma_addr;
        w_conf_dma_wdata[idx]= i_conf_wren? i_conf_wdata[32*idx+:32]: i_dma_wdata[32*idx+:32];
        o_dma_rdata[32*idx+:32]= w_conf_dma_rdata_in128b[idx];
        //* instr conf
        w_conf_wren_instr[idx] = i_conf_wren & ~i_conf_addr[2] & ~i_conf_addr[`MEM_TAG];
        w_conf_addr_instr[idx] = {19'b0,i_conf_addr[15:3]};
        w_conf_wdata_instr[idx]= i_conf_wdata[32*idx+:32];
    end
    for(integer idx=4; idx <8; idx=idx+1) begin
        //* data conf & dma
        w_conf_dma_wren[idx] = i_conf_wren & i_conf_addr[2] & i_conf_addr[`MEM_TAG] | 
                                i_dma_wren & i_dma_wstrb[idx];
        w_conf_dma_addr[idx] = (i_conf_wren|i_conf_rden)? {19'b0,i_conf_addr[15:3]}: 
                                i_dma_winc[idx]? (i_dma_addr + 16'd1):
                                                  i_dma_addr;
        w_conf_dma_wdata[idx]= i_conf_wren? i_conf_wdata[32*(idx-4)+:32]: i_dma_wdata[32*idx+:32];
        o_dma_rdata[32*idx+:32]= w_conf_dma_rdata_in128b[idx];
        //* instr conf
        w_conf_wren_instr[idx] = i_conf_wren & i_conf_addr[2] & ~i_conf_addr[`MEM_TAG];
        w_conf_addr_instr[idx] = {19'b0,i_conf_addr[15:3]};
        w_conf_wdata_instr[idx]= i_conf_wdata[32*(idx-4)+:32];
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
    .i_flush          (i_flush                    ),

    //* interface for PEs    
    .o_data_gnt       (o_data_gnt                 ),
    .i_data_req       (i_data_req                 ),
    .i_data_we        (i_data_we                  ),
    .i_data_addr      (i_data_addr                ),
    .i_data_wstrb     (i_data_wstrb               ),
    .i_data_wdata     (i_data_wdata               ),
    .o_data_valid     (o_data_valid               ),
    .o_data_rdata     (o_data_rdata               ),
    .o_instr_gnt      (o_instr_gnt                ),
    .i_instr_req      (i_instr_req                ),
    .i_instr_req_2b   (i_instr_req_2b             ),
    .i_instr_addr     (i_instr_addr               ),
    .o_instr_valid    (o_instr_valid              ),
    .o_instr_rdata    (o_instr_rdata              ),

    //* interface for reading SRAM
    .o_mm_rden_instr  (w_mm_rden_instr            ),
    .o_mm_addr_instr  (w_mm_addr_instr            ),
    .i_mm_rdata_instr (w_mm_rdata_instr           ),
    .i_mm_rvalid_instr(w_mm_rvalid_instr          ),
    .i_mm_gnt_instr   (1'b1                       ),

    .o_mm_rden_data   (w_mm_rden_data             ),
    .o_mm_wren_data   (w_mm_wren_data             ),
    .o_mm_addr_data   (w_mm_addr_data             ),
    .o_mm_wdata_data  (w_mm_wdata_data            ),
    .o_mm_wstrb_data  (w_mm_wstrb_data            ),
    .i_mm_rdata_data  (w_mm_rdata_data            ),
    .i_mm_rvalid_data (w_mm_rvalid_data           ),
    .i_mm_gnt_data    (1'b1                       )
  );

  reg [1:0] temp_imm_rden_instr, temp_imm_rden_data, temp_dma_rden;
  assign w_mm_rvalid_instr  = temp_imm_rden_instr[1];
  assign w_mm_rvalid_data   = temp_imm_rden_data[1];
`ifdef DATA_SRAM_noBUFFER
  assign o_dma_rvalid = temp_dma_rden[0];
`else
  assign o_dma_rvalid = temp_dma_rden[1];
`endif
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      temp_imm_rden_instr <= 2'b0;
      temp_imm_rden_data  <= 2'b0;
      temp_dma_rden       <= 2'b0;
    end else begin
      temp_imm_rden_instr <= {temp_imm_rden_instr[0],w_mm_rden_instr};
      temp_imm_rden_data  <= {temp_imm_rden_data[0],w_mm_rden_data};
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
    for (i_ram = 0; i_ram < 8; i_ram = i_ram+1) begin: gen_mem
      SRAM_Wrapper_instr instr_sram(
        .clk    (i_clk                          ),
        .rst_n  (i_rst_n                        ),
        .rda    (w_conf_rden_instr[i_ram]       ),
        .wea    (w_conf_wren_instr[i_ram]       ),  
        .addra  (w_conf_addr_instr[i_ram]       ),
        .dina   (w_conf_wdata_instr[i_ram]      ),
        .stra   (4'hf                           ),
        .douta  (w_conf_rdata_instr[i_ram]      ),
        .rdb    (w_mm_rden_instr                ),
        .web    ('0                             ),  
        .addrb  (w_mm_addr_instr                ),
        .dinb   ('0                             ),
        .strb   ('0                             ),
        .doutb  (w_mm_rdata_instr[i_ram]        )
      );
    `ifdef DATA_SRAM_noBUFFER
      SRAM_Wrapper_instr data_sram(
    `else
      SRAM_Wrapper data_sram(
    `endif
        .clk    (i_clk                          ),
        .rst_n  (i_rst_n                        ),
        .rda    (w_conf_dma_rden[i_ram]         ),
        .wea    (w_conf_dma_wren[i_ram]         ),  
        .addra  (w_conf_dma_addr[i_ram]         ),
        .dina   (w_conf_dma_wdata[i_ram]        ),
        .stra   (4'hf                           ),
        .douta  (w_conf_dma_rdata[i_ram]        ),
        .rdb    (w_mm_rden_data                 ),
        .web    (w_mm_wren_data                 ),  
        .addrb  (w_mm_addr_data                 ),
        .dinb   (w_mm_wdata_data[i_ram]         ),
        .strb   (w_mm_wstrb_data[i_ram]         ),
        .doutb  (w_mm_rdata_data[i_ram]         )
      );
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


endmodule