/*
 *  picoCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2020.07.01
 *  Description: This module is used to store instruction, i.e., itcm,  
 *   and data, i.e., dtcm.
 *
 *  To AoTuman, my dear cat, thanks for your company.
 */

`timescale 1 ns / 1 ps

/** Please toggle following comment (i.e., `define FPGA_ALTERA) if you 
 **  use an Alater (Intel) FPGA
 **/
`define FPGA_ALTERA
// `define USING_REGISTER

module mem_instr(
    input                   clk,
    input                   resetn,
    // interface for cpu
    input                   mem_valid_i,        // read valid
    input           [31:0]  mem_addr_i,         // addr
    output  wire    [31:0]  mem_rdata_instr_o,  // data out

    // interface for configuration
    input                   conf_rden_i,        
    input                   conf_wren_i,
    input           [31:0]  conf_addr_i,
    input           [31:0]  conf_wdata_i,
    output  wire    [31:0]  conf_rdata_o
    );

    localparam      depth_itcm   = 12,           // need to modify
                    words_itcm   = 4096;

    //* port a for cpu, port b for configuration;
    `ifdef FPGA_ALTERA
        ram sram_for_instr(
            .address_a(mem_addr_i[depth_itcm-1:0]),
            .address_b(conf_addr_i[depth_itcm-1:0]),
            .clock(clk),
            .data_a(32'b0),
            .data_b(conf_wdata_i),
            .rden_a(mem_valid_i),
            .rden_b(conf_rden_i),
            .wren_a(1'b0),
            .wren_b(conf_wren_i),
            .q_a(mem_rdata_instr_o),
            .q_b(conf_rdata_o));  
        defparam    
            sram_for_instr.width    = 32,
            sram_for_instr.depth    = depth_itcm,
            sram_for_instr.words    = words_itcm;
    `else
        ram_32_4096 sram_for_instr(
            .clka(clk),
            .wea(1'b0),
            .addra(mem_addr_i[depth_itcm-1:0]),
            .dina(32'b0),
            .douta(mem_rdata_instr_o),
            .clkb(clk),
            .web(conf_wren_i),
            .addrb(conf_addr_i[depth_itcm-1:0]),
            .dinb(conf_wdata_i),
            .doutb(conf_rdata_o)
        );
    `endif   
endmodule



module mem_data(
    input                   clk,
    input                   resetn,
    //* interface for cpu
    // input                   mem_valid_i,
    input                   mem_rden_i,
    input                   mem_wren_i,
    input           [31:0]  mem_addr_i,
    input           [3:0]   mem_wstrb_i,
    input           [31:0]  mem_wdata_i,
    output  wire    [31:0]  mem_rdata_o,
    //* interface for configuration    
    input                   conf_rden_i,
    input                   conf_wren_i,
    input           [31:0]  conf_addr_i,
    input           [31:0]  conf_wdata_i,
    output  wire    [31:0]  conf_rdata_o,
    //* for input or output packet;
    // interface for packet(dtcm)
    input                   dataIn_valid_i,
    input           [133:0] dataIn_i,   // 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
    output reg              dataOut_valid_o,
    output reg      [133:0] dataOut_o,

    // interface for outputing "print"
    output  reg             print_valid_o,  
    output  reg     [7:0]   print_value_o
);
    parameter               depth_dtcm  = 12;
    parameter               words_dtcm  = 4096;
    parameter               depth_pkt   = 9;
    parameter               words_pkt   = 512;

    //* selete one ram for writing;
    wire            [3:0]   mem_wren;   // bitmap for writing four 8b ram;
    wire                    mem_rden;   // read valid;
    wire            [31:0]  mem_rdata;  // data out;
    //* interfaces of fifo_for_recvPkt
    reg                     rdreq_pkt, wrreq_recvPkt;
    wire                    empty_pkt;
    wire            [133:0] q_pkt;
    reg             [133:0] data_recvPkt;
    wire            [8:0]   usedw_pkt;
    //* interfaces of ram_for_Pkt
    reg             [depth_pkt-1:0] addr_pkt;
    reg             [127:0]         data_pkt;
    reg                             rden_pkt, wren_pkt;
    wire            [127:0]         ctx_pkt;
    wire                            mem_wren_pkt[3:0];
    wire            [31:0]          mem_rdata_pkt[3:0];
    reg             [31:0]          mem_addr_temp[1:0];

    // mux of configuration or cpu writing
    assign mem_wren[0]  = (mem_wstrb_i[0] && mem_addr_i[14] == 1'b0)? mem_wren_i: 1'b0;
    assign mem_wren[1]  = (mem_wstrb_i[1] && mem_addr_i[14] == 1'b0)? mem_wren_i: 1'b0;
    assign mem_wren[2]  = (mem_wstrb_i[2] && mem_addr_i[14] == 1'b0)? mem_wren_i: 1'b0;
    assign mem_wren[3]  = (mem_wstrb_i[3] && mem_addr_i[14] == 1'b0)? mem_wren_i: 1'b0;
    assign mem_wren_pkt[0]  = (mem_wren_i && mem_addr_i[14] && mem_addr_i[1:0] == 2'd3)? 1'b1: 1'b0;
    assign mem_wren_pkt[1]  = (mem_wren_i && mem_addr_i[14] && mem_addr_i[1:0] == 2'd2)? 1'b1: 1'b0;
    assign mem_wren_pkt[2]  = (mem_wren_i && mem_addr_i[14] && mem_addr_i[1:0] == 2'd1)? 1'b1: 1'b0;
    assign mem_wren_pkt[3]  = (mem_wren_i && mem_addr_i[14] && mem_addr_i[1:0] == 2'd0)? 1'b1: 1'b0;

    assign mem_rden     =   mem_rden_i;

    assign mem_rdata_o  =   (mem_addr_temp[1][14] && mem_addr_temp[1][1:0] == 2'b0)? mem_rdata_pkt[3]:
                            (mem_addr_temp[1][14] && mem_addr_temp[1][1:0] == 2'd1)? mem_rdata_pkt[2]:
                            (mem_addr_temp[1][14] && mem_addr_temp[1][1:0] == 2'd2)? mem_rdata_pkt[1]:
                            (mem_addr_temp[1][14] && mem_addr_temp[1][1:0] == 2'd3)? mem_rdata_pkt[0]:
                            mem_rdata;

    //* maintain mem_addr;
    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            mem_addr_temp[0]       <= 32'b0;
            mem_addr_temp[1]       <= 32'b0;
        end
        else begin
            mem_addr_temp[0]    <= mem_addr_i;          // valid before wait_2_clk;
            mem_addr_temp[1]    <= mem_addr_temp[0];    // valid before read_ram;
        end
    end

    //* port a for cinfiguration, port b for cpu;
    genvar i_ram;
    generate
        for (i_ram = 0; i_ram < 4; i_ram = i_ram+1) begin: ram_data
            `ifdef FPGA_ALTERA
                ram sram_for_data(
                    .clock(clk),
                    .address_a(conf_addr_i[depth_dtcm-1:0]),
                    .data_a(conf_wdata_i[i_ram*8+7:i_ram*8]),
                    .rden_a(conf_rden_i),
                    .wren_a(conf_wren_i),
                    .q_a(conf_rdata_o[i_ram*8+7:i_ram*8]),

                    .address_b(mem_addr_i[depth_dtcm-1:0]),
                    .data_b(mem_wdata_i[i_ram*8+7:i_ram*8]),
                    .rden_b(mem_rden),
                    .wren_b(mem_wren[i_ram]),
                    .q_b(mem_rdata[i_ram*8+7:i_ram*8]));
                defparam    
                    sram_for_data.width = 8,
                    sram_for_data.depth = depth_dtcm,
                    sram_for_data.words = words_dtcm;
            `else
                ram_8_4096 sram_for_data(
                    .clka(clk),
                    .wea(conf_wren_i),
                    .addra(conf_addr_i[depth_dtcm-1:0]),
                    .dina(conf_wdata_i[i_ram*8+7:i_ram*8]),
                    .douta(conf_rdata_o[i_ram*8+7:i_ram*8]),
                    .clkb(clk),
                    .web(mem_wren[i_ram]),
                    .addrb(mem_addr_i[depth_dtcm-1:0]),
                    .dinb(mem_wdata_i[i_ram*8+7:i_ram*8]),
                    .doutb(mem_rdata[i_ram*8+7:i_ram*8]) );
            `endif
        end
    endgenerate

    `ifdef FPGA_ALTERA
        fifo fifo_for_recvPkt(
            .aclr(!resetn),
            .clock(clk),
            .data(data_recvPkt),
            .rdreq(rdreq_pkt),
            .wrreq(wrreq_recvPkt),
            .empty(empty_pkt),
            .full(),
            .q(q_pkt),
            .usedw(usedw_pkt)
        );
        defparam
            fifo_for_recvPkt.width = 134,
            fifo_for_recvPkt.depth = 9,
            fifo_for_recvPkt.words = 512;
    `else
        fifo_134_512 fifo_for_recvPkt(
            .clk(clk),
            .srst(!resetn),
            .din(data_recvPkt),
            .wr_en(wrreq_recvPkt),
            .rd_en(rdreq_pkt),
            .dout(q_pkt),
            .full(),
            .empty(empty_pkt),
            .data_count(usedw_pkt)
        );
    `endif
    //* input recvPkt fifo;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wrreq_recvPkt   <= 1'b0;
            data_recvPkt    <= 134'b0;
        end
        else begin
            data_recvPkt        <= dataIn_i;
            if(dataIn_i[133:132] == 2'b01 && usedw_pkt < 9'd400)
                wrreq_recvPkt   <= dataIn_valid_i;
            else
                wrreq_recvPkt   <= dataIn_valid_i&wrreq_recvPkt;
        end
    end

    //* port a for pkt, port b for cpu;
    genvar p_ram;
    generate
        for (p_ram = 0; p_ram < 4; p_ram = p_ram+1) begin: ram_pkt
            `ifdef FPGA_ALTERA
                ram sram_for_pkt(
                    .clock(clk),
                    .address_a(addr_pkt),
                    .data_a(data_pkt[32*p_ram+31:32*p_ram]),
                    .rden_a(rden_pkt),
                    .wren_a(wren_pkt),
                    .q_a(ctx_pkt[32*p_ram+31:32*p_ram]),

                    .address_b(mem_addr_i[depth_pkt+1:2]),
                    .data_b(mem_wdata_i),
                    .rden_b(mem_rden),
                    .wren_b(mem_wren_pkt[p_ram]),
                    .q_b(mem_rdata_pkt[p_ram]));
                defparam    
                    sram_for_pkt.width = 32,
                    sram_for_pkt.depth = depth_pkt,
                    sram_for_pkt.words = words_pkt;
            `else
                ram_32_512 sram_for_pkt(
                    .clka(clk),
                    .wea(wren_pkt),
                    .addra(addr_pkt),
                    .dina(data_pkt[32*p_ram+31:32*p_ram]),
                    .douta(ctx_pkt[32*p_ram+31:32*p_ram]),
                    .clkb(clk),
                    .web(mem_wren_pkt[p_ram]),
                    .addrb(mem_addr_i[depth_pkt+1:2]),
                    .dinb(mem_wdata_i),
                    .doutb(mem_rdata_pkt[p_ram]) );
            `endif
        end
    endgenerate

    //* record ram_pkt state;
    integer     i;
    reg [1:0]   tag_proc_send[3:0];
     always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // reset
            for(i=0; i<4; i=i+1)    tag_proc_send[i]    <= 2'b0;
        end
        else begin
            if(wren_pkt == 1'b1 && addr_pkt == 9'd0)                        tag_proc_send[0]    <= data_pkt[97:96];
            else if(mem_wren_pkt[3] == 1'b1 && mem_addr_i[10:2] == 9'd0)    tag_proc_send[0]    <= mem_wdata_i[1:0];
            if(wren_pkt == 1'b1 && addr_pkt == 9'd128)                      tag_proc_send[1]    <= data_pkt[97:96];
            else if(mem_wren_pkt[3] == 1'b1 && mem_addr_i[10:2] == 9'd128)  tag_proc_send[1]    <= mem_wdata_i[1:0];
            if(wren_pkt == 1'b1 && addr_pkt == 9'd256)                      tag_proc_send[2]    <= data_pkt[97:96];
            else if(mem_wren_pkt[3] == 1'b1 && mem_addr_i[10:2] == 9'd256)  tag_proc_send[2]    <= mem_wdata_i[1:0];
            if(wren_pkt == 1'b1 && addr_pkt == 9'd384)                      tag_proc_send[3]    <= data_pkt[97:96];
            else if(mem_wren_pkt[3] == 1'b1 && mem_addr_i[10:2] == 9'd384)  tag_proc_send[3]    <= mem_wdata_i[1:0];
        end
    end


    reg [15:0]  length_pkt;
    reg [3:0]   state_pkt;
    localparam  IDLE_S              = 4'd0,
                READ_FIFO_S         = 4'd1,
                WAIT_WR_PKT_END_S   = 4'd2,
                WR_RECV_TAG_S       = 4'd3,
                WAIT_RAM_1_S        = 4'd4,
                WAIT_RAM_2_S        = 4'd5,
                READ_RAM_S          = 4'd6,
                WAIT_RD_PKT_END_S   = 4'd7,
                WAIT_1_CLK_S        = 4'd8;


    //* recv & send packet;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // reset
            rdreq_pkt       <= 1'b0;
            wren_pkt        <= 1'b0;
            rden_pkt        <= 1'b0;
            data_pkt        <= 128'b0;
            addr_pkt        <= 9'b0;

            dataOut_valid_o <= 1'b0;
            dataOut_o       <= 134'b0;

            state_pkt       <= IDLE_S;
        end
        else begin
            case(state_pkt)
                IDLE_S: begin
                    wren_pkt        <= 1'b0;
                    dataOut_valid_o <= 1'b0;
                    rden_pkt        <= 1'b0;
                    if(empty_pkt == 1'b0 && (tag_proc_send[0]==2'b0 || tag_proc_send[1]==2'b0)) begin
                        //* recv packet;
                        state_pkt   <= READ_FIFO_S;
                        rdreq_pkt   <= 1'b1;
                    end
                    else if(tag_proc_send[0][0] == 1'b1) begin
                        state_pkt   <= WAIT_RAM_1_S;
                        addr_pkt    <= 9'd1;
                        rden_pkt    <= 1'b1;
                    end
                    else if(tag_proc_send[1][0] == 1'b1) begin
                        state_pkt   <= WAIT_RAM_1_S;
                        addr_pkt    <= 9'd129;
                        rden_pkt    <= 1'b1;
                    end
                    else if(tag_proc_send[2][0] == 1'b1) begin
                        state_pkt   <= WAIT_RAM_1_S;
                        addr_pkt    <= 9'd257;
                        rden_pkt    <= 1'b1;
                    end
                    else if(tag_proc_send[3][0] == 1'b1) begin
                        state_pkt   <= WAIT_RAM_1_S;
                        addr_pkt    <= 9'd385;
                        rden_pkt    <= 1'b1;
                    end
                    else begin
                        state_pkt   <= IDLE_S;
                    end
                end
                READ_FIFO_S: begin
                    if(tag_proc_send[0] == 2'b0)    addr_pkt <= 9'd1;
                    else                            addr_pkt <= 9'd129;
                    wren_pkt        <= 1'b1;
                    data_pkt        <= q_pkt[127:0];
                    state_pkt       <= WAIT_WR_PKT_END_S;
                end
                WAIT_WR_PKT_END_S: begin
                    data_pkt        <= q_pkt[127:0];
                    addr_pkt        <= addr_pkt + 9'd1;
                    if(q_pkt[133:132] == 2'b10) begin
                        state_pkt   <= WR_RECV_TAG_S;
                        rdreq_pkt   <= 1'b0;
                    end
                    else begin
                        state_pkt   <= WAIT_WR_PKT_END_S;
                    end
                end
                WR_RECV_TAG_S: begin
                    data_pkt        <= {32'd2,32'd0,32'd0,32'd0};
                    addr_pkt        <= {addr_pkt[31:7],7'b0};
                    state_pkt       <= IDLE_S;
                end
                WAIT_RAM_1_S: begin
                    state_pkt       <= WAIT_RAM_2_S;
                    addr_pkt        <= addr_pkt + 9'd1;
                end
                WAIT_RAM_2_S: begin
                    state_pkt       <= READ_RAM_S;
                    addr_pkt        <= addr_pkt + 9'd1;
                end
                READ_RAM_S: begin
                    state_pkt       <= WAIT_RD_PKT_END_S;
                    length_pkt      <= ctx_pkt[127:112] - 16'd16;
                    dataOut_valid_o <= 1'b1;
                    dataOut_o       <= {2'b01,4'hf,ctx_pkt};
                    addr_pkt        <= addr_pkt + 9'd1;
                end
                WAIT_RD_PKT_END_S: begin
                    addr_pkt        <= addr_pkt + 9'd1;
                    dataOut_o[127:0]<= ctx_pkt;
                    length_pkt      <= length_pkt - 16'd16;
                    if(length_pkt[15:4] == 12'd0) begin
                        state_pkt   <= WAIT_1_CLK_S;
                        dataOut_o[133:128]  <= {2'b10,length_pkt[3:0]};
                        addr_pkt    <= {addr_pkt[31:7],7'b0};
                        wren_pkt    <= 1'b1;
                        data_pkt    <= 128'b0;
                        rden_pkt    <= 1'b0;
                    end
                    else if(length_pkt == 16'h10) begin
                        state_pkt   <= WAIT_1_CLK_S;
                        dataOut_o[133:128]  <= {2'b10,4'hf};
                        addr_pkt    <= {addr_pkt[31:7],7'b0};
                        wren_pkt    <= 1'b1;
                        data_pkt    <= 128'b0;
                        rden_pkt    <= 1'b0;
                    end
                    else begin
                        state_pkt   <= WAIT_RD_PKT_END_S;
                        dataOut_o[133:128]  <= {2'b00,4'hf};
                    end
                end
                WAIT_1_CLK_S: begin
                    state_pkt       <= IDLE_S;
                    dataOut_valid_o <= 1'b0;
                end
                default: begin
                    state_pkt       <= IDLE_S;
                end
            endcase
        end
    end



    reg tag;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            print_value_o <= 8'b0;
            print_valid_o <= 1'b0;
            tag <= 1'b0;
        end
        else begin
            if(mem_wren_i == 1'b1 && mem_addr_i == 32'h4000000) begin
                print_valid_o <= 1'b1;
                print_value_o <= mem_wdata_i[7:0];
                // $display("%c", mem_wdata_i[7:0]);
                $write("%c", mem_wdata_i[7:0]);
                $fflush();
            end
            else begin
                print_valid_o <= 1'b0;
            end
        end
    end

    //************************************************************************************************
    //* a register-based sim and dtcm
    // reg     [31:0]  mem_rdata;
    // assign          mem_rdata_o = mem_rdata;
    // reg     [31:0]  dtcm_reg[2*1024-1:0];
    // always @(posedge clk) begin
    //     mem_rdata   <= mem_addr_i[29]? coreID: dtcm_reg[mem_addr_i[10:0]];

    //     if(mem_valid_i == 1'b1 && mem_wstrb_i[0] == 1'b1)    dtcm_reg[mem_addr_i[10:0]][7:0] <= mem_wdata_i[7:0];
    //     if(mem_valid_i == 1'b1 && mem_wstrb_i[1] == 1'b1)    dtcm_reg[mem_addr_i[10:0]][15:8] <= mem_wdata_i[15:8];
    //     if(mem_valid_i == 1'b1 && mem_wstrb_i[2] == 1'b1)    dtcm_reg[mem_addr_i[10:0]][23:16] <= mem_wdata_i[23:16];
    //     if(mem_valid_i == 1'b1 && mem_wstrb_i[3] == 1'b1)    dtcm_reg[mem_addr_i[10:0]][31:24] <= mem_wdata_i[31:24];
    // end
    //************************************************************************************************


endmodule