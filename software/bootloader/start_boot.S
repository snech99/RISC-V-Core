# start_boot.S -- Startup des Bootloaders (liegt bei 0x0000)
.section .init, "ax"
.global _start
_start:
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop
    la   sp, _sp                 # Bootloader-Stack (0x4000)

    la   a0, _bss_start          # .bss putzen
    la   a1, _bss_end
    bge  a0, a1, 2f
1:  sw   zero, 0(a0)
    addi a0, a0, 4
    blt  a0, a1, 1b
2:
    call main
3:  j 3b                         # main soll nicht zurueckkehren; sonst halt
