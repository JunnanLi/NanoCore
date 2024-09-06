/*
 *  Project:            timelyRV_v1.0 -- a RISCV-32IMC SoC.
 *  Module name:        memory_part.
 *  Description:        instr/data memory of timelyRV core.
 *  Last updated date:  2022.05.13.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    This module is used to store instruction & data. And we use
 *      "conf_sel" to distinguish configuring or running mode.
 */

  module SRAM_Wrapper_instr (
      input                 clk,
      input                 rst_n,
      //* prot a
      input                 wea,
      input                 rda,
      input         [31:0]  addra,
      input         [31:0]  dina,
      input         [ 3:0]  stra,
      output  wire  [31:0]  douta,
      //* prot b
      input                 web,
      input                 rdb,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      input         [ 3:0]  strb,
      output  wire  [31:0]  doutb
  );
genvar idx;  
generate for(idx = 0; idx <4; idx=idx+1) begin: gen_8b_ram
  `ifdef MEM_256KB
    `ifdef XILINX_FIFO_RAM
      ram_8_4096_instr mem(
        .clka   (clk                ),
        .wea    (wea & stra[idx]    ),
        .addra  (addra[11:0]        ),
        .dina   (dina[idx*8+:8]     ),
        .douta  (douta[idx*8+:8]    ),
        .clkb   (clk                ),
        .web    (web & strb[idx]    ),
        .addrb  (addrb[11:0]        ),
        .dinb   (dinb[idx*8+:8]     ),
        .doutb  (doutb[idx*8+:8]    ),
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[11:0]    ),
        .address_b  (addrb[11:0]    ),
        .clock      (clk            ),
        .data_a     (dina[idx*8+:8] ),
        .data_b     (dinb[idx*8+:8] ),
        .rden_a     (rda            ),
        .rden_b     (rdb            ),
        .wren_a     (wea & stra[idx]),
        .wren_b     (web & strb[idx]),
        .q_a        (douta[idx*8+:8]),
        .q_b        (doutb[idx*8+:8])
      );
      defparam  mem.BUFFER= 0,
                mem.width = 8,
                mem.depth = 12,
                mem.words = 4096;
    `endif
  `elsif MEM_128KB
    `ifdef XILINX_FIFO_RAM
      ram_8_2048_instr mem(
        .clka   (clk                ),
        .wea    (wea & stra[idx]    ),
        .addra  (addra[10:0]        ),
        .dina   (dina[idx*8+:8]     ),
        .douta  (douta[idx*8+:8]    ),
        .clkb   (clk                ),
        .web    (web & strb[idx]    ),
        .addrb  (addrb[10:0]        ),
        .dinb   (dinb[idx*8+:8]     ),
        .doutb  (doutb[idx*8+:8]    ),
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[10:0]    ),
        .address_b  (addrb[10:0]    ),
        .clock      (clk            ),
        .data_a     (dina[idx*8+:8] ),
        .data_b     (dinb[idx*8+:8] ),
        .rden_a     (rda            ),
        .rden_b     (rdb            ),
        .wren_a     (wea & stra[idx]),
        .wren_b     (web & strb[idx]),
        .q_a        (douta[idx*8+:8]),
        .q_b        (doutb[idx*8+:8])
      );
      defparam  mem.BUFFER= 0,
                mem.width = 8,
                mem.depth = 11,
                mem.words = 2048;
    `endif
  `elsif MEM_64KB
    `ifdef XILINX_FIFO_RAM
      ram_8_1024_instr mem(
        .clka   (clk                ),
        .wea    (wea & stra[idx]    ),
        .addra  (addra[9:0]         ),
        .dina   (dina[idx*8+:8]     ),
        .douta  (douta[idx*8+:8]    ),
        .clkb   (clk                ),
        .web    (web & strb[idx]    ),
        .addrb  (addrb[9:0]         ),
        .dinb   (dinb[idx*8+:8]     ),
        .doutb  (doutb[idx*8+:8]    ),
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[9:0]     ),
        .address_b  (addrb[9:0]     ),
        .clock      (clk            ),
        .data_a     (dina[idx*8+:8] ),
        .data_b     (dinb[idx*8+:8] ),
        .rden_a     (rda            ),
        .rden_b     (rdb            ),
        .wren_a     (wea & stra[idx]),
        .wren_b     (web & strb[idx]),
        .q_a        (douta[idx*8+:8]),
        .q_b        (doutb[idx*8+:8])
      );
      defparam  mem.BUFFER= 0,
                mem.width = 8,
                mem.depth = 10,
                mem.words = 1024;
    `endif
  `endif
  end
