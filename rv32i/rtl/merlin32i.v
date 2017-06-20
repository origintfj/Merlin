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
        input  wire                  clk_i,
        input  wire                  clk_en_i,
        input  wire                  resetb_i,
        // hardware interrupt interface
        input  wire  [C_IRQV_SZ-1:0] irqv_i, // TODO
        // instruction port
        input  wire                  ireqready_i,
        output wire                  ireqvalid_o,
        output wire            [1:0] ireqhpl_o,
        output wire           [31:0] ireqaddr_o,
        output wire                  irspready_o,
        input  wire                  irspvalid_i,
        input  wire                  irsprerr_i,
        input  wire           [31:0] irspdata_i,
        // data port
        input  wire                  dreqready_i, // TODO
        output wire                  dreqvalid_o, // TODO
        output wire            [1:0] dreqhpl_o, // TODO
        output wire           [31:0] dreqaddr_o, // TODO
        output wire                  drspready_o, // TODO
        input  wire                  drspvalid_i, // TODO
        input  wire                  drsprerr_i, // TODO
        input  wire                  drspwerr_i, // TODO
        input  wire           [31:0] drspdata_i // TODO
        // debug interface
        // TODO - debug interface
    );

    //--------------------------------------------------------------

    parameter C_XLEN = 32;

    // prefetch unit
    wire                pfu_ids_dav;
    wire                pfu_ids_sofr;
    wire   [C_XLEN-1:0] pfu_ids_ins;
    wire                pfu_ids_ferr;
    wire   [C_XLEN-1:0] pfu_ids_pc;
    // instruction decoder stage
    wire                ids_pfu_ack;
    wire                ids_exs_dav;
    wire                ids_exs_sofr;
    wire                ids_exs_ins_uerr;
    wire                ids_exs_ins_ferr;
    wire                ids_exs_cond;
    wire  [`ZONE_RANGE] ids_exs_zone;
    wire                ids_exs_link;
    wire   [C_XLEN-1:0] ids_exs_pc;
    wire [`ALUOP_RANGE] ids_exs_alu_op;
    wire   [C_XLEN-1:0] ids_exs_operand_left;
    wire   [C_XLEN-1:0] ids_exs_operand_right;
    wire   [C_XLEN-1:0] ids_exs_regs1_data;
    wire   [C_XLEN-1:0] ids_exs_regs2_data;
    wire          [4:0] ids_exs_regd_addr;
    wire          [2:0] ids_exs_funct3;
    wire                ids_exs_csr_access;
    wire         [11:0] ids_exs_csr_addr;
    wire   [C_XLEN-1:0] ids_exs_csr_wr_data;
        // write-back interface
    wire                exs_ids_regd_wr;
    wire          [4:0] exs_ids_regd_addr;
    wire   [C_XLEN-1:0] exs_ids_regd_data;
    // execution stage
    wire                exs_ids_ack;

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
            .vic_pc_ready_o  (), // TODO
            .vic_pc_wr_i     (1'b0), // TODO
            .vic_pc_din_i    (32'b0), // TODO
            .vic_link_addr_o (), // TODO
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
            .ids_dav_o           (ids_exs_dav),
            .ids_ack_i           (exs_ids_ack),
            .ids_sofr_o          (ids_exs_sofr),
            .ids_ins_uerr_o      (ids_exs_ins_uerr),
            .ids_ins_ferr_o      (ids_exs_ins_ferr),
            .ids_cond_o          (ids_exs_cond),
            .ids_zone_o          (ids_exs_zone),
            .ids_link_o          (ids_exs_link),
            .ids_pc_o            (ids_exs_pc),
            .ids_alu_op_o        (ids_exs_alu_op),
            .ids_operand_left_o  (ids_exs_operand_left),
            .ids_operand_right_o (ids_exs_operand_right),
            .ids_regs1_data_o    (ids_exs_regs1_data),
            .ids_regs2_data_o    (ids_exs_regs2_data),
            .ids_regd_addr_o     (ids_exs_regd_addr),
            .ids_funct3_o        (ids_exs_funct3),
            .ids_csr_access_o    (ids_exs_csr_access),
            .ids_csr_addr_o      (ids_exs_csr_addr),
            .ids_csr_wr_data_o   (ids_exs_csr_wr_data),
                // write-back interface
            .ids_regd_wr_i       (exs_ids_regd_wr),
            .ids_regd_addr_i     (exs_ids_regd_addr),
            .ids_regd_data_i     (exs_ids_regd_data),
            // load/store queue interface
            .lsq_reg_wr_i        (1'b0), // TODO
            .lsq_reg_addr_i      (5'b0), // TODO
            .lsq_reg_data_i      (32'b0) // TODO
        );


    // execution stage
    //
    ex_stage
        #(
            .C_XLEN              (C_XLEN)
        ) i_ex_stage (
            // global
            .clk_i               (clk_i),
            .clk_en_i            (clk_en_i),
            .resetb_i            (resetb_i),
            // instruction decoder stage interface
            .ids_dav_i           (ids_exs_dav),
            .ids_ack_o           (exs_ids_ack),
            .ids_sofr_i          (ids_exs_sofr),
            .ids_ins_uerr_i      (ids_exs_ins_uerr),
            .ids_ins_ferr_i      (ids_exs_ins_ferr),
            .ids_cond_i          (ids_exs_cond),
            .ids_zone_i          (ids_exs_zone),
            .ids_link_i          (ids_exs_link),
            .ids_pc_i            (ids_exs_pc),
            .ids_alu_op_i        (ids_exs_alu_op),
            .ids_operand_left_i  (ids_exs_operand_left),
            .ids_operand_right_i (ids_exs_operand_right),
            .ids_regs1_data_i    (ids_exs_regs1_data),
            .ids_regs2_data_i    (ids_exs_regs2_data),
            .ids_regd_addr_i     (ids_exs_regd_addr),
            .ids_funct3_i        (ids_exs_funct3),
            .ids_csr_access_i    (ids_exs_csr_access),
            .ids_csr_addr_i      (ids_exs_csr_addr),
            .ids_csr_wr_data_i   (ids_exs_csr_wr_data),
                // write-back interface
            .ids_regd_wr_o       (exs_ids_regd_wr),
            .ids_regd_addr_o     (exs_ids_regd_addr),
            .ids_regd_data_o     (exs_ids_regd_data),
            // hart vectoring and exception controller interface TODO
            .hvec_vec_strobe_o   (), // TODO
            .hvec_vec_o          (), // TODO
            .hvec_pc_o           (), // TODO
            // load/store queue interface
            .lsq_lq_full_i       (1'b0), // TODO
            .lsq_lq_wr_o         (), // TODO
            .lsq_sq_wr_o         (), // TODO
            .lsq_funct3_o        (), // TODO
            .lsq_regd_addr_o     (), // TODO
            .lsq_regs2_data_o    (), // TODO
            .lsq_addr_o          () // TODO
        );
endmodule

