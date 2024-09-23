/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Out_Data.
 *  Description:        This module is used to output packets.
 *  Last updated date:  2022.06.16.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module DMA_Out_Data(
   input  wire                      i_clk
  ,input  wire                      i_rst_n
  //* data to output;
  ,output reg                       o_data_valid
  ,output reg   [133:0]             o_data

  //* 16b data in;
  ,output reg   [`NUM_PE-1:0]       o_rden_low16b
  ,input  wire  [`NUM_PE*20-1:0]    i_dout_low16b
  ,output reg   [`NUM_PE-1:0]       o_rden_high16b
  ,input  wire  [`NUM_PE*17-1:0]    i_dout_high16b
  //* usedw to cnt number of pkts buffered in 16b_fifo;
  ,input  wire  [`NUM_PE-1:0]       i_wren_16b
  ,input  wire  [`NUM_PE-1:0]       i_endTag
  //* debug;
  ,output wire  [3:0]               d_state_out_4b
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* for output (two 16b fifo);
  // wire  [15:0]              w_dout_16bData[1:0];
  wire  [15:0]              w_dout_low16b, w_dout_high16b;
  wire                      w_dout_endTag;
  wire  [3:0]               w_dout_validTag;

  reg   [`NUM_PE-1:0]       r_cpuID;
  reg   [7:0]               r_cnt_pkt[`NUM_PE-1:0];
  reg   [1:0]               r_cnt_rd;
  reg   [3:0]               r_temp_validTag;
  reg   [3:0]               state_out;
  //* assign temp for each PE;
  assign {w_dout_endTag,  w_dout_high16b} = (r_cpuID[0] == 1'b1)? i_dout_high16b[0+:17]:
                                          `ifdef PE1_EN
                                            (r_cpuID[1] == 1'b1)? i_dout_high16b[17+:17]:
                                          `endif
                                          `ifdef PE2_EN
                                            (r_cpuID[2] == 1'b1)? i_dout_high16b[17*2+:17]:
                                          `endif
                                          `ifdef PE3_EN
                                            (r_cpuID[3] == 1'b1)? i_dout_high16b[17*3+:17]:
                                          `endif
                                            i_dout_high16b[0+:17];
  assign {w_dout_validTag,w_dout_low16b } = (r_cpuID[0] == 1'b1)? i_dout_low16b[0+:20]:
                                          `ifdef PE1_EN
                                            (r_cpuID[1] == 1'b1)? i_dout_low16b[20+:20]:
                                          `endif
                                          `ifdef PE2_EN
                                            (r_cpuID[2] == 1'b1)? i_dout_low16b[20*2+:20]:
                                          `endif
                                          `ifdef PE3_EN
                                            (r_cpuID[3] == 1'b1)? i_dout_low16b[20*3+:20]:
                                          `endif
                                            i_dout_low16b[0+:20];

  //* states;
  localparam  IDLE_S        = 4'd0,
              OUTPUT_HEAD_S = 4'd2,
              WAIT_END_S    = 4'd3,
              PAD_TAIL_S    = 4'd4;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_data_valid                    <= 1'b0;
      o_data                          <= 134'b0;
      o_rden_high16b                  <= {`NUM_PE{1'b0}};
      o_rden_low16b                   <= {`NUM_PE{1'b0}};
      r_cpuID                         <= {`NUM_PE{1'b0}};
      r_cnt_rd                        <= 2'b0;
      // r_cnt_128b                      <= 8'b0;
      r_temp_validTag                 <= 4'b0;
      state_out                       <= IDLE_S;
      for(i=0; i<`NUM_PE; i=i+1) begin
        r_cnt_pkt[i]                  <= 8'b0;
      end
    end else begin
      //* count pkts;
      for(i=0; i<`NUM_PE; i=i+1) begin
        (*parallel_case, full_case*)
        case({i_wren_16b[i]&i_endTag[i], o_rden_high16b[i]&w_dout_endTag&r_cpuID[i]})
          2'b00,2'b11:  r_cnt_pkt[i]  <= r_cnt_pkt[i];
          2'b01:        r_cnt_pkt[i]  <= r_cnt_pkt[i] - 8'd1;
          2'b10:        r_cnt_pkt[i]  <= r_cnt_pkt[i] + 8'd1;
        endcase
      end
      
      //* output pkts from `NUM_PE PEs (MUX);
      case(state_out)
        IDLE_S: begin
          r_cnt_rd                    <= 2'b0;
          o_data_valid                <= 1'b0;
          r_cpuID                     <= {`NUM_PE{1'b0}};
            if(r_cnt_pkt[0] != 8'b0) begin
              o_rden_high16b[0]       <= 1'b1;
              o_rden_low16b[0]        <= 1'b1;
              r_cpuID[0]              <= 1'b1;
              state_out               <= OUTPUT_HEAD_S;
            end
          `ifdef PE1_EN
            else if(r_cnt_pkt[1] != 8'b0) begin
              o_rden_high16b[1]       <= 1'b1;
              o_rden_low16b[1]        <= 1'b1;
              r_cpuID[1]              <= 1'b1;
              state_out               <= OUTPUT_HEAD_S;
            end
          `endif
          `ifdef PE2_EN          
            else if(r_cnt_pkt[2] != 8'b0) begin
              o_rden_high16b[2]       <= 1'b1;
              o_rden_low16b[2]        <= 1'b1;
              r_cpuID[2]              <= 1'b1;
              state_out               <= OUTPUT_HEAD_S;
            end
          `endif
          `ifdef PE3_EN 
            else if(r_cnt_pkt[3] != 8'b0) begin
              o_rden_high16b[3]       <= 1'b1;
              o_rden_low16b[3]        <= 1'b1;
              r_cpuID[3]              <= 1'b1;
              state_out               <= OUTPUT_HEAD_S;
            end
          `endif
            else begin
              state_out               <= IDLE_S;
            end
        end
        OUTPUT_HEAD_S: begin
          r_cnt_rd                    <= r_cnt_rd + 2'd1;
          (*parallel_case, full_case*)
          case(r_cnt_rd)
            2'd0: o_data              <= {2'b01,4'hf,w_dout_high16b,w_dout_low16b,96'b0};
            2'd1: o_data[64+:32]      <= {w_dout_high16b,w_dout_low16b};
            2'd2: o_data[32+:32]      <= {w_dout_high16b,w_dout_low16b};
            2'd3: o_data[0+:32]       <= {w_dout_high16b,w_dout_low16b};
          endcase
          o_data_valid                <= (r_cnt_rd == 2'd3)? 1'b1: 1'b0;
          // r_cnt_128b                  <= 8'd1;
          r_temp_validTag             <= w_dout_validTag;
          state_out                   <= (r_cnt_rd == 2'd3)? WAIT_END_S: OUTPUT_HEAD_S;
        end
        WAIT_END_S: begin
          r_cnt_rd                    <= r_cnt_rd + 2'd1;
          (*parallel_case, full_case*)
          case(r_cnt_rd)
            2'd0: o_data              <= {2'b00,4'hf,w_dout_high16b,w_dout_low16b,96'b0};
            2'd1: o_data[64+:32]      <= {w_dout_high16b,w_dout_low16b};
            2'd2: o_data[32+:32]      <= {w_dout_high16b,w_dout_low16b};
            2'd3: o_data[0+:32]       <= {w_dout_high16b,w_dout_low16b};
          endcase
          // r_cnt_128b                  <= (r_cnt_rd == 2'd3)? (r_cnt_128b + 8'd1): r_cnt_128b;
          o_data_valid                <= (r_cnt_rd == 2'd3)? 1'b1: 1'b0;

          if(w_dout_endTag == 1'b1) begin
            o_rden_high16b            <= {`NUM_PE{1'b0}};
            o_rden_low16b             <= {`NUM_PE{1'b0}};

            if(r_cnt_rd == 2'b0) begin
              o_data_valid            <= 1'b1;
              o_data                  <= {2'b11,r_temp_validTag,128'b0};
              state_out               <= IDLE_S;
            end
            else begin
              o_data_valid            <= 1'b1;
              state_out               <= PAD_TAIL_S;
            end
          end
        end
        PAD_TAIL_S: begin
          o_data_valid                <= 1'b1;
          o_data                      <= {2'b11,r_temp_validTag,128'b0};
          state_out                   <= IDLE_S;
        end
        default: state_out            <= IDLE_S;
      endcase
    end
  end

  



  //* debug;
  assign      d_state_out_4b        = state_out;

endmodule
