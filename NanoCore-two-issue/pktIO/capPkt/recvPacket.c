#include "send_recv.h"

void get_packet(unsigned char *argument, const struct pcap_pkthdr *p_pkthdr, const unsigned char *packet_content){
	
	if((packet_content[0] == 0xff && packet_content[1] == 0xff && 
		packet_content[2] == 0xff && packet_content[3] == 0xff) || (
		packet_content[0] == DST_MAC_0 && packet_content[1] == DST_MAC_1 && 
		packet_content[2] == DST_MAC_2 && packet_content[3] == DST_MAC_3))
	{
		printf("pkt length :%d\n",p_pkthdr->len);
		printf("dst_mac is %02x%02x%02x%02x%02x%02x\n", packet_content[0],packet_content[1],packet_content[2],packet_content[3],packet_content[4],packet_content[5]);
		FILE* fp = fopen(file_recvPkt, "w");
		fprintf(fp, "%08x\n", ++cnt_recvPkt);
		unsigned short unvalid = 16-(p_pkthdr->len)%16;
		unsigned short valid = (p_pkthdr->len-1)%16;
		unsigned short len = (p_pkthdr->len + 15)/16;
		// fprintf(fp, "%08x\n", unvalid<<8 | len);
		fprintf(fp, "%08x\n", valid<<8 | len);
		int i=0;
		while(i<p_pkthdr->len){
			if(i%16 == 15)
				fprintf(fp, "%02x\n", packet_content[i++]);
			else
				fprintf(fp, "%02x", packet_content[i++]);
		}
		while(i%16 != 0){
			if(i%16 == 15)
				fprintf(fp, "%02x\n", 0);
			else
				fprintf(fp, "%02x", 0);
			i++;
		}
		fclose(fp);
	}

}


void main(int argc, char *argv[]){
	int recvPktPID=0;
	cnt_recvPkt = 0;


	pcap_t * pcap_h = NULL;  
	char error_content[100] = "";
	const unsigned char *packet = NULL;
	char *p_net_interface_name = NULL;
	struct pcap_pkthdr p_pkthdr;

	p_net_interface_name = pcap_lookupdev(error_content);  
	if(NULL == p_net_interface_name) {  
		perror("pcap_lookupdev");  
		exit(-1);  
	}  
	// printf("interface: %s\n", p_net_interface_name); 

	pcap_h = pcap_open_live(NAME_NETIF,BUFSIZE,1,10,error_content);
	if(pcap_h == NULL){
		printf("error_pcap_handle\n");
		exit(0);
	}

	//BPF filter;
	// struct bpf_program filter;
	// pcap_compile(pcap_h, &filter, "ehter dst 00:01:02:03:04:05", 1, 0);
	
	// pcap_setfilter(pcap_h, &filter);

	if(pcap_loop(pcap_h,-1,get_packet,NULL)<0){
		
		perror("pcap_loop");
		exit(-1);
	}
  
    pcap_close(pcap_h);
	
} 



