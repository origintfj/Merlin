/*
 * Author         : Tom Stanway-Mayers
 * Description    : Integer Register File
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module merlin_int_regs
    (
        // global
        input  wire                clk_i,
        input  wire                reset_i,
        // write port
        input  wire                wreg_a_wr_i,
        input  wire          [4:0] wreg_a_addr_i,
        input  wire [`RV_XLEN-1:0] wreg_a_data_i,
        input  wire                wreg_b_wr_i,
        input  wire          [4:0] wreg_b_addr_i,
        input  wire [`RV_XLEN-1:0] wreg_b_data_i,
        // read port
        input  wire                rreg_a_rd_i,
        input  wire          [4:0] rreg_a_addr_i,
        output reg  [`RV_XLEN-1:0] rreg_a_data_o,
        input  wire                rreg_b_rd_i,
        input  wire          [4:0] rreg_b_addr_i,
        output reg  [`RV_XLEN-1:0] rreg_b_data_o
    );

    //--------------------------------------------------------------

    reg [`RV_XLEN-1:0] mem[1:31];

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // write
    //--------------------------------------------------------------
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        // write port a
        if (wreg_a_wr_i) begin
            mem[wreg_a_addr_i] <= wreg_a_data_i;
        end
        // write port b
        if (wreg_b_wr_i) begin
            mem[wreg_b_addr_i] <= wreg_b_data_i;
        end
    end


    //--------------------------------------------------------------
    // read
    //--------------------------------------------------------------
    always @ (*) begin
        // read port a
        if (rreg_a_rd_i && rreg_a_addr_i != 5'b0) begin
            rreg_a_data_o = mem[rreg_a_addr_i];
        end else begin
            rreg_a_data_o = { `RV_XLEN {1'b0} };
        end
        // read port b
        if (rreg_b_rd_i && rreg_b_addr_i != 5'b0) begin
            rreg_b_data_o = mem[rreg_b_addr_i];
        end else begin
            rreg_b_data_o = { `RV_XLEN {1'b0} };
        end
    end
endmodule

