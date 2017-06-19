`ifndef RISCV_DEFS_
`define RISCV_DEFS_

//--------------------------------------------------------------
// pipeline bundles
//--------------------------------------------------------------
// zones
`define ZONE_SZ         2
`define ZONE_RANGE      `ZONE_SZ-1:0
//
`define ZONE_LOADQ      2'b11
`define ZONE_STOREQ     2'b10
`define ZONE_REGFILE    2'b00

//--------------------------------------------------------------
// ALU definitions
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

`endif

