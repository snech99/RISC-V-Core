# =============================================================================
# start.S — bare-metal boot/crt0 for the RV32IM core
# -----------------------------------------------------------------------------
# Entry point of the program image. The linker script forces the ".init"
# section to address 0, which is where the core begins fetching after reset.
# It sets up the stack pointer, calls main(), and parks the CPU in a halt loop
# should main() ever return.
# =============================================================================

# The ".init" section is pinned to address 0x0 by the linker script.
.section .init, "ax"
.global _start

_start:
    # 1. Initialise the stack pointer (sp / x2).
    #    The stack grows downward from this address.
    li sp, 4096

    # 2. Enter the C program.
    call main

    # 3. Safety-net halt loop:
    #    should main() ever return, trap the CPU here in an infinite loop so it
    #    does not run off and execute garbage from the rest of memory.
halt:
    j halt
