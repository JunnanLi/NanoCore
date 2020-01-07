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

module test_for_TuMan32();
	reg clk = 1;
	reg resetn = 0;
	
	/** clk */
	always #5 clk = ~clk;
	/** reset */
	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end
	
	reg [1023:0] firmware_file;
	initial begin
		if (!$value$plusargs("firmware=%s", firmware_file))
			firmware_file = "/home/lijunnan/code/code_of_hw/1-vivado_project/openbox/OpenBox_TuMan/OpenBox_S4.srcs/sources_1/user/um_xilinx/TuMan/firmware.hex";
		// $readmemh(firmware_file, genData.memory);
	end


	wire 		data_in_valid, data_out_valid;
	wire[133:0]	data_in, data_out;

um UM(
	.clk(clk),
	.rst_n(resetn),
	.um_timestamp(),
	.pktin_data_wr(data_in_valid),
	.pktin_data(data_in),
	.pktin_data_valid(),
	.pktin_data_valid_wr(),
	.pktin_ready(),
	.pktout_data_wr(data_out_valid),
	.pktout_data(data_out),
	.pktout_data_valid(),
	.pktout_data_valid_wr(),
	.pktout_ready(),

	.dma2um_data(),
	.dma2um_data_wr(),
	.um2dma_ready(),
	.um2dma_data(),
	.um2dma_data_wr(),
	.dma2um_ready(),

	.um2me_key_wr(),
	.um2me_key_valid(),
	.um2match_key(),
	.um2me_ready(),

	.me2um_id_wr(),
	.match2um_id(),
	.um2match_gme_alful(),

	.ctrl_valid(),
	.ctrl2um_cs_n(),
	.um2ctrl_ack_n(),
	.ctrl_cmd(),
	.ctrl_datain(),
	.ctrl_addr(),
	.ctrl_dataout()
);

gen_data genData(
	.clk(clk),
	.resetn(resetn),

	.data_in_valid(data_in_valid),
	.data_in(data_in),
	.data_out_valid(data_out_valid),
	.data_out(data_out)
);

endmodule