endgenerate
  // genvar i_ram;
  // generate
  //   for (i_ram = 0; i_ram < 4; i_ram = i_ram+1) begin: gen_8b_ram
  //     `ifdef MEM_256KB
  //       `ifdef XILINX_FIFO_RAM
  //         ram_8_8192 mem(
  //           .clka   (clk                ),
  //           .wea    (wea                ),
  //           .addra  (addra[12:0]        ),
  //           .dina   (dina[i_ram*8+:8]   ),
  //           .douta  (douta[i_ram*8+:8]  ),
  //           .clkb   (clk                ),
  //           .web    (web[i_ram]         ),
  //           .addrb  (addrb[12:0]        ),
  //           .dinb   (dinb[i_ram*8+:8]   ),
  //           .doutb  (doutb[i_ram*8+:8]  )
  //         );
  //       `elsif SIM_FIFO_RAM
  //         syncram mem(
  //           .address_a  (addra[12:0]    ),
  //           .address_b  (addrb[12:0]    ),
  //           .clock      (clk            ),
  //           .data_a     (dina[i_ram*8+:8]),
  //           .data_b     (dinb[i_ram*8+:8]),
  //           .rden_a     (rda            ),
  //           .rden_b     (rdb            ),
  //           .wren_a     (wea            ),
  //           .wren_b     (web[i_ram]     ),
  //           .q_a        (douta[i_ram*8+:8]),
  //           .q_b        (doutb[i_ram*8+:8])
  //         );
  //         defparam  mem.width = 8,
  //                   mem.depth = 13,
  //                   mem.words = 8192;
  //       `endif
  //     `elsif MEM_128KB
  //       `ifdef XILINX_FIFO_RAM
  //         ram_32_4096 mem(
  //           .clka   (clk                ),
  //           .wea    (wea                ),
  //           .addra  (addra[11:0]        ),
  //           .dina   (dina[i_ram*8+:8]   ),
  //           .douta  (douta[i_ram*8+:8]  ),
  //           .clkb   (clk                ),
  //           .web    (web[i_ram]         ),
  //           .addrb  (addrb[11:0]        ),
  //           .dinb   (dinb[i_ram*8+:8]   ),
  //           .doutb  (doutb[i_ram*8+:8]  )
  //         );
  //       `elsif SIM_FIFO_RAM
  //         syncram mem(
  //           .address_a  (addra[11:0]    ),
  //           .address_b  (addrb[11:0]    ),
  //           .clock      (clk            ),
  //           .data_a     (dina[i_ram*8+:8]),
  //           .data_b     (dinb[i_ram*8+:8]),
  //           .rden_a     (rda            ),
  //           .rden_b     (rdb            ),
  //           .wren_a     (wea            ),
  //           .wren_b     (web[i_ram]     ),
  //           .q_a        (douta[i_ram*8+:8]),
  //           .q_b        (doutb[i_ram*8+:8])
  //         );
  //         defparam  mem.width = 8,
  //                   mem.depth = 12,
  //                   mem.words = 4096;
  //       `endif
  //     `elsif MEM_64KB
  //       `ifdef XILINX_FIFO_RAM
  //         ram_32_2048 mem(
  //           .clka   (clk                ),
  //           .wea    (wea                ),
  //           .addra  (addra[10:0]        ),
  //           .dina   (dina[i_ram*8+:8]   ),
  //           .douta  (douta[i_ram*8+:8]  ),
  //           .clkb   (clk                ),
  //           .web    (web[i_ram]         ),
  //           .addrb  (addrb[10:0]        ),
  //           .dinb   (dinb[i_ram*8+:8]   ),
  //           .doutb  (doutb[i_ram*8+:8]  )
  //         );
  //       `elsif SIM_FIFO_RAM
  //         syncram mem(
  //           .address_a  (addra[10:0]    ),
  //           .address_b  (addrb[10:0]    ),
  //           .clock      (clk            ),
  //           .data_a     (dina[i_ram*8+:8]),
  //           .data_b     (dinb[i_ram*8+:8]),
  //           .rden_a     (rda            ),
  //           .rden_b     (rdb            ),
  //           .wren_a     (wea            ),
  //           .wren_b     (web[i_ram]     ),
  //           .q_a        (douta[i_ram*8+:8]),
  //           .q_b        (doutb[i_ram*8+:8])
  //         );
  //         defparam  mem.width = 8,
  //                   mem.depth = 11,
  //                   mem.words = 2048;
  //       `endif
  //     `endif
  //   end
  // endgenerate
  endmodule


// module memory_part_0KB (
//   input   wire          clk,
//   //* prot a
//   input   wire  [3:0]   wea,
//   input   wire  [31:0]  addra,
//   input   wire  [31:0]  dina,
//   output  wire  [31:0]  douta,
//   //* prot b
//   input   wire  [3:0]   web,
//   input   wire  [31:0]  addrb,
//   input   wire  [31:0]  dinb,
//   output  wire  [31:0]  doutb
// );

//   assign douta = 32'b0;
//   assign doutb = 32'b0;
// endmodule