/*
 *  Project:            timelyRV_v1.4.x -- a RISCV-32IMC SoC.
 *  Module name:        Testbench.
 *  Description:        Testbench of timelyRV_SoC_hardware.
 *  Last updated date:  2022.10.10.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */


`define SIM_RVPIPE_SOC

`timescale 1ns/1ps
module Testbench_wrapper(
);

localparam  GEN_FAKE_TIME_IRQ = 0; 

`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
    $vcdpluson;
    $vcdplusmemon;
  end
`endif

  reg               clk,rst_n;
  reg               r_pktIn_valid[1:0];
  reg   [133:0]     r_pktIn[1:0];
  wire              w_pktOut_valid[1:0], w_pktData_valid_gmii[1:0], w_pkt2calc_valid[1:0];
  wire  [133:0]     w_pktOut[1:0], w_pktData_gmii[1:0], w_pkt2calc[1:0];

`ifdef SIM_RVPIPE_SOC
  reg   [133:0]     r_pktData_gmii[1:0];
  reg               r_pktData_valid_gmii[1:0];
  wire  [11:0]      w_pktOut_length[1:0];
  wire              w_toConf[1:0], w_toDMA[1:0];
  reg   [11:0]      length_pkt_data[1:0];

  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      r_pktData_valid_gmii[0]   <= 1'b0;
      r_pktData_valid_gmii[1]   <= 1'b0;
    end else begin
      r_pktData_valid_gmii[0]   <= r_pktIn_valid[0];
      r_pktData_valid_gmii[1]   <= r_pktIn_valid[1];
      r_pktData_gmii[0]         <= r_pktIn[0];
      r_pktData_gmii[1]         <= r_pktIn[1];
    end
  end

  assign w_toConf[0]               = r_pktIn_valid[0] & !r_pktData_valid_gmii[0] & (r_pktIn[0][31:28] == 4'h9);
  assign w_pktData_valid_gmii[0]   = r_pktIn_valid[0] | r_pktData_valid_gmii[0];
  assign w_pktData_gmii[0]         = (r_pktIn_valid[0] & !r_pktData_valid_gmii[0])? 
                                    {2'b11,4'hf,96'b0,2'b0,~w_toConf[0],w_toConf[0],length_pkt_data[0],16'b0}:
                                    r_pktData_gmii[0];
  assign w_toConf[1]               = r_pktIn_valid[1] & !r_pktData_valid_gmii[1] & (r_pktIn[1][31:28] == 4'h9);
  assign w_pktData_valid_gmii[1]   = r_pktIn_valid[1] | r_pktData_valid_gmii[1];
  assign w_pktData_gmii[1]         = (r_pktIn_valid[1] & !r_pktData_valid_gmii[1])? 
                                    {2'b11,4'hf,96'b0,2'b0,~w_toConf[1],w_toConf[1],length_pkt_data[1],16'b0}:
                                    r_pktData_gmii[1];
`else
  assign w_pktData_valid_gmii[0]   = r_pktIn_valid[0];
  assign w_pktData_gmii[1]         = r_pktIn[1];
