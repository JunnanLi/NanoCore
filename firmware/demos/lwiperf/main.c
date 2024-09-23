/*
 *  LwIP for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2022.10.13
 *  Description: port LwIP to RISC-V MCU. 
 */

#include "riscvnetif.h"
#include "firmware.h"
#include "lwip/tcp.h"
#include "lwip/apps/lwiperf.h"

//* version of LwIP
#define V2_1_3 1

static struct netif server_netif;
struct netif *p_server_netif;
#ifdef V2_1_3
    struct ip4_addr ipaddr, netmask, gw;
#else
    struct ip_addr ipaddr, netmask, gw;
#endif

// volatile unsigned int timer_irq_count;
 
static void
lwiperf_report(void *arg, enum lwiperf_report_type report_type,
  const ip_addr_t* local_addr, u16_t local_port, const ip_addr_t* remote_addr, u16_t remote_port,
  u32_t bytes_transferred, u32_t ms_duration, u32_t bandwidth_kbitpsec)
{
    LWIP_UNUSED_ARG(arg);
    LWIP_UNUSED_ARG(local_addr);
    LWIP_UNUSED_ARG(local_port);

    printf("IPERF report: type=%d, remote: %s:%d, total bytes: %"U32_F", duration in ms: %"U32_F", kbits/s: %"U32_F"\n",
        (int)report_type, ipaddr_ntoa(remote_addr), (int)remote_port, bytes_transferred, ms_duration, bandwidth_kbitpsec);
}
 
 
void
lwiperf_example_init(void)
{
    ip4_addr_t ipaddr;

    lwiperf_start_tcp_server_default(lwiperf_report, NULL);

    // IP4_ADDR(&ipaddr,192,168,1,20);
    // lwiperf_start_tcp_client_default(&ipaddr, lwiperf_report, NULL);
}

int main(){
    //* system inilization, open all interrupt (32_bitmap);
    irq_init();
    
    printf("LwIP_v2.1.3 starting ......\n\r");

    //* for timer_irq;
    timer_irq_count = 0;
    *((volatile uint32_t *) DMA_START_EN) = 0x1234;
    *((volatile uint32_t *) DMA_START_EN) = 1;
    dma_recv_cnt = DMA_CNT_RECV_PKT;

    //* lwip-related;
    int tail =0; 
    //* lwip initialization;
        //* the mac address of the board. this should be unique per board
        // unsigned char mac_ethernet_address[] =
        // { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };
        /* initliaze IP addresses to be used */
        IP4_ADDR(&ipaddr,  192, 168,   1, 200);
        IP4_ADDR(&netmask, 255, 255, 255,  0);
        IP4_ADDR(&gw,      192, 168,   1,  1);

        lwip_init();

        p_server_netif = &server_netif;
        if (netif_add(p_server_netif, &ipaddr, &netmask, &gw,
                            (void*)&tail,
                            ethernetif_init,
                            ethernet_input
                            ) == NULL)
        {
            printf("init error\r\n");
            return 0;
        }

        netif_set_default(p_server_netif);
        //* specify that the network if is up */
        if (netif_is_link_up(p_server_netif)) {
            // *When the netif is fully configured this function must be called */
            netif_set_up(p_server_netif);
        }
        else {
            //* When the netif link is down this function must be called */
            netif_set_down(p_server_netif);
        }
        // netif_set_up(p_server_netif);

        //* start the application (web server, rxtest, txtest, etc..) */
        // start_tcp_application();
        // start_udp_application();
        // udpecho_raw_init();

        printf("\rsystem boot finished\r\n");
    
    //* receive and process packets */
        lwiperf_example_init();
        printf("tcp bind port 5001\r\n");

    // ping_init();

    //* set timer_irq_value, i.e., TIMERCMP_ADDR
        // *((volatile uint32_t *) TIMERCMP_ADDR) = 50000000;
        // *((volatile uint32_t *) TIMERCMP_ADDR) = 50000;

    //* to recv pkt and retransmit tcp pkt;
        while (1) {
            // if (timer_irq_count != 0){
            //     timer_irq_count = 0;
            //     tcp_tmr();
            //     printf("tcp_tmr\r\n");
            // }
            // else timer_irq_count = 0;
            ethernetif_input(p_server_netif);
        }

}

