#include "riscv_gh.h"

int main() {
    int t1 = 0;
    int t2 = 1;
    int nextTerm;

    print_number(t1);
    print_char('\n');
    print_number(t2);
    print_char('\n');


    for (int i = 0; i < 12; i++) {
        nextTerm = t1 + t2;
        print_number(nextTerm);
        print_char('\n');
        t1 = t2;
        t2 = nextTerm;
    }

    return 0;
}