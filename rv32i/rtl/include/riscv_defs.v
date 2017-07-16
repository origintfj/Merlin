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
`define SOFID_SZ            2
`define SOFID_RANGE         `SOFID_SZ-1:0
//
`define SOFID_RUN           2'b00
`define SOFID_JUMP          2'b01
// zones
`define ZONE_SZ             2
`define ZONE_RANGE          `ZONE_SZ-1:0
//
`define ZONE_NONE           2'b00
`define ZONE_REGFILE        2'b01
`define ZONE_STOREQ         2'b10
`define ZONE_LOADQ          2'b11

//--------------------------------------------------------------
// OPCODEs
//--------------------------------------------------------------
`define MINOR_OPCODE_ADDSUB 3'b000
`define MINOR_OPCODE_SLL    3'b001
`define MINOR_OPCODE_SLT    3'b010
`define MINOR_OPCODE_SLTU   3'b011
`define MINOR_OPCODE_XOR    3'b100
`define MINOR_OPCODE_SRLSRA 3'b101
`define MINOR_OPCODE_OR     3'b110
`define MINOR_OPCODE_AND    3'b111
//
`define MINOR_OPCODE_PRIV   3'b000
//--------------------------------------------------------------
// ALU Definitions
//--------------------------------------------------------------
`define ALUOP_SZ        4
`define ALUOP_RANGE     `ALUOP_SZ-1:0
// alu opcodes - top bit is for uniquification
`define ALUOP_ADD       { 1'b0, `MINOR_OPCODE_ADDSUB }
`define ALUOP_SUB       { 1'b1, `MINOR_OPCODE_ADDSUB }
`define ALUOP_SLL       { 1'b0, `MINOR_OPCODE_SLL    }
`define ALUOP_SLT       { 1'b0, `MINOR_OPCODE_SLT    }
`define ALUOP_SLTU      { 1'b0, `MINOR_OPCODE_SLTU   }
`define ALUOP_XOR       { 1'b0, `MINOR_OPCODE_XOR    }
`define ALUOP_SRL       { 1'b0, `MINOR_OPCODE_SRLSRA }
`define ALUOP_SRA       { 1'b1, `MINOR_OPCODE_SRLSRA }
`define ALUOP_OR        { 1'b0, `MINOR_OPCODE_OR     }
`define ALUOP_AND       { 1'b0, `MINOR_OPCODE_AND    }
`define ALUOP_MOV       { 1'b1, `MINOR_OPCODE_AND    } // pass right operand to output (e.g. LUI)
// alu condition codes - used in conditional branching
`define ALUCOND_EQ      3'b000
`define ALUCOND_NE      3'b001
`define ALUCOND_LT      3'b100
`define ALUCOND_GE      3'b101
`define ALUCOND_LTU     3'b110
`define ALUCOND_GEU     3'b111

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
`define RV_CAUSE_RANGE                      `RV_XLEN-1:0
`define EXCP_CAUSE_INS_ADDR_MISALIGNED      { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd00 }
`define EXCP_CAUSE_INS_ACCESS_FAULT         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd01 }
`define EXCP_CAUSE_ILLEGAL_INS              { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd02 }
//`define EXCP_CAUSE_BREAKPOINT               { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd03 }
`define EXCP_CAUSE_LOAD_ADDR_MISALIGNED     { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd04 }
`define EXCP_CAUSE_LOAD_ACCESS_FAULT        { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd05 }
`define EXCP_CAUSE_STORE_ADDR_MISALIGNED    { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd06 }
`define EXCP_CAUSE_STORE_ACCESS_FAULT       { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd07 }
`define EXCP_CAUSE_ECALL_FROM_UMODE         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd08 }
`define EXCP_CAUSE_ECALL_FROM_SMODE         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd09 }
`define EXCP_CAUSE_ECALL_FROM_MMODE         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd11 }
//`define EXCP_CAUSE_INS_PAGE_FAULT           { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd12 }
//`define EXCP_CAUSE_LOAD_PAGE_FAULT          { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd13 }
//`define EXCP_CAUSE_STORE_PAGE_FAULT         { 1'b0, { `RV_XLEN-5 {1'b0} }, 4'd15 }

//--------------------------------------------------------------

`endif

