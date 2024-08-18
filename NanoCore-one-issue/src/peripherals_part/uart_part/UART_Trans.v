/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        UART_Trans.
 *  Description:        output r_data 1b by 1b.
 *  Last updated date:  2021.11.20.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module UART_Trans(
  input  wire               i_clk,
  input  wire               i_rst_n,
  input  wire [7:0]         i_din_8b,
  input  wire               i_wren,
  input  wire               i_clken,
  output reg                o_tx,
  output wire               o_tx_busy
);

  //======================= internal reg/wire/param declarations =//
  localparam  STATE_IDLE    = 2'b00,
              STATE_START   = 2'b01,
              STATE_DATA    = 2'b10,
              STATE_STOP    = 2'b11;

  reg         [7:0]         r_data;
  reg         [2:0]         r_bitpos;
  reg         [1:0]         state;
  //==============================================================//

  //======================= UART sends data ======================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      o_tx                  <= 1'b1;
      r_data                <= 8'b0;
      r_bitpos              <= 3'b0;
      state                 <= STATE_IDLE;
    end
    else begin
      case (state)
        STATE_IDLE: begin
          if(i_wren == 1'b1) begin
            state           <= STATE_START;
            r_data          <= i_din_8b;
            r_bitpos        <= 3'h0;
          end
          else begin
            state           <= STATE_IDLE;
            r_data          <= r_data;
            r_bitpos        <= 3'h0;
          end
        end
        STATE_START: begin
          if (i_clken) begin
            o_tx            <= 1'b0;
            state           <= STATE_DATA;
          end
          else begin
            o_tx            <= o_tx;
            state           <= STATE_START;
          end
        end
        STATE_DATA: begin
          if (i_clken) begin
            if (r_bitpos == 3'h7) begin 
              state         <= STATE_STOP;
            end
            else begin
              r_bitpos      <= r_bitpos + 3'h1;
            end
            (*parallel_case, full_case*)
            case(r_bitpos)
              3'd0: o_tx    <= r_data[0];
              3'd1: o_tx    <= r_data[1];
              3'd2: o_tx    <= r_data[2];
              3'd3: o_tx    <= r_data[3];
              3'd4: o_tx    <= r_data[4];
              3'd5: o_tx    <= r_data[5];
              3'd6: o_tx    <= r_data[6];
              3'd7: o_tx    <= r_data[7];
            endcase
          end
          else begin
            state           <= STATE_DATA;
          end
        end
        STATE_STOP: begin
          if (i_clken) begin
            o_tx            <= 1'b1;
            state           <= STATE_IDLE;
          end
          else begin
            o_tx            <= o_tx;
            state           <= STATE_STOP;
          end
        end
        default: begin
          o_tx              <= 1'b1;
          state             <= STATE_IDLE;
        end
      endcase
    end
  end

  assign o_tx_busy          = (state != STATE_IDLE);
  //==============================================================//

endmodule
