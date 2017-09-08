/*
 * Author         : Tom Stanway-Mayers
 * Description    : ALU
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

// TODO - investigate using func7 and func3 instead of aluop

`include "riscv_defs.v"

module alu
    (
        //
        input  wire                   clk_i,
        input  wire                   clk_en_i,
        input  wire                   resetb_i,
        //
        input  wire    [`RV_XLEN-1:0] op_left_i,
        input  wire    [`RV_XLEN-1:0] op_right_i,
        output reg     [`RV_XLEN-1:0] op_result_o,
        input  wire [`RV_ALUOP_RANGE] op_opcode_i,
        //
        input  wire    [`RV_XLEN-1:0] cmp_left_i,
        input  wire    [`RV_XLEN-1:0] cmp_right_i,
        output reg                    cmp_result_o,
        input  wire             [2:0] cmp_opcode_i
    );

    //--------------------------------------------------------------

    // alu output register
    // operation result mux
    reg  [`RV_XLEN-1:0] op_result_mux_out;
    // shifter
    genvar              genvar_i;
    reg  [`RV_XLEN-1:0] shift_left_array[0:`RV_XLEN_X];
    reg  [`RV_XLEN-1:0] shift_right_array[0:`RV_XLEN_X];
    // alu comparitor
    reg                 cmp_lts;
    reg                 cmp_ltu;

    //--------------------------------------------------------------


    //--------------------------------------------------------------
    // alu output register
    //--------------------------------------------------------------
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            op_result_o <= op_result_mux_out;
        end
    end


    //--------------------------------------------------------------
    // operation result mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        op_result_mux_out = { `RV_XLEN {1'b0} }; // NOTE: don't actually care
        case (op_opcode_i)
            `RV_ALUOP_ADD  : op_result_mux_out = op_left_i + op_right_i;
            `RV_ALUOP_SUB  : op_result_mux_out = op_left_i - op_right_i;
            `RV_ALUOP_SLL  : op_result_mux_out = shift_left_array[`RV_XLEN_X];
            `RV_ALUOP_SLT  : op_result_mux_out = { { `RV_XLEN-1 {1'b0} }, cmp_lts };
            `RV_ALUOP_SLTU : op_result_mux_out = { { `RV_XLEN-1 {1'b0} }, cmp_ltu };
            `RV_ALUOP_XOR  : op_result_mux_out = op_left_i ^ op_right_i;
            `RV_ALUOP_SRL  : op_result_mux_out = shift_right_array[`RV_XLEN_X];
            `RV_ALUOP_SRA  : op_result_mux_out = shift_right_array[`RV_XLEN_X];
            `RV_ALUOP_OR   : op_result_mux_out = op_left_i | op_right_i;
            `RV_ALUOP_AND  : op_result_mux_out = op_left_i & op_right_i;
            `RV_ALUOP_MOV  : op_result_mux_out = op_right_i;
            default : begin
            end
        endcase
    end


    //--------------------------------------------------------------
    // shifter
    //--------------------------------------------------------------
    assign shift_left_array[0]  = op_left_i;
    assign shift_right_array[0] = op_left_i;
    //
    generate
    for (genvar_i = 0; genvar_i < `RV_XLEN_X; genvar_i = genvar_i + 1) begin : shifter
        always @ (*)
        begin
            if (op_right_i[genvar_i] == 1'b1) begin
                // left shift
                shift_left_array[genvar_i + 1][2**genvar_i - 1:   0] = { 2**genvar_i {1'b0} };
                shift_left_array[genvar_i + 1][`RV_XLEN - 1:2**genvar_i] = shift_left_array[genvar_i][`RV_XLEN - 1 - 2**genvar_i:0];
                // right shift
                if (op_opcode_i == `RV_ALUOP_SRA && op_left_i[`RV_XLEN-1] == 1'b1) begin
                    shift_right_array[genvar_i + 1][`RV_XLEN - 1:`RV_XLEN - 2**genvar_i] = { 2**genvar_i {1'b1} };
                end else begin
                    shift_right_array[genvar_i + 1][`RV_XLEN - 1:`RV_XLEN - 2**genvar_i] = { 2**genvar_i {1'b0} };
                end
                shift_right_array[genvar_i + 1][`RV_XLEN - 1 - 2**genvar_i:0] = shift_right_array[genvar_i][`RV_XLEN - 1:2**genvar_i];
            end else begin
                // left shift
                shift_left_array[genvar_i + 1] = shift_left_array[genvar_i];
                // right shift
                shift_right_array[genvar_i + 1] = shift_right_array[genvar_i];
            end
        end
    end
    endgenerate


    //--------------------------------------------------------------
    // alu comparitor
    //--------------------------------------------------------------
    always @ (*) // TODO consider using one compariter here and switching the MSBs to do signed vs. unsigned
    begin
        cmp_lts = $signed(cmp_left_i) < $signed(cmp_right_i);

        cmp_ltu = cmp_left_i < cmp_right_i;
    end
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            cmp_result_o <= 1'b0;
            case (cmp_opcode_i)
                `RV_ALUCOND_EQ  : begin
                    if (cmp_left_i == cmp_right_i) begin
                        cmp_result_o <= 1'b1;
                    end
                end
                `RV_ALUCOND_NE  : begin
                    if (cmp_left_i != cmp_right_i) begin
                        cmp_result_o <= 1'b1;
                    end
                end
                `RV_ALUCOND_LT  : begin
                    cmp_result_o <= cmp_lts;
                end
                `RV_ALUCOND_GE  : begin
                    cmp_result_o <= ~cmp_lts;
                end
                `RV_ALUCOND_LTU : begin
                    cmp_result_o <= cmp_ltu;
                end
                `RV_ALUCOND_GEU : begin
                    cmp_result_o <= ~cmp_ltu;
                end
                default : begin
                end
            endcase
        end
    end
endmodule

