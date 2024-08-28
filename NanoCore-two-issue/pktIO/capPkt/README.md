# 模拟网卡收发数据
## 功能描述
调用libnet，libpcap库文件实现FL-M32 SoC收发报文的功能。例如，FL-M32上运行的LwIP程序，则外部主机可ping通FL-M32。
## 文件描述
主要包含以下文件

| 文件名       | 功能描述              |
|-------------|----------------------|
| send_recv.h | 头文件                |
| sendPacket.c| 调用libnet库构造报文，为FL-M32模拟网卡发送报文  |
| recvPacket.c| 调用libpcap库接收报文，为FL-M32模拟网卡接收报文 |

## 使用说明
1) 修改`send_recv.h`中`NAME_NETIF`为自己的网卡名，可通过ifconfig查看
2) 修改`send_recv.h`中`DST_MAC_0-5`为待模拟网卡的MAC地址
3) 修改`send_recv.h`中`file_sendPkt`为待发送报文的缓存地址
4) 修改`send_recv.h`中`file_recvPkt`为已接收报文的缓存地址

#define DST_MAC_0 0x00
#define DST_MAC_1 0xe0
#define DST_MAC_2 0x4c
#define DST_MAC_3 0x3c
#define DST_MAC_4 0x03
#define DST_MAC_5 0x78
