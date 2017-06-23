module cs_registers // TODO
    #(
        parameter C_XLEN = 32
    )
    (
        //
        input  wire               clk_i,
        input  wire               clk_en_i,
        input  wire               resetb_i,
        // read/write interface
        input  wire               access_i,
        input  wire        [11:0] addr_i,
        input  wire  [C_XLEN-1:0] data_i,
        output wire  [C_XLEN-1:0] data_o,
        // static i/o
        output wire               illegal_access_o,
        output wire         [1:0] hpl_o
    );

    assign data_o = '0;
    assign illegal_access_o = 1'b0;
    assign hpl_o = '0;
endmodule
