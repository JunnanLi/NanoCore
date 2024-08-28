#include "send_recv.h"

void main(int argc, char *argv[])
{
	cnt_sendPkt = 0;
	char payload[1600] = {0};
	unsigned short ethType;
	while(1){
		unsigned short tag_cnt_senPkt = cnt_sendPkt;
		unsigned int unvalidLen;
		int len;
		char err_buf[100] = "";
		libnet_t *lib_net = NULL;
		libnet_ptag_t lib_t = 0;
		unsigned char dst_mac[6] = {0x88,0x88,0x88,0x88,0x89,0x88};
		unsigned char src_mac[6] = {0x00,0x01,0x02,0x03,0x04,0x05};
	   	
		FILE *fp_rd = fopen(file_sendPkt,"r");
	   	fscanf(fp_rd,"%08x\n", &tag_cnt_senPkt);
	   	// printf("%x\n", tag_cnt_senPkt);
	   	if(tag_cnt_senPkt == cnt_sendPkt){
	   		fclose(fp_rd);
	   		continue;
	   	}
	   	cnt_sendPkt = tag_cnt_senPkt;
	   	fscanf(fp_rd,"%08x\n", &unvalidLen);
	   	printf("%08x\n", unvalidLen);
	   	len = ((unvalidLen & 0xff)<<4) -15 + ((unvalidLen&0xf00)>>8) - 12;
	   	printf("payload's len: %d\n", len);
	   	int len_payload = (len<46)? 46:len-2;

		lib_net = libnet_init(LIBNET_LINK_ADV, NAME_NETIF, err_buf);
		// lib_net = libnet_init(LIBNET_LINK_ADV, "wlp0s20f3", err_buf);
		
		if(NULL == lib_net)  {  
		    perror("libnet_init");  
		    exit(-1);  
		}  

		int i;
		for(i=0; i<6; i++)
			fscanf(fp_rd,"%02x", &dst_mac[i]);
		for(i=0; i<6; i++)
			printf("%02x_",dst_mac[i]);
		printf("\n");
		for(i=0; i<6; i++)
			fscanf(fp_rd,"%02x", &src_mac[i]);
		i=0;
		while(i<len){
			fscanf(fp_rd,"%02x", &payload[i++]);
			if(i%16 == 3)
				fscanf(fp_rd,"\n");
		}
		ethType = (((unsigned short) payload[0])<<8) + (unsigned short) payload[1];
		// printf("%04x\n",ethType);

		// set sel = 1;
		lib_t = libnet_build_ethernet(
			(u_int8_t *)dst_mac,  
			(u_int8_t *)src_mac,  
			ethType,
			(u8 *) &payload[2],	// payload 
			len_payload,		// payload length
			lib_net,  
			0  
		);  
	    
		int res = 0;  
		res = libnet_write(lib_net);
		if(-1 == res)  
		{  
		    perror("libnet_write");  
		    exit(-1);  
		}

		libnet_destroy(lib_net);     
		// printf("----ok-----\n");
	}
} 
