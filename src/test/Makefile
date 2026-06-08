TOOLCHAIN = riscv64-elf-

CC = $(TOOLCHAIN)gcc
OBJCOPY = $(TOOLCHAIN)objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -O0 -ffreestanding -nostdlib -Wl,--no-warn-rwx-segments -T linker.ld -Xlinker --no-relax

all: test_program_code_hex.mem

main.elf: start.S main.c linker.ld
	$(CC) $(CFLAGS) -o main.elf start.S main.c riscv_gh.c -lgcc

main.bin: main.elf
	$(OBJCOPY) -O binary main.elf main.bin

test_program_code_hex.mem: main.bin
	hexdump -v -e '1/4 "%08x\n"' main.bin > test_program_code_hex.mem

clean:
	rm -f *.elf *.bin *.mem
