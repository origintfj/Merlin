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
        input  wire               rd_i,
        input  wire        [11:0] rd_addr_i,
        output wire  [C_XLEN-1:0] rd_data_o,
        input  wire               wr_i, // the write will be ignored if it triggers an exception
        input  wire        [11:0] wr_addr_i,
        input  wire  [C_XLEN-1:0] wr_data_i,
        // static i/o
        output wire               illegal_rd_o,
        output wire               illegal_wr_o,
        output wire         [1:0] hpl_o
    );

    assign rd_data_o = { C_XLEN {1'b0} };
    assign illegal_rd_o = 1'b0;
    assign illegal_wr_o = 1'b0;
    assign hpl_o = 2'b0;
endmodule
