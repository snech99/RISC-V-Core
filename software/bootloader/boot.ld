OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
    /* Bootloader-Bereich: 0x0000 - 0x3FFF (16 KB) */
    BOOT (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS {
    .text   : { *(.init) *(.text .text.*) }                 > BOOT
    .rodata : { *(.rodata .rodata.*) }                      > BOOT
    .data   : {
        *(.data .data.*)
        . = ALIGN(8);
        PROVIDE( __global_pointer$ = . + 0x800 );
        *(.sdata .sdata.*)
    }                                                       > BOOT
    .bss    : {
        PROVIDE( _bss_start = . );
        *(.sbss .sbss.*) *(.bss .bss.*) *(COMMON)
        PROVIDE( _bss_end = . );
    }                                                       > BOOT

    /* Bootloader-Stack waechst vom Ende seines Bereichs abwaerts */
    PROVIDE( _sp = ORIGIN(BOOT) + LENGTH(BOOT) );           /* 0x4000 */
}
