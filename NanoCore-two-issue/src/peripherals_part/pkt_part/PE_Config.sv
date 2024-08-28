/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        PE_Config.
 *  Description:        This module is used to configure itcm and dtcm of CPU.
 *  Last updated date:  2024.02.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2024 NUDT.
 *
 *  Noted:
 */

module PE_Config(
  //* clk & rst_n
   input                    i_clk
  ,input                    i_rst_n
  //* network;
  ,input  wire              i_data_conf_valid
  ,input  wire [   133:0]   i_data_conf      
  ,output reg               o_data_conf_valid
  ,output reg  [   133:0]   o_data_conf      
  //* config interface;
  ,output reg               o_conf_rden     //* configure interface
  ,output reg               o_conf_wren
  ,output reg   [   15:0]   o_conf_addr
  ,output reg   [  127:0]   o_conf_wdata
  ,input        [  127:0]   i_conf_rdata
  ,output reg   [    3:0]   o_conf_en       //* '1' means configuring is valid;
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  /** state_conf is used to configure (read or write) itcm and dtcm
  *   stat_out is used to output "print" in the program running on CPU
  */

  typedef enum logic [3:0] {IDLE_S, WR_SEL_NET_S, RD_SEL_NET_S, 
                            WR_ADDR_NET_S, RD_ADDR_NET_S,
                            WR_PROG_NET_S, RD_PROG_NET_S, DISCARD_NET_S, 
                            SEND_HEAD_NET, SEND_HEAD_0, SEND_HEAD_1, SEND_HEAD_2, 
                            SEND_HEAD_3, SEND_HEAD_WR} state_t;
  state_t state_conf, state_out;

  /** r_read_sel_tag is used to identify whether need to read "sel", i.e., 
   *    running mode of CPU;
   *  r_write_tag is used to respond a pkt for writing action;
  */
  reg                       r_read_sel_tag[1:0];
  reg                       r_write_tag[1:0];

  //* fifo used to buffer read data;
  wire                      w_empty_rdata;
  wire      [       63:0]   w_dout_rdata;
  reg       [       63:0]   r_fake_dout_rdata;
  reg                       r_rden_rdata;
  //* temp;
  reg       [       31:0]   r_addr_temp[1:0];
  reg       [        1:0]   r_rden_temp;
  reg       [       47:0]   r_local_mac, r_dst_mac;
  reg       [       15:0]   r_pre_data_h16b;
  reg       [       15:0]   r_conf_addr;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   parser pkt and config MEM
  //====================================================================//
  /** state machine for configuring itcm and dtcm:
  *   1) distinguish action type according to ethernet_type filed;
  *   2) configure running mode, i.e., "conf_sel_dtcm", 0 is configure, 
  *     while 1 is running;
  *   3) read running mode, i.e., toggle "r_read_sel_tag[0]";
  *   4) write program, including itcm and dtcm;
  *   5) read program, including itcm and dtcm;
  */
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      //* config interface;
      o_conf_rden             <= 1'b0;
      o_conf_wren             <= 1'b0;
      o_conf_en               <= 4'hf;
      //* temp;
      r_read_sel_tag[0]       <= 1'b0;
      r_write_tag[0]          <= 1'b0;
      r_local_mac             <= 48'h1111_2222_4444;
      r_dst_mac               <= 48'h1111_2222_3333;
      state_conf              <= IDLE_S;
    end
    else begin
      o_conf_wren             <= 1'b0;
      o_conf_rden             <= 1'b0;
      r_pre_data_h16b         <= i_data_conf[15:0];
      o_conf_addr             <= r_conf_addr;

      case(state_conf)
        IDLE_S: begin
          //* configure by network directly;
          if(i_data_conf_valid == 1'b1 && i_data_conf[133:132] == 2'b01) begin
            (*full_case, parallel_case*)
            case(i_data_conf[1:0])
              2'd1: state_conf    <= WR_SEL_NET_S;
              2'd2: state_conf    <= RD_SEL_NET_S;
              2'd3: state_conf    <= WR_ADDR_NET_S;
              2'd0: state_conf    <= RD_ADDR_NET_S;
              // 2'd0: state_conf  <= IDLE_S;
            endcase
            r_dst_mac             <= i_data_conf[32+:48];
            r_local_mac           <= i_data_conf[80+:48];
          end
          else begin
            state_conf            <= IDLE_S;
          end
        end
        ////////////////////////////////////////////
        //* network;
        ////////////////////////////////////////////
          WR_SEL_NET_S: begin
            o_conf_en             <= i_data_conf[19:16];
            state_conf            <= DISCARD_NET_S;
          end
          RD_SEL_NET_S: begin
            state_conf            <= DISCARD_NET_S;
            r_read_sel_tag[0]     <= ~r_read_sel_tag[0];
          end
          WR_ADDR_NET_S: begin
            r_conf_addr           <= i_data_conf[127-:16];
            state_conf            <= WR_PROG_NET_S;
          end
          WR_PROG_NET_S: begin
            o_conf_wren           <= 1'b1;
            r_conf_addr           <= r_conf_addr + 16'd4;
            o_conf_wdata          <= {i_data_conf[47:16],i_data_conf[79:48],
                                      i_data_conf[111:80],r_pre_data_h16b,i_data_conf[127:112]};

            state_conf            <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? IDLE_S: WR_PROG_NET_S;
            r_write_tag[0]        <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? ~r_write_tag[0]: r_write_tag[0];
          end
          RD_ADDR_NET_S: begin
            o_conf_addr           <= i_data_conf[127-:16];
            state_conf            <= RD_PROG_NET_S;
          end
          RD_PROG_NET_S: begin
            // TODO:
            state_conf            <= DISCARD_NET_S;
            o_conf_rden           <= 1'b1;
            o_conf_addr           <= i_data_conf[47:16];
          end
          DISCARD_NET_S: begin
            state_conf            <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? IDLE_S: DISCARD_NET_S;
          end
        default: begin
          state_conf              <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  //====================================================================//
  //*     return config_en or radata
  //====================================================================//
  /** state machine used to output reading result or print value:
  *   1) configure metadata_0&1 (according to fast packet format);
  *   2) output reading result or print value which is distinguished
  *     by ethernet_type filed;
  */
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      // reset
      o_data_conf_valid           <= 1'b0;
      o_data_conf                 <= 134'b0;
      r_read_sel_tag[1]           <= 1'b0;
      r_write_tag[1]              <= 1'b0;
      //* temp;
      r_rden_temp                 <= 2'b0;
      r_addr_temp[0]              <= 32'b0;
      r_addr_temp[1]              <= 32'b0;
      //* fifo;
      r_rden_rdata                <= 1'b0;
      //* state;
      state_out                   <= IDLE_S;
    end
    else begin
      case(state_out)
        IDLE_S: begin
          o_data_conf_valid       <= 1'b0;
          if(r_read_sel_tag[1] != r_read_sel_tag[0]) begin
            state_out             <= SEND_HEAD_0;
          end
          else if(r_write_tag[1] != r_write_tag[0]) begin
            state_out             <= SEND_HEAD_WR;
          end
          else if(w_empty_rdata == 1'b0) begin
            o_data_conf[133:32]   <= {2'b01,4'hf,r_dst_mac, r_local_mac}; 
            o_data_conf[31:0]     <= {16'h9005,16'h14};
            o_data_conf_valid     <= 1'b1;
            r_rden_rdata          <= 1'b1;
            state_out             <= SEND_HEAD_NET;
          end
          else begin
            state_out             <= IDLE_S;
          end
        end
        SEND_HEAD_0: begin
          state_out               <= SEND_HEAD_1;
          o_data_conf_valid       <= 1'b1;
          o_data_conf[31:0]       <= {16'h9005,16'h12};
          o_data_conf[133:32]     <= {2'b01,4'hf,r_dst_mac, r_local_mac};  
          r_read_sel_tag[1]       <= r_read_sel_tag[0];    
        end
        SEND_HEAD_WR: begin
          state_out               <= SEND_HEAD_1;
          o_data_conf_valid       <= 1'b1;
          o_data_conf[31:0]       <= {16'h9005,16'h12};
          o_data_conf[133:32]     <= {2'b01,4'hf,r_dst_mac, r_local_mac};
          r_write_tag[1]          <= r_write_tag[0];
        end
        SEND_HEAD_1: begin
          o_data_conf[111:16]     <= {88'b0,o_conf_en};
          o_data_conf[133:112]    <= {2'b0,4'hf,16'b0};
          o_data_conf[15:0]       <= 16'b0;
          state_out               <= SEND_HEAD_2;
        end
        SEND_HEAD_NET: begin
          r_rden_rdata            <= 1'b0;
          o_data_conf[133:112]    <= {2'b0,4'hf,16'b0};
          o_data_conf[111:16]     <= {32'b0,w_dout_rdata};
          o_data_conf[15:0]       <= 16'b0;
          state_out               <= SEND_HEAD_2;
        end
        SEND_HEAD_2: begin
          o_data_conf             <= {2'b0,4'hf,128'd1};
          state_out               <= SEND_HEAD_3;
        end
        SEND_HEAD_3: begin
          o_data_conf             <= {2'b10,4'hf,128'd2};
          state_out               <= IDLE_S;
        end
        default: begin
          state_out               <= IDLE_S;
        end
      endcase

      //* temp;
      r_rden_temp                     <= {r_rden_temp[0],o_conf_rden};
      {r_addr_temp[1],r_addr_temp[0]} <= {r_addr_temp[0],o_conf_addr};
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

    
  //* fake fifo;
  reg [1:0] cnt_rdata;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      // reset
      r_fake_dout_rdata           <= 64'b0;
      cnt_rdata                   <= 2'b0;
    end
    else begin
      r_fake_dout_rdata           <= (r_rden_temp[1] == 1'b1)? {i_conf_rdata, r_addr_temp[1]}:
                                      r_fake_dout_rdata;
      case({r_rden_temp[1],r_rden_rdata})
        2'b00: cnt_rdata          <= cnt_rdata;
        2'b01: cnt_rdata          <= cnt_rdata - 2'd1;
        2'b10: cnt_rdata          <= cnt_rdata + 2'd1;
        2'b11: cnt_rdata          <= cnt_rdata;
        default: begin end
      endcase
    end
  end
  assign w_dout_rdata   = r_fake_dout_rdata;
  assign w_empty_rdata  = (cnt_rdata == 2'b0);

endmodule
