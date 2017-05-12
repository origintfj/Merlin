module id_stage
    (
        // global
        input  logic                clk_i,
        input  logic                clk_en_i,
        input  logic                resetb_i,
        // pfu interface
        output logic                pfu_dav_i,   // new fetch available
        input  logic                pfu_pull_o,  // ack this fetch
        output logic                pfu_sofr_i,  // first fetch since vectoring
        output logic         [31:0] pfu_ins_i,   // instruction fetched
        output logic                pfu_ferr_i,  // this instruction fetch resulted in error
        output logic         [31:0] pfu_pc_i,    // address of this instruction
    );

    //--------------------------------------------------------------


    //--------------------------------------------------------------

    regfile_integer
        #(
            .C_XLEN        (C_XLEN)
        ) i_regfile_integer (
            // global
            .clk_i         (clk_i),
            .clk_en_i      (clk_en_i),
            .resetb_i      (resetb_i),
            // write port
            .wreg_a_wr_i   (),
            .wreg_a_addr_i (),
            .wreg_a_data_i (),
            .wreg_b_wr_i   (),
            .wreg_b_addr_i (),
            .wreg_b_data_i (),
            // read port
            .rreg_a_rd_i   (),
            .rreg_a_addr_i (),
            .rreg_a_data_o (),
            .rreg_b_rd_i   (),
            .rreg_b_addr_i (),
            .rreg_b_data_o ()
        );
endmodule
