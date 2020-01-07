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


module um #(
	parameter    PLATFORM = "Xilinx"
)(
	input clk,
	input [63:0] um_timestamp,
	input rst_n,
    
	//cpu or port
	input  pktin_data_wr,
	input  [133:0] pktin_data,
	input  pktin_data_valid,
	input  pktin_data_valid_wr,
	output reg pktin_ready,//pktin_ready = um2port_alf
		
	output reg pktout_data_wr,
	output reg [133:0] pktout_data,
	output reg pktout_data_valid,
	output reg pktout_data_valid_wr,
	input pktout_ready,//pktout_ready = port2um_alf    

	//control path
	input [133:0] dma2um_data,
	input dma2um_data_wr,
	output wire um2dma_ready,

	output wire [133:0] um2dma_data,
	output wire um2dma_data_wr,
	input dma2um_ready,
    //(*mark_debug = "true"*)    	
	//to match
	output reg um2me_key_wr,
	output reg um2me_key_valid,
	output reg [511:0] um2match_key,
	input um2me_ready,//um2me_ready = ~match2um_key_alful

	//from match
	input me2um_id_wr,
	input [15:0] match2um_id,
	output reg um2match_gme_alful,
	//localbus
	input ctrl_valid,  
	input ctrl2um_cs_n,
	output reg um2ctrl_ack_n,
	input ctrl_cmd,//ctrl2um_rd_wr,//0 write 1:read
	input [31:0] ctrl_datain,//ctrl2um_data_in,
	input [31:0] ctrl_addr,//ctrl2um_addr,
	output reg [31:0] ctrl_dataout//um2ctrl_data_out
);
 

assign um2dma_data = dma2um_data;
assign um2dma_data_wr = dma2um_data_wr;
assign um2dma_ready = dma2um_ready;

/*********************************************************/
/**state for initializing UM2GEM*/
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
	// reset
		um2match_gme_alful <= 1'b0;
		um2me_key_wr <= 1'b0;
		um2me_key_valid <= 1'b0;
		um2match_key <= 512'b0;
		um2ctrl_ack_n <= 1'b1;
		ctrl_dataout <= 32'b0;
	end
	else begin
	end
end

reg			phv_in_valid;
reg	[943:0]	phv_in;
wire		phv_out_valid;
wire[943:0]	phv_out;

reg 		wren_rule;
reg			rden_rule;
reg	[5:0]	addr_rule;
reg [192:0]	data_rule;
wire		rdata_rule_valid;
wire[192:0]	rdata_rule;




	wire 		conf_rden_itcm, conf_wren_itcm, conf_rden_dtcm, conf_wren_dtcm;
	wire [31:0]	conf_addr_itcm, conf_wdata_itcm, conf_rdata_itcm;
	wire [31:0]	conf_addr_dtcm, conf_wdata_dtcm, conf_rdata_dtcm;
	wire 		conf_sel_dtcm;
	wire 		pktout_data_wr_temp;
	wire [133:0]pktout_data_temp;
	wire 		print_valid;
	wire [7:0]	print_value;

TuMan32_top tm(
	.clk(clk),
	.resetn(rst_n),

	.conf_rden_itcm(conf_rden_itcm),
	.conf_wren_itcm(conf_wren_itcm),
	.conf_addr_itcm(conf_addr_itcm),
	.conf_wdata_itcm(conf_wdata_itcm),
	.conf_rdata_itcm(conf_rdata_itcm),

	.conf_sel_dtcm(conf_sel_dtcm),
	.conf_rden_dtcm(conf_rden_dtcm),
	.conf_wren_dtcm(conf_wren_dtcm),
	.conf_addr_dtcm(conf_addr_dtcm),
	.conf_wdata_dtcm(conf_wdata_dtcm),
	.conf_rdata_dtcm(conf_rdata_dtcm),

	.print_valid(print_valid),
	.print_value(print_value)
);

conf_mem confMem(
	.clk(clk),
	.resetn(rst_n),

	.data_in_valid(pktin_data_wr),
	.data_in(pktin_data),
	.data_out_valid(pktout_data_wr_temp),
	.data_out(pktout_data_temp),

	.conf_rden_itcm(conf_rden_itcm),
	.conf_wren_itcm(conf_wren_itcm),
	.conf_addr_itcm(conf_addr_itcm),
	.conf_wdata_itcm(conf_wdata_itcm),
	.conf_rdata_itcm(conf_rdata_itcm),

	.conf_sel_dtcm(conf_sel_dtcm),
	.conf_rden_dtcm(conf_rden_dtcm),
	.conf_wren_dtcm(conf_wren_dtcm),
	.conf_addr_dtcm(conf_addr_dtcm),
	.conf_wdata_dtcm(conf_wdata_dtcm),
	.conf_rdata_dtcm(conf_rdata_dtcm),

	.print_valid(print_valid),
	.print_value(print_value)
);


always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		pktout_data_valid_wr <= 1'b0;
		pktout_data_valid <= 1'b0;
		pktout_data_wr <= 1'b0;
		pktout_data <= 134'b0;
	end
	else begin
		if((pktout_data_wr_temp == 1'b1) && (pktout_data_temp[133:132] == 2'b10)) begin
			pktout_data_valid <= 1'b1;
			pktout_data_valid_wr <= 1'b1;
		end
		else begin
			pktout_data_valid_wr <= 1'b0;
		end
		pktout_data_wr <= pktout_data_wr_temp;
		pktout_data <= pktout_data_temp;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		pktin_ready <= 1'b0;
	end
	else begin
		pktin_ready <= 1'b1;
		// if(usedw_pkt <= 8'd200) begin
			// pktin_ready <= 1'b1;
		// end
		// else begin
			// pktin_ready <= 1'b0;
		// end
	end
end


	
endmodule    