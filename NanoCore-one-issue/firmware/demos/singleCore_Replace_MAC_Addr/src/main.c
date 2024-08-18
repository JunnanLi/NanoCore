/*
 *  LwIP for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2022.10.13
 *  Description: port LwIP to RISC-V MCU. 
 */

#include "firmware.h"

int main(){
    //* system inilization, open all interrupt (32_bitmap);
    irq_init();

    // //* for timer_irq;
    // timer_irq_count = 0;
    
    printf("\rsystem boot finished\r\n");
    
    //* set timer_irq_value, i.e., SYSTICK_ADDR
    *((volatile uint32_t *) SYSTICK_ADDR) = 50000000;
    // *((volatile uint32_t *) SYSTICK_ADDR) = 100;

    //* recv buffer;
    unsigned char buf_recv_pkt[2000];
    unsigned char mac_tmp[6];
    int i;
    
    //* enable dma;
    *((volatile uint32_t *) DMA_START_EN) = 0x1234;
    *((volatile uint32_t *) DMA_START_EN) = 1;

    while(1){
        int get_pkt_len = (unsigned int)(rv_recv((unsigned int *)buf_recv_pkt));
        
        if(get_pkt_len > 0) {
            printf("recv, len: %d\n\r",get_pkt_len);
            for(i = 0; i < 6; i++) printf("%02x\n\r",buf_recv_pkt[i]);
            for(i = 0; i < 6; i++) mac_tmp[i] = buf_recv_pkt[i];
            for(i = 0; i < 6; i++) buf_recv_pkt[i] = buf_recv_pkt[i+6];
            for(i = 0; i < 6; i++) buf_recv_pkt[i+6] = mac_tmp[i];
            for(i = 0; i < 6; i++) printf("%02x\n\r",buf_recv_pkt[i]);
            
            rv_send((unsigned int *)buf_recv_pkt, get_pkt_len);
        }
    }
    
    return 0;
}

