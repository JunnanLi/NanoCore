 /*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2019.12.01
 *  Description: This module is used to configure itcm and dtcm of CPU, 
 *   and output "print" in program running on cpu.
 *
 *  To AoTuman, my dear cat, thanks for your company.
 */

`timescale 1 ns / 1 ps

/** Please toggle following comment (i.e., `define FPGA_ALTERA) if you 
 **  use an Alater (Intel) FPGA
 **/
`define FPGA_ALTERA

module conf_mem(
input               clk,
input               resetn,

input               dataIn_valid_i,     // input data valid
input       [133:0] dataIn_i,           // input data, the format is 
                                        //  according to fast project 
                                        //  (www.http://www.fastswitch.org/)
output  reg         dataOut_valid_o,    // output data valid
output  reg [133:0] dataOut_o,          // output data

output  reg         conf_rden_itcm_o,    // configure itcm of CPU
output  reg         conf_wren_itcm_o,
output  reg [31:0]  conf_addr_itcm_o,
output  reg [31:0]  conf_wdata_itcm_o,
input       [31:0]  conf_rdata_itcm_i,

output  reg         conf_sel_dtcm_o,    // configure dtcm of CPU
output  reg         conf_rden_dtcm_o,
output  reg         conf_wren_dtcm_o,
output  reg [31:0]  conf_addr_dtcm_o,
output  reg [31:0]  conf_wdata_dtcm_o,
input       [31:0]  conf_rdata_dtcm_i,

input               print_valid_i,      // output "print" in software program
input       [7:0]   print_value_i
);


/** state_conf is used to configure (read or write) itcm and dtcm
*   stat_out is used to output "print" in the program running on CPU
*/
reg [3:0]   state_conf, state_out;
parameter   IDLE_S      = 4'd0,
            READ_META_1 = 4'd1,
            READ_HEAD_0 = 4'd2,
            WR_SEL_S    = 4'd3,
            RD_SEL_S    = 4'd4,
            WR_PROG_S   = 4'd5,
            RD_PROG_S   = 4'd6,
            DISCARD_S   = 4'd7,
            SEND_META_0 = 4'd1,
            SEND_META_1 = 4'd2,
            SEND_HEAD_0 = 4'd3,
            SEND_HEAD_1 = 4'd4,
            SEND_HEAD_2 = 4'd5,
            SEND_HEAD_3 = 4'd6,
            SEND_PKT_S  = 4'd7;

/** read_sel_tag is used to identify whether need to read "sel", i.e., 
*       running mode of CPU
*/
reg         read_sel_tag[1:0];

/** state machine for configuring itcm and dtcm:
*       1) distinguish action type according to ethernet_type filed;
*       2) configure running mode, i.e., "conf_sel_dtcm", 1 is configure, 
*           while 0 is running;
*       3) read running mode, i.e., toggle "read_sel_tag[0]";
*       4) write program, including itcm and dtcm;
*       5) read program, including itcm and dtcm;
*/
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        // reset
        conf_rden_itcm_o    <= 1'b0;
        conf_wren_itcm_o    <= 1'b0;
        conf_addr_itcm_o    <= 32'b0;
        conf_wdata_itcm_o   <= 32'b0;
        conf_sel_dtcm_o     <= 1'b1;
        conf_rden_dtcm_o    <= 1'b0;
        conf_wren_dtcm_o    <= 1'b0;
        conf_addr_dtcm_o    <= 32'b0;
        conf_wdata_dtcm_o   <= 32'b0;

        state_conf          <= IDLE_S;
        read_sel_tag[0]     <= 1'b0;
    end
    else begin
        case(state_conf)
            IDLE_S: begin
                conf_wren_itcm_o    <= 1'b0;
                conf_wren_dtcm_o    <= 1'b0;
                if((dataIn_valid_i == 1'b1)&&(dataIn_i[133:132] == 2'b01)) begin
                    state_conf      <= READ_META_1;
                end
                else begin
                    state_conf      <= IDLE_S;
                end
            end
            READ_META_1: begin
                state_conf          <= READ_HEAD_0;
            end
            READ_HEAD_0: begin
                /** write sel */
                if(dataIn_i[31:16] == 16'h9001) begin
                    state_conf      <= WR_SEL_S;
                end
                /** read sel */
                else if(dataIn_i[31:16] == 16'h9002) begin
                    state_conf      <= RD_SEL_S;
                end
                /** write program */
                else if(dataIn_i[31:16] == 16'h9003) begin
                    state_conf      <= WR_PROG_S;
                end
                /** read program */
                else if(dataIn_i[31:16] == 16'h9004) begin
                    state_conf      <= RD_PROG_S;
                end
                else begin
                    state_conf      <= DISCARD_S;
                end
            end
            WR_SEL_S: begin
                conf_sel_dtcm_o     <= dataIn_i[16];
                state_conf          <= DISCARD_S;
                // gen_ack_tag[0] <= ~gen_ack_tag[0];
            end
            RD_SEL_S: begin
                state_conf          <= DISCARD_S;
                read_sel_tag[0]     <= ~read_sel_tag[0];
            end
            WR_PROG_S: begin
                // if(dataIn_i[27] == 1'b1)
                //     {conf_wren_itcm_o, conf_wren_dtcm_o} <= 2'b01;
                // else
                //     {conf_wren_itcm_o, conf_wren_dtcm_o} <= 2'b10;
                {conf_wren_itcm_o, conf_wren_dtcm_o} <= 2'b11;
                conf_addr_itcm_o    <= dataIn_i[47:16];
                conf_wdata_itcm_o   <= dataIn_i[79:48];
                conf_addr_dtcm_o    <= dataIn_i[47:16];
                conf_wdata_dtcm_o   <= dataIn_i[79:48];

                if(dataIn_i[133:132] == 2'b10) begin
                    state_conf      <= IDLE_S;
                end
                else begin
                    state_conf      <= WR_PROG_S;
                end
            end
            RD_PROG_S: begin
                state_conf          <= DISCARD_S;
                conf_rden_itcm_o    <= 1'b1;
                conf_addr_itcm_o    <= dataIn_i[47:16];
                conf_rden_dtcm_o    <= 1'b1;
                conf_addr_dtcm_o    <= dataIn_i[47:16];
            end
            DISCARD_S: begin
                conf_rden_itcm_o    <= 1'b0;
                conf_rden_dtcm_o    <= 1'b0;
                if(dataIn_i[133:132] == 2'b10)
                    state_conf      <= IDLE_S;
                else
                    state_conf      <= DISCARD_S;
            end
            default: begin
                state_conf          <= IDLE_S;
            end
        endcase
    end
end


/** register and wire */
reg [31:0]  addr_temp[1:0]; // maintain address for reading program;
reg         rden_temp[1:0]; // maintain action type;
reg         rdreq_rdata;    // fifo interface of reading program
wire        empty_rdata;    
wire[95:0]  q_rdata;        
reg         rdreq_value;    // fifo interface of outputing "print"
wire        empty_value;
wire[7:0]   q_value;
wire[8:0]   usedw_value;
wire        pad;
reg [9:0]   clk_count_value;// read value fifo every 1000 clocks;
reg [8:0]   count_value;    // number of valid value in the packet;
reg [11:0]  pkt_length;     // packet length include metadata;
reg [3:0]   count_head;     // number of value in the one head;

/** state machine used for maintaining address and action type of reading 
 ** program
 **/
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        // reset
        addr_temp[0] <= 32'b0;
        addr_temp[1] <= 32'b0;
        rden_temp[0] <= 1'b0;
        rden_temp[1] <= 1'b0;

        clk_count_value <= 9'd0;
    end
    else begin
        addr_temp[0] <= conf_addr_itcm_o;
        addr_temp[1] <= addr_temp[0];
        rden_temp[0] <= conf_rden_itcm_o;
        rden_temp[1] <= rden_temp[0];

        clk_count_value <= 9'd1 + clk_count_value;
    end
end

/** fifo used to buffer reading result*/
`ifdef FPGA_ALTERA
    fifo rdata_buffer(
        .aclr(!resetn),
        .clock(clk),
        .data({conf_rdata_itcm_i, conf_rdata_dtcm_i, addr_temp[1]}),
        .rdreq(rdreq_rdata),
        .wrreq(rden_temp[1]),
        .empty(empty_rdata),
        .full(),
        .q(q_rdata),
        .usedw()
    );
    defparam
        rdata_buffer.width = 96,
        rdata_buffer.depth = 6,
        rdata_buffer.words = 64;
