// TODO clk_en should prob. gate all interface control signals, such as reqvalid

`ifndef RISCV_DEFS_
`define RISCV_DEFS_

//--------------------------------------------------------------
// Global Definitions
//--------------------------------------------------------------
`define RV_XLEN_X               5
`define RV_XLEN                 (2**`RV_XLEN_X)
//
`define RV_RESET_VECTOR         { `RV_XLEN {1'b0} } // Set the reset vector here
//
`define RV_VENDOR_ID            { `RV_XLEN {1'b0} } // Set the vendor ID here
`define RV_ARCHITECTURE_ID      { `RV_XLEN {1'b0} } // TODO
`define RV_IMPLEMENTATION_ID    { `RV_XLEN {1'b0} } // TODO
`define RV_HART_ID              { `RV_XLEN {1'b0} } // Set the HART ID here

//--------------------------------------------------------------
// Pipeline Bundles
//--------------------------------------------------------------
// instruction size bytes (there is an implied 0 LSB)
`define RV_INSSIZE_SZ       2
`define RV_INSSIZE_RANGE    1:0
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
`define RV_MODE_MACHINE                     2'b11
`define RV_MODE_SUPERVISOR                  2'b01
`define RV_MODE_USER                        2'b00
//
`define RV_USTATUS_ACCESS_MASK              { 4'h0, { `RV_XLEN-32 {1'b0} }, 28'h0000011 }
//
`define RV_SSTATUS_ACCESS_MASK              { 4'h8, { `RV_XLEN-32 {1'b0} }, 28'h00de133 }
`define RV_SEDELEG_LEGAL_MASK               16'h01ff
//
`define RV_MSTATUS_ACCESS_MASK              { 4'h8, { `RV_XLEN-32 {1'b0} }, 28'h07ff9bb }
`define RV_MSTATUS_MPP_RANGE                12:11
`define RV_MSTATUS_SPP_INDEX                8
`define RV_MSTATUS_MPIE_INDEX               7
`define RV_MSTATUS_SPIE_INDEX               5
`define RV_MSTATUS_UPIE_INDEX               4
`define RV_MSTATUS_MIE_INDEX                3
`define RV_MSTATUS_SIE_INDEX                1
`define RV_MSTATUS_UIE_INDEX                0
//
`define RV_TVEC_BASE_RANGE                  `RV_XLEN-1:2
`define RV_TVEC_BASE_LOB                    2'b0
`define RV_TVEC_MODE_RANGE                  1:0
`define RV_TVEC_MODE_DIRECT                 2'd0
`define RV_TVEC_MODE_VECTORED               2'd1
//
`define RV_MEDELEG_LEGAL_MASK               16'h03ff
`define RV_EDELEG_SZX                       4
`define RV_EDELEG_RANGE                     15:0
`define RV_EDELEG_HOB                       16'b0
`define RV_EPC_RANGE                        `RV_XLEN-1:2 // TODO `RV_XLEN-1:1 iff Ext. C is supported
`define RV_EPC_LOB                          2'b0 // Low Order Bits TODO 1'b1 iff Ext. C is supported
//
`define RV_CAUSE_RANGE                          `RV_XLEN-1:0
`define RV_EXCP_CAUSE_INS_ADDR_MISALIGNED       { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd00 }
`define RV_EXCP_CAUSE_INS_ACCESS_FAULT          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd01 }
`define RV_EXCP_CAUSE_ILLEGAL_INS               { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd02 }
//`define RV_EXCP_CAUSE_BREAKPOINT                { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd03 }
`define RV_EXCP_CAUSE_LOAD_ADDR_MISALIGNED      { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd04 }
`define RV_EXCP_CAUSE_LOAD_ACCESS_FAULT         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd05 }
`define RV_EXCP_CAUSE_STORE_ADDR_MISALIGNED     { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd06 }
`define RV_EXCP_CAUSE_STORE_ACCESS_FAULT        { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd07 }
`define RV_EXCP_CAUSE_ECALL_FROM_UMODE          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd08 }
`define RV_EXCP_CAUSE_ECALL_FROM_SMODE          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd09 }
`define RV_EXCP_CAUSE_ECALL_FROM_MMODE          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd11 }
//`define RV_EXCP_CAUSE_INS_PAGE_FAULT            { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd12 }
//`define RV_EXCP_CAUSE_LOAD_PAGE_FAULT           { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd13 }
//`define RV_EXCP_CAUSE_STORE_PAGE_FAULT          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd15 }

//--------------------------------------------------------------

`endif

