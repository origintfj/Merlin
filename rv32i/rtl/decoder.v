/*
 * Author         : Tom Stanway-Mayers
 * Description    : RV32I Instruction Decoder
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

// TODO add support for the 16-bit extention

`include "riscv_defs.v"

module decoder
    (
        // instruction decoder interface
            // ingress side
        input  wire              [31:0] ins_i,
            // egress side
        output wire               [1:0] ins_size_o,
        output reg                      ins_err_o,
        output reg                      fencei_o,
        output reg                      wfi_o,
        output reg                      jump_o,
        output reg                      ecall_o,
        output reg                      trap_rtn_o,
        output wire               [1:0] trap_rtn_mode_o,
        output reg     [`RV_ZONE_RANGE] zone_o,
        output reg                      regd_tgt_o,
        output wire               [4:0] regd_addr_o,
        output reg                      regs1_rd_o,
        output wire               [4:0] regs1_addr_o,
        output reg                      regs2_rd_o,
        output wire               [4:0] regs2_addr_o,
        output reg       [`RV_XLEN-1:0] imm_o,
        output reg                      link_o,
        output reg                      sels1_pc_o,
        output reg                      sel_csr_wr_data_imm_o,
        output reg                      sels2_imm_o,
        output reg                      selcmps2_imm_o,
        output reg    [`RV_ALUOP_RANGE] aluop_o,
        output wire               [2:0] funct3_o,
        output reg                      csr_rd_o,
        output reg                      csr_wr_o,
        output wire              [11:0] csr_addr_o,
        output reg                      conditional_o
    );

    //--------------------------------------------------------------

    // global
    // instruction type decoder
    parameter C_IMM_TYPE_UDEF     = 3'd0; // This is really "don't care"
    parameter C_IMM_TYPE_R        = 3'd0;
    parameter C_IMM_TYPE_I        = 3'd1;
    parameter C_IMM_TYPE_I_ZIMM   = 3'd2;
    parameter C_IMM_TYPE_S        = 3'd3;
    parameter C_IMM_TYPE_SB       = 3'd4;
    parameter C_IMM_TYPE_U        = 3'd5;
    parameter C_IMM_TYPE_UJ       = 3'd6;
    parameter C_IMM_TYPE_MISC_MEM = 3'd7;
    //
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] regd_addr;
    wire [4:0] regs1_addr;
    reg  [2:0] ins_type;
    // immediate generation
    reg [`RV_XLEN-1:0] sign_imm;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // global
    //--------------------------------------------------------------
    assign ins_size_o      = 2'b10;
    assign trap_rtn_mode_o = ins_i[29:28];
    assign regd_addr_o     = regd_addr;
    assign regs1_addr_o    = regs1_addr;
    assign regs2_addr_o    = ins_i[24:20];
    assign funct3_o        = funct3;
    assign csr_addr_o      = ins_i[31:20];


    //--------------------------------------------------------------
    // instruction type decode
    //--------------------------------------------------------------
    assign opcode     = ins_i[ 6: 0];
    assign funct3     = ins_i[14:12];
    assign funct7     = ins_i[31:25];
    assign regd_addr  = ins_i[11: 7];
    assign regs1_addr = ins_i[19:15];
    //
    always @ (*)
    begin
        ins_err_o             = 1'b0;
        fencei_o              = 1'b0;
        wfi_o                 = 1'b0;
        jump_o                = 1'b0;
        ecall_o               = 1'b0;
        trap_rtn_o            = 1'b0;
        zone_o                = `RV_ZONE_NONE;
        regd_tgt_o            = 1'b0;
        regs1_rd_o            = 1'b0;
        regs2_rd_o            = 1'b0;
        aluop_o               = `RV_ALUOP_ADD; // NOTE: don't actually care
        link_o                = 1'b0;
        sels1_pc_o            = 1'b0;
        sels2_imm_o           = 1'b0;
        selcmps2_imm_o        = 1'b0;
        sel_csr_wr_data_imm_o = 1'b0;
        csr_rd_o              = 1'b0;
        csr_wr_o              = 1'b0;
        conditional_o         = 1'b0;
        ins_type              = C_IMM_TYPE_UDEF;
        //
        case (opcode)
            7'b0110111 : begin // lui
                ins_type    = C_IMM_TYPE_U;
                zone_o      = `RV_ZONE_REGFILE;
                regd_tgt_o  = 1'b1;
                aluop_o     = `RV_ALUOP_MOV;
                sels2_imm_o = 1'b1;
            end
            7'b0010111 : begin // auipc
                ins_type    = C_IMM_TYPE_U;
                zone_o      = `RV_ZONE_REGFILE;
                regd_tgt_o  = 1'b1;
                aluop_o     = `RV_ALUOP_ADD;
                sels1_pc_o  = 1'b1;
                sels2_imm_o = 1'b1;
            end
            7'b1101111 : begin // jal
                ins_type    = C_IMM_TYPE_UJ;
                jump_o      = 1'b1;
                zone_o      = `RV_ZONE_REGFILE;
                regd_tgt_o  = 1'b1;
                aluop_o     = `RV_ALUOP_ADD;
                link_o      = 1'b1;
                sels1_pc_o  = 1'b1;
                sels2_imm_o = 1'b1;
            end
            7'b1100111 : begin // jalr
                ins_type    = C_IMM_TYPE_I;
                jump_o      = 1'b1;
                zone_o      = `RV_ZONE_REGFILE;
                regd_tgt_o  = 1'b1;
                regs1_rd_o  = 1'b1;
                aluop_o     = `RV_ALUOP_ADD;
                link_o      = 1'b1;
                sels2_imm_o = 1'b1;
                if (funct3 != 3'b0) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b1100011 : begin // branch
                ins_type      = C_IMM_TYPE_SB;
                jump_o        = 1'b1;
                regs1_rd_o    = 1'b1;
                regs2_rd_o    = 1'b1;
                aluop_o       = `RV_ALUOP_ADD;
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
                ins_type    = C_IMM_TYPE_I;
                zone_o      = `RV_ZONE_LOADQ;
                regd_tgt_o  = 1'b1;
                regs1_rd_o  = 1'b1;
                aluop_o     = `RV_ALUOP_ADD;
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
                ins_type    = C_IMM_TYPE_S;
                regs1_rd_o  = 1'b1;
                regs2_rd_o  = 1'b1;
                zone_o      = `RV_ZONE_STOREQ;
                aluop_o     = `RV_ALUOP_ADD;
                sels2_imm_o = 1'b1;
                if (funct3 != 3'b000 &&
                    funct3 != 3'b001 &&
                    funct3 != 3'b010) begin
                    ins_err_o = 1'b1;
                end
            end
            7'b0010011 : begin // op-imm
                ins_type    = C_IMM_TYPE_I;
                zone_o      = `RV_ZONE_REGFILE;
                regd_tgt_o  = 1'b1;
                regs1_rd_o  = 1'b1;
                sels2_imm_o = 1'b1;
                case (funct3)
                    `RV_MINOR_OPCODE_ADDSUB : begin
                        aluop_o = `RV_ALUOP_ADD;
                    end
                    `RV_MINOR_OPCODE_SLL : begin
                        aluop_o = `RV_ALUOP_SLL;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_SLT : begin
                        aluop_o        = `RV_ALUOP_SLT;
                        selcmps2_imm_o = 1'b1;
                    end
                    `RV_MINOR_OPCODE_SLTU : begin
                        aluop_o        = `RV_ALUOP_SLTU;
                        selcmps2_imm_o = 1'b1;
                    end
                    `RV_MINOR_OPCODE_XOR : begin
                        aluop_o = `RV_ALUOP_XOR;
                    end
                    `RV_MINOR_OPCODE_SRLSRA : begin
                        if (funct7 == 7'b0000000) begin
                            aluop_o = `RV_ALUOP_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            aluop_o = `RV_ALUOP_SRA;
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_OR : begin
                        aluop_o = `RV_ALUOP_OR;
                    end
                    `RV_MINOR_OPCODE_AND : begin
                        aluop_o = `RV_ALUOP_AND;
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            7'b0110011 : begin // op
                ins_type   = C_IMM_TYPE_R;
                zone_o     = `RV_ZONE_REGFILE;
                regd_tgt_o = 1'b1;
                regs1_rd_o = 1'b1;
                regs2_rd_o = 1'b1;
                case (funct3)
                    `RV_MINOR_OPCODE_ADDSUB : begin
                        if (funct7 == 7'b0000000) begin
                            aluop_o = `RV_ALUOP_ADD;
                        end else if (funct7 == 7'b0100000) begin
                            aluop_o = `RV_ALUOP_SUB;
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_SLL : begin
                        aluop_o = `RV_ALUOP_SLL;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_SLT : begin
                        aluop_o = `RV_ALUOP_SLT;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_SLTU : begin
                        aluop_o = `RV_ALUOP_SLTU;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_XOR : begin
                        aluop_o = `RV_ALUOP_XOR;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_SRLSRA : begin
                        if (funct7 == 7'b0000000) begin
                            aluop_o = `RV_ALUOP_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            aluop_o = `RV_ALUOP_SRA;
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_OR : begin
                        aluop_o = `RV_ALUOP_OR;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    `RV_MINOR_OPCODE_AND : begin
                        aluop_o = `RV_ALUOP_AND;
                        if (funct7 != 7'b0000000) begin
                            ins_err_o = 1'b1;
                        end
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            7'b0001111 : begin // misc-mem
                ins_type = C_IMM_TYPE_MISC_MEM;
                // NOTE: any fence is treated as a fence.i
                if (funct3 == 3'b001) begin // fence.i
                    fencei_o = 1'b1;
                end
            end
            7'b1110011 : begin // system
                if (funct3 == `RV_MINOR_OPCODE_PRIV) begin
                    if (regd_addr == 5'b0) begin
                        if (funct7 == 7'b0001001) begin // TODO SFENCE.VMA
                            ins_err_o = 1'b1;
                        end else if (regs1_addr == 5'b0) begin
                            if (ins_i[31:20] == 12'h000) begin // ECALL
                                ecall_o = 1'b1;
                            end else if (ins_i[31:20] == 12'h001) begin // TODO EBREAK
                            end else if (ins_i[31:30] == 2'b0 && ins_i[27:20] == 8'h02) begin // TRAP RETURN
                                trap_rtn_o = 1'b1;
                            end else if (ins_i[31:20] == 12'h105) begin
                                wfi_o = 1'b1;
                            end else begin
                                ins_err_o = 1'b1;
                            end
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end else begin
                        ins_err_o = 1'b1;
                    end
                end else if (funct3 == 3'b001 ||
                             funct3 == 3'b010 ||
                             funct3 == 3'b011) begin // CSR access with rs1
                    zone_o     = `RV_ZONE_REGFILE;
                    regd_tgt_o = 1'b1;
                    regs1_rd_o = 1'b1;
                    if (regd_addr != 5'b0) begin
                        csr_rd_o = 1'b1;
                    end
                    if (regs1_addr != 5'b0) begin
                        csr_wr_o = 1'b1;
                    end
                end else if (funct3 == 3'b101 ||
                             funct3 == 3'b110 ||
                             funct3 == 3'b111) begin // CSR access with zimm
                    ins_type              = C_IMM_TYPE_I_ZIMM;
                    zone_o                = `RV_ZONE_REGFILE;
                    regd_tgt_o            = 1'b1;
                    sel_csr_wr_data_imm_o = 1'b1;
                    if (regd_addr != 5'b0) begin
                        csr_rd_o = 1'b1;
                    end
                    if (regs1_addr != 5'b0) begin
                        csr_wr_o = 1'b1;
                    end
                end else begin
                    ins_err_o = 1'b1;
                end
            end
            default : begin
                ins_err_o = 1'b1;
            end
        endcase
    end


    //--------------------------------------------------------------
    // immediate generation
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (ins_i[31]) begin
            sign_imm = { `RV_XLEN {1'b1} };
        end else begin
            sign_imm = { `RV_XLEN {1'b0} };
        end
        //
        case (ins_type)
            C_IMM_TYPE_I      : imm_o = { sign_imm[`RV_XLEN-1:11], ins_i[30:20] };
            C_IMM_TYPE_I_ZIMM : imm_o = {   { `RV_XLEN-5 {1'b0} }, ins_i[19:15] };
            C_IMM_TYPE_S      : imm_o = { sign_imm[`RV_XLEN-1:11], ins_i[30:25], ins_i[11:7] };
            C_IMM_TYPE_SB     : imm_o = { sign_imm[`RV_XLEN-1:12], ins_i[7],     ins_i[30:25], ins_i[11:8],  1'b0 };
            C_IMM_TYPE_U      : imm_o = { sign_imm[`RV_XLEN-1:31], ins_i[30:12], 12'b0 };
            C_IMM_TYPE_UJ     : imm_o = { sign_imm[`RV_XLEN-1:20], ins_i[19:12], ins_i[20],    ins_i[30:21], 1'b0 };
            default           : imm_o = { `RV_XLEN {1'b0} }; // NOTE don't care
        endcase
    end
endmodule
