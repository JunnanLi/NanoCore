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


// `define SIM_PKT_IO

`ifndef SIM_PKT_IO
  `define GEN_A_PKT
  // `define GEN_ARP
`else 
  `define SIM_RVPIPE_SOC
`endif
// `define SIM_RVPIPE_SOC

`timescale 1ns/1ps
module Testbench_wrapper(
);

localparam  GEN_FAKE_TIME_IRQ = 0; 

`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpMDA();
    $vcdpluson;
    $vcdplusmemon;
  end
`endif
  

  localparam  ARP_0             = 128'hffff_ffff_ffff_4242_1aa8_239f_0806_0001,
              ARP_1             = 128'h0800_0604_0001_4242_1aa8_239f_c0a8_0114,
              ARP_2             = 128'h0000_0000_0000_c0a8_01c8_0000_0000_0000,
              ARP_3             = 128'h0000_0000_0000_0000_0000_0000_7374_7576;

  reg               clk,rst_n;
  reg               r_pktIn_valid;
  reg   [133:0]     r_pktIn;
  wire              w_pktOut_valid, w_pktData_valid_gmii;
  wire  [133:0]     w_pktOut, w_pktData_gmii;


`ifdef SIM_RVPIPE_SOC
  reg   [133:0]     r_pktData_gmii;
  reg               r_pktData_valid_gmii;
  wire  [15:0]      w_pkt_length;
  wire              w_toConf, w_toDMA;
  reg   [7:0]       length_pkt_data;

  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      r_pktData_valid_gmii      <= 1'b0;
    end else begin
      r_pktData_valid_gmii      <= r_pktIn_valid;
      r_pktData_gmii            <= r_pktIn;
    end
  end

  assign w_toConf               = r_pktIn_valid & !r_pktData_valid_gmii & (r_pktIn[31:28] == 4'h9);
  assign w_pktData_valid_gmii   = r_pktIn_valid | r_pktData_valid_gmii;
  assign w_pktData_gmii         = (r_pktIn_valid & !r_pktData_valid_gmii)? 
                                    {2'b11,4'hf,96'b0,2'b0,~w_toConf,w_toConf,length_pkt_data,4'b0,16'b0}:
                                    r_pktData_gmii;
`else
  assign w_pktData_valid_gmii   = r_pktIn_valid;
  assign w_pktData_gmii         = r_pktIn;
`endif  

  NanoCore_SoC NanoCore_SoC(
    //* clk & rst_n
     .i_sys_clk       (clk            )
    ,.i_sys_rst_n     (rst_n          )
    ,.i_pe_clk        (clk            )
    ,.i_rst_n         (rst_n          )
    //* pkt;
    ,.i_pe_conf_mac   (48'b0          )
    ,.i_data_valid    (w_pktData_valid_gmii  )
    ,.i_data          (w_pktData_gmii        )
    ,.o_alf           (               )
    ,.o_data_valid    (w_pktOut_valid )
    ,.o_data          (w_pktOut       )
    ,.i_alf           (1'b0           )
    ,.i_uart_rx       (1'b1           )
    ,.o_uart_tx       (               )
    ,.i_uart_cts      (1'b1           )
    ,.o_uart_rts      (               )
  );

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
    #400000 $finish;
    //#3000000 $finish;
  `endif
  end
  

  /** read firmware.hex and write memory */
  reg [2047:0]  firmware_file;
  `ifdef MEM_64KB
    reg [31:0]  memory[0:16*1024-1];  /* verilator public */
  `elsif MEM_128KB
    reg [31:0]  memory[0:32*1024-1];  /* verilator public */
  `elsif MEM_256KB
    reg [31:0]  memory[0:64*1024-1];  /* verilator public */
  `endif
  // reg [31:0]    memory[0:64*1024-1];  /* verilator public */
  initial begin
    if (!$value$plusargs("firmware=%s", firmware_file))
      firmware_file = "./firmware.hex";
    $readmemh(firmware_file, memory);
  end

`ifdef SIM_PKT_IO
  reg     [2047:0]        pktIn_file, pktOut_file;
  initial begin
    pktIn_file  = "./pktIO/pktIn.txt";
    pktOut_file = "./pktIO/pktOut.txt";
  end
  reg     [127:0]         memPktIn[0:127];
  //* fifo;
  reg                     rden_pktOut, rden_length;
  wire    [133:0]         dout_pktOut;
  wire    [ 11:0]         dout_length;
  wire                    empty_pktOut, empty_length;
  reg                     wren_length;
  reg     [ 7:0]          data_length;
  reg     [ 3:0]          data_valid;

  reg     [127:0]         pktIn_rdata;
  wire    [ 7:0]          w_cnt_pkt_data[3:0];
  reg     [7:0]           cnt_pkt_data;
  reg     [31:0]          cnt_clk;
  reg     [15:0]          tag_pkt;  //* from 0 to 2^16-1;
  reg     [3:0]           tag_pkt_valid;  //* from 4'b0 to 4'b1111;

  //* fifo used to buffer pkt;
  syncfifo fifo_pktOut (
    .clock                (clk                      ),  //* ASYNC WriteClk, SYNC use wrclk
    .aclr                 (!rst_n                   ),  //* Reset the all signal
    .data                 (w_pktOut                 ),  //* The Inport of data 
    .wrreq                (w_pktOut_valid           ),  //* active-high
    .rdreq                (rden_pktOut              ),  //* active-high
    .q                    (dout_pktOut              ),  //* The output of data
    .empty                (empty_pktOut             ),  //* Read domain empty
    .usedw                (                         ),  //* Usedword
    .full                 (                         )   //* Full
  );
  defparam  fifo_pktOut.width = 134,
            fifo_pktOut.depth = 7,
            fifo_pktOut.words = 128;

  //* fifo used to buffer pkt;
  syncfifo fifo_length (
    .clock                (clk                      ),  //* ASYNC WriteClk, SYNC use wrclk
    .aclr                 (!rst_n                   ),  //* Reset the all signal
    .data                 ({data_valid,data_length} ),  //* The Inport of data 
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

  //* count length;
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      wren_length             <= 1'b0;
      data_length             <= 8'b0;
      data_valid              <= 4'b0;
    end else begin
      if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b01) begin
        data_length           <= 8'd1;
      end
      else if(w_pktOut_valid == 1'b1) begin
        data_length           <= 8'd1 + data_length;
      end
      
      wren_length             <= 1'b0;
      if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b10) begin
        data_valid            <= w_pktOut[131:128];
        wren_length           <= 1'b1;
      end
    end
  end

  //* write pkt to file;
  integer       handle_wr;
  reg   [3:0]   state_wrPkt;
  reg   [15:0]  cnt_wrPkt;
  parameter     IDLE_WRPKT_S      = 4'd0,
                WR_PKT_S          = 4'd1;
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      rden_length             <= 1'b0;
      rden_pktOut             <= 1'b0;
      cnt_wrPkt               <= 16'b0;
      state_wrPkt             <= IDLE_WRPKT_S;
      length_pkt_data         <= 'b0;
    end else begin
      case (state_wrPkt)
        IDLE_WRPKT_S: begin
          if(empty_length == 1'b0) begin
            handle_wr = $fopen(pktOut_file,"w");
            state_wrPkt       <= WR_PKT_S;
            rden_length       <= 1'b1;
            rden_pktOut       <= 1'b1;
            cnt_wrPkt         <= 16'b1 + cnt_wrPkt;
            $fwrite(handle_wr,"%08x\n",cnt_wrPkt);
            $fwrite(handle_wr,"%08x\n",dout_length);

          end
        end
        WR_PKT_S: begin
          rden_length         <= 1'b0;
          $fwrite(handle_wr,"%32x\n",dout_pktOut[127:0]);
          if(dout_pktOut[133:132] == 2'b10) begin
            rden_pktOut       <= 1'b0;
            state_wrPkt       <= IDLE_WRPKT_S;
            $fclose(handle_wr);
          end
        end
        default: begin end
      endcase
    end
  end

  task handle_pktIn_rdata; begin
    if (cnt_pkt_data < 128) begin
      pktIn_rdata = {memPktIn[cnt_pkt_data+2]};
    end
  end endtask
`endif

  typedef enum logic [3:0] {idle, config_sram, start_core, gen_a_pkt, send_arp, tail, wait_pkt_out,
                            read_sim_pkt, read_pkt_head, wait_pkt_tail, wait_x_clk} state_t;
  state_t testbench_state;

  reg [15:0]  mem_idx;
  reg [7:0]   pkt_cnt;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      r_pktIn_valid         <= 'b0;
    `ifdef SIM_RVPIPE_SOC
      pkt_cnt               <= 'b1;
    `else
      pkt_cnt               <= 'b0;
    `endif
      mem_idx               <= 'b0;
      testbench_state       <= idle;
    end
    else begin
      r_pktIn_valid         <= 1'b0;
      case(testbench_state)
        idle: begin
          testbench_state   <= config_sram;
        end
        config_sram: begin
          pkt_cnt           <= (pkt_cnt == 8'd3)? 8'd3: (pkt_cnt + 8'd1);
          r_pktIn_valid     <= 1'b1;
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h3};
            2'd2: r_pktIn   <= {2'b00, 4'hf, 112'b0, memory[mem_idx][31:16]};
            2'd3: begin
                  r_pktIn   <= {2'b00, 4'hf, memory[mem_idx][15:0], memory[mem_idx+1], memory[mem_idx+2], memory[mem_idx+3], memory[mem_idx+4][31:16]};
                  mem_idx   <= mem_idx + 4;
                `ifdef MEM_64KB
                  if(mem_idx == 16'h3ffc) begin
                `elsif MEM_128KB
                  if(mem_idx == 16'h7ffc) begin
                `elsif MEM_256KB
                  if(mem_idx == 16'hfffc) begin
                `endif
                    r_pktIn[133:132]  <= 2'b10;
                    `ifdef SIM_RVPIPE_SOC
                      pkt_cnt         <= 'b1;
                    `else
                      pkt_cnt         <= 'b0;
                    `endif
                    testbench_state   <= start_core;
                  end
            end
          endcase
        end
        start_core: begin
          pkt_cnt           <= (pkt_cnt == 8'd2)? 8'd2: (pkt_cnt + 8'd1);
          r_pktIn_valid     <= 1'b1;
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h1};
            2'd2: begin
                  r_pktIn   <= {2'b10, 4'hf, 96'b0, 16'hfe, 16'b0};
                `ifdef SIM_RVPIPE_SOC
                  pkt_cnt           <= 'b1;
                `else
                  pkt_cnt           <= 'b0;
                `endif
                `ifdef GEN_A_PKT
                  testbench_state   <= gen_a_pkt;
                `elsif GEN_ARP
                  testbench_state   <= send_arp;
                `elsif SIM_PKT_IO
                  testbench_state   <= read_sim_pkt;
                `else 
                  testbench_state   <= tail;
                `endif
            end
          endcase
        end
        wait_pkt_out: begin
          if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b10 && w_pktOut[48+:8] == 8'h0a)
            testbench_state <= gen_a_pkt;
        end
        gen_a_pkt: begin
          pkt_cnt           <= (pkt_cnt == 8'd4)? 8'd4: (pkt_cnt + 8'd1);
          r_pktIn_valid     <= 1'b1;
          case(pkt_cnt[2:0])
            //* metadata;
            3'd0: r_pktIn   <= {2'b11, 4'hf, 96'b0, 4'h2, 12'd60, 16'b0};
            // 3'd1: r_pktIn   <= {2'b01, 4'hf, 48'h000a_3500_0102, 48'h00e0_4d6d_a7b3, 16'h0806, 16'h1};
            // 3'd2: r_pktIn   <= {2'b00, 4'hf, 128'h0800_0604_0002_00e0_4d6d_a7b3_c0a8_010a};
            // 3'd3: r_pktIn   <= {2'b00, 4'hf, 128'h000a_3500_0102_c0a8_0164_0000_0000_0000};
            3'd1: r_pktIn   <= {2'b01, 4'hf, 48'hffff_ffff_ffff, 48'h00e0_4d6d_a7b3, 16'h0806, 16'h1};
            3'd2: r_pktIn   <= {2'b00, 4'hf, 128'h0800_0604_0001_00e0_4d6d_a7b3_c0a8_0114};
            3'd3: r_pktIn   <= {2'b00, 4'hf, 128'h0000_0000_0000_c0a8_01c8_0000_0000_0000};
            3'd4: begin
                  r_pktIn   <= {2'b10, 4'hb, 128'b0};
                  pkt_cnt   <= 'b0;
                  testbench_state   <= tail;
            end
          endcase
        end
        send_arp: begin
          pkt_cnt           <= pkt_cnt + 8'd1;
          r_pktIn_valid     <= 1'b1;
          case(pkt_cnt[2:0])
            //* metadata;
            3'd0: r_pktIn   <= {2'b11, 4'hf, 96'b0, 4'h2, 12'd64, 16'b0};
            3'd1: r_pktIn   <= {2'b01, 4'hf, ARP_0};
            3'd2: r_pktIn   <= {2'b00, 4'hf, ARP_1};
            // 3'd3: r_pktIn   <= {2'b00, 4'hf, ARP_2};
            // 3'd4: begin
            //       r_pktIn   <= {2'b10, 4'hf, ARP_3};
            //       testbench_state   <= tail;
            // end
            3'd3: begin
                  r_pktIn   <= {2'b10, 4'h9, ARP_2};
                  testbench_state   <= tail;
            end
          endcase
        end
        tail: begin
          pkt_cnt           <= pkt_cnt + 8'd1;
          if(pkt_cnt == 8'd0) begin
            pkt_cnt         <= 'b0;
          `ifdef GEN_ARP
            testbench_state <= send_arp;
          `endif
          `ifdef GEN_A_PKT
            // testbench_state <= gen_a_pkt;
          `endif
          end
        end
      `ifdef SIM_PKT_IO
        read_sim_pkt: begin
          r_pktIn_valid         <= 'b0;
          cnt_pkt_data          <= 'b0;
          cnt_clk               <= 'b0;
          $readmemh(pktIn_file, memPktIn);
          testbench_state       <= read_pkt_head;
          handle_pktIn_rdata;
        end
        read_pkt_head: begin
          handle_pktIn_rdata;
          if(memPktIn[0][15:0] == tag_pkt)
            testbench_state     <= wait_x_clk;
          else begin
            tag_pkt             <= memPktIn[0][15:0];
            length_pkt_data     <= memPktIn[1][7:0];
            tag_pkt_valid       <= memPktIn[1][11:8];

            r_pktIn_valid       <= 1'b1;
            r_pktIn             <= {2'b01,4'hf, pktIn_rdata};
            testbench_state     <= wait_pkt_tail;
            cnt_pkt_data        <= 8'd1 + cnt_pkt_data;
          end
        end
        wait_pkt_tail: begin
          handle_pktIn_rdata;
          r_pktIn_valid         <= 'b1;
          cnt_pkt_data          <= 8'd1 + cnt_pkt_data;
          if(length_pkt_data == (cnt_pkt_data+8'd1)) begin
            r_pktIn             <= {2'b10,tag_pkt_valid, pktIn_rdata};
            // state_cur           <= IDLE_S;
            testbench_state     <= read_sim_pkt;
          end
          else begin
            r_pktIn             <= {2'b00,4'hf, pktIn_rdata};
          end
        end
        wait_x_clk: begin
          r_pktIn_valid        <= 'b0;
          cnt_clk               <= 32'd1 + cnt_clk;
          if(cnt_clk[15] == 1'b1)
            testbench_state     <= read_sim_pkt;
        end
      `endif  
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
