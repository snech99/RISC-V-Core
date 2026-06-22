OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
    /* App-Bereich: 0x4000 - 0xFFFF (48 KB) */
    APP (rwx) : ORIGIN = 0x00004000, LENGTH = 48K
}

SECTIONS {
    .text   : { *(.init) *(.text .text.*) }                 > APP
    .rodata : { *(.rodata .rodata.*) }                      > APP
    .data   : {
        *(.data .data.*)
        . = ALIGN(8);
        PROVIDE( __global_pointer$ = . + 0x800 );
        *(.sdata .sdata.*)
    }                                                       > APP
    .bss    : {
        PROVIDE( _bss_start = . );
        *(.sbss .sbss.*) *(.bss .bss.*) *(COMMON)
        PROVIDE( _bss_end = . );
    }                                                       > APP

    /* App-Stack waechst vom oberen RAM-Ende abwaerts */
    PROVIDE( _sp = 0x10000 );
}
