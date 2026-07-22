#include "riscv_gh.h"

// =============================================================================
// Test program for the RV32IM core.
//
// Goals:
//   * exercise the RV32M hardware:   MUL (ALU) and DIV/REM (HardwareDivider)
//   * hammer the branch predictor:   long, highly-biased loops (BHT/BTB warm up
//     and should predict correctly after the first 1-2 iterations), plus a few
//     data-dependent branches (prime test) that are NOT perfectly predictable.
//
// NOTE: all division operands are kept POSITIVE. The HardwareDivider is
// unsigned-only, so signed DIV/REM with negative operands would be wrong.
// =============================================================================

int main() {
    // -------------------------------------------------------------------------
    // 1) MUL inside a well-predicted loop.
    //    The backward loop branch is taken 10 times in a row -> after warm-up
    //    the BHT saturates to "taken" and the BTB holds the loop-top target,
    //    so every iteration but the last is predicted correctly.
    // -------------------------------------------------------------------------
    print_string("factorials: ");
    int fact = 1;
    for (int i = 1; i <= 10; i++) {
        fact = fact * i;            // -> MUL
        print_number(fact);
        print_char(' ');
    }
    print_char('\n');

    // -------------------------------------------------------------------------
    // 2) DIV + REM (positive operands) in another tight, well-predicted loop.
    // -------------------------------------------------------------------------
    print_string("1000 divmod n: ");
    for (int n = 1; n <= 16; n++) {
        int q = 1000 / n;           // -> DIV
        int r = 1000 % n;           // -> REM
        print_number(q);
        print_char('r');
        print_number(r);
        print_char(' ');
    }
    print_char('\n');

    // -------------------------------------------------------------------------
    // 3) Nested loops + data-dependent branches: prime sieve by trial division.
    //    * outer/inner loop branches are strongly biased  -> good for predictor
    //    * "x % d == 0" and the early break are data-dependent -> the predictor
    //      is genuinely challenged here (some mispredicts expected).
    //    Uses MUL (d*d) and REM (x % d).
    // -------------------------------------------------------------------------
    print_string("primes<60: ");
    for (int x = 2; x < 60; x++) {
        int is_prime = 1;
        for (int d = 2; d * d <= x; d++) {   // -> MUL in the condition
            if (x % d == 0) {                // -> REM
                is_prime = 0;
                break;
            }
        }
        if (is_prime) {
            print_number(x);
            print_char(' ');
        }
    }
    print_char('\n');

    // -------------------------------------------------------------------------
    // 4) A pure accumulation loop with a large trip count. This is the
    //    cleanest branch-prediction win: one backward branch, taken 199 times.
    // -------------------------------------------------------------------------
    print_string("sum 1..200: ");
    unsigned int sum = 0;
    for (unsigned int k = 1; k <= 200; k++) {
        sum += k;                   // expect 20100
    }
    print_number((int)sum);
    print_char('\n');

    // -------------------------------------------------------------------------
    // 5) SIGNED DIV/REM with negative operands (rounds toward zero, RISC-V).
    //    Expected: -20/3=-6 r-2 | 20/-3=-6 r2 | -20/-3=6 r-2 | -7/2=-3 r-1
    // -------------------------------------------------------------------------
    print_string("signed div: ");
    int aa[4] = { -20, 20, -20, -7 };
    int bb[4] = {   3, -3,  -3,  2 };
    for (int i = 0; i < 4; i++) {
        print_number(aa[i] / bb[i]);   // -> DIV (signed)
        print_char('r');
        print_number(aa[i] % bb[i]);   // -> REM (signed)
        print_char(' ');
    }
    print_char('\n');

    print_string("done\n");
    return 0;
}
