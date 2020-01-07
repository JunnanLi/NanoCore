/*
 *  TuMan32 -- A Small but pipelined RISC-V (RV32I) Processor Core
 *
 *  Copyright (C) 2019-2020  Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *	To AoTuman, my dear cat, thanks for your company.
 */

 `timescale 1 ns / 1 ps

module TuMan32_top(
	input					clk,
	input 					resetn,

	input					conf_rden_itcm,
	input					conf_wren_itcm,
	input			[31:0]	conf_addr_itcm,
	input			[31:0]	conf_wdata_itcm,
	output	wire 	[31:0]	conf_rdata_itcm,

	input					conf_sel_dtcm,
	input					conf_rden_dtcm,
	input					conf_wren_dtcm,
	input			[31:0]	conf_addr_dtcm,
	input			[31:0]	conf_wdata_dtcm,
	output	wire 	[31:0]	conf_rdata_dtcm,
	output 	wire 			print_valid,
	output 	wire 	[7:0]	print_value
);

/** sram interface for instruction and data*/
	wire 		mem_rinst;			//	read request
	wire [31:0]	mem_rinst_addr;		//	read addr
	wire [31:0]	mem_rdata_instr;	//	instruction
	wire 		mem_wren;			//	write data request
	wire 		mem_rden;			//	read data request
	wire [31:0]	mem_addr;			//	write/read addr
	wire [31:0]	mem_wdata;			//	write data
	wire [3:0]	mem_wstrb;			//	write wstrb
	wire [31:0]	mem_rdata;			//	data
//	wire 		ready_dtcm;			//	ready of dtcm


TuMan_core TuMan32(
	.clk(clk),
	.resetn(resetn&~conf_sel_dtcm),
	.finish(),

	.mem_rinst(mem_rinst),
	.mem_rinst_addr(mem_rinst_addr),
	.mem_rdata_instr(mem_rdata_instr),

	.mem_wren(mem_wren),
	.mem_rden(mem_rden),
	.mem_addr(mem_addr),
	.mem_wdata(mem_wdata),
	.mem_wstrb(mem_wstrb),
	.mem_rdata(mem_rdata),

	.trace_valid(),
	.trace_data()
);

mem_instr ITCM(
	.clk(clk),
	.resetn(resetn),

	.mem_rinst(mem_rinst),
	.mem_rinst_addr({2'b0,mem_rinst_addr[31:2]}),
	.mem_rdata_instr(mem_rdata_instr),

	.conf_rden(conf_rden_itcm),
	.conf_wren(conf_wren_itcm),
	.conf_addr(conf_addr_itcm),
	.conf_wdata(conf_wdata_itcm),
	.conf_rdata(conf_rdata_itcm)
);

mem_data DTCM(
	.clk(clk),
	.resetn(resetn),
	.mem_wren(mem_wren),
	.mem_rden(mem_rden),
	.mem_addr({2'b0,mem_addr[31:2]}),
	.mem_wdata(mem_wdata),
	.mem_wstrb(mem_wstrb),
	.mem_rdata(mem_rdata),
	.ready(),

	.conf_sel(conf_sel_dtcm),
	.conf_rden(conf_rden_dtcm),
	.conf_wren(conf_wren_dtcm),
	.conf_addr(conf_addr_dtcm),
	.conf_wdata(conf_wdata_dtcm),
	.conf_rdata(conf_rdata_dtcm),

	.print_valid(print_valid),
	.print_value(print_value)
);


endmodule

