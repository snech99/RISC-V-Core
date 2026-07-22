// =============================================================================
// riscv_gh.h — bare-metal I/O runtime for the RV32IM core
// -----------------------------------------------------------------------------
// Minimal freestanding helpers (no libc). Output is produced through
// memory-mapped I/O: writing a byte to PRINTER (address 0x4000) is intercepted
// by the DataMemory module and printed to the simulation console.
// =============================================================================
#ifndef RISCV_GH_H
#define RISCV_GH_H

typedef unsigned int uint32_t;
#define PRINTER (*(volatile unsigned char*) 0x4000)

void print_char(char);
void print_string(const char*);
void print_hex(unsigned int);
void print_number(int);

#endif