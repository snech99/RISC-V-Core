# =============================================================================
# software/Makefile  --  builds the bootloader and all apps for the RV32IM core.
#
#   make            -> builds all apps under apps/  to build/<name>.bin
#   make boot       -> builds the bootloader
#   make <name>     -> builds only apps/<name>.c
#   make flash APP=timing PORT=/dev/ttyUSB1   -> upload over UART
#   make clean
# =============================================================================

CROSS   ?= riscv64-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy

CFLAGS   = -march=rv32im_zicsr -mabi=ilp32 -Os -ffreestanding -nostdlib \
           -nostartfiles -Icommon -Wall

# --- app build (runs from 0x4000, returns to the bootloader on exit) ---
APP_LD   = apps/app.ld
APP_CRT  = apps/start_app.S
APP_SRCS = $(wildcard apps/*.c)
APP_BINS = $(patsubst apps/%.c,build/%.bin,$(APP_SRCS))

# --- upload parameters ---
PORT    ?= /dev/ttyUSB1
BAUD    ?= 115200
APP     ?= timing

all: $(APP_BINS)

build:
	mkdir -p build

build/%.elf: apps/%.c $(APP_CRT) $(APP_LD) | build
	$(CC) $(CFLAGS) -T $(APP_LD) -o $@ $(APP_CRT) $<

build/%.bin: build/%.elf
	$(OBJCOPY) -O binary $< $@

# convenient short name:  make timing
%: build/%.bin
	@:

# --- bootloader (runs from 0x0000) ---
boot: | build
	$(CC) $(CFLAGS) -T bootloader/boot.ld -o build/boot.elf \
	    bootloader/start_boot.S bootloader/boot.c
	$(OBJCOPY) -O binary build/boot.elf build/boot.bin
	@echo "Bootloader: build/boot.bin  (-> convert to .mem, BRAM init, bitstream)"

# --- upload an app over UART ---
flash: build/$(APP).bin
	python3 tools/send_app.py build/$(APP).bin $(PORT) $(BAUD)

clean:
	rm -rf build

.PHONY: all boot flash clean