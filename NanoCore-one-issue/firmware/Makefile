# SHELL := /bin/bash

## RISCV GCC ENVIRONMENT
# RISCV            	?= $PULP_RISCV_GCC_TOOLCHAIN
# TOOLCHAIN_PREFIX 	= $(RISCV)/bin/riscv32-unknown-elf-
TOOLCHAIN_PREFIX 	= /home/lijunnan/Documents/2-software/riscv32i/bin/riscv32-unknown-elf-

## MAKE ENV
MAKE 		= make
CCFLAGS 	= -march=rv32i
GCC_WARNS  	= -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS 	+= -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic -ffreestanding -nostdlib 

## RAM_SIZE
RAM_SIZE_KB = 256
RAM_SIZE 	= $(shell expr $(RAM_SIZE_KB) \* 256)

##############################################################################
## user-related param, you can add SRC,OBJS,DIR for new flods;
### SRC
MAIN_SRC 		= ${wildcard *.c}
ASM_SRC			= ${wildcard *.S}
### OBJ
MAIN_OBJS 		= $(patsubst %.c,%.o,$(notdir $(MAIN_SRC)))	
ASM_OBJS 		= $(patsubst %.S,%.o,$(notdir $(ASM_SRC)))
##############################################################################

FIRMWARE_OBJS 	= $(addprefix Source/, ${MAIN_OBJS} ${ASM_OBJS})

##############################################################################
## gen firmware.hex
firmware: Source/firmware.bin
	python3 makehex.py $< $(RAM_SIZE) \
		> Source/$(addsuffix .hex,$@)
# 	python3 makebin.py $< $(RAM_SIZE) \
# 		Source/$(addsuffix .bin,$@)
	cp Source/firmware.hex ../../firmware.hex
#	cp hex/firmware.bin /home/lijunnan/share/firmware.bin
#	cp hex/firmware.hex ../iCore_Controller/firmware.hex
##############################################################################

##############################################################################
## gen firmware.bin
Source/firmware.bin: Source/firmware.elf Source/firmware.elf.S
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@;
	wc -c Source/firmware.bin
	size Source/firmware.elf
	chmod -x $@
##############################################################################


##############################################################################
## gen firmware.elf.S
Source/firmware.elf.S: Source/firmware.elf
	$(TOOLCHAIN_PREFIX)objdump $< -s -d > $@
## gen firmware.elf
Source/firmware.elf: ${FIRMWARE_OBJS}
	$(TOOLCHAIN_PREFIX)gcc $(CCFLAGS) -Os -ffreestanding -nostdlib -o $@ \
		-Wl,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
		${FIRMWARE_OBJS} -lgcc
	chmod -x $@
##############################################################################

##############################################################################
## compile .S
Source/%.o: %.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) -o $@ $< 
## compile .c
Source/%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 \
		$(GCC_WARNS) -o $@ $<
##############################################################################

##############################################################################
.PHONY: clean
clean:
	rm ./Source/*
##############################################################################
