/*
 * Author         : Tom Stanway-Mayers
 * Description    : RV32I Compressed Instruction Expander
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module rv32ic_expander
    (
        input  wire [15:0] ins_i,
        output reg         ins_rvc_o,
        output reg         ins_err_o,
        output reg  [31:0] ins_o
    );

    //--------------------------------------------------------------

    // rv32ic expander
    wire [1:0] op;
    wire [2:0] funct3;

    //--------------------------------------------------------------


    // rv32ic expander
    //
    assign op     = ins_i[1:0];
    assign funct3 = ins_i[15:13];
    //
    always @ (*)
    begin
        ins_rvc_o = 1'b1;
        ins_err_o = 1'b0;
        //
        ins_o     = 32'b0; // NOTE: don't care
        //
        case (op)
            2'b00 : begin
                case (funct3)
                    3'b000 : begin // c.add14spn / c.illegal
                        if (ins_i[12:2] == 11'b0) begin // c.illegal
                            ins_err_o = 1'b1;
                        end else if (ins_i[12:5] != 8'b0) begin // c.add14spn
                            ins_o = { 2'b0, ins_i[10:7], ins_i[12:11], ins_i[5], ins_i[6], 2'b0, 5'd2, 3'b000, 2'b01, ins_i[4:2], 7'b0010011 };
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b010 : begin // c.lw
                        ins_o = { 5'b0, ins_i[5], ins_i[12:10], ins_i[6], 2'b0, 2'b01, ins_i[9:7], 3'b010, 2'b01, ins_i[4:2], 7'b0000011 };
                    end
                    3'b110 : begin // c.sw
                        ins_o = { 5'b0, ins_i[5], ins_i[12], 2'b01, ins_i[4:2], 2'b01, ins_i[9:7], 3'b010, ins_i[11:10], ins_i[6], 2'b0, 7'b0100011 };
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            2'b01 : begin
                case (funct3)
                    3'b000 : begin // c.addi / c.nop
                        if (ins_i[12:2] == 11'b0) begin // c.nop
                            ins_o = { 25'b0, 7'b0010011 }; // nop
                        end else if (!(ins_i[12] == 1'b0 && ins_i[6:2] == 5'b0) ) begin // c.addi
                            ins_o = { { 7 {ins_i[12]} }, ins_i[6:2], ins_i[11:7], 3'b000, ins_i[11:7], 7'b0010011 };
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b001 : begin // c.jal
                        ins_o = { ins_i[12], ins_i[8], ins_i[10:9], ins_i[6], ins_i[7], ins_i[2], ins_i[11], ins_i[5:3], ins_i[12], { 8 {ins_i[12]} }, 5'd1, 7'b1101111 };
                    end
                    3'b010 : begin // c.li
                        if (ins_i[11:7] != 5'd0) begin
                            ins_o = { { 7 {ins_i[12]} }, ins_i[6:2], 5'd0, 3'b000, ins_i[11:7], 7'b0010011 };
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b011 : begin // c.[lui/addi16sp]
                        if (!(ins_i[12] == 1'b0 && ins_i[6:2] == 5'b0)) begin
                            if (ins_i[11:7] != 5'd0) begin
                                if (ins_i[11:7] == 5'd2) begin // c.addi16sp
                                    ins_o = { { 3 {ins_i[12]} }, ins_i[4], ins_i[3], ins_i[5], ins_i[2], ins_i[6], 4'b0, 5'd2, 3'b000, 5'd2, 7'b0010011 };
                                end else begin // lui
                                    ins_o = { { 15 {ins_i[12]} }, ins_i[6:2], ins_i[11:7], 7'b0110111 };
                                end
                            end else begin
                                ins_err_o = 1'b1;
                            end
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b100 : begin // c.sr[l/a]i
                        if (ins_i[12:10] == 3'b011) begin // c.sub / c.xor / c.or / c.and
                            if (ins_i[6:5] == 2'b00) begin // c.sub
                                ins_o = { 7'b0100000, 2'b01, ins_i[4:2], 2'b01, ins_i[9:7], 3'b000, 2'b01, ins_i[9:7], 7'b0110011 };
                            end else if (ins_i[6:5] == 2'b01) begin // c.xor
                                ins_o = { 7'b0000000, 2'b01, ins_i[4:2], 2'b01, ins_i[9:7], 3'b100, 2'b01, ins_i[9:7], 7'b0110011 };
                            end else if (ins_i[6:5] == 2'b10) begin // c.or
                                ins_o = { 7'b0000000, 2'b01, ins_i[4:2], 2'b01, ins_i[9:7], 3'b110, 2'b01, ins_i[9:7], 7'b0110011 };
                            end else begin // c.and
                                ins_o = { 7'b0000000, 2'b01, ins_i[4:2], 2'b01, ins_i[9:7], 3'b111, 2'b01, ins_i[9:7], 7'b0110011 };
                            end
                        end else begin
                            if (ins_i[11:10] == 2'b10) begin // c.andi
                                    ins_o = { { 7 {ins_i[12]} }, ins_i[6:2], 2'b01, ins_i[9:7], 3'b111, 2'b01, ins_i[9:7], 7'b0010011 };
                            end else begin
                                if (ins_i[12] == 1'b0 && ins_i[6:2] == 5'b0) begin
                                    ins_err_o = 1'b1;
                                end else begin
                                    if (ins_i[11:10] == 2'b00) begin // c.srli
                                        ins_o = { 7'b0000000, ins_i[6:2], 2'b01, ins_i[9:7], 3'b101, 2'b01, ins_i[9:7], 7'b0010011 };
                                    end else if (ins_i[11:10] == 2'b01) begin // c.srai
                                        ins_o = { 7'b0100000, ins_i[6:2], 2'b01, ins_i[9:7], 3'b101, 2'b01, ins_i[9:7], 7'b0010011 };
                                    end else begin
                                        ins_err_o = 1'b1;
                                    end
                                end
                            end
                        end
                    end
                    3'b101 : begin // c.j
                        ins_o = { ins_i[12], ins_i[8], ins_i[10:9], ins_i[6], ins_i[7], ins_i[2], ins_i[11], ins_i[5:3], ins_i[12], { 8 {ins_i[12]} }, 5'd0, 7'b1101111 };
                    end
                    3'b110 : begin // c.beqz
                        ins_o = { { 4 {ins_i[12]} }, ins_i[6], ins_i[5], ins_i[2], 5'd0, 2'b01, ins_i[9:7], 3'b000, ins_i[11], ins_i[10], ins_i[4], ins_i[3], ins_i[12], 7'b1100011 };
                    end
                    3'b111 : begin // c.bnez
                        ins_o = { { 4 {ins_i[12]} }, ins_i[6], ins_i[5], ins_i[2], 5'd0, 2'b01, ins_i[9:7], 3'b001, ins_i[11], ins_i[10], ins_i[4], ins_i[3], ins_i[12], 7'b1100011 };
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            2'b10 : begin
                case (funct3)
                    3'b000 : begin // c.slli
                        if (ins_i[12] == 1'b0 && ins_i[6:2] != 5'b0 && ins_i[11:7] != 5'b0) begin
                            ins_o = { 7'b0, ins_i[6:2], ins_i[11:7], 3'b001, ins_i[11:7], 7'b0010011 };
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b010 : begin // c.lwsp
                        if (ins_i[11:7] != 5'b0) begin
                            ins_o = { 4'b0, ins_i[3:2], ins_i[12], ins_i[6:4], 2'b0, 5'd2, 3'b010, ins_i[11:7], 7'b0000011 };
                        end else begin
                            ins_err_o = 1'b1;
                        end
                    end
                    3'b110 : begin // c.swsp
                        ins_o = { 4'b0, ins_i[8:7], ins_i[12], ins_i[6:2], 5'd2, 3'b010, ins_i[11:9], 2'b0, 7'b0100011 };
                    end
                    3'b100 : begin // c.j[al]r
                        if (ins_i[6:2] == 5'd0) begin // c.j[al]r / c.ebreak
                            if (ins_i[11:7] == 5'd0) begin
                                if (ins_i[12] == 1'b1) begin // c.ebreak
                                    ins_o = { 11'b0, 1'b1, 13'b0, 7'b1110011 };
                                end else begin
                                    ins_err_o = 1'b1;
                                end
                            end else begin // c.j[al]r
                                if (ins_i[12] == 1'b0) begin // c.jr
                                    ins_o = { 12'b0, ins_i[11:7], 3'b000, 5'd0, 7'b1100111 };
                                end else begin // c.jalr
                                    ins_o = { 12'b0, ins_i[11:7], 3'b000, 5'd1, 7'b1100111 };
                                end
                            end
                        end else begin // c.add / c.mv
                            if (ins_i[11:7] != 5'd0) begin // c.add / c.mv
                                if (ins_i[12] == 1'b0) begin // c.mv
                                    ins_o = { 7'b0, ins_i[6:2], 5'd0, 3'b000, ins_i[11:7], 7'b0110011 };
                                end else begin // c.add
                                    ins_o = { 7'b0, ins_i[6:2], ins_i[11:7], 3'b000, ins_i[11:7], 7'b0110011 };
                                end
                            end else begin
                                ins_err_o = 1'b1;
                            end
                        end
                    end
                    default : begin
                        ins_err_o = 1'b1;
                    end
                endcase
            end
            default : begin
                ins_rvc_o = 1'b0;
            end
        endcase
    end
endmodule

