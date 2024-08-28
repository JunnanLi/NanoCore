/**
 * @file
 * Ethernet Interface Skeleton
 *
 */

/*
 * Copyright (c) 2001-2004 Swedish Institute of Computer Science.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * This file is part of the lwIP TCP/IP stack.
 *
 * Author: Adam Dunkels <adam@sics.se>
 * Ported by Junnan Li <lijunnan@nudt.edu.cn>
 *
 */

/*
 * This file is a skeleton for developing Ethernet network interface
 * drivers for lwIP. Add code to the low_level functions and do a
 * search-and-replace for the word "ethernetif" to replace it with
 * something that better describes your network interface.
 */

#if 1

#include "lwip/opt.h"
#include "lwip/mem.h"
#include "lwip/memp.h"
#include "lwip/netif.h"
#include "netif/etharp.h"
#include "riscvnetif.h"

/* Define those to better describe your network interface. */
#define IFNAME0 's'
#define IFNAME1 't'

#define META_LEN 16

//* meta_buffer used to pad meta, each pkt has a 256b meta before its head;
// u32_t meta_buffer[8] ={0,0,0,0,0,0,0,0};
// u32_t meta_send_buffer[8] ={0,0x80,0,0,0,0,0,0};
u32_t meta_buffer[4] = {0, 0, 0, 0};
u32_t meta_send_buffer[4] = {0, 0x80, 0, 0};

//* TODO, ...
// struct ethernetif {
//   struct eth_addr *ethaddr;
//    Add whatever per-interface state that is needed here. 
// };

/**
 * Helper struct to hold private data used to operate your ethernet interface.
 * Keeping the ethernet address of the MAC in this struct is not necessary
 * as it is already kept in the struct netif.
 * But this is only an example, anyway...
 */

/* Forward declarations. */
// static void  ethernetif_input(struct netif *netif);

/**
 * In this function, the hardware should be initialized.
 * Called from ethernetif_init().
 *
 * @param netif the already initialized lwip network interface structure
 *        for this ethernetif
 */
static void
low_level_init(struct netif *netif)
{
  /* set MAC hardware address length */
  netif->hwaddr_len = NETIF_MAX_HWADDR_LEN;

  /* set MAC hardware address */
  netif->hwaddr[0] = 0x00;
  netif->hwaddr[1] = 0x0a;
  netif->hwaddr[2] = 0x35;
  netif->hwaddr[3] = 0x00;
  netif->hwaddr[4] = 0x01;
  netif->hwaddr[5] = 0x02;
  //* eth.addr == 00:0a:35:00:01:02, e.g., xilinx_00_01_02
  /* maximum transfer unit */
  netif->mtu = TCP_MSS;

  /* device capabilities */
  /* don't set NETIF_FLAG_ETHARP if this device is not an ethernet one */
  netif->flags = NETIF_FLAG_BROADCAST  | NETIF_FLAG_ETHARP | NETIF_FLAG_LINK_UP;// NETIF_FLAG_ETHARP
  
#if LWIP_IGMP
  netif->flags |= NETIF_FLAG_IGMP;
#endif
  //* TODO, initial NIC;

  return ERR_OK;
}

/**
 * This function should do the actual transmission of the packet. The packet is
 * contained in the pbuf that is passed to the function. This pbuf
 * might be chained.
 *
 * @param netif the lwip network interface structure for this ethernetif
 * @param p the MAC packet to send (e.g. IP packet including MAC addresses and type)
 * @return ERR_OK if the packet could be sent
 *         an err_t value if the packet couldn't be sent
 *
 * @note Returning ERR_MEM here if a DMA queue of your MAC is full can lead to
 *       strange results. You might consider waiting for space in the DMA queue
 *       to become available since the stack doesn't retry to send a packet
 *       dropped because of memory failure (except for the TCP timers).
 */

