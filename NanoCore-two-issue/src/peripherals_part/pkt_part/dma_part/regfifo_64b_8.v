/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        regfifo_64b_8.
 *  Description:        This module is fake fifo implemented by Regs.
 *  Last updated date:  2022.08.19.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module regfifo_64b_8(
   input  wire              clk
  ,input  wire              srst
  //* pkt in & out;
  ,input  wire              wr_en
  ,input  wire  [63:0]      din
  ,input  wire              rd_en
  ,output wire  [63:0]      dout
  ,output wire              full
  ,output wire              empty
  ,output reg   [9:0]       data_count
);

  //======================= internal reg/wire/param declarations =//
  //* fifo for receiving pkt;
  reg   [63:0]              r_data[7:0];
  reg   [7:0]               r_bm_valid;
  
  assign                    dout  = r_data[0];
  assign                    full  = &r_bm_valid;
  assign                    empty = ~(|r_bm_valid);
  //==============================================================//

  //======================= buffer data    =======================//
  integer i;
  always @(posedge clk or posedge srst) begin
    if (srst) begin
      r_bm_valid            <= 4'b0;
      data_count            <= 10'b0;
    end
    else begin
      (*full_case, parallel_case*)
      case({wr_en, rd_en})
        2'b00: begin 
              data_count    <= data_count;
        end
        2'b01: begin 
              r_bm_valid    <= {1'b0,r_bm_valid[7:1]};
              for(i=0; i<7; i=i+1) begin
                r_data[i]   <= r_data[i+1];
              end
              r_data[7]     <= 64'b0;
              data_count    <= data_count - 10'd1;
        end
        2'b10: begin 
            casex(r_bm_valid)
              8'bxxxx_xxx0: begin r_bm_valid  <= 8'b1;        r_data[0]   <= din; end
              8'bxxxx_xx01: begin r_bm_valid  <= 8'b11;       r_data[1]   <= din; end
              8'bxxxx_x011: begin r_bm_valid  <= 8'b111;      r_data[2]   <= din; end
              8'bxxxx_0111: begin r_bm_valid  <= 8'b1111;     r_data[3]   <= din; end
              8'bxxx0_1111: begin r_bm_valid  <= 8'b1_1111;   r_data[4]   <= din; end
              8'bxx01_1111: begin r_bm_valid  <= 8'b11_1111;  r_data[5]   <= din; end
              8'bx011_1111: begin r_bm_valid  <= 8'b111_1111; r_data[6]   <= din; end
              8'b0111_1111: begin r_bm_valid  <= 8'b1111_1111;r_data[7]   <= din; end
              default: begin end
            endcase
              data_count    <= data_count + 10'd1;
        end
        2'b11: begin
          case(r_bm_valid)
            8'b000_0000,8'b0000_0001:  r_data[0]  <= din;
            8'b0000_0011:         {r_data[0],r_data[1]}  <= {r_data[1],din};
            8'b0000_0111:         {r_data[0],r_data[1],r_data[2]}  <= {r_data[1],r_data[2],din};
            8'b0000_1111:         {r_data[0],r_data[1],r_data[2],r_data[3]}  <= {r_data[1],r_data[2],r_data[3],din};
            8'b0001_1111:         {r_data[0],r_data[1],r_data[2],r_data[3],
                                    r_data[4]}  <= {r_data[1],r_data[2],r_data[3],r_data[4],din};
            8'b0011_1111:         {r_data[0],r_data[1],r_data[2],r_data[3],
                                    r_data[4],r_data[5]}  <= {r_data[1],r_data[2],r_data[3],r_data[4],r_data[5],din};
            8'b0111_1111:         {r_data[0],r_data[1],r_data[2],r_data[3],
                                    r_data[4],r_data[5],r_data[6]}  <= {r_data[1],r_data[2],r_data[3],r_data[4],
                                                                        r_data[5],r_data[6],din};
            8'b1111_1111:         {r_data[0],r_data[1],r_data[2],r_data[3],
                                    r_data[4],r_data[5],r_data[6],r_data[7]}  <= {r_data[1],r_data[2],r_data[3],
                                                                        r_data[4],r_data[5],r_data[6],r_data[7],din};
            default: begin end
          endcase
            data_count      <= data_count;
        end
      endcase
    end
  end
  //==============================================================//
  

endmodule
