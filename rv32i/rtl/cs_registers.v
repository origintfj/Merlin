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
        output wire  [C_XLEN-1:0] data_o
        // static i/o
    );

    assign data_o = '0;
endmodule
