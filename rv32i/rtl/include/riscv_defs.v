/*
 * Author         : Tom Stanway-Mayers
 * Description    : Core Defines
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`ifndef RV_RISCV_DEFS_
`define RV_RISCV_DEFS_

`include "merlin_config.v"

//--------------------------------------------------------------
// Global Definitions
//--------------------------------------------------------------
`ifdef RV_RESET_TYPE_SYNC
    `define RV_SYNC_LOGIC_CLOCK(clock)                  (posedge clock)
    `define RV_SYNC_LOGIC_CLOCK_RESET(clock, reset)     (posedge clock)
`else
    `define RV_SYNC_LOGIC_CLOCK(clock)                  (posedge clock)
    `define RV_SYNC_LOGIC_CLOCK_RESET(clock, reset)     (posedge clock or posedge reset)
`endif

`ifdef RV_CONFIG_STDEXT_64
    `define RV_XLEN_X   6 // 64-bit
`else
    `define RV_XLEN_X   5 // 32-bit
`endif

`ifdef RV_LSQUEUE_PASSTHROUGH
    `define RV_LSQUEUE_BYPASS   1
`else
    `define RV_LSQUEUE_BYPASS   0
`endif
`ifdef RV_PFU_PASSTHROUGH
    `define RV_PFU_BYPASS       1
`else
    `define RV_PFU_BYPASS       0
`endif

`define RV_XLEN                 (2**`RV_XLEN_X)
//
`define RV_VENDOR_ID            { `RV_XLEN {1'b0} } // Set the vendor ID here
`define RV_ARCHITECTURE_ID      { `RV_XLEN {1'b0} } // TODO
`define RV_IMPLEMENTATION_ID    { `RV_XLEN {1'b0} } // TODO
`define RV_HART_ID              { `RV_XLEN {1'b0} } // Set the HART ID here

//--------------------------------------------------------------
// Pipeline Bundles
//--------------------------------------------------------------
// frame id
`define RV_SOFID_SZ         2
`define RV_SOFID_RANGE      `RV_SOFID_SZ-1:0
//
`define RV_SOFID_RUN        2'b00
`define RV_SOFID_JUMP       2'b01
// zones
`define RV_ZONE_SZ          2
`define RV_ZONE_RANGE       `RV_ZONE_SZ-1:0
//
`define RV_ZONE_NONE        2'b00
`define RV_ZONE_REGFILE     2'b01
`define RV_ZONE_STOREQ      2'b10
`define RV_ZONE_LOADQ       2'b11

//--------------------------------------------------------------
// OPCODEs
//--------------------------------------------------------------
`define RV_MAJOR_OPCODE_LUI     7'b0110111
`define RV_MAJOR_OPCODE_AUIPC   7'b0010111
`define RV_MAJOR_OPCODE_JAL     7'b1101111
`define RV_MAJOR_OPCODE_JALR    7'b1100111
`define RV_MAJOR_OPCODE_BRANCH  7'b1100011
`define RV_MAJOR_OPCODE_LOAD    7'b0000011
`define RV_MAJOR_OPCODE_STORE   7'b0100011
`define RV_MAJOR_OPCODE_OPIMM   7'b0010011
`define RV_MAJOR_OPCODE_OP      7'b0110011
`define RV_MAJOR_OPCODE_MISCMEM 7'b0001111
`define RV_MAJOR_OPCODE_SYSTEM  7'b1110011
//
`define RV_MINOR_OPCODE_ADDSUB  3'b000
`define RV_MINOR_OPCODE_SLL     3'b001
`define RV_MINOR_OPCODE_SLT     3'b010
`define RV_MINOR_OPCODE_SLTU    3'b011
`define RV_MINOR_OPCODE_XOR     3'b100
`define RV_MINOR_OPCODE_SRLSRA  3'b101
`define RV_MINOR_OPCODE_OR      3'b110
`define RV_MINOR_OPCODE_AND     3'b111
//
`define RV_MINOR_OPCODE_PRIV    3'b000
//--------------------------------------------------------------
// ALU Definitions
//--------------------------------------------------------------
`define RV_ALUOP_SZ         4
`define RV_ALUOP_RANGE      `RV_ALUOP_SZ-1:0
// alu opcodes - top bit is for uniquification
`define RV_ALUOP_ADD        { 1'b0, `RV_MINOR_OPCODE_ADDSUB }
`define RV_ALUOP_SUB        { 1'b1, `RV_MINOR_OPCODE_ADDSUB }
`define RV_ALUOP_SLL        { 1'b0, `RV_MINOR_OPCODE_SLL    }
`define RV_ALUOP_SLT        { 1'b0, `RV_MINOR_OPCODE_SLT    }
`define RV_ALUOP_SLTU       { 1'b0, `RV_MINOR_OPCODE_SLTU   }
`define RV_ALUOP_XOR        { 1'b0, `RV_MINOR_OPCODE_XOR    }
`define RV_ALUOP_SRL        { 1'b0, `RV_MINOR_OPCODE_SRLSRA }
`define RV_ALUOP_SRA        { 1'b1, `RV_MINOR_OPCODE_SRLSRA }
`define RV_ALUOP_OR         { 1'b0, `RV_MINOR_OPCODE_OR     }
`define RV_ALUOP_AND        { 1'b0, `RV_MINOR_OPCODE_AND    }
`define RV_ALUOP_MOV        { 1'b1, `RV_MINOR_OPCODE_AND    } // pass right operand to output (e.g. LUI)
// alu condition codes - used in conditional branching
`define RV_ALUCOND_EQ       3'b000
`define RV_ALUCOND_NE       3'b001
`define RV_ALUCOND_LT       3'b100
`define RV_ALUCOND_GE       3'b101
`define RV_ALUCOND_LTU      3'b110
`define RV_ALUCOND_GEU      3'b111

//--------------------------------------------------------------
// CSR/Exception/Interrupt Definitions
//--------------------------------------------------------------
`define RV_CSR_MODE_MACHINE                         2'b11
`define RV_CSR_MODE_SUPERVISOR                      2'b01
`define RV_CSR_MODE_USER                            2'b00
// cause
`define RV_CSR_INTR_CAUSE_US                        { 2'b00, 2'b00 }
`define RV_CSR_INTR_CAUSE_SS                        { 2'b00, 2'b01 }
`define RV_CSR_INTR_CAUSE_MS                        { 2'b00, 2'b11 }
`define RV_CSR_INTR_CAUSE_UT                        { 2'b01, 2'b00 }
`define RV_CSR_INTR_CAUSE_ST                        { 2'b01, 2'b01 }
`define RV_CSR_INTR_CAUSE_MT                        { 2'b01, 2'b11 }
`define RV_CSR_INTR_CAUSE_UE                        { 2'b10, 2'b00 }
`define RV_CSR_INTR_CAUSE_SE                        { 2'b10, 2'b01 }
`define RV_CSR_INTR_CAUSE_ME                        { 2'b10, 2'b11 }
`define RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED       { 4'd00 }
`define RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT          { 4'd01 }
`define RV_CSR_EXCP_CAUSE_ILLEGAL_INS               { 4'd02 }
    //`define RV_CSR_EXCP_CAUSE_BREAKPOINT                { 4'd03 }
`define RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED      { 4'd04 }
`define RV_CSR_EXCP_CAUSE_LOAD_ACCESS_FAULT         { 4'd05 }
`define RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED     { 4'd06 }
`define RV_CSR_EXCP_CAUSE_STORE_ACCESS_FAULT        { 4'd07 }
`define RV_CSR_EXCP_CAUSE_ECALL_FROM_UMODE          { 4'd08 }
`define RV_CSR_EXCP_CAUSE_ECALL_FROM_SMODE          { 4'd09 }
`define RV_CSR_EXCP_CAUSE_ECALL_FROM_MMODE          { 4'd11 }
    //`define RV_CSR_EXCP_CAUSE_INS_PAGE_FAULT            { 4'd12 }
    //`define RV_CSR_EXCP_CAUSE_LOAD_PAGE_FAULT           { 4'd13 }
    //`define RV_CSR_EXCP_CAUSE_STORE_PAGE_FAULT          { 4'd15 }
//
`define RV_CSR_TVEC_MODE_DIRECT                     2'd0
`define RV_CSR_TVEC_MODE_VECTORED                   2'd1

//--------------------------------------------------------------

`ifdef RV_ASSERTS_ON
    `define RV_ASSERT(assertion, message)                                   \
        if (!(assertion)) begin                                             \
            $display("[ASSERTION ERROR @ %0t in %m] %s", $time(), message); \
            $finish();                                                      \
        end
`else
    `define RV_ASSERT(assertion, message)   \
        if (0) begin                        \
        end
`endif

`endif

