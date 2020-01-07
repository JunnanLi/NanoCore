# Controller
## Files
There are 5 files in this folder:

| File name   | Function description |
|-------------|----------------------|
| send_recv.h | Header file          |
| sendPacket.c|Used to send Ethernet packet (0x9001-0x9004) to configure Core leveraging libpcap, 0x9001 is used to start program; 0x9002 is used to read cpu state (pause or start); 0x9003 is used to load program; 0x9004 is used to read program loade in CPU |
|sender_test.c| Has a main function used to configure Core          |
|recvPacket.c | Used to receive Ehternet packet returned from CPU, 0x9002 is state; 0x9004 is program loade 
                    in CPU; 0x9005 is "printf" in running program          |
|receive_test.c| Has a main function used to print information returned from CPU          |