static err_t
low_level_output(struct netif *netif, struct pbuf *p)
{

// uint32_t time_s, time_20ns;
// time_s = *((volatile uint32_t *) TIMER_S_ADDR);
// time_20ns = *((volatile uint32_t *) TIMER_NS_ADDR);
// printf("s_t:%u, %u\n\r",time_s, time_20ns);

  struct pbuf *q;
  struct eth_hdr *ethhdr;

  //* write length, if len < 60B, then padding to 60B;
  u32_t len = (uint32_t)(p->tot_len); //* current length;
  __DBUG_PRINT("\r\ntot_send_len: %u\r\n",len);
  // printf("s_len: %d\n\r", len);
  len = len << 28;
  len = len >> 12;

  //* dma (add metadata);
  //* write metadata;
  *((volatile uint32_t *) DMA_SEND_LEN_ADDR) = (uint32_t)(META_LEN+len);
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t )(meta_send_buffer);
  //* write pkt;
  q = p;
  // printf("s: %08x, len: %d\n\r", (uint32_t )(q->payload), (uint32_t)(q->len));
  __DBUG_PRINT("s: %08x, len: %d\n\r", (uint32_t )(q->payload), (uint32_t)(q->len));
  *((volatile uint32_t *) DMA_SEND_LEN_ADDR) = (uint32_t)(q->len);
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t )(q->payload);
  q = q->next;
  while (q != NULL) {
    // printf("s: %08x, len: %d\n\r", (uint32_t )(q->payload), (uint32_t)(q->len));
    __DBUG_PRINT("s: %08x, len: %d\n\r", (uint32_t )(q->payload), (uint32_t)(q->len));
    *((volatile uint32_t *) DMA_SEND_LEN_ADDR) = (uint32_t)(q->len);
    *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t )(q->payload);
    q = q->next;
  }
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = 0x80000000;

  //* print recv info;
  // printf("tot_send_len: %u\r\n",len);
  // for(int i=0; i<len; i++){
  //   printf("%02x_",*((u8_t*) (ADDR_SEND_PKT)+i));
  // }

// time_s = *((volatile uint32_t *) TIMER_S_ADDR);
// time_20ns = *((volatile uint32_t *) TIMER_NS_ADDR);
// printf("s_dt:%u, %u\n\r",time_s, time_20ns);

  return ERR_OK;
}

/**
 * Should allocate a pbuf and transfer the bytes of the incoming
 * packet from the interface into the pbuf.
 *
 * @param netif the lwip network interface structure for this ethernetif
 * @return a pbuf filled with the received packet (including MAC header)
 *         NULL on memory error
 */
static struct pbuf *
low_level_input(struct netif *netif, u16_t len)
{
  struct pbuf *p, *q;
  
  //* allocate pbuf;
  p = pbuf_alloc(PBUF_RAW, len, PBUF_POOL);
  // while(p == NULL){
  //   p = pbuf_alloc(PBUF_RAW, len, PBUF_POOL);
  // }
  if(p == NULL)
    printf("len: %d\r\n", len);
  //   while(1);
  //* write dma info;
  if(p != NULL){
    //* recv meta;
    *((volatile uint32_t *) DMA_RECV_LEN_ADDR)    = (uint32_t )(META_LEN);
    *((volatile uint32_t *) DMA_RECV_ADDR_ADDR)   = (uint32_t )(meta_buffer);
    //* recv pkt;
    for (q = p; q != NULL; q = q->next) {
      // printf("r: %08x, %d\n\r", (uint32_t )(q->payload), (uint32_t )(q->len));
      *((volatile uint32_t *) DMA_RECV_LEN_ADDR)  = (uint32_t )(q->len);
      *((volatile uint32_t *) DMA_RECV_ADDR_ADDR) = (uint32_t )(q->payload);
      // printf("dma_wr\n\r");
    }
  }

  return p;
}

/**
 * This function should be called when a packet is ready to be read
 * from the interface. It uses the function low_level_input() that
 * should handle the actual reception of bytes from the network
 * interface. Then the type of the received packet is determined and
 * the appropriate input function is called.
 *
 * @param netif the lwip network interface structure for this ethernetif
 */
