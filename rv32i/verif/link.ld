OUTPUT_ARCH ("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    .text.init         : { *(.text.init) }
    .tohost ALIGN(0x4) : { *(.tohost) }
    .text   ALIGN(0x4) : { *(.text) }
    .data   ALIGN(0x4) : { *(.data) }
    .rodata ALIGN(0x4) : { *(.rodata) }
    .bss    ALIGN(0x4) : { *(.bss) }
    _end = .;
}

