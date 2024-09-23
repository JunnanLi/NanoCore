/*
 *  LwIP for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2022.10.13
 *  Description: irq funciton, include uart, dma, timer. 
 */

#include "firmware.h"
// extern unsigned int timer_irq_count;

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     uart_echo: input 'x', output 'x'                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void uart_echo(void){
	uint32_t uart_data = *((volatile uint32_t *) UART_RD_ADDR);
	char uart_data_char;
	while(uart_data != 0x80000000){
		uart_data_char = (char) (uart_data & 0xff);
		printf("%c\r\n", uart_data_char);
		uart_data = *((volatile uint32_t *) UART_RD_ADDR);
	}
}
void uart_irq_handler(void) {
    uart_echo();
}

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     dma_irq_handler:                                         //
//*			1): '0x80000000' is empty;                           //
//*     	2)	'8xxxxxxxx' is irq of finishing recving; low 16b // 
//*			 	 is thefirst addr of DMA;                        //
//*     	3) 	'0xxxxxxxx' is irq of finishing sending; low 16b //
//*				 is the first addr of DMA;                       //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void dma_irq_handler(void) {
    uint32_t dma_irq_data = *((volatile uint32_t *) DMA_INT_ADDR);
    // printf("%08x\r\n", dma_irq_data);
    while(dma_irq_data != 0x80000000){
    	if((dma_irq_data & 0x80000000) != 0){
	        *((volatile uint32_t *) DMA_CNT_RECV_PKT) = 1;
	    }
	    dma_irq_data = *((volatile uint32_t *) DMA_INT_ADDR);
    }
}

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     time_irq_handler: increase timer_irq_count               //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void time_irq_handler(void) {
	timer_irq_count++;
	printf("cnt: %d\n\r",timer_irq_count);
}

void irq_puts(char *string) {
	printf("%s\n", string);
}


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//* 	irq inilization                                          //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
	volatile uint32_t ie_mask32_std           = 0;
	volatile uint32_t irq_mask                = 0;
	void irq_init(void){
		//* irq initialization, Enable all mie (need to store)
	    ie_mask32_std = 0xFFFFFFFF;

	    //* enable mstatus.mie
	    __set_irq_mask(ie_mask32_std);
	}
