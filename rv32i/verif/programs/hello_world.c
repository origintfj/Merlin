//--------------------------------------------------------------
// Program Entry Point
//--------------------------------------------------------------
asm (
    "_entry:\n"
    "   li      sp,     65532\n"
    "   csrrw   x0,     mscratch,   sp\n"
    "   la      x1,     excp_handler_wrap\n"
    "   csrw    mtvec,  x1\n"
    "   addi    x1,     x1,     1\n"
    "   lw      x1,     0(x1)\n" // this will generate an exception
    "   li      sp,     32768\n"
    "   j       main\n"
);
//--------------------------------------------------------------

//--------------------------------------------------------------
// Machine Mode Exception Handler
//--------------------------------------------------------------
asm (
    "excp_handler_wrap:\n"
    "   csrrw   sp,     mscratch,   sp\n"
    "   sw      x1,     0(sp)\n"
    "   sw      a0,     0(sp)\n"
    "   addi    sp,     sp,     -8\n"

    "   csrrw   a0,     mepc,       x0\n"
    "   addi    a0,     a0,     4\n"
    "   csrrw   x0,     mepc,       a0\n"
    "   jal     x1,     excp_handler\n"

    "   addi    sp,     sp,     8\n"
    "   lw      a0,     0(sp)\n"
    "   lw      x1,     0(sp)\n"
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

        c = word >> (index << 3);

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

    asm (
        "   ecall\n"
    );

    writes("From the Merlin RV32I test program\n");
    writex(0x27a7fe4);

    *(unsigned *const)0xfffffffc = 0; // end test
}

