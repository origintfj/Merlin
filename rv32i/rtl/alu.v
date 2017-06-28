// TODO - investigate using func7 and func3 instead of aluop

`include "riscv_defs.v"

module alu
    #(
        parameter C_XLEN_X = 5,
        // derived parameters
        parameter C_XLEN   = 2**C_XLEN_X
    )
    (
        //
        input  wire                clk_i,
        input  wire                clk_en_i,
        input  wire                resetb_i,
        //
        input  wire   [C_XLEN-1:0] op_left_i,
        input  wire   [C_XLEN-1:0] op_right_i,
        output reg    [C_XLEN-1:0] op_result_o,
        input  wire [`ALUOP_RANGE] op_opcode_i,
        //
        input  wire   [C_XLEN-1:0] cmp_left_i,
        input  wire   [C_XLEN-1:0] cmp_right_i,
        output reg                 cmp_result_o,
        input  wire          [2:0] cmp_opcode_i
    );

    //--------------------------------------------------------------

    // alu output register
    // operation result mux
    reg  [C_XLEN-1:0] op_result_mux_out;
    // shifter
    genvar genvar_i;
    reg  [C_XLEN-1:0] shift_left_array[0:C_XLEN_X];
    reg  [C_XLEN-1:0] shift_right_array[0:C_XLEN_X];

    //--------------------------------------------------------------


    // alu output register
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            op_result_o <= op_result_mux_out;
        end
    end


    // operation result mux
    //
    always @ (*)
    begin
        op_result_mux_out = { C_XLEN {1'b0} }; // NOTE: don't actually care
        case (op_opcode_i)
            `ALUOP_ADD  : op_result_mux_out = op_left_i + op_right_i;
            `ALUOP_SUB  : op_result_mux_out = op_left_i - op_right_i;
            `ALUOP_SLL  : op_result_mux_out = shift_left_array[C_XLEN_X];
            `ALUOP_SLT  : op_result_mux_out = { C_XLEN {1'b0} }; // TODO
            `ALUOP_SLTU : op_result_mux_out = { C_XLEN {1'b0} }; // TODO
            `ALUOP_XOR  : op_result_mux_out = op_left_i ^ op_right_i;
            `ALUOP_SRL  : op_result_mux_out = shift_right_array[C_XLEN_X];
            `ALUOP_SRA  : op_result_mux_out = shift_right_array[C_XLEN_X];
            `ALUOP_OR   : op_result_mux_out = op_left_i | op_right_i;
            `ALUOP_AND  : op_result_mux_out = op_left_i & op_right_i;
            `ALUOP_MOV  : op_result_mux_out = op_right_i;
            default : begin
            end
        endcase
    end


    // shifter
    //
    generate
    for (genvar_i = 0; genvar_i < C_XLEN_X; genvar_i = genvar_i + 1) begin : shifter
        always @ (*)
        begin
            shift_left_array[0]  = op_left_i;
            shift_right_array[0] = op_left_i;
            //
            if (op_right_i[genvar_i] == 1'b1) begin
                // left shift
                shift_left_array[genvar_i + 1][2**genvar_i - 1:   0] = { 2**genvar_i {1'b0} };
                shift_left_array[genvar_i + 1][C_XLEN - 1:2**genvar_i] = shift_left_array[genvar_i][C_XLEN - 1 - 2**genvar_i:0];
                // right shift
                if (op_opcode_i == `ALUOP_SRA && op_left_i[C_XLEN-1] == 1'b1) begin
                    shift_right_array[genvar_i + 1][C_XLEN - 1:C_XLEN - 2**genvar_i] = { 2**genvar_i {1'b1} };
                end else begin
                    shift_right_array[genvar_i + 1][C_XLEN - 1:C_XLEN - 2**genvar_i] = { 2**genvar_i {1'b0} };
                end
                shift_right_array[genvar_i + 1][C_XLEN - 1 - 2**genvar_i:0] = shift_right_array[genvar_i][C_XLEN - 1:2**genvar_i];
            end else begin
                // left shift
                shift_left_array[genvar_i + 1] = shift_left_array[genvar_i];
                // right shift
                shift_right_array[genvar_i + 1] = shift_right_array[genvar_i];
            end
        end
    end
    endgenerate


    // alu comparitor
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            cmp_result_o <= 1'b0;
            case (cmp_opcode_i)
                `ALUCOND_EQ  : begin
                    if (cmp_left_i == cmp_right_i) begin
                        cmp_result_o <= 1'b1;
                    end
                end
                `ALUCOND_NE  : begin
                    if (cmp_left_i != cmp_right_i) begin
                        cmp_result_o <= 1'b1;
                    end
                end
                `ALUCOND_LT  : begin // TODO
                end
                `ALUCOND_GE  : begin // TODO
                end
                `ALUCOND_LTU : begin // TODO
                end
                `ALUCOND_GEU : begin // TODO
                end
                default : begin
                end
            endcase
        end
    end
endmodule

