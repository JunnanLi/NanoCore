# SHELL := /bin/bash
RUNTIME_PATH 	= ../../Firmware_Runtime
MAINFUNC_PATH 	= ./src
include $(RUNTIME_PATH)/Makefile.sys

##############################################################################
## user-related param, you can add SRC,OBJS,DIR for new flods;
### DIR
MAIN_DIR		= src/
### SRC
MAIN_SRC 		= ${wildcard $(MAINFUNC_PATH)/*.c}
### OBJ
MAIN_OBJS 		= $(patsubst %.c,%.o,$(notdir $(MAIN_SRC)))	
##############################################################################

FIRMWARE_OBJS 	= $(addprefix Source/, ${MAIN_OBJS} ${SYSTEM_OBJS} $(IRQ_OBJS) \
					$(NETIF_OBJS) ${ASM_OBJS} )
VPATH           = ${MAIN_DIR} ${SYSTEM_DIR} $(IRQ_DIR) \
					$(NETIF_DIR) ${ASM_DIR}
INCLUDES		= -I$(RUNTIME_PATH)/src 
INCLUDES		+= -I$(MAINFUNC_PATH)

all: hex_obj_dir firmware

hex_obj_dir:
	mkdir Source

##############################################################################
## gen firmware.hex
firmware: Source/firmware.bin
	python3 $(RUNTIME_PATH)/makehex.py $< $(RAM_SIZE) \
		> Source/$(addsuffix .hex,$@)
# 	python3 $(RUNTIME_PATH)/makebin.py $< $(RAM_SIZE) \
# 		Source/$(addsuffix .bin,$@)
	cp Source/firmware.hex ../../../firmware.hex
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
		-Wl,-Bstatic,-T,$(RUNTIME_PATH)/sections.lds,-Map,Source/firmware.map,--strip-debug \
		${FIRMWARE_OBJS} -lgcc
	chmod -x $@
##############################################################################

##############################################################################
## compile .S
Source/%.o: %.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -o $@ $< $(TIMER_IRQ_IN_ASM) \
		$(DMA_IRQ_IN_ASM)
## compile .c
Source/%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 \
		$(GCC_WARNS) -o $@ $<
##############################################################################

##############################################################################
.PHONY: clean
clean:
	rm -r Source
##############################################################################
