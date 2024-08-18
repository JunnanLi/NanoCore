# SHELL := /bin/bash
RUNTIME_PATH 	= ../../Firmware_Runtime
MAINFUNC_PATH 	= ./src
include $(RUNTIME_PATH)/Makefile.sys

##############################################################################
## user-related param, you can add SRC,OBJS,DIR for new flods;
### DIR
MAIN_DIR_RV32UI	= src/rv32ui
MAIN_DIR_RV32UM	= src/rv32um
MAIN_DIR		= src/
### SRC
MAIN_SRC_C 		= ${wildcard $(MAINFUNC_PATH)/*.c}
MAIN_SRC_S 		= ${wildcard $(MAINFUNC_PATH)/*.S}
MAIN_SRC_S 		+= ${wildcard ${MAIN_DIR_RV32UI}/*.S}
MAIN_SRC_S 		+= ${wildcard ${MAIN_DIR_RV32UM}/*.S}
### OBJ
MAIN_OBJS 		= $(patsubst %.S,%.o,$(notdir $(MAIN_SRC_S)))	
MAIN_OBJS 		+= $(patsubst %.c,%.o,$(notdir $(MAIN_SRC_C)))

##############################################################################

FIRMWARE_OBJS 	= $(addprefix Source/, ${MAIN_OBJS} ${SYSTEM_OBJS} ${IRQ_OBJS} \
					${ASM_OBJS})
VPATH           = ${MAIN_DIR} ${MAIN_DIR_RV32UI} ${MAIN_DIR_RV32UM} ${SYSTEM_DIR} \
					${IRQ_DIR} ${ASM_DIR}
INCLUDES		+= -I$(RUNTIME_PATH)/src
INCLUDES		+= -I$(MAINFUNC_PATH)
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
		-Wl,--no-relax,-T,$(RUNTIME_PATH)/sections.lds,-Map,firmware.map,--strip-debug \
		${FIRMWARE_OBJS} -lgcc
	chmod -x $@
##############################################################################

##############################################################################
## compile .S
Source/%.o: %.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -o $@ $< \
		-DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' -DTEST_FUNC_RET=$(notdir $(basename $<))_ret \
		-DTEST_FUNC_TXT_DATA=$(notdir $(basename $<))_data
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
