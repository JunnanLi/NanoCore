# SHELL := /bin/bash
# lwip = lwip141
# lwip_version = lwip-1.4.1
lwip = lwip_v213
lwip_version = lwip-2.1.3
include $(lwip)/Makefile

# RISCV            ?= $PULP_RISCV_GCC_TOOLCHAIN
# TOOLCHAIN_PREFIX = $(RISCV)/bin/riscv32-unknown-elf-
TOOLCHAIN_PREFIX 	= /home/lijunnan/Documents/2-software/riscv32i/bin/riscv32-unknown-elf-

MAKE = make
CCFLAGS = -march=rv32im
GCC_WARNS  = -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic -ffreestanding -nostdlib 

## TIMER_IRQ_IN_ASM, DMA_IRQ_IN_ASM
TIMER_IRQ_PROC_IN_ASM   = 1
DMA_IRQ_PROC_IN_ASM     = 1
ifeq ("$(TIMER_IRQ_PROC_IN_ASM)", "1")
    TIMER_IRQ_IN_ASM    = -DTIMER_IRQ_IN_ASM=1
else
    TIMER_IRQ_IN_ASM    = -DTIMER_IRQ_IN_ASM=0
endif
ifeq ("$(DMA_IRQ_PROC_IN_ASM)", "1")
    DMA_IRQ_IN_ASM      = -DDMA_IRQ_IN_ASM=1
else
    DMA_IRQ_IN_ASM      = -DDMA_IRQ_IN_ASM=0
endif

FIRMWARE_OBJS = crt0.o main.o $(lwip)/obj/lwiperf.o

SYSTEM_OBJS = system.o irq.o vectors.o custom_ops.o
RAM_SIZE = 131072 #128*1024
# BLOCK_RAM_SIZE = 131072 # 4096

nPORT = $(lwip)/contrib/ports/riscv
nLWIP_DIR = $(lwip)/$(lwip_version)
INCLUDES=-I$(nLWIP_DIR)/src/include \
		-I$(nPORT)/include/arch \
		-I$(nPORT)/include/netif \
		-I$(nPORT)/include \
		-I$(lwip)/lwip-2.1.3/src/apps/lwiperf

$(LWIP_INCLUDEFILES)+=$(lwip)/lwip-2.1.3/src/include/apps/lwiperf.h

VPATH = $(nLWIP_DIR)/src/core/ $(nLWIP_DIR)/src/core/ipv4/ \
	$(nLWIP_DIR)/src/core/ipv6 \
	$(nLWIP_DIR)/src/core/snmp $(nLWIP_DIR)/src/netif \
	$(nPORT) $(nPORT)/netif \
	$(lwip)/lwip-2.1.3/src/apps/lwiperf

all: firmware

firmware: firmware.bin
	python3 makehex.py $< $(RAM_SIZE) > hex/$(addsuffix .hex,$@)
	python3 makebin.py $< $(RAM_SIZE) hex/$(addsuffix .bin,$@)
# 	cp hex/firmware.hex /home/lijunnan/share/firmware.hex
# 	cp hex/firmware.bin /home/lijunnan/share/firmware.bin
	cp hex/firmware.hex ../../../firmware.hex

firmware.bin: firmware.elf firmware.elf.S
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@;
	wc -c firmware.bin
	size firmware.elf
	chmod -x $@

firmware.elf.S: firmware.elf
	$(TOOLCHAIN_PREFIX)objdump $< -s -d > $@

firmware.elf: $(FIRMWARE_OBJS) $(SYSTEM_OBJS) $(LWIP_OBJ) link.ld
	$(TOOLCHAIN_PREFIX)gcc $(CCFLAGS) -Os -ffreestanding -nostdlib -o $@ \
		-Wl,-Bstatic,-T,link.ld,-Map,hex/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) $(SYSTEM_OBJS) $(LWIP_OBJ) -lgcc
	chmod -x $@

crt0.o: crt0.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) -Os --std=c99 $(GCC_WARNS) -o $@ $<

vectors.o: vectors.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) -Os --std=c99 $(GCC_WARNS) -o $@ $< \
		$(TIMER_IRQ_IN_ASM) $(DMA_IRQ_IN_ASM)

custom_ops.o: custom_ops.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) -Os --std=c99 $(GCC_WARNS) -o $@ $<

%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<

$(lwip)/obj/%.o: %.c $(LWIP_INCLUDEFILES)
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<


clean:
	rm -f  hex/* *.coe *.bin *.elf.S
	rm -vrf $(FIRMWARE_OBJS) $(TEST_OBJS)
	rm -f *.o
	rm -rf $(lwip)/obj/*.o
	rm -f *.elf

copy:
	cp hex/firmware.hex ../iCore_Controller/firmware.hex

# -I$(nLWIP_DIR)/src/include/ipv4 \
