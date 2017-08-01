//--------------------------------------------------------------
// Program Entry Point
//--------------------------------------------------------------
asm (
    "_entry:\n"
    "   li      sp,         65532\n"
    "   csrrw   x0,         mscratch,   sp\n"
    "   la      x1,         excp_handler_wrap\n"
    "   csrw    mtvec,      x1\n"
    "   addi    x1,         x1,     1\n"
    //"   lw      x1,         0(x1)\n" // this will generate an exception
    "   li      sp,         32768\n"
    "   li      t0,         0x800\n"
    "   csrs    mie,        t0\n"
    "   li      t0,         0x8\n"
    "   csrs    mstatus,    t0\n"
    "   j       main\n"
);
//--------------------------------------------------------------

//--------------------------------------------------------------
// Machine Mode Exception Handler
//--------------------------------------------------------------
asm (
    "excp_handler_wrap:\n"
    "   csrrw   sp,     mscratch,   sp\n"
    "   addi    sp,     sp,         -124\n"
    "   sw      x1,     0(sp)\n"
    "   sw      x2,     4(sp)\n"
    "   sw      x3,     8(sp)\n"
    "   sw      x4,     12(sp)\n"
    "   sw      x5,     16(sp)\n"
    "   sw      x6,     20(sp)\n"
    "   sw      x7,     24(sp)\n"
    "   sw      x8,     28(sp)\n"
    "   sw      x9,     32(sp)\n"
    "   sw      x10,    36(sp)\n"
    "   sw      x11,    40(sp)\n"
    "   sw      x12,    44(sp)\n"
    "   sw      x13,    48(sp)\n"
    "   sw      x14,    52(sp)\n"
    "   sw      x15,    56(sp)\n"
    "   sw      x16,    60(sp)\n"
    "   sw      x17,    64(sp)\n"
    "   sw      x18,    68(sp)\n"
    "   sw      x19,    72(sp)\n"
    "   sw      x20,    76(sp)\n"
    "   sw      x21,    80(sp)\n"
    "   sw      x22,    84(sp)\n"
    "   sw      x23,    88(sp)\n"
    "   sw      x24,    92(sp)\n"
    "   sw      x25,    96(sp)\n"
    "   sw      x26,    100(sp)\n"
    "   sw      x27,    104(sp)\n"
    "   sw      x28,    108(sp)\n"
    "   sw      x29,    112(sp)\n"
    "   sw      x30,    116(sp)\n"
    "   sw      x31,    120(sp)\n"

    "   csrrw   a0,     mepc,       x0\n"
    //"   addi    a0,     a0,         4\n"
    //"   csrrw   x0,     mepc,       a0\n"
    "   jal     x1,     excp_handler\n"

    "   lw      x1,     0(sp)\n"
    "   lw      x2,     4(sp)\n"
    "   lw      x3,     8(sp)\n"
    "   lw      x4,     12(sp)\n"
    "   lw      x5,     16(sp)\n"
    "   lw      x6,     20(sp)\n"
    "   lw      x7,     24(sp)\n"
    "   lw      x8,     28(sp)\n"
    "   lw      x9,     32(sp)\n"
    "   lw      x10,    36(sp)\n"
    "   lw      x11,    40(sp)\n"
    "   lw      x12,    44(sp)\n"
    "   lw      x13,    48(sp)\n"
    "   lw      x14,    52(sp)\n"
    "   lw      x15,    56(sp)\n"
    "   lw      x16,    60(sp)\n"
    "   lw      x17,    64(sp)\n"
    "   lw      x18,    68(sp)\n"
    "   lw      x19,    72(sp)\n"
    "   lw      x20,    76(sp)\n"
    "   lw      x21,    80(sp)\n"
    "   lw      x22,    84(sp)\n"
    "   lw      x23,    88(sp)\n"
    "   lw      x24,    92(sp)\n"
    "   lw      x25,    96(sp)\n"
    "   lw      x26,    100(sp)\n"
    "   lw      x27,    104(sp)\n"
    "   lw      x28,    108(sp)\n"
    "   lw      x29,    112(sp)\n"
    "   lw      x30,    116(sp)\n"
    "   lw      x31,    120(sp)\n"
    "   addi    sp,     sp,         124\n"
    "   csrrw   sp,     mscratch,   sp\n"
    "   mret\n"
);
void writes(char const* const str);
void writex(int const value);
void excp_handler(void) {
    int a;
    writes("*** Exception ***\n");
    writes("MCAUSE=0x");
    asm (
        "   csrrw   a0,     mcause,     x0\n"
        "   jal     x1,     writex\n"
    );
    writes("\n");
    asm (
        "   li      a0,     0x55"
    );
    register int temp asm("a0");
    a = temp;
    writes("\n");
    writex(a);
    writes("\n\n");

    // clear interrupt
    *(int volatile *const)0x00000004 = 1;
}
//--------------------------------------------------------------

int a = (unsigned const)'0';

void writex(int const value) {
    int i;
    int nibble;
    int digit;

    for (i = 7; i >= 0; --i) {
        nibble = (value >> (i << 2)) & 0xf;
        if (nibble >= 0 && nibble <= 9) {
            digit = nibble + '0';
        } else {
            digit = nibble - 10 + 'A';
        }
        *(int volatile *const)0x80000000 = digit;
    }
}

void writes(char const* str) {
    char const *word_addr;
    unsigned word;
    unsigned index;
    unsigned c;
    
    word_addr = (char const *const)((unsigned const)str & ~0x3);
    word = *(unsigned const *const)word_addr;
    do {
        index     = (unsigned const)str &  0x3;

        if (index == 0) {
            word_addr = (char const *const)((unsigned const)str & ~0x3);
            word = *(unsigned const *const)word_addr;
        }

        c = (word >> (index << 3)) & 0xff;

        if (c != '\0') {
            *(unsigned volatile *const)0x80000000 = c;
            ++str;
        }
    } while (c != '\0');
}

void main(void) {
    int i, j;

    for (j = 0; j < 4; ++j) {
        for (i = 0; i < j; ++i) {
            writes((char const *const)&a);
            a += 1;

            writes("Hello World!\n");
        }
    }
/*
    asm (
        "   ecall\n"
    );
*/
    writes("From the Merlin RV32I test program\n");
    writex(0x27a7fe4);

    asm (
        "loop:\n"
        "   j       loop\n"
    );

    *(unsigned *const)0xfffffffc = 0; // end test
}

