/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2020.07.01
 *  Description: This module is the top module.
 *  Modification: Simplify memory management. 
 *
 *  To AoTuman, my dear cat, thanks for your company.
 */
 `timescale 1 ns / 1 ps

module TuMan32_top(
    input                   clk,
    input                   resetn,
    // interface for configuring itcm
    input                   conf_rden_itcm_i,
    input                   conf_wren_itcm_i,
    input           [31:0]  conf_addr_itcm_i,
    input           [31:0]  conf_wdata_itcm_i,
    output  wire    [31:0]  conf_rdata_itcm_o,
    // interface for configuring dtcm
    input                   conf_sel_dtcm_i,
    input                   conf_rden_dtcm_i,
    input                   conf_wren_dtcm_i,
    input           [31:0]  conf_addr_dtcm_i,
    input           [31:0]  conf_wdata_dtcm_i,
    output  wire    [31:0]  conf_rdata_dtcm_o,
    // interface for outputing "print"
    output  wire            print_valid_o,
    output  wire    [7:0]   print_value_o,
    // interface for accessing ram in pipeline
    input                   dataIn_valid_i,
    input           [133:0] dataIn_i,
    output  wire            dataOut_valid_o,
    output  wire    [133:0] dataOut_o
);

/** sram interface for instruction and data*/
    (* mark_debug = "true" *)wire           mem_rinst_1b;           //  read request
    (* mark_debug = "true" *)wire [31:0]    mem_rinst_addr_32b;     //  read addr
    (* mark_debug = "true" *)wire [31:0]    mem_rdata_instr_32b;    //  instruction
    wire        mem_wren_1b;    //  write data request
    wire        mem_rden_1b;    //  read data request
    wire [31:0] mem_addr_32b;    //  write/read addr
    wire [31:0] mem_wdata_32b;  //  write data
    wire [3:0]  mem_wstrb_4b;                  //  write wstrb
    wire [31:0] mem_rdata_32b;  //  data

/** mux of writing by conf or dtcm*/
    // wire         conf_wren_itcm_mux, conf_wren_d2i;
    // wire [31:0]  conf_addr_itcm_mux, conf_addr_d2i;
    // wire [31:0]  conf_wdata_itcm_mux, conf_wdata_d2i;

    // assign conf_wren_itcm_mux = conf_sel_dtcm? conf_wren_itcm: conf_wren_d2i;
    // assign conf_addr_itcm_mux = conf_sel_dtcm? conf_addr_itcm: conf_addr_d2i;
    // assign conf_wdata_itcm_mux = conf_sel_dtcm? conf_wdata_itcm: conf_wdata_d2i;

TuMan_core TuMan32(
    .clk(clk),
    .resetn(resetn&~conf_sel_dtcm_i),
    .finish(),

    .mem_rinst(mem_rinst_1b),
    .mem_rinst_addr(mem_rinst_addr_32b),
    .mem_rdata_instr(mem_rdata_instr_32b),

    .mem_wren(mem_wren_1b),
    .mem_rden(mem_rden_1b),
    .mem_addr(mem_addr_32b),
    .mem_wdata(mem_wdata_32b),
    .mem_wstrb(mem_wstrb_4b),
    .mem_rdata(mem_rdata_32b),

    .trace_valid(),
    .trace_data()
);

mem_instr ITCM(
    .clk(clk),
    .resetn(resetn),

    .mem_valid_i(mem_rinst_1b),
    .mem_addr_i({2'b0,mem_rinst_addr_32b[31:2]}),
    .mem_rdata_instr_o(mem_rdata_instr_32b),

    .conf_rden_i(conf_rden_itcm_i),
    .conf_wren_i(conf_wren_itcm_i),
    .conf_addr_i(conf_addr_itcm_i),
    .conf_wdata_i(conf_wdata_itcm_i),
    .conf_rdata_o(conf_rdata_itcm_o)
);

mem_data DTCM(
    .clk(clk),
    .resetn(resetn),
    // .mem_valid_i(mem_wren_1b|mem_rden_1b),
    .mem_rden_i(mem_rden_1b),
    .mem_wren_i(mem_wren_1b),
    .mem_addr_i({2'b0,mem_addr_32b[31:2]}),
    .mem_wdata_i(mem_wdata_32b),
    .mem_wstrb_i(mem_wstrb_4b),
    .mem_rdata_o(mem_rdata_32b),

    .conf_rden_i(conf_rden_dtcm_i),
    .conf_wren_i(conf_wren_dtcm_i),
    .conf_addr_i(conf_addr_dtcm_i),
    .conf_wdata_i(conf_wdata_dtcm_i),
    .conf_rdata_o(conf_rdata_dtcm_o),
   
    .dataIn_valid_i(dataIn_valid_i),
    .dataIn_i(dataIn_i),
    .dataOut_valid_o(dataOut_valid_o),
    .dataOut_o(dataOut_o),

    .print_valid_o(print_valid_o),
    .print_value_o(print_value_o)
);

endmodule

