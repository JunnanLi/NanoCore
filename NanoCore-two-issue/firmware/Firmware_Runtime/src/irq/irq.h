#include "firmware.h"
#include "../system/system.h"

#ifndef _IRQ_H_
#define _IRQ_H_

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     irq inilization                                          //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void irq_init(void);
void mstatus_enable(uint32_t bit_enabled);
void mstatus_disable(uint32_t bit_disabled);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     uart_echo: input 'x', output 'x'                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void uart_echo(void);
void uart_irq_handler(void);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     dma_irq_handler:                                         //
//*			1): '0x80000000' is empty;                           //
//*     	2)	'8xxxxxxxx' is irq of finishing recving; low 16b // 
//*			 	 is thefirst addr of DMA;                        //
//*     	3) 	'0xxxxxxxx' is irq of finishing sending; low 16b //
//*				 is the first addr of DMA;                       //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void dma_irq_handler(void);

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     time_irq_handler: increase timer_irq_count               //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void time_irq_handler(void);

void irq_puts(char *string);


#endif
