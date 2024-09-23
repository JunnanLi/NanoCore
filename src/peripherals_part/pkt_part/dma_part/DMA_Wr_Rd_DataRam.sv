/*
 *  Project:            RvPipe -- a RISCV-32IM SoC.
 *  Module name:        DMA_Wr_Rd_DataRAM.
 *  Description:        This module is used to dma packets.
 *  Last updated date:  2024.02.21.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */
    
module DMA_Wr_Rd_DataRAM(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* data to DMA;
  ,input  wire              i_empty_data
  ,output reg               o_data_rden
  ,input  wire  [133:0]     i_data
  //* DMA (communicaiton with data SRAM);
  ,output reg               o_dma_rden
  ,output reg               o_dma_wren
  ,output reg   [ 31:0]     o_dma_addr
  ,output reg   [255:0]     o_dma_wdata
  ,output reg   [  7:0]     o_dma_wstrb
  ,output reg   [  7:0]     o_dma_winc
  ,input  wire  [255:0]     i_dma_rdata
  ,input  wire              i_dma_rvalid
  ,input  wire              i_dma_gnt
  //* 16b data out;
  ,output reg   [133:0]     o_din_rdDMA
  ,output reg               o_wren_rdDMA
  ,input  wire  [  8:0]     i_usedw_rdDMA
  //* pBuf in interface;
  ,output reg               o_rden_pBufWR
  ,input  wire  [ 47:0]     i_dout_pBufWR
  ,input  wire              i_empty_pBufWR
  ,output reg               o_rden_pBufRD
  ,input  wire  [ 63:0]     i_dout_pBufRD
  ,input  wire              i_empty_pBufRD
  ,input  wire  [  9:0]     i_usedw_pBufRD
  //* wait new pBufWR;
  ,output wire              o_wait_free_pBufWR
  //* int out;
  ,output reg   [ 31:0]     o_din_int
  ,output reg               o_wren_int
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* output related register;
  reg   [15:0]              r_din_16bData[1:0];
  reg   [1:0]               w_wren_16bData;
  reg   [3:0]               r_din_validTag, r_length_left;

  
  typedef enum logic [3:0] {IDLE_S, DMA_WRITE_S, WAIT_FREE_PBUF_S, 
                  DMA_READ_PART_DATA_0_S, DMA_READ_PART_DATA_1_S, DMA_READ_DATA_S, 
                  WAIT_NEXT_PBUF_S, WAIT_1_S, DISCARD_S} state_t;
  state_t state_dma;
  //==============================================================//


  //======================= Write & Read SRAM ====================//
  //* write SRAM & read SRAM; 
  reg   [15:0]  r_length_pBuf;  //* length of current pBuf;
  reg   [7:0]   r_din_rdDMA_mask;
  wire  [127:0] w_din_rdDMA_mask;
  reg   [1:0]   r_start_byte;
  reg   [2:0]   r_start_addr; 
  reg   [3:0]   temp_start_addr;
  wire  [127:0] reserve_i_data;
  logic [127:0] reserve_data_rdDMA_l, reserve_data_rdDMA_h;
  wire  [3:0]   dataValid_in_bm;
  reg           r_add_0_or_1;
  integer i;
  assign      reserve_i_data = {i_data[8*0+:8],i_data[8*1+:8],i_data[8*2+:8],i_data[8*3+:8],
                                i_data[8*4+:8],i_data[8*5+:8],i_data[8*6+:8],i_data[8*7+:8],
                                i_data[8*8+:8],i_data[8*9+:8],i_data[8*10+:8],i_data[8*11+:8],
                                i_data[8*12+:8],i_data[8*13+:8],i_data[8*14+:8],i_data[8*15+:8]};
  assign  reserve_data_rdDMA_l = {i_dma_rdata[8*0+:8],i_dma_rdata[8*1+:8],i_dma_rdata[8*2+:8],i_dma_rdata[8*3+:8],
                                i_dma_rdata[8*4+:8],i_dma_rdata[8*5+:8],i_dma_rdata[8*6+:8],i_dma_rdata[8*7+:8],
                                i_dma_rdata[8*8+:8],i_dma_rdata[8*9+:8],i_dma_rdata[8*10+:8],i_dma_rdata[8*11+:8],
                                i_dma_rdata[8*12+:8],i_dma_rdata[8*13+:8],i_dma_rdata[8*14+:8],i_dma_rdata[8*15+:8]};
  assign  reserve_data_rdDMA_h = {i_dma_rdata[8*16+:8],i_dma_rdata[8*17+:8],i_dma_rdata[8*18+:8],i_dma_rdata[8*19+:8],
                                i_dma_rdata[8*20+:8],i_dma_rdata[8*21+:8],i_dma_rdata[8*22+:8],i_dma_rdata[8*23+:8],
                                i_dma_rdata[8*24+:8],i_dma_rdata[8*25+:8],i_dma_rdata[8*26+:8],i_dma_rdata[8*27+:8],
                                i_dma_rdata[8*28+:8],i_dma_rdata[8*29+:8],i_dma_rdata[8*30+:8],i_dma_rdata[8*31+:8]};
  assign    w_din_rdDMA_mask = {{16{r_din_rdDMA_mask[7]}},{16{r_din_rdDMA_mask[6]}},{16{r_din_rdDMA_mask[5]}},{16{r_din_rdDMA_mask[4]}},
                                {16{r_din_rdDMA_mask[3]}},{16{r_din_rdDMA_mask[2]}},{16{r_din_rdDMA_mask[1]}},{16{r_din_rdDMA_mask[0]}}};
  //* 2'b000-2'b11
  //* [0]: 00-11 
  //* [1]: 01, 10, 11
  //* [2]: 10, 11
  //* [3]: 11
  assign      dataValid_in_bm[0] = 1'b1;
  assign      dataValid_in_bm[1] = |i_data[131:130];
  assign      dataValid_in_bm[2] = i_data[131];
  assign      dataValid_in_bm[3] = &i_data[131:130];
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_dma_rden                          <= 1'b0;
      o_dma_wren                          <= 1'b0;
      // o_dma_wdata                         <= 32'b0;
      o_dma_addr                          <= 32'b0;
      //* fifo;
      o_data_rden                         <= 1'b0;
      o_rden_pBufWR                       <= 1'b0;
      o_rden_pBufRD                       <= 1'b0;
      o_wren_int                          <= 1'b0;
      o_din_int                           <= 32'b0;
      r_length_pBuf                       <= 16'b0;
      o_wren_rdDMA                        <= 1'b0;

      state_dma                           <= IDLE_S;
    end 
    else begin
      case(state_dma)
        IDLE_S: begin
          o_wren_int                      <= 1'b0;
          o_wren_rdDMA                    <= 1'b0;
          o_dma_wren                      <= 1'b0;
          o_data_rden                     <= 1'b0;
          //* dma_wr;
          if(i_empty_data == 1'b0 && i_empty_pBufWR == 1'b0) begin 
            //* check head tag;
            if(i_data[133:132] == 2'b11) begin
              o_data_rden                 <= 1'b1;
              o_rden_pBufWR               <= 1'b1;
              o_din_int                   <= {1'b1, i_dout_pBufWR[30:0]};
              r_start_addr                <= i_dout_pBufWR[2+:3];
              r_length_pBuf               <= i_dout_pBufWR[47:32];
              r_add_0_or_1                <= i_dout_pBufWR[4];
              state_dma                   <= DMA_WRITE_S;
            end
            else begin
              //* discard pkt data untile meeting a new head;
              o_data_rden                 <= 1'b1;
              state_dma                   <= DISCARD_S;
            end
          end
          //* dma_rd;
          else if((i_usedw_pBufRD[9:1] != 9'b0) && 
            (i_usedw_rdDMA < 9'd100)) 
          begin
            o_rden_pBufRD                 <= 1'b1;
            // if(i_dout_pBufRD[1:0] == 2'd2)
            //   state_dma                   <= DMA_READ_DATA_TOP_2B_S;
            // else
              state_dma                   <= DMA_READ_DATA_S;
            r_start_addr                  <= i_dout_pBufRD[2+:3];
            r_start_byte                  <= i_dout_pBufRD[0+:2];
            r_length_pBuf                 <= i_dout_pBufRD[47:32];
            o_din_int                     <= {1'b0, i_dout_pBufRD[30:0]};
            r_din_validTag                <= (i_dout_pBufRD[48+:4] - 4'd1);
            r_add_0_or_1                  <= i_dout_pBufRD[4];
          end
          else begin
            state_dma                     <= IDLE_S;
          end
        end
        DMA_WRITE_S: begin
          o_data_rden                     <= 1'b1;
          o_rden_pBufWR                   <= 1'b0;
          o_dma_wren                      <= 1'b1;
          r_start_addr[2]                 <= ~r_start_addr[2];
          case(r_start_addr)
            3'd0: o_dma_wdata             <= {128'b0,reserve_i_data};
            3'd1: o_dma_wdata             <= {96'b0,reserve_i_data,32'b0};
            3'd2: o_dma_wdata             <= {64'b0,reserve_i_data,64'b0};
            3'd3: o_dma_wdata             <= {32'b0,reserve_i_data,96'b0};
            3'd4: o_dma_wdata             <= {reserve_i_data,128'b0};
            3'd5: o_dma_wdata             <= {reserve_i_data[95:0],128'b0,reserve_i_data[96+:32]};
            3'd6: o_dma_wdata             <= {reserve_i_data[63:0],128'b0,reserve_i_data[64+:64]};
            3'd7: o_dma_wdata             <= {reserve_i_data[31:0],128'b0,reserve_i_data[32+:96]};
          endcase
          case(r_start_addr)
            3'd0: o_dma_wstrb             <= {4'b0,dataValid_in_bm};
            3'd1: o_dma_wstrb             <= {3'b0,dataValid_in_bm,1'b0};
            3'd2: o_dma_wstrb             <= {2'b0,dataValid_in_bm,2'b0};
            3'd3: o_dma_wstrb             <= {1'b0,dataValid_in_bm,3'b0};
            3'd4: o_dma_wstrb             <= {dataValid_in_bm,4'b0};
            3'd5: o_dma_wstrb             <= {dataValid_in_bm[2:0],4'b0,dataValid_in_bm[3]};
            3'd6: o_dma_wstrb             <= {dataValid_in_bm[1:0],4'b0,dataValid_in_bm[3:2]};
            3'd7: o_dma_wstrb             <= {dataValid_in_bm[0],4'b0,dataValid_in_bm[3:1]};
          endcase
          case(r_start_addr)
            3'd0: o_dma_winc              <= 8'b0;
            3'd1: o_dma_winc              <= 8'b0;
            3'd2: o_dma_winc              <= 8'b0;
            3'd3: o_dma_winc              <= 8'b0;
            3'd4: o_dma_winc              <= 8'b0;
            3'd5: o_dma_winc              <= 8'b1;
            3'd6: o_dma_winc              <= 8'b11;
            3'd7: o_dma_winc              <= 8'b111;
          endcase
          r_length_pBuf                   <= r_length_pBuf - 16'd16;
          o_dma_addr                      <= o_rden_pBufWR? {5'b0,i_dout_pBufWR[31:5]}: 
                                              r_add_0_or_1? (o_dma_addr + 32'd1): o_dma_addr;
          r_add_0_or_1                    <= o_rden_pBufWR? i_dout_pBufWR[4]: ~r_add_0_or_1; 
                    
          //* finish writing;
          if(i_data[133:132] == 2'b10 ) begin 
            o_data_rden                   <= 1'b0;
            o_wren_int                    <= 1'b1;  //* gen a int.
            state_dma                     <= WAIT_1_S;
          end
          //* read next pBuf
          else if(r_length_pBuf[15:4] == 12'b0 || r_length_pBuf == 16'h10) 
          begin
            r_length_left                 <= 4'd0 - r_length_pBuf[3:0];
            o_data_rden                   <= 1'b0;
            state_dma                     <= WAIT_FREE_PBUF_S;
          end
          else begin
            state_dma                     <= DMA_WRITE_S;
          end
        end
        WAIT_FREE_PBUF_S: begin
          o_dma_wren                      <= 1'b0;
          if(i_empty_pBufWR == 1'b0) begin
            o_data_rden                   <= 1'b1;
            o_rden_pBufWR                 <= 1'b1;
            r_start_addr                  <= i_dout_pBufWR[2+:3];
            r_length_pBuf                 <= i_dout_pBufWR[47:32];
            state_dma                     <= (i_dout_pBufWR[31] == 1'b1)? DISCARD_S: DMA_WRITE_S;
          end
        end
        DMA_READ_PART_DATA_0_S: begin //* for reading data from dma;
          o_rden_pBufRD                   <= 1'b0;
          o_dma_rden                      <= 1'b1;
          o_dma_addr                      <= o_rden_pBufRD? {5'b0,i_dout_pBufRD[31:5]}: 
                                              r_add_0_or_1? (o_dma_addr + 32'd1): o_dma_addr;
          r_add_0_or_1                    <= o_rden_pBufRD? i_dout_pBufRD[4]: ~r_add_0_or_1; 
          // r_start_addr[2]                 <= ~r_start_addr[2];
          temp_start_addr                 <= {r_start_addr,1'b0} - {1'b0,(3'd0-r_length_left[3:1])};
          case(r_start_addr)
            3'd0: o_dma_winc              <= 8'b0;
            3'd1: o_dma_winc              <= 8'b01;
            3'd2: o_dma_winc              <= 8'b011;
            3'd3: o_dma_winc              <= 8'b0111;
            3'd4: o_dma_winc              <= 8'b0_1111;
            3'd5: o_dma_winc              <= 8'b1_1111;
            3'd6: o_dma_winc              <= 8'b11_1111;
            3'd7: o_dma_winc              <= 8'b111_1111;
          endcase
          case(r_length_left[3:1])
            3'd1: o_din_rdDMA[0+:16*1]    <= 'b0;
            3'd2: o_din_rdDMA[0+:16*2]    <= 'b0;
            3'd3: o_din_rdDMA[0+:16*3]    <= 'b0;
            3'd4: o_din_rdDMA[0+:16*4]    <= 'b0;
            3'd5: o_din_rdDMA[0+:16*5]    <= 'b0;
            3'd6: o_din_rdDMA[0+:16*6]    <= 'b0;
            3'd7: o_din_rdDMA[0+:16*7]    <= 'b0;
            default: begin
            end
          endcase
          case(r_length_left[3:1])
            3'd0: r_din_rdDMA_mask        <= 8'b0000_0000;
            3'd1: r_din_rdDMA_mask        <= 8'b0000_0001;
            3'd2: r_din_rdDMA_mask        <= 8'b0000_0011;
            3'd3: r_din_rdDMA_mask        <= 8'b0000_0111;
            3'd4: r_din_rdDMA_mask        <= 8'b0000_1111;
            3'd5: r_din_rdDMA_mask        <= 8'b0001_1111;
            3'd6: r_din_rdDMA_mask        <= 8'b0011_1111;
            3'd7: r_din_rdDMA_mask        <= 8'b0111_1111;
          endcase
          state_dma                       <= DMA_READ_PART_DATA_1_S;
        end

        DMA_READ_PART_DATA_1_S: begin //* for waiting rdData from dma;
          o_dma_rden                      <= 1'b0;
          o_wren_rdDMA                    <= i_dma_rvalid;
          if(i_dma_rvalid == 1'b1) begin
            // case({r_start_addr[1:0],r_start_byte[1]})
            //   3'd0: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & reserve_data_rdDMA_l;
            //   3'd1: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*1],reserve_data_rdDMA_l[127:16*1]};
            //   3'd2: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*2],reserve_data_rdDMA_l[127:16*2]};
            //   3'd3: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*3],reserve_data_rdDMA_l[127:16*3]};
            //   3'd4: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*4],reserve_data_rdDMA_l[127:16*4]};
            //   3'd5: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*5],reserve_data_rdDMA_l[127:16*5]};
            //   3'd6: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*6],reserve_data_rdDMA_l[127:16*6]};
            //   3'd7: o_din_rdDMA[127:0]    <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*7],reserve_data_rdDMA_l[127:16*7]};
            // endcase
            case(temp_start_addr)
              4'd0: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & reserve_data_rdDMA_l;
              4'd1: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*7],reserve_data_rdDMA_h[127:16*7]};
              4'd2: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*6],reserve_data_rdDMA_h[127:16*6]};
              4'd3: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*5],reserve_data_rdDMA_h[127:16*5]};
              4'd4: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*4],reserve_data_rdDMA_h[127:16*4]};
              4'd5: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*3],reserve_data_rdDMA_h[127:16*3]};
              4'd6: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*2],reserve_data_rdDMA_h[127:16*2]};
              4'd7: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_l[0+:16*1],reserve_data_rdDMA_h[127:16*1]};
              4'd8: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & reserve_data_rdDMA_h;
              4'd9: o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*7],reserve_data_rdDMA_l[127:16*7]};
              4'd10:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*6],reserve_data_rdDMA_l[127:16*6]};
              4'd11:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*5],reserve_data_rdDMA_l[127:16*5]};
              4'd12:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*4],reserve_data_rdDMA_l[127:16*4]};
              4'd13:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*3],reserve_data_rdDMA_l[127:16*3]};
              4'd14:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*2],reserve_data_rdDMA_l[127:16*2]};
              4'd15:o_din_rdDMA[127:0]      <= o_din_rdDMA[127:0] | w_din_rdDMA_mask & {reserve_data_rdDMA_h[0+:16*1],reserve_data_rdDMA_l[127:16*1]};
            endcase
            o_din_rdDMA[133:128]          <= {2'b00,4'hf};
            
            //* get {r_length_pBuf, o_dma_addr};
            r_length_pBuf                 <= r_length_pBuf - {12'b0,r_length_left};
            o_dma_addr                    <= ({r_start_addr,r_start_byte[1]} > ~{1'b0,r_length_left[3:1]})? (o_dma_addr + 32'd1): o_dma_addr;
            r_start_addr                  <= r_start_addr + {1'b0,r_length_left[3:2]};
            r_start_byte                  <= r_start_byte + r_length_left[1:0];
            // r_add_0_or_1                  <= |(({r_start_addr,r_start_byte[1]} + {1'b0,r_length_left[3:1]}) & 4'b1000);
            r_add_0_or_1                  <= 1'b0;

            //* wait next pbuf;
            if(r_length_pBuf <= {12'b0,r_length_left}) 
            begin
              o_dma_rden                  <= 1'b0;
              o_wren_rdDMA                <= 1'b0;
              // r_length_pBuf               <= r_length_pBuf;
              r_length_left               <= r_length_left - r_length_pBuf[3:0];
              state_dma                   <= WAIT_NEXT_PBUF_S;
            end
            else begin
              state_dma                   <= DMA_READ_DATA_S;
            end
          end
        end
        DMA_READ_DATA_S: begin
          o_rden_pBufRD                   <= 1'b0;
          o_dma_rden                      <= 1'b1;
          r_start_addr[2]                 <= ~r_start_addr[2];
          case(r_start_addr)
            3'd0: o_dma_winc              <= 8'b0;
            3'd1: o_dma_winc              <= 8'b01;
            3'd2: o_dma_winc              <= 8'b011;
            3'd3: o_dma_winc              <= 8'b0111;
            3'd4: o_dma_winc              <= 8'b0_1111;
            3'd5: o_dma_winc              <= 8'b1_1111;
            3'd6: o_dma_winc              <= 8'b11_1111;
            3'd7: o_dma_winc              <= 8'b111_1111;
          endcase

          o_wren_rdDMA                    <= i_dma_rvalid;
          // case({r_start_addr,r_start_byte[1]})
          //   4'd0: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_h;
          //   4'd1: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*1],reserve_data_rdDMA_h[127:16*1]};
          //   4'd2: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*2],reserve_data_rdDMA_h[127:16*2]};
          //   4'd3: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*3],reserve_data_rdDMA_h[127:16*3]};
          //   4'd4: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*4],reserve_data_rdDMA_h[127:16*4]};
          //   4'd5: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*5],reserve_data_rdDMA_h[127:16*5]};
          //   4'd6: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*6],reserve_data_rdDMA_h[127:16*6]};
          //   4'd7: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*7],reserve_data_rdDMA_h[127:16*7]};
          //   4'd8: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_l;
          //   4'd9: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*1],reserve_data_rdDMA_l[127:16*1]};
          //   4'd10:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*2],reserve_data_rdDMA_l[127:16*2]};
          //   4'd11:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*3],reserve_data_rdDMA_l[127:16*3]};
          //   4'd12:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*4],reserve_data_rdDMA_l[127:16*4]};
          //   4'd13:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*5],reserve_data_rdDMA_l[127:16*5]};
          //   4'd14:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*6],reserve_data_rdDMA_l[127:16*6]};
          //   4'd15:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*7],reserve_data_rdDMA_l[127:16*7]};
          // endcase
        `ifdef DATA_SRAM_noBUFFER
          case({r_start_addr,r_start_byte[1]})
            4'd8: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_h;
            4'd9: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*7],reserve_data_rdDMA_l[127:16*7]};
            4'd10:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*6],reserve_data_rdDMA_l[127:16*6]};
            4'd11:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*5],reserve_data_rdDMA_l[127:16*5]};
            4'd12:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*4],reserve_data_rdDMA_l[127:16*4]};
            4'd13:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*3],reserve_data_rdDMA_l[127:16*3]};
            4'd14:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*2],reserve_data_rdDMA_l[127:16*2]};
            4'd15:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*1],reserve_data_rdDMA_l[127:16*1]};
            4'd0: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_l;
            4'd1: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*7],reserve_data_rdDMA_h[127:16*7]};
            4'd2: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*6],reserve_data_rdDMA_h[127:16*6]};
            4'd3: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*5],reserve_data_rdDMA_h[127:16*5]};
            4'd4: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*4],reserve_data_rdDMA_h[127:16*4]};
            4'd5: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*3],reserve_data_rdDMA_h[127:16*3]};
            4'd6: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*2],reserve_data_rdDMA_h[127:16*2]};
            4'd7: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*1],reserve_data_rdDMA_h[127:16*1]};
          endcase
        `else  
          case({r_start_addr,r_start_byte[1]})
            4'd0: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_h;
            4'd1: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*7],reserve_data_rdDMA_l[127:16*7]};
            4'd2: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*6],reserve_data_rdDMA_l[127:16*6]};
            4'd3: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*5],reserve_data_rdDMA_l[127:16*5]};
            4'd4: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*4],reserve_data_rdDMA_l[127:16*4]};
            4'd5: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*3],reserve_data_rdDMA_l[127:16*3]};
            4'd6: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*2],reserve_data_rdDMA_l[127:16*2]};
            4'd7: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_h[0+:16*1],reserve_data_rdDMA_l[127:16*1]};
            4'd8: o_din_rdDMA[127:0]      <= reserve_data_rdDMA_l;
            4'd9: o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*7],reserve_data_rdDMA_h[127:16*7]};
            4'd10:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*6],reserve_data_rdDMA_h[127:16*6]};
            4'd11:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*5],reserve_data_rdDMA_h[127:16*5]};
            4'd12:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*4],reserve_data_rdDMA_h[127:16*4]};
            4'd13:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*3],reserve_data_rdDMA_h[127:16*3]};
            4'd14:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*2],reserve_data_rdDMA_h[127:16*2]};
            4'd15:o_din_rdDMA[127:0]      <= {reserve_data_rdDMA_l[0+:16*1],reserve_data_rdDMA_h[127:16*1]};
          endcase
        `endif
          o_din_rdDMA[133:128]            <= {2'b00,4'hf};
          
          //* get {r_length_pBuf, o_dma_addr};
          r_length_pBuf                   <= i_dma_rvalid? (r_length_pBuf - 16'd16): r_length_pBuf;
          o_dma_addr                      <= o_rden_pBufRD? {5'b0,i_dout_pBufRD[31:5]}: 
                                              r_add_0_or_1? (o_dma_addr + 32'd1): o_dma_addr;
          // r_add_0_or_1                    <= o_rden_pBufRD? i_dout_pBufRD[4]: ~r_add_0_or_1; 
          r_add_0_or_1                    <= o_rden_pBufRD? i_dout_pBufRD[4]: r_start_addr[2]; 

          //* wait next pbuf;
          if((r_length_pBuf[15:4] == 12'b0 || r_length_pBuf == 16'h10) && i_dma_rvalid) 
          begin
            o_dma_rden                    <= 1'b0;
            o_wren_rdDMA                  <= 1'b0;
            // r_length_pBuf                 <= r_length_pBuf;
            r_length_left                 <= 4'd0 - r_length_pBuf[3:0];
            state_dma                     <= WAIT_NEXT_PBUF_S;
          end
          else begin
            state_dma                     <= DMA_READ_DATA_S;
          end
        end
        WAIT_NEXT_PBUF_S: begin
          o_dma_rden                      <= 1'b0;
          if(!i_empty_pBufRD & !i_dma_rvalid) 
          begin
            o_rden_pBufRD                 <= 1'b1;
            o_wren_rdDMA                  <= 1'b0;

            if(i_dout_pBufRD[31:0] == 32'h80000000) 
            begin
              o_wren_int                  <= 1'b1; //* tell cpu;
              o_wren_rdDMA                <= 1'b1;
              o_din_rdDMA[133:128]        <= {2'b10,r_din_validTag};
              state_dma                   <= WAIT_1_S;
            end
            else begin
              r_start_addr                <= i_dout_pBufRD[2+:3];
              r_start_byte                <= i_dout_pBufRD[0+:2];
              r_length_pBuf               <= i_dout_pBufRD[47:32];
              o_din_int                   <= {1'b0, i_dout_pBufRD[30:0]};
              if(r_length_left != 4'b0) begin
                state_dma                 <= DMA_READ_PART_DATA_0_S;
              end
              else begin
                o_wren_rdDMA              <= 1'b1;
                state_dma                 <= DMA_READ_DATA_S;
              end
            end
          end
        end
        WAIT_1_S: begin
          o_wren_int                      <= 1'b0;
          o_dma_wren                      <= 1'b0;
          o_rden_pBufRD                   <= 1'b0;
          o_wren_rdDMA                    <= 1'b0;
          state_dma                       <= IDLE_S;
        end
        DISCARD_S: begin
          o_rden_pBufWR                   <= 1'b0;
          if(i_data[133:132] == 2'b10) begin
            o_data_rden                   <= 1'b0;
            state_dma                     <= WAIT_1_S;
          end
          else begin
            o_data_rden                   <= o_data_rden;
            state_dma                     <= DISCARD_S;
          end
        end
        default: begin 
          state_dma                       <= IDLE_S;
        end
      endcase
    end
  end
  //==============================================================//

  assign  o_wait_free_pBufWR  = (state_dma == WAIT_FREE_PBUF_S);

endmodule
