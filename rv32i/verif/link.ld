OUTPUT_ARCH ("riscv")

SECTIONS
{
    . = 0x00000000;
    .init                    : { *(.init) }
    .got            ALIGN(4) : { *(.got) }
    .got.plt        ALIGN(4) : { *(.got.plt) }
    .text           ALIGN(4) : { *(.master_handler) }
    .text           ALIGN(4) : { *(.text) }
    .data           ALIGN(4) : { *(.data) }
    .rodata         ALIGN(4) : { *(.rodata) }
    .bss            ALIGN(4) : { *(.bss) }
    /DISCARD/                : {*(*)}
    /*
    */
}

ENTRY(_entry)