`else
    fifo_96_64 rdata_buffer(
        .clk(clk),
        .srst(!resetn),
        .din({conf_rdata_itcm_i, conf_rdata_dtcm_i, addr_temp[1]}),
        .wr_en(rden_temp[1]),
        .rd_en(rdreq_rdata),
        .dout(q_rdata),
        .full(),
        .empty(empty_rdata)
    );
`endif

/** fifo used to buffer "print" value*/
`ifdef FPGA_ALTERA
    fifo value_buffer(
        .aclr(!resetn),
        .clock(clk),
        .data(print_value_i),
        .rdreq(rdreq_value),
        .wrreq(print_valid_i),
        .empty(empty_value),
        .full(),
        .q(q_value),
        .usedw(usedw_value)
    );
    defparam
        value_buffer.width = 8,
        value_buffer.depth = 9,
        value_buffer.words = 512;
`else
    fifo_8_512 value_buffer(
        .clk(clk),
        .srst(!resetn),
        .din(print_value_i),
        .wr_en(print_valid_i),
        .rd_en(rdreq_value),
        .dout(q_value),
        .full(),
        .empty(empty_value),
        .data_count(usedw_value)
    );
`endif

/** state machine used to output reading result or print value:
*       1) configure metadata_0&1 (according to fast packet format);
*       2) output reading result or print value which is distinguished
*           by ethernet_type filed;
*/
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        // reset
        dataOut_valid_o <= 1'b0;
        dataOut_o       <= 134'b0;
        read_sel_tag[1] <= 1'b0;
        count_value     <= 9'b0;
        count_head      <= 4'b0;
        pkt_length      <= 12'b0;

        rdreq_rdata     <= 1'b0;
        rdreq_value     <= 1'b0;
    end
    else begin
        case(state_out)
            IDLE_S: begin
                count_value     <= 9'b0;
                dataOut_valid_o <= 1'b0;
                if(read_sel_tag[1] != read_sel_tag[0] || empty_rdata == 1'b0) begin
                    pkt_length  <= 12'd96;
                    state_out   <= SEND_META_0;
                end
                else if(empty_value == 1'b0 && clk_count_value == 0) begin
                    pkt_length  <= 12'd96 + {3'b0,(usedw_value[8:4]+5'd1),4'b0};
                    count_value <= usedw_value;
                    state_out   <= SEND_META_0;
                end
                else begin
                    state_out   <= IDLE_S;
                end
            end
            SEND_META_0: begin
                dataOut_valid_o <= 1'b1;
                dataOut_o       <= {2'b01,4'b0,1'b0,1'b0,6'b0,2'b0,6'd0,3'b0,1'b0,pkt_length,96'b0};
                state_out       <= SEND_META_1;
            end
            SEND_META_1: begin
                dataOut_o       <= {2'b11,4'b0,128'b0};
                state_out       <= SEND_HEAD_0;
            end
            SEND_HEAD_0: begin
                if(read_sel_tag[1] != read_sel_tag[0]) begin
                    dataOut_o[31:0] <= {16'h9002,16'd1};
                end
                else if(empty_rdata == 1'b0) begin
                    dataOut_o[31:0] <= {16'h9004,16'b0};
                    rdreq_rdata     <= 1'b1;
                end
                else begin
                    dataOut_o[31:0] <= {16'h9005,7'b0,count_value};
                    rdreq_value     <= 1'b0;
                end
                state_out           <= SEND_HEAD_1;
                dataOut_o[133:32]   <= {2'b11,4'b0,48'd1,48'd2};                
            end
            SEND_HEAD_1: begin
                rdreq_rdata         <= 1'b0;
                rdreq_value         <= 1'b0;
                if(read_sel_tag[1] != read_sel_tag[0]) begin
                    dataOut_o[111:16]<= {95'b0,conf_sel_dtcm_o};
                    read_sel_tag[1] <= read_sel_tag[0];
                end
                else if(rdreq_rdata == 1'b1)
                    dataOut_o[111:16]<= q_rdata;
                else
                    dataOut_o[111:16]<= 96'b0;
                dataOut_o[133:112]  <= {2'b11,4'b0,16'b0};
                dataOut_o[15:0]     <= 16'b0;
                state_out           <= SEND_HEAD_2;
            end
            SEND_HEAD_2: begin
                dataOut_o           <= {2'b11,4'b0,128'd1};
                state_out           <= SEND_HEAD_3;
            end
            SEND_HEAD_3: begin
                if(count_value == 9'd0) begin
                    state_out       <= IDLE_S;
                    dataOut_o       <= {2'b10,4'b0,128'd2};
                end
                else begin
                    state_out       <= SEND_PKT_S;
                    dataOut_o       <= {2'b11,4'b0,128'd2};
                    rdreq_value     <= 1'b1;
                    count_value     <= count_value - 9'd1;
                    count_head      <= 4'b0;
                end
            end
            SEND_PKT_S: begin
                count_value         <= count_value - 9'd1;
                count_head          <= count_head + 4'd1;
                dataOut_o[127:0]    <= dataOut_o[127:0];
                (* full_case *)
                case(count_head)
                    4'd0:   dataOut_o[127:120]  <= q_value;
                    4'd1:   dataOut_o[119:112]  <= q_value;
                    4'd2:   dataOut_o[111:104]  <= q_value;
                    4'd3:   dataOut_o[103:96]   <= q_value;
                    4'd4:   dataOut_o[95:88]    <= q_value;
                    4'd5:   dataOut_o[87:80]    <= q_value;
                    4'd6:   dataOut_o[79:72]    <= q_value;
                    4'd7:   dataOut_o[71:64]    <= q_value;
                    4'd8:   dataOut_o[63:56]    <= q_value;
                    4'd9:   dataOut_o[55:48]    <= q_value;
                    4'd10:  dataOut_o[47:40]    <= q_value;
                    4'd11:  dataOut_o[39:32]    <= q_value;
                    4'd12:  dataOut_o[31:24]    <= q_value;
                    4'd13:  dataOut_o[23:16]    <= q_value;
                    4'd14:  dataOut_o[15:8]     <= q_value;
                    4'd15:  dataOut_o[7:0]      <= q_value;
                endcase
                if(count_value == 9'd0) begin
                    rdreq_value         <= 1'b0;
                    dataOut_o[133:128]  <= {2'b10,4'b0};
                    state_out           <= IDLE_S;
                end
                else begin
                    rdreq_value         <= 1'b1;
                    dataOut_o[133:128]  <= {2'b11,4'b0};
                    state_out           <= SEND_PKT_S;
                end
                if(count_head == 4'd15 || count_value == 9'd0)
                    dataOut_valid_o     <= 1'b1;
                else
                    dataOut_valid_o     <= 1'b0;
            end
            default: begin
                state_out <= IDLE_S;
            end
        endcase
    end
end


endmodule