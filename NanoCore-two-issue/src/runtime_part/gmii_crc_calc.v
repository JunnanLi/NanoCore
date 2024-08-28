/*
 *  Project:            timelyRV_v0.1 -- a RISCV-32I SoC.
 *  Module name:        gmii_crc_calculate.
 *  Description:        calcultion of CRC checkout code.
 *  Last updated date:  2021.08.21.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1ns/1ps

module gmii_crc_calculate(
    input                 rst_n,
    input                 clk,
    input  wire           gmii_dv_i, 
    input  wire           gmii_er_i, 
    input  wire  [7:0] gmii_data_i, 
    
    output reg            gmii_en_o, 
    output reg            gmii_er_o, 
    output reg   [7:0]  gmii_data_o
    );

////////////////////////////////////////////////////////////////////////////
//        Intermediate variable Declaration
////////////////////////////////////////////////////////////////////////////
    reg            temp_gmii_dv_i;
    wire           dv_pos_edge;
    wire           dv_neg_edge;
    wire   [7:0]   data_in;
    wire   [31:0]  crc_f;
    reg    [31:0]  next_crc;
    wire   [31:0]  lastcrc;
    reg    [1:0]   crc_cnt;
   
    reg    [2:0]   ctrl_state;
    localparam IDLE_S = 3'd1,
               RCV_S  = 3'd2,
               CRC_S  = 3'd3,
               OUT_S  = 3'd4;

////////////////////////////////////////////////////////////////////////////
assign dv_pos_edge =~temp_gmii_dv_i & gmii_dv_i;
assign dv_neg_edge =temp_gmii_dv_i & ~gmii_dv_i;                 

always @ (posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)begin
        temp_gmii_dv_i <= 1'b0;
    end
    else begin
        temp_gmii_dv_i <= gmii_dv_i;
    end
end      

////////////////////////////////////////////////////////////////////////////
//gmii data 
assign data_in ={gmii_data_i[0],gmii_data_i[1],gmii_data_i[2],gmii_data_i[3],gmii_data_i[4],gmii_data_i[5],gmii_data_i[6],gmii_data_i[7]};

assign crc_f ={next_crc[0],next_crc[1],next_crc[2],next_crc[3],next_crc[4],next_crc[5],next_crc[6],next_crc[7],next_crc[8],next_crc[9],
next_crc[10],next_crc[11],next_crc[12],next_crc[13],next_crc[14],next_crc[15],next_crc[16],next_crc[17],next_crc[18],next_crc[19],
next_crc[20],next_crc[21],next_crc[22],next_crc[23],next_crc[24],next_crc[25],next_crc[26],next_crc[27],next_crc[28],next_crc[29],
next_crc[30],next_crc[31]};
assign lastcrc =~crc_f;
always @ (posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)begin
        gmii_en_o <= 1'b0;
        gmii_er_o <= 1'b0;
        gmii_data_o <= 8'b0;
        crc_cnt<= 2'b0;
        next_crc <= 32'hffffffff;
        ctrl_state <= IDLE_S;         
    end
    else begin
        case(ctrl_state)
        IDLE_S:begin        
            if (dv_pos_edge == 1'b1)begin //posedge of "gmii_dv_i" signal
                gmii_data_o <= gmii_data_i;
                gmii_en_o <= gmii_dv_i;
                gmii_er_o <= gmii_er_i;
                ctrl_state <= RCV_S;
            end
            else begin
                ctrl_state <= IDLE_S;      
            end
        end
        RCV_S:begin
			gmii_data_o <= gmii_data_i;
			gmii_en_o <= gmii_dv_i;
			gmii_er_o <= gmii_er_i;
            if((gmii_dv_i == 1'b1)&&(gmii_data_i == 8'hd5))begin//first byte
                ctrl_state <= CRC_S;
            end
            else begin                
                ctrl_state <= RCV_S; 
            end 
        end            
        CRC_S:begin
            if(dv_neg_edge == 1'b1)begin
                gmii_data_o <= lastcrc[7:0];
                gmii_en_o <= 1'b1;
                ctrl_state <= OUT_S;
            end
            else  begin   

                next_crc[0]<=  data_in[6] ^ data_in[0] ^ next_crc[24] ^ next_crc[30];
                next_crc[1]<=  data_in[7] ^ data_in[6] ^ data_in[1] ^ data_in[0] ^ next_crc[24] ^ next_crc[25] ^ next_crc[30] ^ next_crc[31];
                next_crc[2]<=  data_in[7] ^ data_in[6] ^ data_in[2] ^ data_in[1] ^ data_in[0] ^ next_crc[24] ^ next_crc[25] ^ next_crc[26] ^ next_crc[30] ^ next_crc[31];
                next_crc[3]<=  data_in[7] ^ data_in[3] ^ data_in[2] ^ data_in[1] ^ next_crc[25] ^ next_crc[26] ^ next_crc[27] ^ next_crc[31];
                next_crc[4]<=  data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[2] ^ data_in[0] ^ next_crc[24] ^ next_crc[26] ^ next_crc[27] ^ next_crc[28] ^ next_crc[30];
                next_crc[5]<=  data_in[7] ^ data_in[6] ^ data_in[5] ^ data_in[4] ^ data_in[3] ^ data_in[1] ^ data_in[0] ^ next_crc[24] ^ next_crc[25] ^ next_crc[27] ^ next_crc[28] ^ next_crc[29] ^ next_crc[30] ^ next_crc[31];
                next_crc[6]<=  data_in[7] ^ data_in[6] ^ data_in[5] ^ data_in[4] ^ data_in[2] ^ data_in[1] ^ next_crc[25] ^ next_crc[26] ^ next_crc[28] ^ next_crc[29] ^ next_crc[30] ^ next_crc[31];
                next_crc[7]<=  data_in[7] ^ data_in[5] ^ data_in[3] ^ data_in[2] ^ data_in[0] ^ next_crc[24] ^ next_crc[26] ^ next_crc[27] ^ next_crc[29] ^ next_crc[31];
                next_crc[8]<=  data_in[4] ^ data_in[3] ^ data_in[1] ^ data_in[0] ^ next_crc[0] ^ next_crc[24] ^ next_crc[25] ^ next_crc[27] ^ next_crc[28];
                next_crc[9]<=  data_in[5] ^ data_in[4] ^ data_in[2] ^ data_in[1] ^ next_crc[1] ^ next_crc[25] ^ next_crc[26] ^ next_crc[28] ^ next_crc[29];
                next_crc[10] <= data_in[5] ^ data_in[3] ^ data_in[2] ^ data_in[0] ^ next_crc[2] ^ next_crc[24] ^ next_crc[26] ^ next_crc[27] ^ next_crc[29];
                next_crc[11] <= data_in[4] ^ data_in[3] ^ data_in[1] ^ data_in[0] ^ next_crc[3] ^ next_crc[24] ^ next_crc[25] ^ next_crc[27] ^ next_crc[28];
                next_crc[12] <= data_in[6] ^ data_in[5] ^ data_in[4] ^ data_in[2] ^ data_in[1] ^ data_in[0] ^ next_crc[4] ^ next_crc[24] ^ next_crc[25] ^ next_crc[26] ^ next_crc[28] ^ next_crc[29] ^ next_crc[30];
                next_crc[13] <= data_in[7] ^ data_in[6] ^ data_in[5] ^ data_in[3] ^ data_in[2] ^ data_in[1] ^ next_crc[5] ^ next_crc[25] ^ next_crc[26] ^ next_crc[27] ^ next_crc[29] ^ next_crc[30] ^ next_crc[31];
                next_crc[14] <= data_in[7] ^ data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[2] ^ next_crc[6] ^ next_crc[26] ^ next_crc[27] ^ next_crc[28] ^ next_crc[30] ^ next_crc[31];
                next_crc[15] <= data_in[7] ^ data_in[5] ^ data_in[4] ^ data_in[3] ^ next_crc[7] ^ next_crc[27] ^ next_crc[28] ^ next_crc[29] ^ next_crc[31];
                next_crc[16] <= data_in[5] ^ data_in[4] ^ data_in[0] ^ next_crc[8] ^ next_crc[24] ^ next_crc[28] ^ next_crc[29];
                next_crc[17] <= data_in[6] ^ data_in[5] ^ data_in[1] ^ next_crc[9] ^ next_crc[25] ^ next_crc[29] ^ next_crc[30];
                next_crc[18] <= data_in[7] ^ data_in[6] ^ data_in[2] ^ next_crc[10] ^ next_crc[26] ^ next_crc[30] ^ next_crc[31];
                next_crc[19] <= data_in[7] ^ data_in[3] ^ next_crc[11] ^ next_crc[27] ^ next_crc[31];
                next_crc[20] <= data_in[4] ^ next_crc[12] ^ next_crc[28];
                next_crc[21] <= data_in[5] ^ next_crc[13] ^ next_crc[29];
                next_crc[22] <= data_in[0] ^ next_crc[14] ^ next_crc[24];
                next_crc[23] <= data_in[6] ^ data_in[1] ^ data_in[0] ^ next_crc[15] ^ next_crc[24] ^ next_crc[25] ^ next_crc[30];
                next_crc[24] <= data_in[7] ^ data_in[2] ^ data_in[1] ^ next_crc[16] ^ next_crc[25] ^ next_crc[26] ^ next_crc[31];
                next_crc[25] <= data_in[3] ^ data_in[2] ^ next_crc[17] ^ next_crc[26] ^ next_crc[27];
                next_crc[26] <= data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[0] ^ next_crc[18] ^ next_crc[24] ^ next_crc[27] ^ next_crc[28] ^ next_crc[30];
                next_crc[27] <= data_in[7] ^ data_in[5] ^ data_in[4] ^ data_in[1] ^ next_crc[19] ^ next_crc[25] ^ next_crc[28] ^ next_crc[29] ^ next_crc[31];
                next_crc[28] <= data_in[6] ^ data_in[5] ^ data_in[2] ^ next_crc[20] ^ next_crc[26] ^ next_crc[29] ^ next_crc[30];
                next_crc[29] <= data_in[7] ^ data_in[6] ^ data_in[3] ^ next_crc[21] ^ next_crc[27] ^ next_crc[30] ^ next_crc[31];
                next_crc[30] <= data_in[7] ^ data_in[4] ^ next_crc[22] ^ next_crc[28] ^ next_crc[31];
                next_crc[31] <= data_in[5] ^ next_crc[23] ^ next_crc[29];
                
                
                   
                gmii_data_o <= gmii_data_i;//message normal transmission
                gmii_en_o <= gmii_dv_i;
                gmii_er_o <= gmii_er_i; 
                ctrl_state <= CRC_S; 
            end
        end
        OUT_S:begin           
            if(crc_cnt==2'b00) begin
                gmii_en_o <= 1'b1;
                gmii_data_o   <= lastcrc[15:8];
                ctrl_state <= OUT_S;  
                crc_cnt<=crc_cnt+1'b1;
            end
            else if(crc_cnt==2'b01)begin
                gmii_en_o <= 1'b1;
                gmii_data_o   <= lastcrc[23:16];
                crc_cnt<=crc_cnt+1'b1;
                ctrl_state <= OUT_S; 
            end
            else if(crc_cnt==2'b10)begin
                gmii_en_o <= 1'b1;
                gmii_data_o   <= lastcrc[31:24];
                crc_cnt<=crc_cnt+1'b1;
                ctrl_state <= OUT_S; 
            end
            else begin
                gmii_en_o <= 1'b0;
                gmii_er_o <= 1'b0;
                gmii_data_o <= 8'b0;
                crc_cnt<= 2'b0;
                next_crc <= 32'hffffffff;
                ctrl_state <= IDLE_S; 
            end
        end
        default:ctrl_state <= IDLE_S;
       
        endcase 
    end
end


endmodule

