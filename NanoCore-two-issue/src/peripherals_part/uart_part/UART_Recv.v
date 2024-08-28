/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        UART_Recv.
 *  Description:        receive data 1b by 1b.
 *  Last updated date:  2021.11.20.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module UART_Recv(
  input   wire              i_clk,
  input   wire              i_rst_n,
  input   wire              i_clken,
  output  reg   [7:0]       o_dout_8b,
  output  reg               o_dout_valid,
  input   wire              i_rx
);


  //======================= internal reg/wire/param declarations =//
  localparam RX_STATE_START = 2'b00,
             RX_STATE_DATA  = 2'b01,
             RX_STATE_STOP  = 2'b10;

  reg           [1:0]       state;
  reg           [3:0]       r_sample;
  reg           [3:0]       r_bitpos;
  reg           [7:0]       r_scratch;
  //==============================================================//

  //======================= UART_Receiver    =====================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_dout_valid          <= 1'b0;
      o_dout_8b             <= 8'b0;
      state                 <= RX_STATE_START;
      r_bitpos              <= 4'b0;
      r_sample              <= 4'b0;
      r_scratch             <= 8'b0;
    end
    else begin
      o_dout_valid          <= 1'b0;
      if (i_clken) begin
        case (state)
          RX_STATE_START: begin
            /*
            * Start counting from the first low r_sample, once we've
            * sampled a full bit, start collecting data bits.
            */
            if (!i_rx || r_sample != 4'b0) begin
              r_sample      <= r_sample + 4'b1;
            end
            else begin
              r_sample      <= r_sample;
            end

            if (r_sample == 4'd15) begin
              state         <= RX_STATE_DATA;
              r_bitpos      <= 4'b0;
              r_sample      <= 4'b0;
              r_scratch     <= 8'b0;
            end
            else begin
              state         <= RX_STATE_START;
            end
          end
          RX_STATE_DATA: begin
            r_sample        <= r_sample + 4'b1;
            if (r_sample == 4'h8) begin
              for(i=0; i<8; i=i+1) begin
                if(i == r_bitpos[2:0])
                  r_scratch[i] <= i_rx;
              end
              r_bitpos      <= r_bitpos + 4'b1;
            end
            else begin
              r_bitpos      <= r_bitpos;
            end

            if (r_bitpos == 4'd8 && r_sample == 4'd15) begin
              state         <= RX_STATE_STOP;
            end
            else begin
              state         <= RX_STATE_DATA;
            end
          end
          RX_STATE_STOP: begin
            /*
             * Our baud clock may not be running at exactly the
             * same rate as the transmitter.  If we thing that
             * we're at least half way into the stop bit, allow
             * transition into handling the next start bit.
             */
            if (r_sample == 4'd15 || (r_sample >= 4'd8 && !i_rx)) begin
              state         <= RX_STATE_START;
              o_dout_8b     <= r_scratch;
              o_dout_valid  <= 1'b1;
              r_sample      <= 4'b0;
            end else begin
              r_sample      <= r_sample + 4'b1;
            end
          end
          default: begin
            state           <= RX_STATE_START;
          end
        endcase
      end
    end
  end
  //==============================================================//

endmodule
