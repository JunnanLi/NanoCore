/*
 *  TuMan32 -- A Small but pipelined RISC-V (RV32I) Processor Core
 *
 *  Copyright (C) 2019-2020  Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  To AoTuman, my dear cat, thanks for your company.
 */

`timescale 1 ns / 1 ps
/** Please toggle following comment (i.e., `define MODELSIM) if you use ModelSim **/
`define MODELSIM

module test_for_P2RV();
    reg clk = 1;
    reg resetn = 0;
    
    /** clk */
    always #5 clk = ~clk;
    /** reset */
    initial begin
        repeat (100) @(posedge clk);
        resetn <= 1;
    end
`ifdef MODELSIM 
    reg [1023:0] firmware_file, instr_file, data_file;
    initial begin
        // instr_file = "instr.hex";
        // $readmemh(instr_file, multicore.picoCore_top.sim.sim_reg);
        data_file = "firmware.hex";
        $readmemh(data_file, genData.memory);   
    end
`endif

    wire        data_in_valid, data_out_valid;
    wire[133:0] data_in, data_out;


iCore_top iCore(
    .clk(clk),
    .resetn(resetn),

    // FAST packets from CPU (ARM A8) or Physical ports, the format is according to fast 
    //   project (www.http://www.fastswitch.org/)
    .dataIn_valid_i(data_in_valid),
    .dataIn_i(data_in),  // 2'b01 is head, 2'b00 is body, and 2'b10 is tail;

    .dataOut_valid_o(data_out_valid),
    .dataOut_o(data_out)
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