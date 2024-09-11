#include <stdio.h> 
#include <pcap.h> 
#include <arpa/inet.h> 
#include <time.h> 
#include <stdlib.h> 
#include <string.h> 
#include <unistd.h>
#include <libnet.h>
#include <pthread.h>

#define BUFSIZE 1514

#ifndef SEND_RECV_H__
#define SEND_RECV_H__

typedef unsigned short u16;
typedef unsigned char u8;
typedef unsigned int u32;

#define DST_MAC_0 0x00
#define DST_MAC_1 0x0a
#define DST_MAC_2 0x35
#define DST_MAC_3 0x00
#define DST_MAC_4 0x01
#define DST_MAC_5 0x02

// #define NAME_NETIF "enx00e04d6da7b3"
#define NAME_NETIF "eno1"
// #define NAME_NETIF "wlp0s20f3"

char file_sendPkt[50] = "../pktOut.txt";
char file_recvPkt[50] = "../pktIn.txt";

unsigned short cnt_recvPkt;
unsigned short cnt_sendPkt;

#endif
