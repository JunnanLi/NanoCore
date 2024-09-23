/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        CSR_TOP.
 *  Description:        top module of CSR.
 *  Last updated date:  2022.06.17.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) support pipelined reading/writing;
 */

module CSR_TOP (
  //* clk & reset;
  input   wire                i_clk,
  input   wire                i_rst_n,
  //* peri interface;
  input   wire  [   31:0]     i_addr_32b,
  input   wire                i_wren,
  input   wire                i_rden,
  input   wire  [   31:0]     i_din_32b,
  output  reg   [   31:0]     o_dout_32b,
  output  reg                 o_dout_32b_valid,
  //* interrupt;
  output  wire                o_interrupt,          
  output  reg                 o_time_int 
  // //* system time;
  // ,input  wire                i_update_valid
  // ,input  wire  [   64:0]     i_update_system_time
  // ,output wire  [   63:0]     o_system_time
  // ,output reg                 o_second_pulse
);


  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* r_intTime, r_intTime_dec are timers for irq;
  //*   r_intTime is configured by program;
  //*   r_intTime_dec is used to decrease from r_intTime;
  reg           [31:0]      r_intTime, r_intTime_dec;
  //* r_sysTime_s is system time in second;
  //* r_sysTime_ns is system time in nano-second;
  //* r_toRead_sysTime_s is current system time in second when reading;
  //* r_toUpdate_sysTime_ns is system time in nano-second to update;
  //* r_toUpdate_sysTime_s is system time in second to update;
  //* r_ns_per_clk is related with PE's clock frequency, i.e., 20ns for 50MHz;
  reg           [31:0]      r_sysTime_ns, r_sysTime_s, r_toRead_sysTime_s;
  reg           [31:0]      r_toUpdate_sysTime_ns, r_toUpdate_sysTime_s;
  reg                       r_toUpdate_time, r_intTime_en; 
  reg           [7:0]       r_ns_per_clk;

  //* r_guard should be '0x1234' when writing CSR;
  reg           [15:0]      r_guard;
  reg                       r_wr_req;  //* used to maintain wr req;
  wire                      w_guard_en;
  reg           [31:0]      sw_version;           //* e.g., 0x20220721
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  genvar j_pe;
  assign o_interrupt        = 1'b0;
  // assign o_system_time      = {r_sysTime_s, r_sysTime_ns};

  //* guard;
    assign w_guard_en       = (r_guard == 16'h1234);

  //==============================================================//
  //  time interrupt    
  //==============================================================//
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_time_int                    <= 1'b0;
      //* r_intTime_dec for time_irq (in 20ns);
      r_intTime_dec                 <= 32'b0;
    end 
    else begin
      o_time_int                    <= 1'b0;
      r_intTime_dec                 <= r_intTime_dec - 32'd1;
      if(|r_intTime_dec == 1'b0) begin
        r_intTime_dec               <= r_intTime;
        o_time_int                  <= (|r_intTime) & !r_intTime_en;
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  Config CSR
  //==============================================================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* peri interface;
      o_dout_32b_valid              <= 1'b0;
      r_guard                       <= 16'b0;
      //* cmp timer;
      r_intTime                     <= 32'b0;
      //* system_time
      r_sysTime_ns                  <= 32'b0;
      r_sysTime_s                   <= 32'b0;
      r_toUpdate_time               <= 1'b0;
      r_intTime_en                  <= 'b0;
      sw_version                    <= 32'h20220000; //* e.g., 0x20220721
      r_ns_per_clk                  <= `NS_PER_CLK;
    end 
    else begin
      o_dout_32b_valid              <= i_wren | i_rden;
      r_toUpdate_time               <= 1'b0;
      r_intTime_en                  <= 'b0;

      //* writing;
      if(i_wren) begin
        r_guard                     <= 16'b0;
        case(i_addr_32b[6:2])
          5'd0: begin   end
          5'd1: r_guard             <= i_din_32b[15:0];
          5'd2: sw_version          <= (w_guard_en == 1'b1)? i_din_32b: sw_version;
          5'd9: begin 
                r_toUpdate_sysTime_ns <= r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0};
                r_toUpdate_sysTime_s  <= r_sysTime_s - i_din_32b;
                r_toUpdate_time       <= (w_guard_en == 1'b1)? 1'b1: 1'b0;
          end
          5'd10: begin
                r_toUpdate_sysTime_ns <= r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0};
                r_toUpdate_sysTime_s  <= r_sysTime_s + i_din_32b;
                r_toUpdate_time       <= (w_guard_en == 1'b1)? 1'b1: 1'b0;
          end
          5'd11: begin 
                r_toUpdate_sysTime_ns <= r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - i_din_32b;
                r_toUpdate_sysTime_s  <= r_sysTime_s;
                r_toUpdate_time       <= (w_guard_en == 1'b1)? 1'b1: 1'b0;
          end
          5'd12: begin
                r_toUpdate_sysTime_ns <= r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + i_din_32b;
                r_toUpdate_sysTime_s  <= r_sysTime_s;
                r_toUpdate_time       <= (w_guard_en == 1'b1)? 1'b1: 1'b0;
          end
          5'd14: begin
                r_intTime_en          <= 1'b1;
                r_intTime             <= i_din_32b;
          end
          5'd31:r_ns_per_clk          <= (w_guard_en == 1'b1)? i_din_32b[7:0]: r_ns_per_clk;
          default: begin
          end
        endcase
      end
      else begin
        sw_version                    <= sw_version;
        r_toUpdate_sysTime_ns         <= r_toUpdate_sysTime_ns;
        r_toUpdate_sysTime_s          <= r_toUpdate_sysTime_s;
        r_toUpdate_time               <= 1'b0;
      end

      //* to read;
      if(i_rden == 1'b1) begin
        (*full_case, parallel_case*)
        case(i_addr_32b[2+:5])
          5'd0: o_dout_32b          <= 32'b0;
          5'd1: o_dout_32b          <= r_guard;
          5'd2: o_dout_32b          <= sw_version;
          5'd3: o_dout_32b          <= `HW_VERSION;
          5'd4: o_dout_32b          <= 32'd0;
          5'd12:begin 
                o_dout_32b          <= r_sysTime_ns;
                r_toRead_sysTime_s  <= r_sysTime_s;
          end
          5'd13:o_dout_32b          <= r_toRead_sysTime_s;
          5'd14:o_dout_32b          <= r_intTime;
          5'd15:o_dout_32b          <= 32'b0;
          default: begin
                o_dout_32b          <= 32'b0;
          end
        endcase
      end

      //* update system_time;
      if(r_toUpdate_time == 1'b1) begin
        if(r_toUpdate_sysTime_ns[31] == 1'b1) begin //* minus offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns + 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s - 32'd1;
        end
        else if(r_toUpdate_sysTime_ns >= 32'd1_000_000_000) begin
          //* add offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns - 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s + 32'd1;
        end
        else begin
          r_sysTime_ns              <= r_toUpdate_sysTime_ns;
          r_sysTime_s               <= r_toUpdate_sysTime_s;
        end
      end
      else begin
        if(r_sysTime_ns >= 32'd1_000_000_000) begin
          r_sysTime_ns              <= {24'b0,r_ns_per_clk[7:0]};
          r_sysTime_s               <= r_sysTime_s + 32'd1;
        end
        else begin
          r_sysTime_ns              <= r_sysTime_ns + {24'b0,r_ns_per_clk[7:0]};
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  // //==============================================================//
  // //  second pulse
  // //==============================================================//
  // always @(posedge i_clk or negedge i_rst_n) begin
  //   if(~i_rst_n) begin
  //     o_second_pulse <= 1'b0;
  //   end else begin
  //     o_second_pulse <= (r_sysTime_ns >= 32'd1_000_000_000);
  //   end
  // end
  // //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
endmodule
