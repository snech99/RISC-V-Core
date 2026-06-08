#ifndef RISCV_GH_H
#define RISCV_GH_H

typedef unsigned int uint32_t;
#define PRINTER (*(volatile unsigned char*) 0x4000)

void print_char(char);
void print_string(const char*);
void print_hex(unsigned int);
void print_number(int);

#endif