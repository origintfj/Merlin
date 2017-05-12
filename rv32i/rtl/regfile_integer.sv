module regfile_integer
    #(
        parameter C_XLEN = 32
    )
    (
        // global
        input  logic              clk_i,
        input  logic              clk_en_i,
        input  logic              resetb_i,
        // write port
        input  logic              wreg_a_wr_i,
        input  logic        [4:0] wreg_a_addr_i,
        input  logic [C_XLEN-1:0] wreg_a_data_i,
        input  logic              wreg_b_wr_i,
        input  logic        [4:0] wreg_b_addr_i,
        input  logic [C_XLEN-1:0] wreg_b_data_i,
        // read port
        input  logic              rreg_a_rd_i,
        input  logic        [4:0] rreg_a_addr_i,
        output logic [C_XLEN-1:0] rreg_a_data_o,
        input  logic              rreg_b_rd_i,
        input  logic        [4:0] rreg_b_addr_i,
        output logic [C_XLEN-1:0] rreg_b_data_o
    );

    //--------------------------------------------------------------

    logic [C_XLEN-1:0] mem[0:31];

    //--------------------------------------------------------------

    // read/write logic
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            // read port a
            if (rreg_a_rd_i) begin
                if (rreg_a_addr_i == 0) begin
                    rreg_a_data_o <= { C_XLEN {1'b0} };
                end else begin
                    rreg_a_data_o <= mem[rreg_a_addr_i];
                end
            end
            // read port b
            if (rreg_b_rd_i) begin
                if (rreg_b_addr_i == 0) begin
                    rreg_b_data_o <= { C_XLEN {1'b0} };
                end else begin
                    rreg_b_data_o <= mem[rreg_b_addr_i];
                end
            end
            // write port a
            if (wreg_a_wr_i) begin
                mem[wreg_a_addr_i] <= wreg_a_data_i;
            end
            // write port b
            if (wreg_b_wr_i) begin
                mem[wreg_b_addr_i] <= wreg_b_data_i;
            end
        end
    end
endmodule

