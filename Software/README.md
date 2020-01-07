
/path/to/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o firmware/print_ljn.o firmware/print_ljn.c
/path/to/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -o firmware/start.o firmware/start.S
/path/to/riscv32-unknown-elf-gcc -Os -ffreestanding -nostdlib -o firmware/firmware.elf         -Wl,-Bstatic,-T,firmware/sections.lds,-Map,firmware/firmware.map,--strip-debug         firmware/start.o firmware/stats.o firmware/print_ljn.o firmware/print.o firmware/irq.o -lgcc
chmod -x firmware/firmware.elf
/path/to/riscv32-unknown-elf-objcopy -O binary firmware/firmware.elf firmware/firmware.bin
chmod -x firmware/firmware.bin
python3 firmware/makehex.py firmware/firmware.bin 16384 > firmware/firmware.hex
