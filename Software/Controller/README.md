# Controller
There are 5 files in this folder:
1) send_recv.h:     Header file
2) sendPacket.c:    Used to send Ethernet packet (0x9001-0x9004) 
                    to configure Core leveraging libpcap, 0x9001
                    is used to start program; 0x9001
3) sender_test.c:   Has a main function used to configure Core, 
