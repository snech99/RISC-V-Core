# Memory Map

The core fetches instructions and accesses data over two AXI4-Lite masters
(`M_AXI_IF` for instruction fetch, `M_AXI_DP` for the data path). All of code
and data live in a single 64 KB dual-port BRAM; the AXI peripherals occupy a
separate region of the address space (see [address_map.md](address_map.md)).

## BRAM overview

| Property | Value |
|----------|-------|
| Size | 64 KB |
| Organisation | 16384 words x 32 bit |
| Base address | `0x00000000` |
| Address range | `0x00000000` – `0x0000FFFF` |
| Word address | `addr[15:2]` (byte address / 4) |
| Init source | `mem/test_program_code_hex.mem` via `$readmemh` |
| Ports | A = instruction fetch, B = data path |

The BRAM is byte-writable (4 lane strobes), which is what makes `sb`/`sh`
work correctly. Sub-word stores rely on byte-lane alignment of `WSTRB` **and**
`WDATA` in the AXI master — see `AXI_MemUnit.v`.

## Region layout

The 64 KB is split between the bootloader (resident in the bitstream) and the
user application (uploaded at runtime over UART). The split is defined by the
linker scripts, not by hardware.

| Region | Range | Size | Linker script | Stack pointer (`_sp`) |
|--------|-------|------|---------------|------------------------|
| Bootloader | `0x0000` – `0x3FFF` | 16 KB | `boot.ld` | `0x4000` |
| Application | `0x4000` – `0xFFFF` | 48 KB | `app.ld` | `0x10000` |

Notes:

- The CPU resets the PC to `0x0000`, so the **bootloader always runs first**.
- The bootloader copies an uploaded app to `APP_BASE = 0x4000` and jumps there.
  Its upload size cap (`APP_MAX` in `boot.c`) is a software limit and can be at
  most the 48 KB of the app region.
- Each stack grows **downward** from its `_sp`. The app stack starts at the top
  of the BRAM (`0x10000` = 64 KB) and grows down into the app region; the
  bootloader stack starts at `0x4000` and grows down into the boot region.
- On `main()` return, the app's `start_app.S` jumps back to `0x0000`, handing
  control back to the bootloader.

## Boot / app split rationale

Keeping the bootloader resident in the bitstream means new programs can be
flashed over UART **without** re-running synthesis or regenerating a bitstream.
Only the bootloader image (`mem/test_program_code_hex.mem`) is baked into the
BRAM at build time; everything in the app region is loaded live.

## The `$readmemh` gotcha

`custom_RAM.v` initialises the BRAM with
`$readmemh("test_program_code_hex.mem", ram)`. This is a **relative** path that
resolves against the synthesis/simulation run directory, *not* the repo. The
`.mem` must therefore be added to the Vivado project as a source (handled by
`scripts/create_project.tcl`). If a fresh build boots into an empty BRAM (the
core appears to do nothing), this missing file is almost always the cause.