void
ethernetif_input(struct netif *netif)
{
  struct eth_hdr *ethhdr;
  struct pbuf *p;
  
  //* check whether NIC recv pkt;
  uint32_t tag_w_length = *((volatile uint32_t *) DMA_TAG_ADDR);
  if(tag_w_length == 0x80000000){
    return 0;
  }


// uint32_t time_s, time_20ns;
// time_s = *((volatile uint32_t *) TIMER_S_ADDR);
// time_20ns = *((volatile uint32_t *) TIMER_NS_ADDR);
// printf("r_t:%u, %u\n\r",time_s, time_20ns);

  *((volatile uint32_t *) DMA_CNT_RECV_PKT) = 0;
  u16_t pkt_len = tag_w_length & 0xffff;
  __DBUG_PRINT("pkt_len: %d\n\r", pkt_len);
  // printf("r_len: %d\n\r", pkt_len);
  // pkt_len -= 32;
  /* move received packet into a new pbuf */
  p = low_level_input(netif, pkt_len);

  /* no packet could be read, silently ignore this */
  if (p == NULL) {
    // low_level_input(netif, pkt_len);
    printf("get pbuf error\n\r");
    return 0;
  }
  // printf("r\n\r");

  //* TODO, do not need to wait dma;
  // uint32_t cnt_recv_pkt = *((volatile uint32_t *) DMA_CNT_RECV_PKT);
  // while(cnt_recv_pkt == 0){
  //   cnt_recv_pkt = *((volatile uint32_t *) DMA_CNT_RECV_PKT);
  // }
  while(*((volatile uint32_t *) DMA_CNT_RECV_PKT) == 0);

// time_s = *((volatile uint32_t *) TIMER_S_ADDR);
// time_20ns = *((volatile uint32_t *) TIMER_NS_ADDR);
// printf("rd_t:%u, %u\n\r",time_s, time_20ns);

// __DBUG_PRINT("finish dma\n\r");

  /* points to packet payload, which starts with an Ethernet header */
  ethhdr = (struct eth_hdr *)p->payload;
  //* print recv pkt's type;
  __DBUG_PRINT("recv pkt, ethhdr->type: %04x\n\r", htons(ethhdr->type));
  //* classification;
  switch (htons(ethhdr->type)) {
    /* IP or ARP packet? */
    case ETHTYPE_IP:
    case ETHTYPE_ARP:
      // printf("arp\n\r");
      /* full packet send to tcpip_thread to process */
      if (netif->input(p, netif) != ERR_OK) {
        LWIP_DEBUGF(NETIF_DEBUG, ("ethernetif_input: IP input error\r\n"));
        pbuf_free(p);
        p = NULL;
      }
      break;

    default:
      pbuf_free(p);
      p = NULL;
      break;
  }

  return 1;
}

/**
 * Should be called at the beginning of the program to set up the
 * network interface. It calls the function low_level_init() to do the
 * actual setup of the hardware.
 *
 * This function should be passed as a parameter to netif_add().
 *
 * @param netif the lwip network interface structure for this ethernetif
 * @return ERR_OK if the loopif is initialized
 *         ERR_MEM if private data couldn't be allocated
 *         any other err_t on error
 */
err_t
ethernetif_init(struct netif *netif)
{

#if LWIP_NETIF_HOSTNAME
  /* Initialize interface hostname */
  netif->hostname = "lwip";
#endif /* LWIP_NETIF_HOSTNAME */

  /*
   * Initialize the snmp variables and counters inside the struct netif.
   * The last argument should be replaced with your link speed, in units
   * of bits per second.
   */
  // MIB2_INIT_NETIF(netif, snmp_ifType_ethernet_csmacd, 1000000000);

  netif->name[0] = IFNAME0;
  netif->name[1] = IFNAME1;
  /* We directly use etharp_output() here to save a function call.
   * You can instead declare your own function an call etharp_output()
   * from it if you have to do some checks before sending (e.g. if link
   * is available...) */
#if LWIP_IPV4
  netif->output = etharp_output;
#endif /* LWIP_IPV4 */
  netif->linkoutput = low_level_output;

  /* initialize the hardware */
  low_level_init(netif);

  return ERR_OK;
}

#endif /* 0 */
