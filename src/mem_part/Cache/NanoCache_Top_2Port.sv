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
  input   wire  [      31:0]  i_instr_addr ,
  output  wire                o_instr_valid,
  output  wire  [      31:0]  o_instr_rdata,

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
  wire                  w_miss_resp_data, w_upd_valid_data;
  wire  [7:0][31:0]     w_upd_rdata_data;
  wire                  w_wb_wren_data, w_wb_gnt_data;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  NanoCache_Search cache_search_instr (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),

    .o_cache_gnt    (o_instr_gnt          ),
    .i_cache_rden   (i_instr_req          ),
    .i_cache_addr   (i_instr_addr         ),
    .i_cache_wren   ('0                   ),
    .i_cache_wdata  ('0                   ),
    .i_cache_wstrb  ('0                   ),
    .o_cache_rdata  (o_instr_rdata        ),
    .o_cache_rvalid (o_instr_valid        ),

    .o_wb_wren      (                     ),
    .i_wb_gnt       ('0                   ),
    .o_miss_rden    (w_miss_rden_instr    ),
    .o_miss_wren    (w_miss_wren_instr    ),
    .o_miss_addr    (w_miss_addr_instr    ),
    .o_miss_wdata   (w_miss_wdata_instr   ),
    .i_miss_resp    (w_miss_resp_instr    ),
    .i_upd_valid    (w_upd_valid_instr    ),
    .i_upd_rdata    (w_upd_rdata_instr    )
  );

  NanoCache_Update cache_update_instr (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),

    .i_miss_rden    (w_miss_rden_instr    ),
    .i_miss_wren    (w_miss_wren_instr    ),
    .i_miss_addr    (w_miss_addr_instr    ),
    .i_miss_wdata   (w_miss_wdata_instr   ),
    .o_miss_resp    (w_miss_resp_instr    ),

    .o_mm_rden      (o_mm_rden_instr      ),
    .o_mm_wren      (                     ),
    .o_mm_addr      (o_mm_addr_instr      ),
    .o_mm_wdata     (                     ),
    .i_mm_gnt       (i_mm_gnt_instr       ),
    .i_mm_rdata     (i_mm_rdata_instr     ),
    .i_mm_rvalid    (i_mm_rvalid_instr    ),

    .i_wb_wren      ('0                   ),
    .o_wb_gnt       (                     ),
    .o_upd_valid    (w_upd_valid_instr    ),
    .o_upd_rdata    (w_upd_rdata_instr    )
  );

  NanoCache_Search cache_search_data (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),

    .o_cache_gnt    (o_data_gnt           ),
    .i_cache_rden   (i_data_req           ),
    .i_cache_addr   (i_data_addr          ),
    .i_cache_wren   (i_data_we            ),
    .i_cache_wdata  (i_data_wdata         ),
    .i_cache_wstrb  (i_data_wstrb         ),
    .o_cache_rdata  (o_data_rdata         ),
    .o_cache_rvalid (o_data_valid         ),

    .o_wb_wren      (w_wb_wren_data       ),
    .i_wb_gnt       (w_wb_gnt_data        ),
    .o_miss_rden    (w_miss_rden_data     ),
    .o_miss_wren    (w_miss_wren_data     ),
    .o_miss_addr    (w_miss_addr_data     ),
    .o_miss_wdata   (w_miss_wdata_data    ),
    .i_miss_resp    (w_miss_resp_data     ),
    .i_upd_valid    (w_upd_valid_data     ),
    .i_upd_rdata    (w_upd_rdata_data     )
  );

  NanoCache_Update cache_update_data (
    .i_clk          (i_clk                ),
    .i_rst_n        (i_rst_n              ),

    .i_miss_rden    (w_miss_rden_data     ),
    .i_miss_wren    (w_miss_wren_data     ),
    .i_miss_addr    (w_miss_addr_data     ),
    .i_miss_wdata   (w_miss_wdata_data    ),
    .o_miss_resp    (w_miss_resp_data     ),

    .o_mm_rden      (o_mm_rden_data       ),
    .o_mm_wren      (o_mm_wren_data       ),
    .o_mm_addr      (o_mm_addr_data       ),
    .o_mm_wdata     (o_mm_wdata_data      ),
    .i_mm_gnt       (i_mm_gnt_data        ),
    .i_mm_rdata     (i_mm_rdata_data      ),
    .i_mm_rvalid    (i_mm_rvalid_data     ),

    .i_wb_wren      (w_wb_wren_data       ),
    // .i_wb_wren      ('0                   ),
    .o_wb_gnt       (w_wb_gnt_data        ),
    .o_upd_valid    (w_upd_valid_data     ),
    .o_upd_rdata    (w_upd_rdata_data     )
  );

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule