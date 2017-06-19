`include "riscv_defs.v"

module decoder
    #(
        parameter C_XLEN = 32
    )
    (
        // instruction decoder interface
            // ingress side
        input  wire           [31:0] ins_i,
            // egress side
        output reg                   ins_err_o,
        output reg     [`ZONE_RANGE] zone_o,
        output wire            [4:0] regd_addr_o,
        output wire            [4:0] regs1_addr_o,
        output wire            [4:0] regs2_addr_o,
        output reg      [C_XLEN-1:0] imm_o,
        output reg                   link_o,
        output reg                   sels1_pc_o,
        output reg                   sel_csr_wr_data_imm_o,
        output reg                   sels2_imm_o,
        output reg    [`ALUOP_RANGE] aluop_o,
        output wire            [2:0] funct3_o,
        output reg                   csr_access_o,
        output wire           [11:0] csr_addr_o,
        output reg                   conditional_o
    );

    //--------------------------------------------------------------

    // global
    // instruction type decoder
    `define IMM_TYPE_UDEF       3'd0 // TODO
    `define IMM_TYPE_R          3'd0
    `define IMM_TYPE_I          3'd1
    `define IMM_TYPE_I_ZIMM     3'd2
    `define IMM_TYPE_S          3'd3
    `define IMM_TYPE_SB         3'd4
    `define IMM_TYPE_U          3'd5
    `define IMM_TYPE_UJ         3'd6
    `define IMM_TYPE_MISC_MEM   3'd7
    //
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    reg  [2:0] ins_type;
    // field extraction
    reg [C_XLEN-1:0] sign_imm;

    //--------------------------------------------------------------

    // global
    assign regd_addr_o  = ins_i[11: 7];
    assign regs1_addr_o = ins_i[19:15];
    assign regs2_addr_o = ins_i[24:20];
    assign funct3_o     = funct3;
    assign csr_addr_o   = ins_i[31:20];


    // instruction type decode
    //
    assign opcode = ins_i[6: 0];
    assign funct3 = ins_i[14:12];
    assign funct7 = ins_i[31:25];
    //
    always @ (*)
    begin
        ins_err_o             = 1'b0;
        zone_o                = `ZONE_REGFILE;
        aluop_o               = `ALUOP_ADD; // NOTE don't actually care
        link_o                = 1'b0;
        sels1_pc_o            = 1'b0;
        sels2_imm_o           = 1'b0;
        sel_csr_wr_data_imm_o = 1'b0;
        csr_access_o          = 1'b0;
        conditional_o         = 1'b0;
        ins_type              = `IMM_TYPE_UDEF;
        //
        case (opcode)
            7'b0110111 : begin // lui
                ins_type    = `IMM_TYPE_U;
                aluop_o     = `ALUOP_MOV;
                sels2_imm_o = 1'b1;
            end
            7'b0010111 : begin // auipc
                ins_type    = `IMM_TYPE_U;
                aluop_o     = `ALUOP_ADD;
                sels1_pc_o  = 1'b1;
                sels2_imm_o = 1'b1;
            end
            7'b1101111 : begin // jal
                ins_type    = `IMM_TYPE_UJ;
                aluop_o     = `ALUOP_ADD;
                link_o      = 1'b1;
                sels1_pc_o  = 1'b1;
                sels2_imm_o = 1'b1;
            end
            7'b1100111 : begin // jalr
                ins_type    = `IMM_TYPE_I;
                aluop_o     = `ALUOP_ADD;
                link_o      = 1'b1;
                sels2_imm_o = 1'b1;
                if (funct3 != 3'b0) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b1100011 : begin // branch
                ins_type      = `IMM_TYPE_SB;
                aluop_o       = `ALUOP_ADD;
                sels1_pc_o    = 1'b1;
                sels2_imm_o   = 1'b1;
                conditional_o = 1'b1;
                if (funct3 != 3'b000 &&
                    funct3 != 3'b001 &&
                    funct3 != 3'b100 &&
                    funct3 != 3'b101 &&
                    funct3 != 3'b110 &&
                    funct3 != 3'b111) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b0000011 : begin // load
                ins_type    = `IMM_TYPE_I;
                zone_o      = `ZONE_LOADQ;
                aluop_o     = `ALUOP_ADD;
                sels2_imm_o = 1'b1;
                if (funct3 != 3'b000 &&
                    funct3 != 3'b001 &&
                    funct3 != 3'b010 &&
                    funct3 != 3'b100 &&
                    funct3 != 3'b101) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b0100011 : begin // store
                ins_type    = `IMM_TYPE_S;
                zone_o      = `ZONE_STOREQ;
                aluop_o     = `ALUOP_ADD;
                sels2_imm_o = 1'b1;
                if (funct3 != 3'b000 &&
                    funct3 != 3'b001 &&
                    funct3 != 3'b010) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b0010011 : begin // op-imm
                ins_type    = `IMM_TYPE_I;
                sels2_imm_o = 1'b1;
                case (funct3)
                    `ALUOP_FUNCT3_ADDSUB : begin
                        aluop_o = `ALUOP_ADD;
                    end
                    `ALUOP_FUNCT3_SLL : begin
                        aluop_o = `ALUOP_SLL;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_SLT : begin
                        aluop_o = `ALUOP_SLT;
                    end
                    `ALUOP_FUNCT3_SLTU : begin
                        aluop_o = `ALUOP_SLTU;
                    end
                    `ALUOP_FUNCT3_XOR : begin
                        aluop_o = `ALUOP_XOR;
                    end
                    `ALUOP_FUNCT3_SRLSRA : begin
                        aluop_o = `ALUOP_SRL; // NOTE ALU will chose SRA if funct7 != 0
                        if (funct7 != 7'b0000000 &&
                            funct7 != 7'b0100000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_OR : begin
                        aluop_o = `ALUOP_OR;
                    end
                    `ALUOP_FUNCT3_AND : begin
                        aluop_o = `ALUOP_AND;
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            7'b0110011 : begin // op
                ins_type = `IMM_TYPE_R;
                case (funct3)
                    `ALUOP_FUNCT3_ADDSUB : begin
                        if (funct7 == 7'b0000000) begin
                            aluop_o = `ALUOP_ADD;
                        end else if (funct7 == 7'b0100000) begin
                            aluop_o = `ALUOP_SUB;
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_SLL : begin
                        aluop_o = `ALUOP_SLL;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_SLT : begin
                        aluop_o = `ALUOP_SLT;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_SLTU : begin
                        aluop_o = `ALUOP_SLTU;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_XOR : begin
                        aluop_o = `ALUOP_XOR;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_SRLSRA : begin
                        if (funct7 == 7'b0000000) begin
                            aluop_o = `ALUOP_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            aluop_o = `ALUOP_SRA;
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_OR : begin
                        aluop_o = `ALUOP_OR;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `ALUOP_FUNCT3_AND : begin
                        aluop_o = `ALUOP_AND;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            7'b0001111 : begin // misc-mem TODO
                ins_type = `IMM_TYPE_MISC_MEM;
            end
            7'b1110011 : begin // system
                if (funct3 == 3'b000) begin // TODO ECALL/EBREAK
                end else if (funct3 == 3'b001 ||
                             funct3 == 3'b010 ||
                             funct3 == 3'b011) begin // CSR access with rs1
                    csr_access_o = 1'b1;
                end else if (funct3 == 3'b101 ||
                             funct3 == 3'b110 ||
                             funct3 == 3'b111) begin // CSR access with zimm
                    sel_csr_wr_data_imm_o = 1'b1;
                    ins_type              = `IMM_TYPE_I_ZIMM;
                    csr_access_o          = 1'b1;
                end else begin
                    ins_err_o = 1'b1;
                end
            end
            default : begin
                ins_err_o = 1'b1;
            end
        endcase
    end


    // field extraction
    //
    always @ (*)
    begin
        if (ins_i[31]) begin
            sign_imm = { C_XLEN {1'b1} };
        end else begin
            sign_imm = { C_XLEN {1'b0} };
        end
        //
        case (ins_type)
            `IMM_TYPE_I      : imm_o = { sign_imm[C_XLEN-1:11], ins_i[30:20] };
            `IMM_TYPE_I_ZIMM : imm_o = {   { C_XLEN-5 {1'b0} }, ins_i[19:15] };
            `IMM_TYPE_S      : imm_o = { sign_imm[C_XLEN-1:11], ins_i[30:25], ins_i[11:7] };
            `IMM_TYPE_SB     : imm_o = { sign_imm[C_XLEN-1:12], ins_i[7], ins_i[30:25], ins_i[11:6] };
            `IMM_TYPE_U      : imm_o = { sign_imm[C_XLEN-1:31], ins_i[30:12], 12'b0 };
            `IMM_TYPE_UJ     : imm_o = { sign_imm[C_XLEN-1:20], ins_i[19:12], ins_i[20], ins_i[30:21], 1'b0 };
            default          : imm_o = { C_XLEN {1'b0} }; // NOTE don't care
        endcase
    end
endmodule
