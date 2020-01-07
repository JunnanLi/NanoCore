all:
	gcc -o t_sender sendPacket.c sender_test.c -lnet -lpcap
	gcc -o t_recv recvPacket.c receiver_test.c -lpcap
clean:
	rm t_sender
	rm t_recv
