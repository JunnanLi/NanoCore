# SHELL := /bin/bash
RUNTIME_PATH 	= ../../Firmware_Runtime
MAINFUNC_PATH 	= ./src

include $(RUNTIME_PATH)/Makefile.sys

##############################################################################
## user-related param, you can add SRC,OBJS,DIR for new flods;
### DIR
MAIN_DIR		= ./src
### SRC
MAIN_SRC_C 		= ${wildcard $(MAINFUNC_PATH)/*.c}
### OBJ
MAIN_OBJS 		+= $(patsubst %.c,%.o,$(notdir $(MAIN_SRC_C)))	

##############################################################################
FIRMWARE_OBJS 	= $(addprefix obj/, ${MAIN_OBJS} ${SYSTEM_OBJS} $(IRQ_OBJS) \
					$(NETIF_OBJS) ${ASM_OBJS})
VPATH           = ${MAIN_DIR} ${SYSTEM_DIR} $(IRQ_DIR) \
					$(NETIF_DIR) ${ASM_DIR}
INCLUDES		= -I$(RUNTIME_PATH)/src
INCLUDES		+= -I$(MAINFUNC_PATH)

all: hex_obj_dir firmware
	@echo "---------------------------------------------------------"
	@echo "+  Current RAM size is $(RAM_SIZE_KB) KB"             
	@echo "+  Last modified date is 2023/03/23"                  
	@echo "---------------------------------------------------------"

##############################################################################
## gen firmware.hex
firmware: obj/firmware.bin
	python3 $(RUNTIME_PATH)/makehex.py $< $(RAM_SIZE) \
		> hex/$(addsuffix .hex,$@)
#	python3 $(RUNTIME_PATH)/makebin.py $< $(RAM_SIZE) \
#		hex/$(addsuffix .bin,$@)
#	cp hex/firmware.hex /home/lijunnan/share/firmware.hex
#	cp hex/firmware.bin /home/lijunnan/share/firmware.bin
#	cp hex/firmware.hex ../../../../FL-M32_Remote_Controller/firmware.hex
	cp hex/firmware.hex ../../..
##############################################################################

##############################################################################
## gen firmware.bin
obj/firmware.bin: obj/firmware.elf obj/firmware.elf.S
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@;
	wc -c obj/firmware.bin
	size obj/firmware.elf
	chmod -x $@
##############################################################################


##############################################################################
## gen firmware.elf.S
obj/firmware.elf.S: obj/firmware.elf
	$(TOOLCHAIN_PREFIX)objdump $< -s -d > $@
## gen firmware.elf
obj/firmware.elf: ${FIRMWARE_OBJS}
	$(TOOLCHAIN_PREFIX)gcc $(CCFLAGS) -Os -ffreestanding -nostdlib -o $@ \
		-Wl,-Bstatic,-T,$(RUNTIME_PATH)/sections.lds,-Map,hex/firmware.map,--strip-debug \
		${FIRMWARE_OBJS} -lgcc
	chmod -x $@
##############################################################################

##############################################################################
## compile .S
obj/%.o: %.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -o $@ $< \
		$(TIMER_IRQ_IN_ASM) $(DMA_IRQ_IN_ASM) \
		-DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' -DTEST_FUNC_RET=$(notdir $(basename $<))_ret \
		-DTEST_FUNC_TXT_DATA=$(notdir $(basename $<))_data
## compile .c
obj/%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 \
		$(GCC_WARNS) -o $@ $< -DTIME -DRISCV
## mkdir
hex_obj_dir:
	mkdir hex obj
##############################################################################

##############################################################################
.PHONY: clean help echo
clean:
	rm -r  hex obj
help:
	@echo "----------------------------------------------------------"
	@echo "+  You can use 'make RAM_SIZE_KB=128' to specify RAM size."
	@echo "+  You can use 'make TIMER_IRQ_PROC_IN_ASM=1' to choose"
	@echo "+   processing time irq in asm."
	@echo "+  You can use 'make DRM_IRQ_PROC_IN_ASM=1' to choose"
	@echo "+   processing dma irq in asm."
	@echo "----------------------------------------------------------"
echo:
	@echo "----------------------------------------------------------"
	@echo "+  MAIN_DIR is $(MAIN_DIR)"
	@echo "+  MAIN_SRC_C is $(MAIN_SRC_C)"
	@echo "+  MAIN_SRC_S is $(MAIN_SRC_S)"
	@echo "+  MAIN_OBJS is $(MAIN_OBJS)"
	@echo "----------------------------------------------------------"
##############################################################################
