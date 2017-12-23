/*
 * Author         : Tom Stanway-Mayers
 * Description    : Top Level
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

// TODO - generalise interface data widths

`include "riscv_defs.v"

module merlin
    #(
        parameter C_RESET_VECTOR = 32'h0
    )
    (
        // global
        input  wire                  clk_i,
        input  wire                  fclk_i,
        input  wire                  reset_i,
        // core status
        output wire                  sleeping_o,
        // hardware interrupt interface
        input  wire                  irqm_extern_i,
        input  wire                  irqm_softw_i,
        input  wire                  irqm_timer_i,
        input  wire                  irqs_extern_i,
        input  wire                  irqs_softw_i,
        input  wire                  irqs_timer_i,
        input  wire                  irqu_extern_i,
        input  wire                  irqu_softw_i,
        input  wire                  irqu_timer_i,
        // instruction port
        input  wire                  ireqready_i,
        output wire                  ireqvalid_o,
        output wire            [1:0] ireqhpl_o,
        output wire   [`RV_XLEN-1:0] ireqaddr_o,
        output wire                  irspready_o,
        input  wire                  irspvalid_i,
        input  wire                  irsprerr_i,
        input  wire   [`RV_XLEN-1:0] irspdata_i,
        // data port
        input  wire                  dreqready_i,
        output wire                  dreqvalid_o,
        output wire            [1:0] dreqsize_o,
        output wire                  dreqwrite_o,
        output wire            [1:0] dreqhpl_o,
        output wire           [31:0] dreqaddr_o,
        output wire           [31:0] dreqdata_o,
        output wire                  drspready_o,
        input  wire                  drspvalid_i,
        input  wire                  drsprerr_i,
        input  wire                  drspwerr_i,
        input  wire           [31:0] drspdata_i,
        // instruction trace port
        output wire                  mit_en_o,
        output wire                  mit_commit_o,
        output wire   [`RV_XLEN-1:0] mit_pc_o,
        output wire   [`RV_XLEN-1:0] mit_ins_o,
        output wire   [`RV_XLEN-1:0] mit_regs2_data_o,
        output wire   [`RV_XLEN-1:0] mit_alu_dout_o,
        output wire            [1:0] mit_mode_o,
        output wire                  mit_trap_o,
        output wire   [`RV_XLEN-1:0] mit_trap_cause_o,
        output wire   [`RV_XLEN-1:0] mit_trap_entry_addr_o,
        output wire   [`RV_XLEN-1:0] mit_trap_rtn_addr_o
        // debug interface
        // TODO - debug interface
    );

    //--------------------------------------------------------------

    // prefetch unit
    wire                     pfu_ids_dav;
    wire   [`RV_SOFID_RANGE] pfu_ids_sofid;
    wire              [31:0] pfu_ids_ins;
    wire                     pfu_ids_ferr;
    wire      [`RV_XLEN-1:0] pfu_ids_pc;
    // instruction decoder stage
    wire                     ids_pfu_ack;
    wire               [1:0] ids_pfu_ack_size;
    wire      [`RV_XLEN-1:0] ids_exs_ins;
    wire                     ids_exs_valid;
    wire   [`RV_SOFID_RANGE] ids_exs_sofid;
    wire               [1:0] ids_exs_ins_size;
    wire                     ids_exs_ins_uerr;
    wire                     ids_exs_ins_ferr;
    wire                     ids_exs_fencei;
    wire                     ids_exs_wfi;
    wire                     ids_exs_jump;
    wire                     ids_exs_ecall;
    wire                     ids_exs_trap_rtn;
    wire               [1:0] ids_exs_trap_rtn_mode;
    wire                     ids_exs_cond;
    wire    [`RV_ZONE_RANGE] ids_exs_zone;
    wire                     ids_exs_link;
    wire      [`RV_XLEN-1:0] ids_exs_pc;
    wire   [`RV_ALUOP_RANGE] ids_exs_alu_op;
    wire      [`RV_XLEN-1:0] ids_exs_operand_left;
    wire      [`RV_XLEN-1:0] ids_exs_operand_right;
    wire      [`RV_XLEN-1:0] ids_exs_cmp_right;
    wire      [`RV_XLEN-1:0] ids_exs_regs1_data;
    wire      [`RV_XLEN-1:0] ids_exs_regs2_data;
    wire               [4:0] ids_exs_regd_addr;
    wire               [2:0] ids_exs_funct3;
    wire                     ids_exs_csr_rd;
    wire                     ids_exs_csr_wr;
    wire              [11:0] ids_exs_csr_addr;
    wire      [`RV_XLEN-1:0] ids_exs_csr_wr_data;
    // execution stage
    wire               [1:0] exs_pfu_hpl;
    wire                     exs_pfu_jump;
    wire      [`RV_XLEN-1:0] exs_pfu_jump_addr;
    wire                     exs_ids_stall;
    wire                     exs_ids_regd_cncl_load;
    wire                     exs_ids_regd_wr;
    wire               [4:0] exs_ids_regd_addr;
    wire      [`RV_XLEN-1:0] exs_ids_regd_data;
    wire                     exs_lsq_lq_wr;
    wire                     exs_lsq_sq_wr;
    wire               [1:0] exs_lsq_hpl;
    wire               [2:0] exs_lsq_funct3;
    wire               [4:0] exs_lsq_regd_addr;
    wire      [`RV_XLEN-1:0] exs_lsq_regs2_data;
    wire      [`RV_XLEN-1:0] exs_lsq_addr;
    // load/store queue
    wire                     lsq_ids_reg_wr;
    wire               [4:0] lsq_ids_reg_addr;
    wire      [`RV_XLEN-1:0] lsq_ids_reg_data;
    wire                     lsq_exs_full;
    wire                     lsq_exs_empty;

    //--------------------------------------------------------------


    //--------------------------------------------------------------
    // prefetch unit
    //--------------------------------------------------------------
    merlin_pfu32ic
        #(
            .C_FIFO_PASSTHROUGH (`RV_PFU_BYPASS),
            .C_FIFO_DEPTH_X     (2), // pfu fifo depth base 2 exponent
            .C_RESET_VECTOR     (C_RESET_VECTOR)
        ) i_merlin_pfu32ic (
            // global
            .clk_i           (clk_i),
            .reset_i         (reset_i),
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
            .ids_dav_o       (pfu_ids_dav),      // new fetch available
            .ids_ack_i       (ids_pfu_ack),      // ack this fetch
            .ids_ack_size_i  (ids_pfu_ack_size), // ack this fetch
            .ids_sofid_o     (pfu_ids_sofid),    // first fetch since vectoring
            .ids_ins_o       (pfu_ids_ins),      // instruction fetched
            .ids_ferr_o      (pfu_ids_ferr),     // this instruction fetch resulted in error
            .ids_pc_o        (pfu_ids_pc),       // address of this instruction
            // vectoring and exception controller interface
            .exs_pc_wr_i     (exs_pfu_jump),
            .exs_pc_din_i    (exs_pfu_jump_addr),
            // pfu stage interface
            .exs_hpl_i       (exs_pfu_hpl)
        );


    //--------------------------------------------------------------
    // instruction decoder stage
    //--------------------------------------------------------------
    merlin_id_stage i_merlin_id_stage (
            // global
            .clk_i                (clk_i),
            .reset_i              (reset_i),
            // pfu interface
            .pfu_dav_i            (pfu_ids_dav),      // new fetch available
            .pfu_ack_o            (ids_pfu_ack),      // ack this fetch
            .pfu_ack_size_o       (ids_pfu_ack_size), // ack size
            .pfu_sofid_i          (pfu_ids_sofid),    // first fetch since vectoring
            .pfu_ins_i            (pfu_ids_ins),      // instruction fetched
            .pfu_ferr_i           (pfu_ids_ferr),     // this instruction fetch resulted in error
            .pfu_pc_i             (pfu_ids_pc),       // address of this instruction
            // ex stage interface
            .exs_ins_o            (ids_exs_ins),
            .exs_valid_o          (ids_exs_valid),
            .exs_stall_i          (exs_ids_stall),
            .exs_sofid_o          (ids_exs_sofid),
            .exs_ins_size_o       (ids_exs_ins_size),
            .exs_ins_uerr_o       (ids_exs_ins_uerr),
            .exs_ins_ferr_o       (ids_exs_ins_ferr),
            .exs_fencei_o         (ids_exs_fencei),
            .exs_wfi_o            (ids_exs_wfi),
            .exs_jump_o           (ids_exs_jump),
            .exs_ecall_o          (ids_exs_ecall),
            .exs_trap_rtn_o       (ids_exs_trap_rtn),
            .exs_trap_rtn_mode_o  (ids_exs_trap_rtn_mode),
            .exs_cond_o           (ids_exs_cond),
            .exs_zone_o           (ids_exs_zone),
            .exs_link_o           (ids_exs_link),
            .exs_pc_o             (ids_exs_pc),
            .exs_alu_op_o         (ids_exs_alu_op),
            .exs_operand_left_o   (ids_exs_operand_left),
            .exs_operand_right_o  (ids_exs_operand_right),
            .exs_cmp_right_o      (ids_exs_cmp_right),
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
            .lsq_reg_wr_i         (lsq_ids_reg_wr),
            .lsq_reg_addr_i       (lsq_ids_reg_addr),
            .lsq_reg_data_i       (lsq_ids_reg_data)
        );


    //--------------------------------------------------------------
    // execution stage
    //--------------------------------------------------------------
    merlin_ex_stage i_merlin_ex_stage (
            // global
            .clk_i                 (clk_i),
            .fclk_i                (fclk_i),
            .reset_i               (reset_i),
            // external interface
            .sleeping_o            (sleeping_o),
            //
            .irqm_extern_i         (irqm_extern_i),
            .irqm_softw_i          (irqm_softw_i),
            .irqm_timer_i          (irqm_timer_i),
            .irqs_extern_i         (irqs_extern_i),
            .irqs_softw_i          (irqs_softw_i),
            .irqs_timer_i          (irqs_timer_i),
            .irqu_extern_i         (irqu_extern_i),
            .irqu_softw_i          (irqu_softw_i),
            .irqu_timer_i          (irqu_timer_i),
            // pfu stage interface
            .pfu_hpl_o             (exs_pfu_hpl),
                // hart vectoring interface
            .pfu_jump_o            (exs_pfu_jump),
            .pfu_jump_addr_o       (exs_pfu_jump_addr),
            // instruction decoder stage interface
            .ids_ins_i             (ids_exs_ins),
            .ids_valid_i           (ids_exs_valid),
            .ids_stall_o           (exs_ids_stall),
            .ids_sofid_i           (ids_exs_sofid),
            .ids_ins_size_i        (ids_exs_ins_size),
            .ids_ins_uerr_i        (ids_exs_ins_uerr),
            .ids_ins_ferr_i        (ids_exs_ins_ferr),
            .ids_fencei_i          (ids_exs_fencei),
            .ids_wfi_i             (ids_exs_wfi),
            .ids_jump_i            (ids_exs_jump),
            .ids_ecall_i           (ids_exs_ecall),
            .ids_trap_rtn_i        (ids_exs_trap_rtn),
            .ids_trap_rtn_mode_i   (ids_exs_trap_rtn_mode),
            .ids_cond_i            (ids_exs_cond),
            .ids_zone_i            (ids_exs_zone),
            .ids_link_i            (ids_exs_link),
            .ids_pc_i              (ids_exs_pc),
            .ids_alu_op_i          (ids_exs_alu_op),
            .ids_operand_left_i    (ids_exs_operand_left),
            .ids_operand_right_i   (ids_exs_operand_right),
            .ids_cmp_right_i       (ids_exs_cmp_right),
            .ids_regs1_data_i      (ids_exs_regs1_data),
            .ids_regs2_data_i      (ids_exs_regs2_data),
            .ids_regd_addr_i       (ids_exs_regd_addr),
            .ids_funct3_i          (ids_exs_funct3),
            .ids_csr_rd_i          (ids_exs_csr_rd),
            .ids_csr_wr_i          (ids_exs_csr_wr),
            .ids_csr_addr_i        (ids_exs_csr_addr),
            .ids_csr_wr_data_i     (ids_exs_csr_wr_data),
                // write-back interface
            .ids_regd_cncl_load_o  (exs_ids_regd_cncl_load),
            .ids_regd_wr_o         (exs_ids_regd_wr),
            .ids_regd_addr_o       (exs_ids_regd_addr),
            .ids_regd_data_o       (exs_ids_regd_data),
            // load/store queue interface
            .lsq_full_i            (lsq_exs_full),
            .lsq_empty_i           (lsq_exs_empty),
            .lsq_lq_wr_o           (exs_lsq_lq_wr),
            .lsq_sq_wr_o           (exs_lsq_sq_wr),
            .lsq_hpl_o             (exs_lsq_hpl),
            .lsq_funct3_o          (exs_lsq_funct3),
            .lsq_regd_addr_o       (exs_lsq_regd_addr),
            .lsq_regs2_data_o      (exs_lsq_regs2_data),
            .lsq_addr_o            (exs_lsq_addr),
            // instruction trace port
            .mit_en_o              (mit_en_o),
            .mit_commit_o          (mit_commit_o),
            .mit_pc_o              (mit_pc_o),
            .mit_ins_o             (mit_ins_o),
            .mit_regs2_data_o      (mit_regs2_data_o),
            .mit_alu_dout_o        (mit_alu_dout_o),
            .mit_mode_o            (mit_mode_o),
            .mit_trap_o            (mit_trap_o),
            .mit_trap_cause_o      (mit_trap_cause_o),
            .mit_trap_entry_addr_o (mit_trap_entry_addr_o),
            .mit_trap_rtn_addr_o   (mit_trap_rtn_addr_o)
        );


    //--------------------------------------------------------------
    // load/store queue
    //--------------------------------------------------------------
    merlin_lsqueue
        #(
            .C_FIFO_PASSTHROUGH (`RV_LSQUEUE_BYPASS),
            .C_FIFO_DEPTH_X     (2)
        ) i_merlin_lsqueue (
            // global
            .clk_i              (clk_i),
            .reset_i            (reset_i),
            // instruction decoder stage interface
            .lsq_reg_wr_o       (lsq_ids_reg_wr),
            .lsq_reg_addr_o     (lsq_ids_reg_addr),
            .lsq_reg_data_o     (lsq_ids_reg_data),
            // execution stage interface
            .exs_full_o         (lsq_exs_full),
            .exs_empty_o        (lsq_exs_empty),
            .exs_lq_wr_i        (exs_lsq_lq_wr),
            .exs_sq_wr_i        (exs_lsq_sq_wr),
            .exs_hpl_i          (exs_lsq_hpl),
            .exs_funct3_i       (exs_lsq_funct3),
            .exs_regd_addr_i    (exs_lsq_regd_addr),
            .exs_regs2_data_i   (exs_lsq_regs2_data),
            .exs_addr_i         (exs_lsq_addr),
                // imprecise exceptions
            .plic_int_laf_o     (), // load access fault
            .plic_int_saf_o     (), // store access fault
            .plic_int_rspdata_o (), // response data
            // data port
            .dreqready_i        (dreqready_i),
            .dreqvalid_o        (dreqvalid_o),
            .dreqsize_o         (dreqsize_o),
            .dreqwrite_o        (dreqwrite_o),
            .dreqhpl_o          (dreqhpl_o),
            .dreqaddr_o         (dreqaddr_o),
            .dreqdata_o         (dreqdata_o),
            .drspready_o        (drspready_o),
            .drspvalid_i        (drspvalid_i),
            .drsprerr_i         (drsprerr_i),
            .drspwerr_i         (drspwerr_i),
            .drspdata_i         (drspdata_i)
        );
endmodule

