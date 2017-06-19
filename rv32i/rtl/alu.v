module alu
    #(
        parameter C_XLEN = 32
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
        op_result_mux_out = '0; // NOTE: don't actually care
        case (op_opcode_i)
            `ALUOP_ADD  : op_result_mux_out = op_left_i + op_right_i;
            `ALUOP_SUB  : op_result_mux_out = op_left_i - op_right_i;
            `ALUOP_SLL  : op_result_mux_out = '0; // TODO
            `ALUOP_SLT  : op_result_mux_out = '0; // TODO
            `ALUOP_SLTU : op_result_mux_out = '0; // TODO
            `ALUOP_XOR  : op_result_mux_out = op_left_i ^ op_right_i;
            `ALUOP_SRL  : op_result_mux_out = '0; // TODO
            `ALUOP_SRA  : op_result_mux_out = '0; // TODO
            `ALUOP_OR   : op_result_mux_out = op_left_i | op_right_i;
            `ALUOP_AND  : op_result_mux_out = op_left_i & op_right_i;
            `ALUOP_MOV  : op_result_mux_out = op_right_i;
        endcase
    end


    // alu comparitor
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            cmp_result_o <= 1'b0;
            case (op_opcode_i)
                `ALUCOND_EQ  : begin
                    if (op_left_i == op_right_i) begin
                        cmp_result_o = 1'b1;
                    end
                end
                `ALUCOND_NE  : begin
                    if (op_left_i != op_right_i) begin
                        cmp_result_o = 1'b1;
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
            endcase
        end
    end
endmodule
