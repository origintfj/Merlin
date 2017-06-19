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

    parameter C_XLEN = 32;

    // prefetch unit
    wire              pfu_ids_dav;
    wire              pfu_ids_sofr;
    wire [C_XLEN-1:0] pfu_ids_ins;
    wire              pfu_ids_ferr;
    wire [C_XLEN-1:0] pfu_ids_pc;
    // instruction decoder
    wire              ids_pfu_ack;

    // TODO
    wire              ids_exs_dav;
    reg               exs_ids_ack;

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
            .decoder_dav_o   (pfu_ids_dav),  // new fetch available
            .decoder_ack_i   (ids_pfu_ack),  // ack this fetch
            .decoder_sofr_o  (pfu_ids_sofr), // first fetch since vectoring
            .decoder_ins_o   (pfu_ids_ins),  // instruction fetched
            .decoder_ferr_o  (pfu_ids_ferr), // this instruction fetch resulted in error
            .decoder_pc_o    (pfu_ids_pc)    // address of this instruction
        );


    // instruction decoder stage
    //
    id_stage
        #(
            .C_XLEN              (C_XLEN)
        ) i_id_stage (
            // global
            .clk_i               (clk_i),
            .clk_en_i            (clk_en_i),
            .resetb_i            (resetb_i),
            // pfu interface
            .pfu_dav_i           (pfu_ids_dav),   // new fetch available
            .pfu_ack_o           (ids_pfu_ack),   // ack this fetch
            .pfu_sofr_i          (pfu_ids_sofr),  // first fetch since vectoring
            .pfu_ins_i           (pfu_ids_ins),   // instruction fetched
            .pfu_ferr_i          (pfu_ids_ferr),  // this instruction fetch resulted in error
            .pfu_pc_i            (pfu_ids_pc),    // address of this instruction
            // ex stage interface
            .ids_dav_o           (ids_exs_dav), // TODO
            .ids_ack_i           (exs_ids_ack), // TODO
            .ids_sofr_o          (),
            .ids_ins_uerr_o      (),
            .ids_ins_ferr_o      (),
            .ids_cond_o          (),
            .ids_zone_o          (),
            .ids_link_o          (),
            .ids_pc_o            (),
            .ids_alu_op_o        (),
            .ids_operand_left_o  (),
            .ids_operand_right_o (),
            .ids_regs1_data_o    (),
            .ids_regs2_data_o    (),
            .ids_regd_addr_o     (),
            .ids_funct3_o        (),
            .ids_csr_access_o    (),
            .ids_csr_addr_o      (),
            .ids_csr_wr_data_o   (),
                // write-back interface
            .ids_regd_wr_i       (1'b0),
            .ids_regd_addr_i     (5'b0),
            .ids_regd_data_i     (32'b0),
            // load/store queue interface
            .lsq_reg_wr_i        (1'b0),
            .lsq_reg_addr_i      (5'b0),
            .lsq_reg_data_i      (32'b0)
        );


        //
        //
        always @ (posedge clk_i)
        begin
            if ($random() % 4 != 0) begin
                exs_ids_ack <= ids_exs_dav;
            end else begin
                exs_ids_ack <= 1'b0;
            end
        end
endmodule

