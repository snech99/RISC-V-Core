# start_app.S -- Startup einer App (geladen bei 0x4000)
.section .init, "ax"
.global _start
_start:
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop
    la   sp, _sp                 # App-Stack (0x10000)

    la   a0, _bss_start          # .bss putzen
    la   a1, _bss_end
    bge  a0, a1, 2f
1:  sw   zero, 0(a0)
    addi a0, a0, 4
    blt  a0, a1, 1b
2:
    call main
    # main ist zurueck -> Kontrolle zurueck an den Bootloader bei 0x0000
    li   t0, 0
    jr   t0
