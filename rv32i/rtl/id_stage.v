module id_stage
    #(
        parameter P_XLEN = 32
    )
    (
        // global
        input  wire                 clk_i,
        input  wire                 clk_en_i,
        input  wire                 resetb_i,
        // pfu interface
        output wire                 pfu_dav_i,   // new fetch available
        input  wire                 pfu_pull_o,  // ack this fetch
        output wire                 pfu_sofr_i,  // first fetch since vectoring
        output wire          [31:0] pfu_ins_i,   // instruction fetched
        output wire                 pfu_ferr_i,  // this instruction fetch resulted in error
        output wire          [31:0] pfu_pc_i,    // address of this instruction
        // ex stage interface
        output  logic                ids_dav_o, // TODO
        input   logic                ids_ack_i, // TODO
        output  logic                ids_cond_o, // TODO
        output  t_zone               ids_zone_o,
        output  logic                ids_csr_access_o,
        output  logic                ids_link_o,
        output  logic   [C_XLEN-1:0] ids_pc_o,
        output  logic   [C_XLEN-1:0] ids_operand_left_o,
        output  logic   [C_XLEN-1:0] ids_operand_right_o,
        output  logic   [C_XLEN-1:0] ids_regs1_data_o,
        output  logic   [C_XLEN-1:0] ids_regs2_data_o,
        output  logic   [C_XLEN-1:0] ids_imm_o,
        output  logic          [4:0] ids_regd_addr_o,
        output  logic          [2:0] ids_funct3_o,
        output  logic                ids_csr_access_o,
        output  logic         [11:0] ids_csr_addr_o,
            // write-back interface
        input  logic                ids_regd_wr_i,
        input  logic          [4:0] ids_regd_addr_i,
        input  logic   [C_XLEN-1:0] ids_regd_data_i
    );

    //--------------------------------------------------------------

    // id register stage
    reg             ex_udefins_err_q;
    // instruction decoder
    wire            ex_udefins_err_d;

    //--------------------------------------------------------------


    // id register stage
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
        end else if (clk_en_i) begin
            ex_udefins_err_q <= ex_udefins_err_d;
        end
    end


    // instruction decoder
    //
    decoder
        #(
            .P_XLEN     (P_XLEN),
            .P_ZONE_SZ  (G_ZONE_SZ),
            .P_ALUOP_SZ (G_ALUOP_SZ)
        ) i_decoder (
            // instruction decoder interface
                // ingress side
            .ins_i         (pfu_ins_i),
                // egress side
            .ins_err_o     (ex_udefins_err_d),
            .zone_o        (),
            .regd_addr_o   (),
            .regs1_addr_o  (),
            .regs2_addr_o  (),
            .imm_o         (),
            .sels1_pc_o    (),
            .sels1_imm_o   (),
            .aluop_o       (),
            .funct3_o      (),
            .csr_access_o  (),
            .conditional_o ()
        );


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
