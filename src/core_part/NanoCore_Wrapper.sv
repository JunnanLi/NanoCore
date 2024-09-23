/*************************************************************/
//  Module name: NanoCore_Wrapper
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/02/20
//  Function outline: risc-v core in RvPipe
/*************************************************************/

module NanoCore_Wrapper#(
  parameter [31:0] COREID = 2'b0
) (
  input i_clk, i_rst_n, i_rst_soc_n,
  output wire           flush_o,

  input  wire           data_gnt_i,
  output wire           data_req_o,
  output wire           data_we_o,
  output wire   [31:0]  data_addr_o,
  output wire   [ 3:0]  data_wstrb_o,
  output wire   [31:0]  data_wdata_o,
  input  wire           data_valid_ns_i,
  input  wire           data_valid_i,
  input  wire   [31:0]  data_rdata_i,
  input  wire           instr_gnt_i,
  output wire           instr_req_o,
  output wire   [ 1:0]  instr_req_2b_o, //* behind instr_req_o
  output wire   [31:0]  instr_addr_o,
  input  wire   [ 1:0]  instr_valid_i,
  input  wire   [63:0]  instr_rdata_i,

  output wire           o_peri_rden,
  output wire           o_peri_wren,
  output wire   [31:0]  o_peri_addr,
  output wire   [31:0]  o_peri_wdata,
  output wire   [ 3:0]  o_peri_wstrb,
  input  wire   [31:0]  i_peri_rdata,
  input  wire           i_peri_ready,
  input  wire           i_peri_gnt,

  output wire           o_irq_ack,
  output wire   [ 4:0]  o_irq_id,
  input  wire   [31:0]  i_irq_bitmap

);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire        instr_req;
  wire        data_req, data_we;
  wire        data_ready;
  wire [31:0] instr_addr, data_addr;
  reg  [31:0] r_instr_addr_delay, r_data_addr_delay;
  wire [31:0] data_rdata;
  wire        w_mem_req, w_peri_req;
  reg         peri_ready_delay;
  reg  [31:0] peri_rdata_delay;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  assign w_mem_req    = data_addr_o[31:28] == 4'b0 && data_req;
  assign w_peri_req   = data_addr_o[31:28] != 4'b0 && data_req;
  always_ff @(posedge i_clk) begin
    r_data_addr_delay   <= (data_req & data_gnt_i)? data_addr: r_data_addr_delay;
    r_instr_addr_delay  <= (instr_req & instr_gnt_i)? instr_addr: r_instr_addr_delay;
  end

  assign instr_req_o  = instr_req & instr_gnt_i;
  assign instr_addr_o = instr_gnt_i? instr_addr: r_instr_addr_delay;
  assign data_req_o   = data_gnt_i & w_mem_req & ~data_we; 
  assign data_we_o    = data_gnt_i & w_mem_req & data_we; 
  assign data_addr_o  = data_gnt_i? data_addr: r_data_addr_delay;

  assign o_peri_rden  = data_gnt_i & w_peri_req & ~data_we;
  assign o_peri_wren  = data_gnt_i & w_peri_req & data_we;
  assign o_peri_addr  = data_addr_o;
  assign o_peri_wdata = data_wdata_o;
  assign o_peri_wstrb = data_wstrb_o;

  // assign data_ready    = data_valid_i | i_peri_ready;
  // assign data_rdata    = data_valid_i? data_rdata_i: i_peri_rdata;
  assign data_ready    = data_valid_i | peri_ready_delay;
  assign data_rdata    = data_valid_i? data_rdata_i: peri_rdata_delay;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      peri_ready_delay    <= '0;
    end
    else begin
      peri_ready_delay    <= i_peri_ready;
      peri_rdata_delay    <= i_peri_rdata;
    end
  end

  NanoCore
  #(
    .PROGADDR_RESET (32'h180  ),
    .PROGADDR_IRQ   (32'b0    )
  ) NanoCore(
    .clk              (i_clk          ),
    .resetn           (i_rst_n        ),
    .resetn_soc       (i_rst_soc_n    ),
    .flush_o          (flush_o        ),
    .trap             (               ),

    .data_gnt_i       (data_gnt_i     ),
    .data_req_o       (data_req       ),
    .data_we_o        (data_we        ),
    .data_addr_o      (data_addr      ),
    .data_wstrb_o     (data_wstrb_o   ),
    .data_wdata_o     (data_wdata_o   ),
    .data_ready_ns_i  (data_valid_ns_i),
    .data_ready_i     (data_ready     ),
    .data_rdata_i     (data_rdata     ),
    .instr_gnt_i      (instr_gnt_i    ),
    .instr_req_o      (instr_req      ),
    .instr_req_2b_o   (instr_req_2b_o ),
    .instr_addr_o     (instr_addr     ),
    .instr_ready_i    (instr_valid_i  ),
    .instr_rdata_i    (instr_rdata_i  ),

    .i_irq            (i_irq_bitmap   ),
    .o_irq_ack        (o_irq_ack      ),
    .o_irq_id         (o_irq_id       )
  );

endmodule