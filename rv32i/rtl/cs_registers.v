module cs_registers // TODO
    #(
        parameter C_XLEN = 32
    )
    (
        //
        input  wire               clk_i,
        input  wire               clk_en_i,
        input  wire               resetb_i,
        // read and exception query interface
        input  wire               rd_i,
        input  wire        [11:0] rd_addr_i,
        output reg   [C_XLEN-1:0] rd_data_o,
        output reg                rd_illegal_rd_o,
        output reg                rd_illegal_wr_o,
        // write-back interface
        input  wire               wr_i, // the write will be ignored if it triggers an exception
        input  wire        [11:0] wr_addr_i,
        input  wire  [C_XLEN-1:0] wr_data_i,
        // static i/o
        output wire         [1:0] hpl_o
    );

    //--------------------------------------------------------------

    wire                wren;
    // read decode and o/p register
    reg    [C_XLEN-1:0] rd_data;

    assign hpl_o = 2'b0;

    //--------------------------------------------------------------

    assign wren = wr_i;


    //
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            rd_illegal_rd_o <= 1'b0; // TODO registers which don't exist
            if (rd_addr_i[11:10] == 2'b11) begin // read-only
                rd_illegal_wr_o <= 1'b1; // TODO registers which don't exist
            end else begin
                rd_illegal_wr_o <= 1'b0;
            end
        end
    end


    // read decode and o/p register
    //
    always @ (*)
    begin
        rd_data = 32'bx;
        case (rd_addr_i)
            12'hf11 : rd_data = 32'b0;
            default : begin
            end
        endcase;
    end
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (rd_i) begin
                rd_data_o <= rd_data;
            end
        end
    end


    //
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
        end else if (clk_en_i) begin
            if (wren) begin
/*
                case (wr_addr_i)
                endcase;
*/
            end
        end
    end
endmodule
