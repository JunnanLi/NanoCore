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
  

  localparam  ARP_0             = 128'hffff_ffff_ffff_000b_3601_0203_0806_0001,
              ARP_1             = 128'h0800_0604_0001_000b_3601_0203_c0a8_030a,
              ARP_2             = 128'h0000_0000_0000_c0a8_0364_0000_0000_0000,
              ARP_3             = 128'h0000_0000_0000_0000_0000_0000_7374_7576;

  reg               clk,rst_n;
  reg               r_pktIn_valid;
  reg   [133:0]     r_pktIn;
  wire              w_pktOut_valid, w_pktData_valid_gmii;
  wire  [133:0]     w_pktOut, w_pktData_gmii;

  //* fake-respond packets;
  reg   [7:0][133:0]        temp_meta;
  reg   [7:0][  3:0]        temp_pktLen;
  reg   [7:0][7:0][133:0]   temp_pktData;
  reg   [3:0]               temp_pktNum, cnt_pktNum;
  initial begin
    //* arp respond; .10 -> .200
    temp_pktData[0][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h2a, 16'b0};
    temp_pktData[0][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308060001};
    temp_pktData[0][2]  <= {2'b00, 4'hf, 128'h08000604000200e04d6da7b3c0a8010a};
    temp_pktData[0][3]  <= {2'b10, 4'h9, 128'h000a35000102c0a801c8000000000000};
    temp_pktLen[0]      <= 4'd4;
    //* syn-ack respond; .10 -> .200
    temp_pktData[1][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h3a, 16'b0};
    temp_pktData[1][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308004500};
    temp_pktData[1][2]  <= {2'b00, 4'hf, 128'h002c000040004006b6a9c0a8010ac0a8};
    temp_pktData[1][3]  <= {2'b00, 4'hf, 128'h01c81389c001732f63510000196e6012};
    temp_pktData[1][4]  <= {2'b10, 4'h9, 128'hfaf084410000020405b4000000000000};
    temp_pktLen[1]      <= 4'd5;
    //* ack_0 respond; .10 -> .200
    temp_pktData[2][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h36, 16'b0};
    temp_pktData[2][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308004500};
    temp_pktData[2][2]  <= {2'b00, 4'hf, 128'h0028e84b40004006ce61c0a8010ac0a8};
    temp_pktData[2][3]  <= {2'b00, 4'hf, 128'h01c81389c00138766005000019865010};
    temp_pktData[2][4]  <= {2'b10, 4'h5, 128'hfad8843d000000000000000000000000};
    temp_pktLen[2]      <= 4'd5;
    //* ack_1 respond; .10 -> .200
    temp_pktData[3][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h36, 16'b0};
    temp_pktData[3][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308004500};
    temp_pktData[3][2]  <= {2'b00, 4'hf, 128'h0028e84c40004006ce60c0a8010ac0a8};
    temp_pktData[3][3]  <= {2'b00, 4'hf, 128'h01c81389c001387660050000249e5010};
    temp_pktData[3][4]  <= {2'b10, 4'h5, 128'hf410843d000000000000000000000000};
    temp_pktLen[3]      <= 4'd5;  
    temp_pktNum         <= 4'd4;
    //* ack_2 respond; .10 -> .200
    temp_pktData[4][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h36, 16'b0};
    temp_pktData[4][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308004500};
    temp_pktData[4][2]  <= {2'b00, 4'hf, 128'h0028e84d40004006ce5fc0a8010ac0a8};
    temp_pktData[4][3]  <= {2'b00, 4'hf, 128'h01c81389c0013876600500002a2a5010};
    temp_pktData[4][4]  <= {2'b10, 4'h5, 128'hf99c843d000000000000000000000000};
    temp_pktLen[4]      <= 4'd5;  
    temp_pktNum         <= 4'd4;
    //* ack_3 respond; .10 -> .200
    temp_pktData[5][0]  <= {2'b11, 4'hf, 96'b0, 4'h2, 12'h36, 16'b0};
    temp_pktData[5][1]  <= {2'b01, 4'hf, 128'h000a3500010200e04d6da7b308004500};
    temp_pktData[5][2]  <= {2'b00, 4'hf, 128'h0028e84e40004006ce5ec0a8010ac0a8};
    temp_pktData[5][3]  <= {2'b00, 4'hf, 128'h01c81389c0013876600500002fb65010};
    temp_pktData[5][4]  <= {2'b10, 4'h5, 128'hf99c843d000000000000000000000000};
    temp_pktLen[5]      <= 4'd5;  
    temp_pktNum         <= 4'd6;
  end

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
    #1600000 $finish;
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


  typedef enum logic [3:0] {idle, config_sram, start_core, wait_arp, wait_pkt, gen_resp, tail} state_t;
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
          pkt_cnt           <= (pkt_cnt == 8'd2)? 8'd2: (pkt_cnt + 8'd1);
          r_pktIn_valid     <= 1'b1;
          case(pkt_cnt[1:0])
            //* metadata;
            2'd0: r_pktIn   <= {2'b11, 4'hf, 96'b0, 4'h1, 12'h0, 16'b0};
            2'd1: r_pktIn   <= {2'b01, 4'hf, 48'h8988, 48'h1111, 16'h9005, 16'h3};
            2'd2: begin
                  r_pktIn   <= {2'b00, 4'hf, 48'b0, memory[mem_idx], 16'b0, mem_idx, 16'b0};
                  mem_idx   <= mem_idx + 1;
                `ifdef MEM_64KB
                  if(mem_idx == 16'h3fff) begin
                `elsif MEM_128KB
                  if(mem_idx == 16'h7fff) begin
                `elsif MEM_256KB
                  if(mem_idx == 16'hffff) begin
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
                  pkt_cnt         <= 'b0;
                  cnt_pktNum      <= 'd0;
                  testbench_state <= wait_arp;
            end
          endcase
        end
        wait_arp: begin
          if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b01 && w_pktOut[31:16] == 16'h0806) begin
            pkt_cnt         <= 'd1;
          end
          if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b10 && pkt_cnt[0] == 1'b1) begin
            testbench_state <= wait_pkt;
          end
        end
        wait_pkt: begin
          if(w_pktOut_valid == 1'b1 && w_pktOut[133:132] == 2'b10) begin
            testbench_state <= gen_resp;
            pkt_cnt         <= 'b0;
          end
        end
        gen_resp: begin
          pkt_cnt           <= pkt_cnt + 8'd1;
          r_pktIn_valid     <= 1'b1;
          if(pkt_cnt == temp_pktLen[cnt_pktNum]) begin
            r_pktIn_valid   <= 1'b0;
            cnt_pktNum      <= cnt_pktNum + 4'd1;
            testbench_state <= (cnt_pktNum == (temp_pktNum-1))? tail: wait_pkt;
          end
          for(integer idx=0; idx<8; idx=idx+1) begin
            if(idx == pkt_cnt)
              r_pktIn       <= temp_pktData[cnt_pktNum][idx];
          end
        end
        tail: begin
          pkt_cnt           <= pkt_cnt + 8'd1;
          if(pkt_cnt == 8'd0) begin
            pkt_cnt         <= 'b0;
          `ifdef GEN_ARP
            testbench_state <= send_arp;
          `endif
          end
        end 
      endcase
    end
  end

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
