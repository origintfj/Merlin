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
// frame id
`define SOFID_SZ        2
`define SOFID_RANGE     `SOFID_SZ-1:0
//
`define SOFID_RUN       2'b00
`define SOFID_JUMP      2'b01
// zones
`define ZONE_SZ         2
`define ZONE_RANGE      `ZONE_SZ-1:0
//
`define ZONE_NONE       2'b00
`define ZONE_REGFILE    2'b01
`define ZONE_STOREQ     2'b10
`define ZONE_LOADQ      2'b11

//--------------------------------------------------------------
// ALU Definitions
//--------------------------------------------------------------
`define ALUOP_FUNCT3_ADDSUB 3'b000
`define ALUOP_FUNCT3_SLL    3'b001
`define ALUOP_FUNCT3_SLT    3'b010
`define ALUOP_FUNCT3_SLTU   3'b011
`define ALUOP_FUNCT3_XOR    3'b100
`define ALUOP_FUNCT3_SRLSRA 3'b101
`define ALUOP_FUNCT3_OR     3'b110
`define ALUOP_FUNCT3_AND    3'b111
//
`define ALUOP_SZ        4
`define ALUOP_RANGE     `ALUOP_SZ-1:0
// alu opcodes - top bit is for uniquification
`define ALUOP_ADD       { 1'b0, `ALUOP_FUNCT3_ADDSUB }
`define ALUOP_SUB       { 1'b1, `ALUOP_FUNCT3_ADDSUB }
`define ALUOP_SLL       { 1'b0, `ALUOP_FUNCT3_SLL    }
`define ALUOP_SLT       { 1'b0, `ALUOP_FUNCT3_SLT    }
`define ALUOP_SLTU      { 1'b0, `ALUOP_FUNCT3_SLTU   }
`define ALUOP_XOR       { 1'b0, `ALUOP_FUNCT3_XOR    }
`define ALUOP_SRL       { 1'b0, `ALUOP_FUNCT3_SRLSRA }
`define ALUOP_SRA       { 1'b1, `ALUOP_FUNCT3_SRLSRA }
`define ALUOP_OR        { 1'b0, `ALUOP_FUNCT3_OR     }
`define ALUOP_AND       { 1'b0, `ALUOP_FUNCT3_AND    }
`define ALUOP_MOV       { 1'b1, `ALUOP_FUNCT3_AND    } // pass right operand to output (e.g. LUI)
// alu condition codes - used in conditional branching
`define ALUCOND_EQ      3'b000
`define ALUCOND_NE      3'b001
`define ALUCOND_LT      3'b100
`define ALUCOND_GE      3'b101
`define ALUCOND_LTU     3'b110
`define ALUCOND_GEU     3'b111

//--------------------------------------------------------------
// Exception/Interrupt Definitions
//--------------------------------------------------------------
`define RV_MEDELEG_LEGAL_MASK               16'h0bff
//
`define EXCP_MCAUSE_INS_ADDR_MISALIGNED     { 1'b0, 27'b0, 4'd00 }
`define EXCP_MCAUSE_INS_ACCESS_FAULT        { 1'b0, 27'b0, 4'd01 }
`define EXCP_MCAUSE_ILLEGAL_INS             { 1'b0, 27'b0, 4'd02 }
//`define EXCP_MCAUSE_BREAKPOINT              { 1'b0, 27'b0, 4'd03 }
`define EXCP_MCAUSE_LOAD_ADDR_MISALIGNED    { 1'b0, 27'b0, 4'd04 }
`define EXCP_MCAUSE_LOAD_ACCESS_FAULT       { 1'b0, 27'b0, 4'd05 }
`define EXCP_MCAUSE_STORE_ADDR_MISALIGNED   { 1'b0, 27'b0, 4'd06 }
`define EXCP_MCAUSE_STORE_ACCESS_FAULT      { 1'b0, 27'b0, 4'd07 }
`define EXCP_MCAUSE_ECALL_FROM_UMODE        { 1'b0, 27'b0, 4'd08 }
`define EXCP_MCAUSE_ECALL_FROM_SMODE        { 1'b0, 27'b0, 4'd09 }
`define EXCP_MCAUSE_ECALL_FROM_MMODE        { 1'b0, 27'b0, 4'd11 }
//`define EXCP_MCAUSE_INS_PAGE_FAULT          { 1'b0, 27'b0, 4'd12 }
//`define EXCP_MCAUSE_LOAD_PAGE_FAULT         { 1'b0, 27'b0, 4'd13 }
//`define EXCP_MCAUSE_STORE_PAGE_FAULT        { 1'b0, 27'b0, 4'd15 }

//--------------------------------------------------------------

`endif