`endif  

  genvar gen_idx;
  generate
    for(gen_idx=0; gen_idx<2; gen_idx=gen_idx+1) begin: gen_nanocore_soc
      NanoCore_SoC NanoCore_SoC(
        //* clk & rst_n
         .i_sys_clk       (clk            )
        ,.i_sys_rst_n     (rst_n          )
        ,.i_pe_clk        (clk            )
        ,.i_rst_n         (rst_n          )
        //* pkt;
        ,.i_pe_conf_mac   (48'b0          )
        ,.i_data_valid    (w_pktData_valid_gmii[gen_idx]  )
        ,.i_data          (w_pktData_gmii[gen_idx]        )
        ,.o_alf           (                               )
        ,.o_data_valid    (w_pkt2calc_valid[gen_idx]        )
        ,.o_data          (w_pkt2calc[gen_idx]              )
        ,.i_alf           (1'b0           )
        ,.i_uart_rx       (1'b1           )
        ,.o_uart_tx       (               )
        ,.i_uart_cts      (1'b1           )
        ,.o_uart_rts      (               )
      );

      Calc_Length Calc_Length(
        //* clk & rst_n
         .i_clk           (clk            )
        ,.i_rst_n         (rst_n          )
        //* pkt in & out;
        ,.i_pkt_valid     (w_pkt2calc_valid[gen_idx])
        ,.i_pkt           (w_pkt2calc[gen_idx]      )
        ,.o_pkt_valid     (w_pktOut_valid[gen_idx]  )
        ,.o_pkt           (w_pktOut[gen_idx]        )
        ,.o_pkt_length    (w_pktOut_length[gen_idx] )
      );
    end
  endgenerate
  

  initial begin
    rst_n = 1;
    #2  rst_n = 0;
    #10 rst_n = 1;
  end
  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end
  initial begin
  `ifndef SIM_PKT_IO
    // #800000 $finish;
  `endif
  end
  

  /** read firmware.hex and write memory */
  reg [2047:0]  firmware_file, firmware_file_1;
  `ifdef MEM_64KB
    reg [31:0]  memory[0:16*1024-1];  /* verilator public */
  `elsif MEM_128KB
    reg [31:0]  memory[0:32*1024-1];  /* verilator public */
  `elsif MEM_256KB
    reg [31:0]  memory[0:64*1024-1];  /* verilator public */
    reg [31:0]  memory_1[0:64*1024-1];  /* verilator public */
  `endif
  // reg [31:0]    memory[0:64*1024-1];  /* verilator public */
  initial begin
    if (!$value$plusargs("firmware=%s", firmware_file))
      firmware_file = "./firmware.hex";
    $readmemh(firmware_file, memory);
    if (!$value$plusargs("firmware=%s", firmware_file_1))
      firmware_file_1 = "./firmware_1.hex";
    $readmemh(firmware_file_1, memory_1);
  end

  typedef enum logic [3:0] {idle, config_sram, start_core, gen_a_pkt, send_arp, tail, wait_pkt_out,
                            read_sim_pkt, read_pkt_head, wait_pkt_tail, wait_x_clk} state_t;
  state_t testbench_state;

  reg [15:0]  mem_idx;
  reg [7:0]   pkt_cnt;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      r_pktIn_valid[0]      <= 'b0;
      r_pktIn_valid[1]      <= 'b0;
    `ifdef SIM_RVPIPE_SOC
      pkt_cnt               <= 'b1;
    `else
      pkt_cnt               <= 'b0;
    `endif
      mem_idx               <= 'b0;
      testbench_state       <= idle;
    end
    else begin
      r_pktIn_valid[0]      <= 'b0;
      r_pktIn_valid[1]      <= 'b0;
      case(testbench_state)
        idle: begin
          testbench_state   <= config_sram;
        end
        config_sram: begin
          pkt_cnt           <= (pkt_cnt == 8'd2)? 8'd2: (pkt_cnt + 8'd1);
          r_pktIn_valid[0]  <= 1'b1;
          r_pktIn_valid[1]  <= 1'b1;
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn[0]    <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn[0]    <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h3};
            2'd2: begin
                  r_pktIn[0]    <= {2'b00, 4'hf, 48'b0, memory[mem_idx], 16'b0, mem_idx, 16'b0};
                  mem_idx       <= mem_idx + 1;
                `ifdef MEM_64KB
                  if(mem_idx == 16'h3fff) begin
                `elsif MEM_128KB
                  if(mem_idx == 16'h7fff) begin
                `elsif MEM_256KB
                  if(mem_idx == 16'hffff) begin
                `endif
                    r_pktIn[0][133:132]  <= 2'b10;
                    `ifdef SIM_RVPIPE_SOC
                      pkt_cnt         <= 'b1;
                    `else
                      pkt_cnt         <= 'b0;
                    `endif
                    testbench_state   <= start_core;
                  end
            end
          endcase
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn[1]   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn[1]   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h3};
            2'd2: begin
                  r_pktIn[1]   <= {2'b00, 4'hf, 48'b0, memory_1[mem_idx], 16'b0, mem_idx, 16'b0};
                `ifdef MEM_64KB
                  if(mem_idx == 16'h3fff) begin
                `elsif MEM_128KB
                  if(mem_idx == 16'h7fff) begin
                `elsif MEM_256KB
                  if(mem_idx == 16'hffff) begin
                `endif
                    r_pktIn[1][133:132]  <= 2'b10;
                  end
            end
          endcase
        end
        start_core: begin
          pkt_cnt           <= (pkt_cnt == 8'd2)? 8'd2: (pkt_cnt + 8'd1);
          r_pktIn_valid[0]  <= 1'b1;
          r_pktIn_valid[1]  <= 1'b1;
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn[0]   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn[0]   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h1};
            2'd2: begin
                  r_pktIn[0]   <= {2'b10, 4'hf, 96'b0, 16'hfe, 16'b0};
                `ifdef SIM_RVPIPE_SOC
                  pkt_cnt           <= 'b1;
                `else
                  pkt_cnt           <= 'b0;
                `endif
                `ifdef GEN_A_PKT
                  testbench_state   <= wait_pkt_out;
                `elsif GEN_ARP
                  testbench_state   <= send_arp;
                `elsif SIM_PKT_IO
                  testbench_state   <= read_sim_pkt;
                `else 
                  testbench_state   <= tail;
                `endif
            end
          endcase

          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn[1]   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn[1]   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h1};
            2'd2: r_pktIn[1]   <= {2'b10, 4'hf, 96'b0, 16'hfe, 16'b0};
          endcase
        end
        tail: begin
          pkt_cnt           <= pkt_cnt + 8'd1;
          r_pktIn[0]        <= w_pktOut[1];
          r_pktIn_valid[0]  <= r_pktIn_valid[0]? w_pktOut_valid[1]:
                                    w_pktOut_valid[1] & (w_pktOut[1][133:132]==2'b01) & (w_pktOut[1][31:16]!=16'h9005);
          r_pktIn[1]        <= w_pktOut[0];
          r_pktIn_valid[1]  <= r_pktIn_valid[1]? w_pktOut_valid[0]:
                                    w_pktOut_valid[0] & (w_pktOut[0][133:132]==2'b01) & (w_pktOut[0][31:16]!=16'h9005);
          
          length_pkt_data[0]<= w_pktOut_length[1];
          length_pkt_data[1]<= w_pktOut_length[0];
        end
      endcase
    end
  end


  // //* fake time irq;
  // reg   [15:0]   cnt_clk;
  // always @(posedge clk or negedge rst_n) begin
  //   if(~rst_n) begin
  //     r_irq         <= 32'b0;
  //     cnt_clk       <= 16'b0;
  //   end else begin
  //     r_irq[7]      <= GEN_FAKE_TIME_IRQ & cnt_clk[8];
  //     cnt_clk       <= cnt_clk[8]? 16'b0: (cnt_clk + 16'd1);
  //   end
  // end


endmodule



module Calc_Length(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* pkt in & out;
  ,input  wire                    i_pkt_valid
  ,input  wire  [         133:0]  i_pkt
  ,output reg   [   `NUM_PE-1:0]  o_pkt_valid
  ,output reg   [         133:0]  o_pkt
  //* length out;
  ,output reg   [          11:0]  o_pkt_length
);


  //==============================================================//
  //  calc legth & dispatch pkt   
  //==============================================================//
  //* fifo;
  reg                     rden_pkt, rden_length;
  wire    [133:0]         dout_pkt;
  wire    [ 11:0]         dout_length;
  wire                    empty_length;
  reg                     wren_length;
  reg     [ 11:0]         data_length;

  //* calc length;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      wren_length               <= 'b0;
      data_length               <= 'b0;
    end
    else begin
      wren_length               <= 1'b0;
      if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b01) begin
        data_length[11:4]       <= 8'd1;
        data_length[3:0]        <= 4'b0;
      end
      else if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b00) begin
        data_length[11:4]       <= 8'd1 + data_length[11:4];
      end
      else if(i_pkt_valid == 1'b1 && i_pkt[133:132] == 2'b10) begin
        data_length[11:4]       <= (i_pkt[128+:4] == 4'hf)? (8'd1 + data_length[11:4]): data_length[11:4];
        data_length[3:0]        <= i_pkt[128+:4] + 4'd1;
        wren_length             <= 1'b1;
      end
    end
  end

  reg         state_distribute;
  localparam  IDLE_S            = 1'b0,
              WAIT_END_S        = 1'b1;

  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      rden_pkt                  <= 'b0;
      rden_length               <= 'b0;
      state_distribute          <= IDLE_S;
    end else begin
      //* write dmaWR fifo;
      o_pkt                     <= dout_pkt;
      o_pkt_valid               <= rden_pkt;
      o_pkt_length              <= dout_length;
      
      case (state_distribute)
        IDLE_S: begin
          o_pkt_valid           <= 1'b0;
          if(empty_length == 1'b0) begin
            rden_length         <= 1'b1;
            rden_pkt            <= 1'b1;
            state_distribute    <= WAIT_END_S;
          end
          else begin
            state_distribute    <= IDLE_S;
          end
        end
        WAIT_END_S: begin
          rden_length           <= 1'b0;
          if(dout_pkt[133:132] == 2'b10) begin
            rden_pkt            <= 1'b0;
            state_distribute    <= IDLE_S;
          end
        end
      endcase
    end
  end

  //* fifo used to buffer pkt;
  syncfifo fifo_pkt (
    .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
    .aclr                 (!i_rst_n                 ),  //* Reset the all signal
    .data                 (i_pkt                    ),  //* The Inport of data 
    .wrreq                (i_pkt_valid              ),  //* active-high
    .rdreq                (rden_pkt                 ),  //* active-high
    .q                    (dout_pkt                 ),  //* The output of data
    .empty                (empty_pkt                ),  //* Read domain empty
    .usedw                (                         ),  //* Usedword
    .full                 (                         )   //* Full
  );
  defparam  fifo_pkt.width = 134,
            fifo_pkt.depth = 7,
            fifo_pkt.words = 128;

  //* fifo used to buffer pkt;
  syncfifo fifo_length (
    .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
    .aclr                 (!i_rst_n                 ),  //* Reset the all signal
    .data                 (data_length              ),  //* The Inport of data 
    .wrreq                (wren_length              ),  //* active-high
    .rdreq                (rden_length              ),  //* active-high
    .q                    (dout_length              ),  //* The output of data
    .empty                (empty_length             ),  //* Read domain empty
    .usedw                (                         ),  //* Usedword
    .full                 (                         )   //* Full
  );
  defparam  fifo_length.width = 12,
            fifo_length.depth = 7,
            fifo_length.words = 128;

endmodule