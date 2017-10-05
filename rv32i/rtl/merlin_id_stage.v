/*
 * Author         : Tom Stanway-Mayers
 * Description    : Instruction Decoder Stage
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module merlin_id_stage
    (
        // global
        input  wire                      clk_i,
        input  wire                      clk_en_i,
        input  wire                      resetb_i,
        // pfu interface
        input  wire                      pfu_dav_i,   // new fetch available
        output wire                      pfu_ack_o,   // ack this fetch
        output reg                 [1:0] pfu_ack_size_o, // ack size
        input  wire    [`RV_SOFID_RANGE] pfu_sofid_i, // first fetch since vectoring
        input  wire               [31:0] pfu_ins_i,   // instruction fetched
        input  wire                      pfu_ferr_i,  // this instruction fetch resulted in error
        input  wire       [`RV_XLEN-1:0] pfu_pc_i,    // address of this instruction
        // ex stage interface
        output reg        [`RV_XLEN-1:0] exs_ins_o,
        output reg                       exs_valid_o,
        input  wire                      exs_stall_i,
        output reg     [`RV_SOFID_RANGE] exs_sofid_o,
        output reg                 [1:0] exs_ins_size_o,
        output reg                       exs_ins_uerr_o,
        output reg                       exs_ins_ferr_o,
        output reg                       exs_fencei_o,
        output reg                       exs_wfi_o,
        output reg                       exs_jump_o,
        output reg                       exs_ecall_o,
        output reg                       exs_trap_rtn_o,
        output reg                 [1:0] exs_trap_rtn_mode_o,
        output reg                       exs_cond_o,
        output reg      [`RV_ZONE_RANGE] exs_zone_o,
        output reg                       exs_link_o,
        output wire       [`RV_XLEN-1:0] exs_pc_o,
        output reg     [`RV_ALUOP_RANGE] exs_alu_op_o,
        output reg        [`RV_XLEN-1:0] exs_operand_left_o,
        output reg        [`RV_XLEN-1:0] exs_operand_right_o,
        output reg        [`RV_XLEN-1:0] exs_cmp_right_o,
        output wire       [`RV_XLEN-1:0] exs_regs1_data_o,
        output wire       [`RV_XLEN-1:0] exs_regs2_data_o,
        output reg                 [4:0] exs_regd_addr_o,
        output reg                 [2:0] exs_funct3_o,
        output reg                       exs_csr_rd_o,
        output reg                       exs_csr_wr_o,
        output reg                [11:0] exs_csr_addr_o,
        output reg        [`RV_XLEN-1:0] exs_csr_wr_data_o,
            // write-back interface
        input  wire                      exs_regd_cncl_load_i,
        input  wire                      exs_regd_wr_i,
        input  wire                [4:0] exs_regd_addr_i,
        input  wire       [`RV_XLEN-1:0] exs_regd_data_i,
        // load/store queue interface
        input  wire                      lsq_reg_wr_i,
        input  wire                [4:0] lsq_reg_addr_i,
        input  wire       [`RV_XLEN-1:0] lsq_reg_data_i
    );

    //--------------------------------------------------------------

    // interface assignments
    // id stage qualifier logic
    wire                     id_stage_en;
    wire                     exs_stall;
    // rv32ic instruction expander
    wire                     ins_expanded_valid;
    wire                     rv32ic_ins_uerr;
    wire              [31:0] ins_expanded;
    // instruction mux
    wire                     ins_uerr_d;
    reg               [31:0] rv32i_ins;
    // instruction decoder
    wire                     rv32i_ins_uerr;
    wire                     fencei_d;
    wire                     wfi_d;
    wire                     jump_d;
    wire                     ecall_d;
    wire                     trap_rtn_d;
    wire               [1:0] trap_rtn_mode_d;
    wire    [`RV_ZONE_RANGE] zone_d;
    wire                     regd_tgt;
    wire               [4:0] regd_addr_d;
    wire                     regs1_rd;
    wire               [4:0] regs1_addr;
    wire                     regs2_rd;
    wire               [4:0] regs2_addr;
    wire      [`RV_XLEN-1:0] imm_d;
    wire                     link_d;
    wire                     sels1_pc_d;
    wire                     sel_csr_wr_data_imm_d;
    wire                     sels2_imm_d;
    wire                     selcmps2_imm_d;
    wire   [`RV_ALUOP_RANGE] alu_op_d;
    wire               [2:0] funct3_d;
    wire                     csr_rd_d;
    wire                     csr_wr_d;
    wire              [11:0] csr_addr_d;
    wire                     conditional_d;
    // id stage stall controller
    reg                      ids_stall;
    reg               [31:1] reg_loading_vector_q;
    // integer register file
    wire      [`RV_XLEN-1:0] regs1_dout;
    wire      [`RV_XLEN-1:0] regs2_dout;
    // forwarding register
    reg                      fwd_regd_wr_q;
    reg                [4:0] fwd_regd_addr_q;
    reg       [`RV_XLEN-1:0] fwd_regd_data_q;
    // id register stage
    reg       [`RV_XLEN-1:0] pc_q;
    reg                      ex_udefins_err_q;
    reg       [`RV_XLEN-1:0] imm_q;
    reg                      sels1_pc_q;
    reg                      sel_csr_wr_data_imm_q;
    reg                      sels2_imm_q;
    reg                      selcmps2_imm_q;
    reg                [4:0] regs1_addr_q;
    reg                [4:0] regs2_addr_q;
    // operand forwarding mux
    reg       [`RV_XLEN-1:0] fwd_mux_regs1_data;
    reg       [`RV_XLEN-1:0] fwd_mux_regs2_data;
    // left operand select mux
    // right operand select mux
    // right cmp select mux
    // csr write data select mux

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign exs_pc_o         = pc_q;
    assign exs_regs1_data_o = fwd_mux_regs1_data;
    assign exs_regs2_data_o = fwd_mux_regs2_data;


    //--------------------------------------------------------------
    // id stage qualifier logic
    //--------------------------------------------------------------
    assign pfu_ack_o    = pfu_dav_i & ~ids_stall & ~exs_stall;
    assign id_stage_en  = pfu_ack_o;
    assign exs_stall    = exs_stall_i & exs_valid_o;


    //--------------------------------------------------------------
    // rv32ic instruction expander
    //--------------------------------------------------------------
    merlin_rv32ic_expander i_merlin_rv32ic_expander (
            .ins_i     (pfu_ins_i[15:0]),
            .ins_rvc_o (ins_expanded_valid),
            .ins_err_o (rv32ic_ins_uerr),
            .ins_o     (ins_expanded)
        );


    //--------------------------------------------------------------
    // instruction mux
    //--------------------------------------------------------------
    assign ins_uerr_d = rv32i_ins_uerr | (ins_expanded_valid & rv32ic_ins_uerr);
    //
    always @ (*)
    begin
        if (ins_expanded_valid) begin
            pfu_ack_size_o = 2'b01;
            rv32i_ins      = ins_expanded;
        end else begin
            pfu_ack_size_o = 2'b10;
            rv32i_ins      = pfu_ins_i;
        end
    end


    //--------------------------------------------------------------
    // instruction decoder
    //--------------------------------------------------------------
    merlin_rv32i_decoder i_merlin_rv32i_decoder (
            // instruction decoder interface
                // ingress side
            .ins_i                 (rv32i_ins),
                // egress side
            .ins_err_o             (rv32i_ins_uerr),
            .fencei_o              (fencei_d),
            .wfi_o                 (wfi_d),
            .jump_o                (jump_d),
            .ecall_o               (ecall_d),
            .trap_rtn_o            (trap_rtn_d),
            .trap_rtn_mode_o       (trap_rtn_mode_d),
            .zone_o                (zone_d),
            .regd_tgt_o            (regd_tgt),
            .regd_addr_o           (regd_addr_d),
            .regs1_rd_o            (regs1_rd),
            .regs1_addr_o          (regs1_addr),
            .regs2_rd_o            (regs2_rd),
            .regs2_addr_o          (regs2_addr),
            .imm_o                 (imm_d),
            .link_o                (link_d),
            .sels1_pc_o            (sels1_pc_d),
            .sel_csr_wr_data_imm_o (sel_csr_wr_data_imm_d),
            .sels2_imm_o           (sels2_imm_d),
            .selcmps2_imm_o        (selcmps2_imm_d),
            .aluop_o               (alu_op_d),
            .funct3_o              (funct3_d),
            .csr_rd_o              (csr_rd_d),
            .csr_wr_o              (csr_wr_d),
            .csr_addr_o            (csr_addr_d),
            .conditional_o         (conditional_d)
        );


    //--------------------------------------------------------------
    // id stage stall controller
    //--------------------------------------------------------------
    /* *** RULES ***
     * No register can have more than one pending load at any given time
     *  - This is to prevent the flag being cleared prematuraly by the first load
     * No register can be targeted if it has a pending load
     *
     */
    always @ (*)
    begin
        ids_stall = 1'b0;
        //
        if (pfu_dav_i) begin
            if ( ( regs1_addr != 5'b0 && regs1_rd && reg_loading_vector_q[regs1_addr]) ||
                 ( regs2_addr != 5'b0 && regs2_rd && reg_loading_vector_q[regs2_addr]) ||
                 (regd_addr_d != 5'b0 && regd_tgt && reg_loading_vector_q[regd_addr_d]) ) begin
                ids_stall = 1'b1;
            end
        end
    end
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            reg_loading_vector_q <= 31'b0;
        end else if (clk_en_i) begin
            if (regd_addr_d != 5'b0 && id_stage_en && zone_d == `RV_ZONE_LOADQ) begin
                `RV_ASSERT(reg_loading_vector_q[regd_addr_d] == 1'b0, "Register marked as pending load when already pending.")
                reg_loading_vector_q[regd_addr_d] <= 1'b1;
            end
            if (exs_regd_addr_i != 5'b0 && exs_regd_cncl_load_i) begin
                `RV_ASSERT(reg_loading_vector_q[exs_regd_addr_i] == 1'b1, "Load canceled when not pending.")
                reg_loading_vector_q[exs_regd_addr_i] <= 1'b0;
            end
            if (lsq_reg_addr_i != 5'b0 && lsq_reg_wr_i) begin
                `RV_ASSERT(reg_loading_vector_q[lsq_reg_addr_i] == 1'b1, "Load written when not pending.")
                reg_loading_vector_q[lsq_reg_addr_i] <= 1'b0;
            end
        end
    end


    //--------------------------------------------------------------
    // integer register file
    //--------------------------------------------------------------
    merlin_int_regs i_merlin_int_regs (
            // global
            .clk_i         (clk_i),
            .clk_en_i      (clk_en_i),
            .resetb_i      (resetb_i),
            // write port
            .wreg_a_wr_i   (exs_regd_wr_i),
            .wreg_a_addr_i (exs_regd_addr_i),
            .wreg_a_data_i (exs_regd_data_i),
            .wreg_b_wr_i   (lsq_reg_wr_i),
            .wreg_b_addr_i (lsq_reg_addr_i),
            .wreg_b_data_i (lsq_reg_data_i),
            // read port
            .rreg_a_rd_i   (id_stage_en & regs1_rd),
            .rreg_a_addr_i (regs1_addr),
            .rreg_a_data_o (regs1_dout),
            .rreg_b_rd_i   (id_stage_en & regs2_rd),
            .rreg_b_addr_i (regs2_addr),
            .rreg_b_data_o (regs2_dout)
        );


    //--------------------------------------------------------------
    // forwarding register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            fwd_regd_wr_q   <= 1'b0;
            //fwd_regd_addr_q <= 5'b0; // NOTE: don't actually care
            //fwd_regd_data_q <= { `RV_XLEN {1'b0} }; // NOTE: don't actually care
        end else if (clk_en_i) begin
            fwd_regd_wr_q   <= exs_regd_wr_i;
            fwd_regd_addr_q <= exs_regd_addr_i;
            fwd_regd_data_q <= exs_regd_data_i;
        end
    end


    //--------------------------------------------------------------
    // id register stage
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            exs_valid_o <= 1'b0;
        end else if (clk_en_i) begin
            if (id_stage_en) begin
                exs_valid_o <= 1'b1;
            end else if (~exs_stall) begin
                exs_valid_o <= 1'b0;
            end
        end
    end
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (id_stage_en) begin
                exs_ins_o             <= { { `RV_XLEN-32 {1'b0} }, pfu_ins_i };
                exs_sofid_o           <= pfu_sofid_i;
                exs_fencei_o          <= fencei_d;
                exs_wfi_o             <= wfi_d;
                exs_jump_o            <= jump_d;
                exs_ecall_o           <= ecall_d;
                exs_trap_rtn_o        <= trap_rtn_d;
                exs_trap_rtn_mode_o   <= trap_rtn_mode_d;
                pc_q                  <= pfu_pc_i;
                exs_ins_size_o        <= pfu_ack_size_o;
                exs_ins_uerr_o        <= ins_uerr_d;
                exs_ins_ferr_o        <= pfu_ferr_i;
                exs_zone_o            <= zone_d;
                exs_regd_addr_o       <= regd_addr_d;
                imm_q                 <= imm_d;
                exs_link_o            <= link_d;
                sels1_pc_q            <= sels1_pc_d;
                sel_csr_wr_data_imm_q <= sel_csr_wr_data_imm_d;
                sels2_imm_q           <= sels2_imm_d;
                selcmps2_imm_q        <= selcmps2_imm_d;
                exs_alu_op_o          <= alu_op_d;
                exs_funct3_o          <= funct3_d;
                exs_csr_rd_o          <= csr_rd_d;
                exs_csr_wr_o          <= csr_wr_d;
                exs_csr_addr_o        <= csr_addr_d;
                exs_cond_o            <= conditional_d;
                // register addr delay register
                regs1_addr_q          <= regs1_addr;
                regs2_addr_q          <= regs2_addr;
            end
        end
    end


    //--------------------------------------------------------------
    // operand forwarding mux
    //--------------------------------------------------------------
    // forwarding mux for s1
    always @ (*)
    begin
        if (regs1_addr_q == 5'b0) begin
            // register x0 is always valid
            fwd_mux_regs1_data = regs1_dout;
        end else if (exs_regd_wr_i && exs_regd_addr_i == regs1_addr_q) begin
            // operand at alu output
            fwd_mux_regs1_data = exs_regd_data_i;
        end else if (fwd_regd_wr_q && fwd_regd_addr_q == regs1_addr_q) begin
            // operand at forwarding register output
            fwd_mux_regs1_data = fwd_regd_data_q;
        end else begin
            // operand at register file output
            fwd_mux_regs1_data = regs1_dout;
        end
    end
    // forwarding mux for s2
    always @ (*)
    begin
        if (regs2_addr_q == 5'b0) begin
            // register x0 is always valid
            fwd_mux_regs2_data = regs2_dout;
        end else if (exs_regd_wr_i && exs_regd_addr_i == regs2_addr_q) begin
            // operand at alu output
            fwd_mux_regs2_data = exs_regd_data_i;
        end else if (fwd_regd_wr_q && fwd_regd_addr_q == regs2_addr_q) begin
            // operand at forwarding register output
            fwd_mux_regs2_data = fwd_regd_data_q;
        end else begin
            // operand at register file output
            fwd_mux_regs2_data = regs2_dout;
        end
    end


    //--------------------------------------------------------------
    // left operand select mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (sels1_pc_q) begin
            exs_operand_left_o = pc_q;
        end else begin
            exs_operand_left_o = fwd_mux_regs1_data;
        end
    end


    //--------------------------------------------------------------
    // right operand select mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (sels2_imm_q) begin
            exs_operand_right_o = imm_q;
        end else begin
            exs_operand_right_o = fwd_mux_regs2_data;
        end
    end


    //--------------------------------------------------------------
    // right cmp select mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (selcmps2_imm_q) begin
            exs_cmp_right_o = imm_q;
        end else begin
            exs_cmp_right_o = fwd_mux_regs2_data;
        end
    end


    //--------------------------------------------------------------
    // csr write data select mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (sel_csr_wr_data_imm_q) begin
            exs_csr_wr_data_o = imm_q;
        end else begin
            exs_csr_wr_data_o = fwd_mux_regs1_data;
        end
    end


    //--------------------------------------------------------------
    // assersions
    //--------------------------------------------------------------
`ifdef RV_ASSERTS_ON
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            // register file access assertions
            `RV_ASSERT(!(id_stage_en & regs1_rd == 1'b1 && reg_loading_vector_q[regs1_addr]), "Register read when pending a load.")
            `RV_ASSERT(!(id_stage_en & regs2_rd == 1'b1 && reg_loading_vector_q[regs2_addr]), "Register read when pending a load.")
        end
    end
`endif
endmodule
