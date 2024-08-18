/*
 *  LwIP for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>. All Rights Reserved.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Last updated date: 2022.01.18
 *  Description: basic processing. 
 *  1 tab == 4 spaces!
 */

#ifndef FIRMWARE_H
#define FIRMWARE_H
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#define MSTATUS_MIE_BIT     3           //* for irq;

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* Special address in iCore                                                      //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
#define OUTPORT             0x10010004  //* Print address, i.e., UART write;
#define UART_RD_ADDR        0x10010000  //* UART read;
#define UART_WR_ADDR        0x10010004  //* UART write;

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1002xxxx is left for GPIO                                                   //
//*     0x10020000: '1' to open GPIO;                                             //
//*     0x10020004: 16b bitmap, and '0' to recv/send data, '1' for irq;           //
//*     0x10020008: 16b bitmap, and '0' to recv posedge irq, '1' for negedge;     //
//*     0x1002000c: 16b bitmap, irq result (r);                                   //
//*     0x10020010: 16b bitmap, and '1' to clear irq (w, just maintain one clk);  //
//*     0x10020014: 16b bitmap, and '0' to recv data, '1' for sending;            //
//*     0x10020018: data to send;                                                 //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1003xxxx is left for SPI                                                    //
//*     0x10030000: addr to read flash by spi;                                    //
//*     0x10030004: length to read flash by spi;                                  //
//*     0x10030008: request to read flash;                                        //
//*     0x10030010: empty_tag, '0' means received respond_data from flash (r);    //
//*     0x10030014: count of respond_data waiting to read (r);                    //
//*     0x10030018: respond_data (r);                                             //
//--------------------------------------------------------------------------------//
//*     0x10030100: high 32b of request command_data;                             //
//*     0x10030104: low 32b of request command_data;                              //
//*     0x10030108: high 32b of respond command_data (r);                         //
//*     0x1003010c: high 32b of respond command_data (r);                         //
//*     0x10030110: empty_tag, '0' means received respond_data from flash (r);    //
//*     0x10030114: count of respond_data waiting to read (r);                    //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1004xxxx is left for CSR                                                    //
//*     0x10040000: start_en, high 16b is mask, '1' is valid,                     //
//*                           low 16b is ctrl, '1' to start the corresponding PE; //
//*     0x10040004: guart_reg, 0x1234 is valid;                                   //
//*     0x10040008: software version (wr);                                        //
//*     0x1004000c: hardware version (r);                                         //
//*     0x10040010: pe id, 0-2 (r);                                               //
//*     0x10040014: instr_offset_addr for PE_1;                                   //
//*     0x10040018: instr_offset_addr for PE_2;                                   //
//*     0x1004001c: data_offset_addr for PE_1;                                    //
//*     0x10040020: data_offset_addr for PE_2;                                    //
//*     0x10040024: to minus system s register (w);                               //
//*     0x10040028: to add system s register (w);                                 //
//*     0x1004002c: to minus system ns register (w);                              //
//*     0x10040030: to add system ns register (w); or to read system ns register; //
//*     0x10040034: to read system s register (r), should read ns register first; //
//*     0x10040038: internal time to gen irq;                                     //
//*     0x1004003c: '1' to reset AiPE;                                            //
//*     0x10040040                                                                //
//*         -0x1004005c: shared registers;                                        //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
#define TIMER_NS_ADDR       0x10040030  //* system timer address, 20ns;
#define TIMER_S_ADDR        0x10040034  //* system timer address, s;
#define TIMERCMP_ADDR       0x10040038  //* system timer address, 20ns;
#define TIME_IRQ_CNT        0x10040040  //* used to count time_irq;

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1005xxxx is left for CSRAM                                                  //
//*     0x10050000                                                                //
//*         -0x10050100: shared SRAM;                                             //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1006xxxx is left for dDMA                                                   //
//*     0x10060000: start address for common PEs;                                 //
//*     0x10060004: length to read for common PEs;                                //
//*     0x10060008: start address for AiPE;                                       //
//*     0x1006000c: length to read for AiPE;                                      //
//*     0x10060010: direction, '0' is common PEs -> AiPE, '1' is AiPE -> PEs;     //
//*     0x10060014: write any value to request dma;                               //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//


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
//*     0x1007001c: '1' to open DMA, wirte '0x1234' first;                        //
//*     0x10070020: to filter pkt, default is broadcast pkt (last 8'hff) to 3 PEs;//
//*     0x10070024: enable flat, i.e., dmac_en, smac_en, type_en;                 //
//*     0x10070028: to filter pkt by dmac (last 8b);                              //
//*     0x1007002C: to filter pkt by smac (last 8b);                              //
//*     0x10070030: to filter pkt by type (last 8b);                              //
//*     0x10070034: check state_dma is at wait_free_pBufWR, i.e, wrong state;     //
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

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 0x1008xxxx is left for DRA                                                    //
//*     0x10080000: guart register, 0x1234 is valid;                              //
//*     0x10080004: '1' to start DRA;                                             //
//*     0x10080008: '1' to reset DRA;                                             //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     time_spec struct                       //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
struct time_spec{
    uint32_t tv_sec;
    uint32_t tv_nsec;
};

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     Main function                          //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
int main (void);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     finish function, i.e., stop program;   //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// void sys_finish(void);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     irq inilization                        //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void irq_init(void);
void mstatus_enable(uint32_t bit_enabled);
void mstatus_disable(uint32_t bit_disabled);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     print funciton;                        //
//*         1) print a char; 2) print a string;//
//*         3) print a dec; 4) print a hex;    //
//*         5) printf;                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void print_chr(char ch);
void print_str(const char *p);
void print_dec(unsigned int val);
void print_hex(unsigned int val, int digits);
int  printf(const char *format, ...);
void print_void(void);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     sys_gettime, i.e., gettimeofday        //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void sys_gettime(struct time_spec *timer);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     Memory process                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void *memcpy(void *aa, const void *bb, long n);
void* memset(void* dst,int val, size_t count);
int memcmp(const void *buffer1,const void *buffer2,int count);
void* memmove(void* dest, const void* src, size_t n);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     string process                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
size_t strnlen(const char *str, size_t maxsize);
size_t strlen (const char * str);
char *strcpy(char* dst, const char* src);
int strcmp(const char *s1, const char *s2);
int strncmp(const char* str1, const char* str2 ,int size);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     format transform                       //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
int atoi(const char *str);

volatile unsigned int timer_irq_count;
volatile unsigned int dma_recv_cnt;

#endif