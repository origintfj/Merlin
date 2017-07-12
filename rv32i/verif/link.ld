OUTPUT_ARCH ("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    .text.init : { *(.text.init) }
    .tohost ALIGN (0x4) : { *(.tohost) }
    .text ALIGN(0x4) : { *(.text) }
    .data ALIGN(0x4) : { *(.data) }
    .bss : { *(.bss) }
    _end = .;
}

