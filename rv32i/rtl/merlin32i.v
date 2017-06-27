`include "riscv_defs.v"

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
        input  wire           [31:0] drspdata_i, // TODO
        // debug interface
        // TODO - debug interface
        input  wire                 lsq_exs_full,
        output wire                 exs_lsq_lq_wr,
        output wire                 exs_lsq_sq_wr,
        output wire           [2:0] exs_lsq_funct3,
        output wire           [4:0] exs_lsq_regd_addr,
        output wire    [C_XLEN-1:0] exs_lsq_regs2_data,
        output wire    [C_XLEN-1:0] exs_lsq_addr
    );

    //--------------------------------------------------------------

    parameter C_XLEN = 32;

    // hart vectoring and exception controller
    wire                hvec_pfu_pc_wr;
    wire   [C_XLEN-1:0] hvec_pfu_pc;
    // prefetch unit
    wire                pfu_hvec_ready;
    wire                pfu_ids_dav;
    wire [`SOFID_RANGE] pfu_ids_sofid;
    wire   [C_XLEN-1:0] pfu_ids_ins;
    wire                pfu_ids_ferr;
    wire   [C_XLEN-1:0] pfu_ids_pc;
    // instruction decoder stage
    wire                ids_pfu_ack;
    wire                ids_exs_valid;
    wire [`SOFID_RANGE] ids_exs_sofid;
    wire                ids_exs_ins_uerr;
    wire                ids_exs_ins_ferr;
    wire                ids_exs_jump;
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
    wire                ids_exs_csr_rd;
    wire                ids_exs_csr_wr;
    wire         [11:0] ids_exs_csr_addr;
    wire   [C_XLEN-1:0] ids_exs_csr_wr_data;
    // execution stage
    wire          [1:0] exs_pfu_hpl;
    wire                exs_ids_stall;
    wire                exs_ids_regd_cncl_load;
    wire                exs_ids_regd_wr;
    wire          [4:0] exs_ids_regd_addr;
    wire   [C_XLEN-1:0] exs_ids_regd_data;
    wire                exs_hvec_jump;
    wire   [C_XLEN-1:0] exs_hvec_jump_addr;

    //--------------------------------------------------------------

    assign dreqvalid_o = 1'b0;
    assign dreqhpl_o   = 2'b0;
    assign dreqaddr_o  = 32'b0;
    assign drspready_o = 1'b0;


    // hart vectoring and exception controller
    //
    hvec
        #(
            .C_XLEN          (C_XLEN)
        ) i_hvec (
            // global
            .clk_i           (clk_i),
            .clk_en_i        (clk_en_i),
            .resetb_i        (resetb_i),
            // external interrupt interface
            // pfu interface
            .pfu_pc_ready_i  (pfu_hvec_ready),
            .pfu_pc_wr_o     (hvec_pfu_pc_wr),
            .pfu_pc_o        (hvec_pfu_pc),
            // ex stage interface
            .exs_jump_i      (exs_hvec_jump),
            .exs_jump_addr_i (exs_hvec_jump_addr)
            // lsq interface
        );


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
            // decoder interface
            .ids_dav_o       (pfu_ids_dav),   // new fetch available
            .ids_ack_i       (ids_pfu_ack),   // ack this fetch
            .ids_sofid_o     (pfu_ids_sofid), // first fetch since vectoring
            .ids_ins_o       (pfu_ids_ins),   // instruction fetched
            .ids_ferr_o      (pfu_ids_ferr),  // this instruction fetch resulted in error
            .ids_pc_o        (pfu_ids_pc),    // address of this instruction
            // vectoring and exception controller interface
            .hvec_pc_ready_o (pfu_hvec_ready),
            .hvec_pc_wr_i    (hvec_pfu_pc_wr),
            .hvec_pc_din_i   (hvec_pfu_pc),
            // pfu stage interface
            .exs_hpl_i       (exs_pfu_hpl)
        );


    // instruction decoder stage
    //
    id_stage
        #(
            .C_XLEN               (C_XLEN)
        ) i_id_stage (
            // global
            .clk_i                (clk_i),
            .clk_en_i             (clk_en_i),
            .resetb_i             (resetb_i),
            // pfu interface
            .pfu_dav_i            (pfu_ids_dav),   // new fetch available
            .pfu_ack_o            (ids_pfu_ack),   // ack this fetch
            .pfu_sofid_i          (pfu_ids_sofid), // first fetch since vectoring
            .pfu_ins_i            (pfu_ids_ins),   // instruction fetched
            .pfu_ferr_i           (pfu_ids_ferr),  // this instruction fetch resulted in error
            .pfu_pc_i             (pfu_ids_pc),    // address of this instruction
            // ex stage interface
            .exs_valid_o          (ids_exs_valid),
            .exs_stall_i          (exs_ids_stall),
            .exs_sofid_o          (ids_exs_sofid),
            .exs_ins_uerr_o       (ids_exs_ins_uerr),
            .exs_ins_ferr_o       (ids_exs_ins_ferr),
            .exs_jump_o           (ids_exs_jump),
            .exs_cond_o           (ids_exs_cond),
            .exs_zone_o           (ids_exs_zone),
            .exs_link_o           (ids_exs_link),
            .exs_pc_o             (ids_exs_pc),
            .exs_alu_op_o         (ids_exs_alu_op),
            .exs_operand_left_o   (ids_exs_operand_left),
            .exs_operand_right_o  (ids_exs_operand_right),
            .exs_regs1_data_o     (ids_exs_regs1_data),
            .exs_regs2_data_o     (ids_exs_regs2_data),
            .exs_regd_addr_o      (ids_exs_regd_addr),
            .exs_funct3_o         (ids_exs_funct3),
            .exs_csr_rd_o         (ids_exs_csr_rd),
            .exs_csr_wr_o         (ids_exs_csr_wr),
            .exs_csr_addr_o       (ids_exs_csr_addr),
            .exs_csr_wr_data_o    (ids_exs_csr_wr_data),
                // write-back interface
            .exs_regd_cncl_load_i (exs_ids_regd_cncl_load),
            .exs_regd_wr_i        (exs_ids_regd_wr),
            .exs_regd_addr_i      (exs_ids_regd_addr),
            .exs_regd_data_i      (exs_ids_regd_data),
            // load/store queue interface
            .lsq_reg_wr_i         (1'b0), // TODO
            .lsq_reg_addr_i       (5'b0), // TODO
            .lsq_reg_data_i       (32'b0) // TODO
        );


    // execution stage
    //
    ex_stage
        #(
            .C_XLEN               (C_XLEN)
        ) i_ex_stage (
            // global
            .clk_i                (clk_i),
            .clk_en_i             (clk_en_i),
            .resetb_i             (resetb_i),
            // pfu stage interface
            .pfu_hpl_o            (exs_pfu_hpl),
            // instruction decoder stage interface
            .ids_valid_i          (ids_exs_valid),
            .ids_stall_o          (exs_ids_stall),
            .ids_sofid_i          (ids_exs_sofid),
            .ids_ins_uerr_i       (ids_exs_ins_uerr),
            .ids_ins_ferr_i       (ids_exs_ins_ferr),
            .ids_jump_i           (ids_exs_jump),
            .ids_cond_i           (ids_exs_cond),
            .ids_zone_i           (ids_exs_zone),
            .ids_link_i           (ids_exs_link),
            .ids_pc_i             (ids_exs_pc),
            .ids_alu_op_i         (ids_exs_alu_op),
            .ids_operand_left_i   (ids_exs_operand_left),
            .ids_operand_right_i  (ids_exs_operand_right),
            .ids_regs1_data_i     (ids_exs_regs1_data),
            .ids_regs2_data_i     (ids_exs_regs2_data),
            .ids_regd_addr_i      (ids_exs_regd_addr),
            .ids_funct3_i         (ids_exs_funct3),
            .ids_csr_rd_i         (ids_exs_csr_rd),
            .ids_csr_wr_i         (ids_exs_csr_wr),
            .ids_csr_addr_i       (ids_exs_csr_addr),
            .ids_csr_wr_data_i    (ids_exs_csr_wr_data),
                // write-back interface
            .ids_regd_cncl_load_o (exs_ids_regd_cncl_load),
            .ids_regd_wr_o        (exs_ids_regd_wr),
            .ids_regd_addr_o      (exs_ids_regd_addr),
            .ids_regd_data_o      (exs_ids_regd_data),
            // hart vectoring and exception controller interface TODO
            .hvec_ferr_o          (),
            .hvec_uerr_o          (),
            .hvec_maif_o          (),
            .hvec_ldx0_o          (),
            .hvec_ilgl_o          (),
            .hvec_jump_o          (exs_hvec_jump),
            .hvec_jump_addr_o     (exs_hvec_jump_addr),
            // load/store queue interface
            .lsq_full_i           (lsq_exs_full), // TODO
            .lsq_lq_wr_o          (exs_lsq_lq_wr), // TODO
            .lsq_sq_wr_o          (exs_lsq_sq_wr), // TODO
            .lsq_funct3_o         (exs_lsq_funct3), // TODO
            .lsq_regd_addr_o      (exs_lsq_regd_addr), // TODO
            .lsq_regs2_data_o     (exs_lsq_regs2_data), // TODO
            .lsq_addr_o           (exs_lsq_addr) // TODO
        );
endmodule

