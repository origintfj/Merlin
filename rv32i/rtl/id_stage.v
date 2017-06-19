// TODO - forwarding logic
// TODO - register loading logic -> dav/stall implications

`include "riscv_defs.v"

module id_stage
    #(
        parameter C_XLEN = 32
    )
    (
        // global
        input  wire                 clk_i,
        input  wire                 clk_en_i,
        input  wire                 resetb_i,
        // pfu interface
        input  wire                 pfu_dav_i,   // new fetch available
        output wire                 pfu_ack_o,   // ack this fetch
        input  wire                 pfu_sofr_i,  // first fetch since vectoring
        input  wire          [31:0] pfu_ins_i,   // instruction fetched
        input  wire                 pfu_ferr_i,  // this instruction fetch resulted in error
        input  wire          [31:0] pfu_pc_i,    // address of this instruction
        // ex stage interface
        output wire                 ids_dav_o, // TODO
        input  wire                 ids_ack_i, // TODO
        output reg                  ids_sofr_o,
        output reg                  ids_ins_uerr_o,
        output reg                  ids_ins_ferr_o,
        output reg                  ids_cond_o,
        output reg    [`ZONE_RANGE] ids_zone_o,
        output reg                  ids_link_o,
        output wire    [C_XLEN-1:0] ids_pc_o,
        output reg   [`ALUOP_RANGE] ids_alu_op_o,
        output reg     [C_XLEN-1:0] ids_operand_left_o,
        output reg     [C_XLEN-1:0] ids_operand_right_o,
        output wire    [C_XLEN-1:0] ids_regs1_data_o,
        output wire    [C_XLEN-1:0] ids_regs2_data_o,
        output reg            [4:0] ids_regd_addr_o,
        output reg            [2:0] ids_funct3_o,
        output reg                  ids_csr_access_o,
        output reg           [11:0] ids_csr_addr_o,
        output reg     [C_XLEN-1:0] ids_csr_wr_data_o,
            // write-back interface
        input  wire                 ids_regd_wr_i,
        input  wire           [4:0] ids_regd_addr_i,
        input  wire    [C_XLEN-1:0] ids_regd_data_i,
        // load/store queue interface
        input  wire                 lsq_reg_wr_i,
        input  wire           [4:0] lsq_reg_addr_i,
        input  wire    [C_XLEN-1:0] lsq_reg_data_i
    );

    //--------------------------------------------------------------

    // id stage dav logic
    wire                id_stage_en;
    reg                 pfu_dav_q;
    // instruction decoder
    wire                ins_uerr_d;
    wire  [`ZONE_RANGE] zone_d;
    wire          [4:0] regd_addr_d;
    wire          [4:0] regs1_addr_o;
    wire          [4:0] regs2_addr_o;
    wire   [C_XLEN-1:0] imm_d;
    wire                link_d;
    wire                sels1_pc_d;
    wire                sel_csr_wr_data_imm_d;
    wire                sels2_imm_d;
    wire [`ALUOP_RANGE] alu_op_d;
    wire          [2:0] funct3_d;
    wire                csr_access_d;
    wire         [11:0] csr_addr_d;
    wire                conditional_d;
    // integer register file
    wire   [C_XLEN-1:0] regs1_dout;
    wire   [C_XLEN-1:0] regs2_dout;
    // forwarding register
    reg    [C_XLEN-1:0] fwd_mux_regs1_data;
    reg    [C_XLEN-1:0] fwd_mux_regs2_data;
    // id register stage
    reg    [C_XLEN-1:0] pc_q;
    reg                 ex_udefins_err_q;
    reg    [C_XLEN-1:0] imm_q;
    reg                 sels1_pc_q;
    reg                 sel_csr_wr_data_imm_q;
    reg                 sels2_imm_q;
    // operand forwarding mux
    // left operand select mux
    // right operand select mux
    // csr write data select mux

    //--------------------------------------------------------------

    // interface assignments
    assign pfu_ack_o        = pfu_dav_i & id_stage_en;
    assign ids_dav_o        = pfu_dav_q;
    assign ids_pc_o         = pc_q;
    assign ids_regs1_data_o = fwd_mux_regs1_data;
    assign ids_regs2_data_o = fwd_mux_regs2_data;

    // id stage dav logic
    //
    assign id_stage_en = ids_ack_i | ~pfu_dav_q;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            pfu_dav_q <= 1'b0;
        end else if (id_stage_en) begin
            pfu_dav_q <= pfu_dav_i;
        end
    end


    // instruction decoder
    //
    decoder
        #(
            .C_XLEN                (C_XLEN)
        ) i_decoder (
            // instruction decoder interface
                // ingress side
            .ins_i                 (pfu_ins_i),
                // egress side
            .ins_err_o             (ins_uerr_d),
            .zone_o                (zone_d),
            .regd_addr_o           (regd_addr_d),
            .regs1_addr_o          (regs1_addr_o),
            .regs2_addr_o          (regs2_addr_o),
            .imm_o                 (imm_d),
            .link_o                (link_d),
            .sels1_pc_o            (sels1_pc_d),
            .sel_csr_wr_data_imm_o (sel_csr_wr_data_imm_d),
            .sels2_imm_o           (sels2_imm_d),
            .aluop_o               (alu_op_d),
            .funct3_o              (funct3_d),
            .csr_access_o          (csr_access_d),
            .csr_addr_o            (csr_addr_d),
            .conditional_o         (conditional_d)
        );


    // integer register file
    //
    regfile_integer
        #(
            .C_XLEN        (C_XLEN)
        ) i_regfile_integer (
            // global
            .clk_i         (clk_i),
            .clk_en_i      (clk_en_i),
            .resetb_i      (resetb_i),
            // write port
            .wreg_a_wr_i   (ids_regd_wr_i),
            .wreg_a_addr_i (ids_regd_addr_i),
            .wreg_a_data_i (ids_regd_data_i),
            .wreg_b_wr_i   (lsq_reg_wr_i),
            .wreg_b_addr_i (lsq_reg_addr_i),
            .wreg_b_data_i (lsq_reg_data_i),
            // read port
            .rreg_a_rd_i   (1'b1), // TODO
            .rreg_a_addr_i (regs1_addr_o),
            .rreg_a_data_o (regs1_dout),
            .rreg_b_rd_i   (1'b1), // TODO
            .rreg_b_addr_i (regs2_addr_o),
            .rreg_b_data_o (regs2_dout)
        );


    // forwarding register
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
        end else if (clk_en_i) begin
        end
    end


    // id register stage
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
        end else if (clk_en_i) begin
            ids_sofr_o            <= pfu_sofr_i;
            pc_q                  <= pfu_pc_i;
            ids_ins_uerr_o        <= ins_uerr_d;
            ids_ins_ferr_o        <= pfu_ferr_i;
            ids_zone_o            <= zone_d;
            ids_regd_addr_o       <= regd_addr_d;
            imm_q                 <= imm_d;
            ids_link_o            <= link_d;
            sels1_pc_q            <= sels1_pc_d;
            sel_csr_wr_data_imm_q <= sel_csr_wr_data_imm_d;
            sels2_imm_q           <= sels2_imm_d;
            ids_alu_op_o          <= alu_op_d;
            ids_funct3_o          <= funct3_d;
            ids_csr_access_o      <= csr_access_d;
            ids_csr_addr_o        <= csr_addr_d;
            ids_cond_o            <= conditional_d;
        end
    end


    // operand forwarding mux
    //
    always @ (*)
    begin
        fwd_mux_regs1_data = regs1_dout;
        fwd_mux_regs2_data = regs2_dout;
    end


    // left operand select mux
    //
    always @ (*)
    begin
        if (sels1_pc_q) begin
            ids_operand_left_o = pc_q;
        end else begin
            ids_operand_left_o = fwd_mux_regs1_data;
        end
    end


    // right operand select mux
    //
    always @ (*)
    begin
        if (sels2_imm_q) begin
            ids_operand_right_o = imm_q;
        end else begin
            ids_operand_right_o = fwd_mux_regs2_data;
        end
    end


    // csr write data select mux
    //
    always @ (*)
    begin
        if (sel_csr_wr_data_imm_q) begin
            ids_csr_wr_data_o = imm_q;
        end else begin
            ids_csr_wr_data_o = fwd_mux_regs1_data;
        end
    end
endmodule
