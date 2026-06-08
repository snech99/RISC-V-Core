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