/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        regfifo_528b_4.
 *  Description:        This module is fake fifo implemented by Regs.
 *  Last updated date:  2022.08.19.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module regfifo_528b_4(
   input  wire              clk
  ,input  wire              srst
  //* pkt in & out;
  ,input  wire              wr_en
  ,input  wire  [527:0]     din
  ,input  wire              rd_en
  ,output wire  [527:0]     dout
  ,output wire              full
  ,output wire              empty
);

  //======================= internal reg/wire/param declarations =//
  //* fifo for receiving pkt;
  reg   [527:0]             r_data[3:0];
  reg   [3:0]               r_bm_valid;
  
  assign                    dout  = r_data[0];
  assign                    full  = &r_bm_valid;
  assign                    empty = ~(|r_bm_valid);
  //==============================================================//

  //======================= buffer data    =======================//
  integer i;
  always @(posedge clk or posedge srst) begin
    if (srst) begin
      //* reset
      for(i=0; i<4; i=i+1) begin
        r_data[i]           <= 528'b0;
      end
      r_bm_valid            <= 4'b0;
    end
    else begin
      (*full_case, parallel_case*)
      case({wr_en, rd_en})
        2'b00: begin end
        2'b01: begin 
               r_bm_valid   <= {1'b0,r_bm_valid[3:1]};
               for(i=0; i<3; i=i+1) begin
                 r_data[i]  <= r_data[i+1];
               end
               r_data[3]    <= 528'b0;
        end
        2'b10: begin 
               r_bm_valid   <= (r_bm_valid[0]   == 1'b0)? 4'b1:
                                (r_bm_valid[1]  == 1'b0)? 4'b11:
                                (r_bm_valid[2]  == 1'b0)? 4'b111: 4'b1111;
               r_data[0]    <= (r_bm_valid[0]   == 1'b0)? din: r_data[0];
               r_data[1]    <= (r_bm_valid[1:0] == 2'b01)? din: r_data[1];
               r_data[2]    <= (r_bm_valid[2:0] == 3'b011)? din: r_data[2];
               r_data[3]    <= (r_bm_valid[3:0] == 4'b0111)? din: r_data[3];
        end
        2'b11: begin
          case(r_bm_valid)
            4'b0000,4'b0001:  r_data[0]  <= din;
            4'b0011:          {r_data[0],r_data[1]}  <= {r_data[1],din};
            4'b0111:          {r_data[0],r_data[1],r_data[2]}  <= {r_data[1],r_data[2],din};
            4'b1111:          {r_data[0],r_data[1],r_data[2],r_data[3]}  <= {r_data[1],r_data[2],r_data[3],din};
            default: begin end
          endcase
        end
      endcase
    end
  end
  //==============================================================//
  

endmodule
