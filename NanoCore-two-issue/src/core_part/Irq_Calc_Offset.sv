/*************************************************************/
//  Module name: ALU of Mul & Div
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/02/19
//  Function outline: mul & div for NanoCore
/*************************************************************/

module 	irq_calc_offset (
	input clk, resetn,

	input      [31:0] 	irq,
	input      [31:0] 	irq_mask,
	output reg [4:0] 	irq_offset
);

	reg [31:0] 	irq_pending;
	reg [4:0]	irq_base_offset;
	reg [7:0]	segment_irq_pending;
	always_ff @(posedge clk or negedge resetn) begin
		if(!resetn) begin
			irq_offset 			<= 'b0;
			irq_pending			<= 'b0;
			segment_irq_pending	<= 'b0;
			irq_base_offset		<= 'b0;
		end
		else begin
			// irq_pending			<= (irq_pending | irq ) & irq_mask;
			irq_pending			<= irq & irq_mask;
			segment_irq_pending	<= (|irq_pending[7:0])? irq_pending[7:0]:
									(|irq_pending[15:8])? irq_pending[15:8]:
									(|irq_pending[23:16])? irq_pending[23:16]: 
									(|irq_pending[31:24])? irq_pending[31:24]: 32'b0;
			irq_base_offset		<= (|irq_pending[7:0])? 5'd0:
									(|irq_pending[15:8])? 5'd8:
									(|irq_pending[23:16])? 5'd16: 5'd24;
			
			casez(segment_irq_pending)
				8'b0000_0000:	irq_offset <= 5'd0;
				8'b????_???1:	irq_offset <= irq_base_offset + 5'd0;
				8'b????_??10:	irq_offset <= irq_base_offset + 5'd1;
				8'b????_?100:	irq_offset <= irq_base_offset + 5'd2;
				8'b????_1000:	irq_offset <= irq_base_offset + 5'd3;
				8'b???1_0000:	irq_offset <= irq_base_offset + 5'd4;
				8'b??10_0000:	irq_offset <= irq_base_offset + 5'd5;
				8'b?100_0000:	irq_offset <= irq_base_offset + 5'd6;
				8'b1000_0000:	irq_offset <= irq_base_offset + 5'd7;
			endcase
		end
	end

endmodule