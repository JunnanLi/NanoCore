/*
 *  Firmware_Runtime for NanoCore (RV32IM) Processor Core.
 *
 *  Copyright (C) 2021-2024 Junnan Li <lijunnan@nudt.edu.cn>. All Rights Reserved.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Last updated date: 2024.02.19
 *  Description: firmware.h 
 */

#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdarg.h>

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* Special address in iCore                                                      //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
#define OUTPORT             0x10010004  //* Print address, i.e., UART write;
#define UART_RD_ADDR        0x10010000  //* UART read;
#define UART_WR_ADDR        0x10010004  //* UART write;


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1004xxxx is left for CSR                                                    //
//*     0x10040000: start_en, high 16b is control valid: '1' is valid;            //
//*                           low 16b is control value:                           //
//*                                        '1' to enable the corresponding PE;    //
//*                                        '0' to disable the corresponding PE;   //
//*     0x10040004: guard reg., no-shared (i.e. exclusive for each PE),           //
//*                           0x1234 is valid;                                    //
//*     0x10040008: software version (wr);                                        //
//*     0x1004000c: hardware version (r);                                         //
//*     0x10040010: pe id, 0-2 (r);                                               //
//*     0x10040014: base address (i.e. offset) of instruction RAM for PE_1;       //
//*     0x10040018: base address (i.e. offset) of instruction RAM for PE_2;       //
//*     0x1004001c: base address (i.e. offset) of data RAM for PE_1;              //
//*     0x10040020: base address (i.e. offset) of data RAM for PE_2;              //
//*     0x10040024: to minus system s register (w);                               //
//*     0x10040028: to add system s register (w);                                 //
//*     0x1004002c: to minus system ns register (w);                              //
//*     0x10040030: to add system ns register (w); or to read system ns register; //
//*     0x10040034: to read system s register (r), should read ns register first; //
//*     0x10040038: internal time to gen irq;                                     //
//*     0x1004003c: '1' to reset AiPE;                                            //
//*     0x10040040                                                                //
//*         -0x1004005c: shared registers;                                        //
//*     0x1004007C: x ns/clk, e.g., 20 ns/clk in 50MHz                            //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
#define TIMER_NS_ADDR               0x10040030  //* system timer address, ns;
#define TIMER_S_ADDR                0x10040034  //* system timer address, s;
#define SYSTICK_ADDR                0x10040038  //* system timer address, 20ns;

#define CSR_PE_START_EN             0x10040000
#define CSR_GUARD_REG_ADDR          0x10040004
#define CSR_SW_VERSION              0x10040008
#define CSR_CUR_PE_ID               0x10040010  //* current PE (i.e. CPU core) ID
#define CSR_PE1_INSTR_BASE_ADDR     0x10040014
#define CSR_PE2_INSTR_BASE_ADDR     0x10040018
#define CSR_PE1_DATA_BASE_ADDR      0x1004001c
#define CSR_PE2_DATA_BASE_ADDR      0x10040020

//* systime time related registers;
#define CSR_MINUS_SYSTIME_S         0x10040024
#define CSR_ADD_SYSTIME_S           0x10040028
#define CSR_MINUS_SYSTIME_NS        0x1004002c
#define CSR_ADD_SYSTIME_NS          0x10040030
#define CSR_READ_SYSTIME_NS         0x10040030
#define CSR_READ_SYSTIME_S          0x10040034

//* shared registers;
#define CSR_SHARED_REG_TMP1_ADDR    0x10040040
#define CSR_SHARED_REG_TMP2_ADDR    0x10040044

//* cycle
#define CSR_CYCLE_LOW_ADDR          0x10040060
#define CSR_CYCLE_HIGH_ADDR         0x10040064

#define CSR_NS_PER_CLK              0x1004007C

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1007xxxx is left for DMA                                                    //
//*     0x10070000: irq_info (r), '0x80000000' is empty;                          //
//*     '8xxxxxxxx' is irq of finishing recving; low 16b is the first addr of DMA;//
//*     '0xxxxxxxx' is irq of finishing sending; low 16b is the first addr of DMA;//
//*     0x10070004: length info of received pkt (r);                              //
//*     0x10070008: low 16b is lenght to DMA, from NIC to PE (w);                 //
//*     0x1007000c: start addr to buffer pkt, from NIC to PE (w);                 //
//*     0x10070010: low 16b is lenght to DMA, from PE to NIC (w);                 //
//*     0x10070014: start addr to read pkt, from PE to NIC (w);                   //
//*     0x10070018: shared register can be used to buffer count of received pkts; //
//*     0x1007001c: '1' to allow back pressure for receiving pkts;                //
//*     0x10070020: '1' to reset DMA;                                             //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
#define DMA_INT_ADDR        0x10070000  //* int. type [31] == '0' is write, [30:0] is start addr;
#define DMA_RECV_LEN_ADDR   0x10070008  //* pBuf address for receiveing pkt;
#define DMA_RECV_ADDR_ADDR  0x1007000c  //* pBuf length for receiveing pkt;
#define DMA_SEND_LEN_ADDR   0x10070010  //* pBuf address for sending pkt;
#define DMA_SEND_ADDR_ADDR  0x10070014  //* pBuf length for sending pkt;
#define DMA_TAG_ADDR        0x10070004  //* pBuf address for recv tag & length;
#define DMA_CNT_RECV_PKT    0x10070018  //* cnt of recved pkt (finished dma);
#define DMA_START_EN        0x1007001C  //* open DMA function;
#define DMA_FILTER_EN       0x10070020  //* to filter pkt, default is broadcast 
                                        //*     pkt (48'hffff_ffff_ffff) to 3 PEs;
#define DMA_FILTER_TYPE_EN  0x10070024  //* {o_filter_dmac_en, o_filter_smac_en, o_filter_type_en}; 
#define DMA_FILTER_DMAC     0x10070028  //* to filter pkt by dmac (last 8b);
#define DMA_FILTER_SMAC     0x1007002c  //* to filter pkt by smac (last 8b);
#define DMA_FILTER_TYPE     0x10070030  //* to filter pkt by type (last 8b);
#define DMA_WAIT_PBUFWR     0x10070034  //* state_dma is at i_wait_free_pBufWR;

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //* 0x1008xxxx is left for DRA                                                    //
// //*     0x10080000: guart register, 0x1234 is valid;                              //
// //*     0x10080004: '1' to start DRA;                                             //
// //*     0x10080008: '1' to reset DRA;                                             //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// #define DRA_GUARD_ADDR      0x10080000  //* write '0x1234' before configuring other regs;
// #define DRA_START_EN_ADDR   0x10080004  //* '1' is enable;

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     time_spec struct                       //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// struct time_spec{
//     uint32_t tv_sec;
//     uint32_t tv_nsec;
// };

volatile unsigned int timer_irq_count;
volatile unsigned int recv_cnt, dma_recv_cnt;
volatile unsigned int send_cnt, dma_send_cnt;

#endif
