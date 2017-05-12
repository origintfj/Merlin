module merlin32i
    #(
        parameter C_IRQV_SZ           = 32,
        parameter C_RESET_VECTOR      = 32'h0,
        parameter C_VENDOR_ID         = 32'h0,
        parameter C_ARCHITECTURE_ID   = 32'h0,
        parameter C_IMPLEMENTATION_ID = 32'h0,
        parameter C_HART_ID           = 32'h0
    )
    (
        // global
        input  logic                 clk_i,
        input  logic                 clk_en_i,
        input  logic                 resetb_i,
        // hardware interrupt interface
        input  logic [C_IRQV_SZ-1:0] irqv_i,
        // instruction port
        input  logic                 ireqready_i,
        output logic                 ireqvalid_o,
        output logic           [1:0] ireqhpl_o,
        output logic          [31:0] ireqaddr_o,
        output logic                 irspready_o,
        input  logic                 irspvalid_i,
        input  logic                 irsprerr_i,
        input  logic          [31:0] irspdata_i,
        // data port
        input  logic                 dreqready_i,
        output logic                 dreqvalid_o,
        output logic           [1:0] dreqhpl_o,
        output logic          [31:0] dreqaddr_o,
        output logic                 drspready_o,
        input  logic                 drspvalid_i,
        input  logic                 drsprerr_i,
        input  logic                 drspwerr_i,
        input  logic          [31:0] drspdata_i
        // debug interface
        // TODO - debug interface
    );

    //--------------------------------------------------------------

    // prefetch unit
    logic pfu_decoder_dav;
    // instruction decoder
    logic decoder_pfu_ack;

    //--------------------------------------------------------------

    assign dreqvalid_o = 1'b0;
    assign dreqhpl_o   = 2'b0;
    assign dreqaddr_o  = 32'b0;
    assign drspready_o = 1'b0;


    // prefetch unit
    //
    pfu
        #(
            .C_BUS_SZX      (5), // bus width base 2 exponent
            .C_FIFO_DEPTH_X (2), // pfu fifo depth base 2 exponent
            .C_RESET_VECTOR (32'h00000000)
        ) i_pfu (
            // global
            .clk_i           (clk_i),
            .clk_en_i        (clk_en_i),
            .resetb_i        (resetb_i),
            // instruction cache interface
            .ireqready_i     (ireqready_i),
            .ireqvalid_o     (ireqvalid_o),
            .ireqhpl_o       (ireqhpl_o), // HART priv. level
            .ireqaddr_o      (ireqaddr_o),
            .irspready_o     (irspready_o),
            .irspvalid_i     (irspvalid_i),
            .irsprerr_i      (irsprerr_i),
            .irspdata_i      (irspdata_i),
            // vectoring and exception controller interface
            // TODO
            .vic_pc_ready_o  (),
            .vic_pc_wr_i     (1'b0),
            .vic_pc_din_i    (32'b0),
            .vic_link_addr_o (),
            // decoder interface
            .decoder_dav_o   (pfu_decoder_dav),   // new fetch available
            .decoder_ack_i   (decoder_pfu_ack),   // ack this fetch
            .decoder_sofr_o  (),   // first fetch since vectoring
            .decoder_ins_o   (),   // instruction fetched
            .decoder_ferr_o  (),   // this instruction fetch resulted in error
            .decoder_pc_o    ()    // address of this instruction
        );

        always @ (posedge clk_i)
        begin
            if ($random() % 4 != 0) begin
                decoder_pfu_ack <= pfu_decoder_dav;
            end else begin
                decoder_pfu_ack <= 1'b0;
            end
        end
endmodule

