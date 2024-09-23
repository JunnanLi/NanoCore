/*************************************************************/
//  Module name: NanoCache_Top
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/28
//  Function outline: nano cache
//  Noted:
//    1) two 32b*8 cache lines, one for instr, another for data;
//    2) adopt write-back;
/*************************************************************/


module NanoCache_Top (
  //* clk & reset;
  input   wire                i_clk,
  input   wire                i_rst_n,
  input   wire                i_flush,

  //* interface for PEs (instr.);
  output  wire                o_data_gnt   ,
  input   wire                i_data_req   ,
  input   wire                i_data_we    ,
  input   wire  [      31:0]  i_data_addr  ,
  input   wire  [       3:0]  i_data_wstrb ,
  input   wire  [      31:0]  i_data_wdata ,
  output  wire                o_data_valid ,
  output  wire  [      31:0]  o_data_rdata ,
  output  wire                o_instr_gnt  ,
  input   wire                i_instr_req  ,
  input   wire  [       1:0]  i_instr_req_2b,
  input   wire  [      31:0]  i_instr_addr ,
  output  wire  [       1:0]  o_instr_valid,
  output  wire  [      63:0]  o_instr_rdata,

  //* interface for reading SRAM by Icache;
  output  wire                o_mm_rden_instr,
  output  wire  [     31:0]   o_mm_addr_instr,
  input   wire  [7:0][31:0]   i_mm_rdata_instr,
  input   wire                i_mm_rvalid_instr,
  input   wire                i_mm_gnt_instr,
  output  wire                o_mm_rden_data,
  output  wire                o_mm_wren_data,
  output  wire  [     31:0]   o_mm_addr_data,
  output  wire  [7:0][31:0]   o_mm_wdata_data,
  output  wire  [7:0][ 3:0]   o_mm_wstrb_data,
  input   wire  [7:0][31:0]   i_mm_rdata_data,
  input   wire                i_mm_rvalid_data,
  input   wire                i_mm_gnt_data
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire                  w_miss_rden_instr;
  wire  [31:0]          w_miss_addr_instr;
  wire  [7:0][31:0]     w_miss_wdata_instr;
  wire                  w_miss_resp_instr, w_upd_valid_instr;
  wire  [7:0][31:0]     w_upd_rdata_instr;
  wire                  w_miss_rden_data, w_miss_wren_data;
  wire  [31:0]          w_miss_addr_data;
  wire  [7:0][31:0]     w_miss_wdata_data;
  wire  [7:0][ 3:0]     w_miss_wstrb_data;
  wire                  w_miss_resp_data, w_upd_valid_data, w_wr_finish;
  wire  [7:0][31:0]     w_upd_rdata_data;
  wire                  w_wb_wren_data, w_wb_gnt_data;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  NanoCache_Search 
  #(
    .DATA_WIDTH     (64                   ),
    .RDEN_WIDTH     (2                    ),
    .BYPASS         (0                    )
  ) cache_search_instr (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),
    .i_flush        (i_flush              ),

    .o_cache_gnt    (o_instr_gnt          ),
    .i_cache_rden   (i_instr_req          ),
    .i_cache_rden_v (i_instr_req_2b       ),
    .i_cache_addr   (i_instr_addr         ),
    .i_cache_wren   ('0                   ),
    .i_cache_wdata  ('0                   ),
    .i_cache_wstrb  ('0                   ),
    .o_cache_rdata  (o_instr_rdata        ),
    .o_cache_rvalid (o_instr_valid        ),

    .o_miss_rden    (w_miss_rden_instr    ),
    .o_miss_wren    (                     ),
    .o_miss_addr    (w_miss_addr_instr    ),
    .o_miss_wdata   (                     ),
    .o_miss_wstrb   (                     ),
    .i_miss_resp    (w_miss_resp_instr    ),
    .i_upd_valid    (w_upd_valid_instr    ),
    .i_upd_rdata    (w_upd_rdata_instr    ),
    .i_wr_finish    ('0                   )
  );

  NanoCache_Update #(
    .BUFFER         (0                    )
  ) cache_update_instr (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),
    .i_flush        (i_flush              ),

    .i_miss_rden    (w_miss_rden_instr    ),
    .i_miss_wren    ('0                   ),
    .i_miss_addr    (w_miss_addr_instr    ),
    .i_miss_wdata   ('0                   ),
    .i_miss_wstrb   ('0                   ),
    .o_miss_resp    (w_miss_resp_instr    ),

    .o_mm_rden      (o_mm_rden_instr      ),
    .o_mm_wren      (                     ),
    .o_mm_addr      (o_mm_addr_instr      ),
    .o_mm_wdata     (                     ),
    .o_mm_wstrb     (                     ),
    .i_mm_gnt       (i_mm_gnt_instr       ),
    .i_mm_rdata     (i_mm_rdata_instr     ),
    .i_mm_rvalid    (i_mm_rvalid_instr    ),

    .o_upd_valid    (w_upd_valid_instr    ),
    .o_upd_rdata    (w_upd_rdata_instr    ),
    .o_wr_finish    (                     )
  );

  NanoCache_Search cache_search_data (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),
    .i_flush        ('0                   ),

    .o_cache_gnt    (o_data_gnt           ),
    .i_cache_rden   (i_data_req           ),
    .i_cache_rden_v (i_data_req           ),
    .i_cache_addr   (i_data_addr          ),
    .i_cache_wren   (i_data_we            ),
    .i_cache_wdata  (i_data_wdata         ),
    .i_cache_wstrb  (i_data_wstrb         ),
    .o_cache_rdata  (o_data_rdata         ),
    .o_cache_rvalid (o_data_valid         ),

    .o_miss_rden    (w_miss_rden_data     ),
    .o_miss_wren    (w_miss_wren_data     ),
    .o_miss_addr    (w_miss_addr_data     ),
    .o_miss_wdata   (w_miss_wdata_data    ),
    .o_miss_wstrb   (w_miss_wstrb_data    ),
    .i_miss_resp    (w_miss_resp_data     ),
    .i_upd_valid    (w_upd_valid_data     ),
    .i_upd_rdata    (w_upd_rdata_data     ),
    .i_wr_finish    (w_wr_finish          )
  );

  NanoCache_Update 
`ifdef DATA_SRAM_noBUFFER  
  #(  
    .BUFFER         (0                    )
  ) 
`endif
  cache_update_data (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),
    .i_flush        ('0                   ),

    .i_miss_rden    (w_miss_rden_data     ),
    .i_miss_wren    (w_miss_wren_data     ),
    .i_miss_addr    (w_miss_addr_data     ),
    .i_miss_wdata   (w_miss_wdata_data    ),
    .i_miss_wstrb   (w_miss_wstrb_data    ),
    .o_miss_resp    (w_miss_resp_data     ),

    .o_mm_rden      (o_mm_rden_data       ),
    .o_mm_wren      (o_mm_wren_data       ),
    .o_mm_addr      (o_mm_addr_data       ),
    .o_mm_wdata     (o_mm_wdata_data      ),
    .o_mm_wstrb     (o_mm_wstrb_data      ),
    .i_mm_gnt       (i_mm_gnt_data        ),
    .i_mm_rdata     (i_mm_rdata_data      ),
    .i_mm_rvalid    (i_mm_rvalid_data     ),

    .o_upd_valid    (w_upd_valid_data     ),
    .o_upd_rdata    (w_upd_rdata_data     ),
    .o_wr_finish    (w_wr_finish          )
  );

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule