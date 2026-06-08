#include "riscv_gh.h"

void print_char(char c) {
    PRINTER = c;
}

void print_string(const char* str) {
    while (*str) {
        print_char(*str);
        str++;
    }
}

void print_hex(unsigned int val) {
    for (int i = 7; i >= 0; i--) {
        unsigned int nibble = (val >> (i * 4)) & 0xF;
        if (nibble < 10) print_char('0' + nibble);
        else print_char('A' + (nibble - 10));
    }
}

void print_number(int num) {
    if (num == 0) {
        print_char('0');
        return;
    }
    if (num < 0) {
        print_char('-');
        num = -num;
    }
    
    char buffer[10];
    int i = 0;
    
    while (num > 0) {
        buffer[i++] = '0' + (num % 10);
        num /= 10;
    }
    
    for (int j = i - 1; j >= 0; j--) {
        print_char(buffer[j]);
    }
}