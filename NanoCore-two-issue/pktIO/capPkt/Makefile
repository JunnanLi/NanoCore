all:
	gcc -o t_send sendPacket.c -lnet -lpcap
	gcc -o t_recv recvPacket.c -lpcap
clean:
	rm t_send
	rm t_recv
