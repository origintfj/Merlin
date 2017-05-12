//--------------------------------------------------------------
// decoder definitions
//--------------------------------------------------------------
parameter C_ALUOP_FUNCT3_ADDSUB = 3'b000;
parameter C_ALUOP_FUNCT3_SLL    = 3'b001;
parameter C_ALUOP_FUNCT3_SLT    = 3'b010;
parameter C_ALUOP_FUNCT3_SLTU   = 3'b011;
parameter C_ALUOP_FUNCT3_XOR    = 3'b100;
parameter C_ALUOP_FUNCT3_SRLSRA = 3'b101;
parameter C_ALUOP_FUNCT3_OR     = 3'b110;
parameter C_ALUOP_FUNCT3_AND    = 3'b111;

//--------------------------------------------------------------
// pipeline bundles
//--------------------------------------------------------------
// zones
parameter C_ZONE_SZ = 2;
//
parameter C_ZONE_LOADQ   = 2'b11;
parameter C_ZONE_STOREQ  = 2'b10;
parameter C_ZONE_REGFILE = 2'b00;

//--------------------------------------------------------------
// ALU definitions
//--------------------------------------------------------------
parameter C_ALUOP_SZ = 4;
// alu opcodes - top bit is for uniquification
parameter C_ALUOP_ADD  = { 1'b0, C_ALUOP_FUNCT3_ADDSUB };
parameter C_ALUOP_SUB  = { 1'b1, C_ALUOP_FUNCT3_ADDSUB };
parameter C_ALUOP_SLL  = { 1'b0, C_ALUOP_FUNCT3_SLL    };
parameter C_ALUOP_SLT  = { 1'b0, C_ALUOP_FUNCT3_SLT    };
parameter C_ALUOP_SLTU = { 1'b0, C_ALUOP_FUNCT3_SLTU   };
parameter C_ALUOP_XOR  = { 1'b0, C_ALUOP_FUNCT3_XOR    };
parameter C_ALUOP_SRL  = { 1'b0, C_ALUOP_FUNCT3_SRLSRA };
parameter C_ALUOP_SRA  = { 1'b1, C_ALUOP_FUNCT3_SRLSRA };
parameter C_ALUOP_OR   = { 1'b0, C_ALUOP_FUNCT3_OR     };
parameter C_ALUOP_AND  = { 1'b0, C_ALUOP_FUNCT3_AND    };
parameter C_ALUOP_MOV  = { 1'b1, C_ALUOP_FUNCT3_AND    }; // pass right operand to output (e.g. LUI)
//--------------------------------------------------------------

