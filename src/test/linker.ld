/* ============================================================================
 * linker.ld — memory layout for the bare-metal image
 * ----------------------------------------------------------------------------
 * Places .init (the _start boot code) at address 0x0, followed by .text,
 * .rodata, .data and .bss, all inside a single 16K region starting at 0x0.
 * The core fetches from 0x0 after reset, so _start must land there.
 * ==========================================================================*/
OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
    APP (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.init)           
        *(.text .text.*)   
    } > APP

    .rodata : {
        *(.rodata .rodata.*)
    } > APP

    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*) 
        PROVIDE( __global_pointer$ = . + 0x800 ); 
    } > APP

    .bss : {
        PROVIDE( _bss_start = . );
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        PROVIDE( _bss_end = . );
    } > APP

    PROVIDE( _sp = ORIGIN(APP) + LENGTH(APP) );
}