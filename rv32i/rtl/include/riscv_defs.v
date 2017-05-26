//--------------------------------------------------------------
// pipeline bundles
//--------------------------------------------------------------
// zones
`define ZONE_SZ         2
//
`define ZONE_LOADQ      2'b11
`define ZONE_STOREQ     2'b10
`define ZONE_REGFILE    2'b00

//--------------------------------------------------------------
// ALU definitions
//--------------------------------------------------------------
`define ALUOP_SZ        4
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
//--------------------------------------------------------------

