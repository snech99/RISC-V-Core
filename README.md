# RV32IM Soft-Core on the Basys 3

A hand-built, 5-stage pipelined **RV32IM** RISC-V soft-core (base integer + M extension) running on the Digilent **Basys 3** (Artix-7 `XC7A35T`). Peripherals are attached over **AXI4-Lite**: BRAM, GPIO (LEDs/switches/buttons), UART and a timer. Programs are loaded at runtime over UART via a **bootloader** — no new bitstream required.

## Features

- RV32I base + M extension (MUL/DIV via a hardware divider)
- 5-stage pipeline with forwarding and load-use hazard stalling
- AXI4-Lite masters for instruction fetch and the data path
- Peripherals: 64K BRAM, AXI GPIO, AXI Uartlite, AXI Timer
- UART bootloader: upload and run apps at runtime

## Repository layout

| Path | Contents |
|------|----------|
| `rtl/` | Core RTL sources (core/) and the BRAM (mem/) |
| `ip/` | Packaged custom IP (core, custom_bram) |
| `bd/` | Block design as a Tcl export (`write_bd_tcl`) |
| `constraints/` | `basys3.xdc` (pins, clock, QSPI config) |
| `scripts/` | `create_project.tcl`, `build.tcl` |
| `mem/` | Bootloader image (`*.mem`) for BRAM init |
| `software/` | Bootloader, apps, BSP (`board.h`), upload tool |
| `docs/` | Memory map, address map, images |

## Generating the Vivado project

The Vivado project is **not** stored in Git (it is regenerated). Build it like this:

```tcl
# in the Vivado Tcl console, from the repo root:
source scripts/create_project.tcl
source scripts/build.tcl          ;# optional: build the bitstream right away
```

or headless:

```bash
vivado -mode batch -source scripts/create_project.tcl -source scripts/build.tcl
```

### Exporting the block design (after editing the BD)

```tcl
write_bd_tcl -force bd/system_bd.tcl
```

Then commit `bd/system_bd.tcl` — this keeps the block design reproducible.

## Building & uploading software

```bash
cd software
make                 # builds all apps -> build/<name>.bin
make flash APP=timing PORT=/dev/ttyUSB1
```

Toolchain: `riscv32-unknown-elf-gcc` (or `riscv64-...` with `-march=rv32im -mabi=ilp32`).

## Memory & address map

| Region | Address |
|--------|---------|
| BRAM (bootloader 0x0–0x3FFF, app 0x4000–0xFFFF) | `0x00000000` |
| GPIO0 — LEDs (ch1), switches (ch2 @ +0x08) | `0x40000000` |
| GPIO1 — buttons (ch1) | `0x40010000` |
| AXI Timer | `0x41C00000` |
| AXI Uartlite | `0x40600000` |

> **Gotcha:** reading `0xDEC0DEE3` back from a peripheral means the address is
> not mapped (AXI decode error) — check the base address in
> `software/common/board.h` against the Address Editor.

## License

See `LICENSE`.