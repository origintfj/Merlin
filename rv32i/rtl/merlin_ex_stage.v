/*
 * Author         : Tom Stanway-Mayers
 * Description    : Execute Stage
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module merlin_ex_stage
    (
        // global
        input  wire                     clk_i,
        input  wire                     fclk_i,
        input  wire                     reset_i,
        // external interface
        output wire                     sleeping_o,
        //
        input  wire                     irqm_extern_i,
        input  wire                     irqm_softw_i,
        input  wire                     irqm_timer_i,
        input  wire                     irqs_extern_i,
        // pfu stage interface
        output wire               [1:0] pfu_hpl_o,
            // hart vectoring interface
        output wire                     pfu_jump_o,
        output reg       [`RV_XLEN-1:0] pfu_jump_addr_o,
        // instruction decoder stage interface
        input  wire      [`RV_XLEN-1:0] ids_ins_i,
        input  wire                     ids_valid_i,
        output wire                     ids_stall_o,
        input  wire   [`RV_SOFID_RANGE] ids_sofid_i,
        input  wire               [1:0] ids_ins_size_i,
        input  wire                     ids_ins_uerr_i,
        input  wire                     ids_ins_ferr_i,
        input  wire                     ids_fencei_i,
        input  wire                     ids_wfi_i,
        input  wire                     ids_jump_i,
        input  wire                     ids_ecall_i,
        input  wire                     ids_trap_rtn_i,
        input  wire               [1:0] ids_trap_rtn_mode_i,
        input  wire                     ids_cond_i,
        input  wire    [`RV_ZONE_RANGE] ids_zone_i,
        input  wire                     ids_link_i,
        input  wire      [`RV_XLEN-1:0] ids_pc_i,
        input  wire   [`RV_ALUOP_RANGE] ids_alu_op_i,
        input  wire      [`RV_XLEN-1:0] ids_operand_left_i,
        input  wire      [`RV_XLEN-1:0] ids_operand_right_i,
        input  wire      [`RV_XLEN-1:0] ids_cmp_right_i,
        input  wire      [`RV_XLEN-1:0] ids_regs1_data_i,
        input  wire      [`RV_XLEN-1:0] ids_regs2_data_i,
        input  wire               [4:0] ids_regd_addr_i,
        input  wire               [2:0] ids_funct3_i,
        input  wire                     ids_csr_rd_i,
        input  wire                     ids_csr_wr_i,
        input  wire              [11:0] ids_csr_addr_i,
        input  wire      [`RV_XLEN-1:0] ids_csr_wr_data_i,
            // write-back interface
        output wire                     ids_regd_cncl_load_o,
        output wire                     ids_regd_wr_o,
        output wire               [4:0] ids_regd_addr_o,
        output reg       [`RV_XLEN-1:0] ids_regd_data_o,
        // load/store queue interface
        input  wire                     lsq_full_i,
        input  wire                     lsq_empty_i,
        output wire                     lsq_lq_wr_o,
        output wire                     lsq_sq_wr_o,
        output wire               [1:0] lsq_hpl_o,
        output wire               [2:0] lsq_funct3_o,
        output wire               [4:0] lsq_regd_addr_o,
        output wire      [`RV_XLEN-1:0] lsq_regs2_data_o,
        output wire      [`RV_XLEN-1:0] lsq_addr_o,
        // instruction trace port
        output wire                     mit_en_o,
        output wire                     mit_commit_o,
        output wire      [`RV_XLEN-1:0] mit_pc_o,
        output wire      [`RV_XLEN-1:0] mit_ins_o,
        output wire      [`RV_XLEN-1:0] mit_regs2_data_o,
        output wire      [`RV_XLEN-1:0] mit_alu_dout_o,
        output wire               [1:0] mit_mode_o,
        output wire                     mit_trap_o,
        output wire      [`RV_XLEN-1:0] mit_trap_cause_o,
        output wire      [`RV_XLEN-1:0] mit_trap_entry_addr_o,
        output wire      [`RV_XLEN-1:0] mit_trap_rtn_addr_o
    );

    //--------------------------------------------------------------

    // interface assignments
    // hart vectoring logic
    wire                   jump;
    // execute commit signals
    wire                   csr_wr;
    wire             [1:0] csr_wr_mode;
    wire                   csr_trap_rtn;
    // exception signaling logic
    wire                   excp_ecall;
    wire                   excp_ferr;
    wire                   excp_uerr;
    wire                   excp_maif;
    reg                    excp_mala;
    reg                    excp_masa;
    reg                    excp_ilgl;
    // instruction qualification logic
    wire                   ex_valid;
    wire                   execute_commit;
    reg  [`RV_SOFID_RANGE] sofid_q;
    reg                    sofid_run;
    // delay stage
    reg     [`RV_XLEN-1:0] ids_ins_q;
    reg                    ids_valid_q;
    reg                    ids_ins_uerr_q;
    reg                    ids_ins_ferr_q;
    reg                    ids_fencei_q;
    reg                    ids_wfi_q;
    reg                    ids_jump_q;
    reg                    ids_ecall_q;
    reg                    ids_trap_rtn_q;
    reg              [1:0] ids_trap_rtn_mode_q;
    reg                    ids_cond_q;
    reg                    lq_wr_q;
    reg                    sq_wr_q;
    reg                    regd_wr_q;
    reg                    ids_csr_rd_q;
    reg                    ids_csr_wr_q;
    reg             [11:0] ids_csr_addr_q;
    reg     [`RV_XLEN-1:0] ids_csr_wr_data_q;
    reg                    ids_link_q;
    reg     [`RV_XLEN-1:0] ids_pc_q;
    reg     [`RV_XLEN-1:0] pc_inc_q;
    reg     [`RV_XLEN-1:0] ids_regs2_data_q;
    reg              [4:0] ids_regd_addr_q;
    reg              [2:0] funct3_q;
    reg     [`RV_XLEN-1:0] csr_rd_data_q;
    reg                    csr_badpriv_q;
    reg                    csr_badwrite_q;
    reg                    csr_badcsr_q;
    // wfi latch
    reg                    wfi_latch_q;
    // ex stage stall controller
    wire                   ex_stage_en;
    reg                    exs_stall;
    // regd data out mux
    // alu pcinc mux
    reg     [`RV_XLEN-1:0] alu_pcinc_mux_out;
    // alu
    wire    [`RV_XLEN-1:0] alu_data_out;
    wire                   alu_cmp_out;
    // cs register file and write data logic
    wire    [`RV_XLEN-1:0] csr_rd_data_d;
    wire                   csr_badcsr_d;
    wire                   csr_badwrite_d;
    wire                   csr_badpriv_d;
    wire                   csr_interrupt;
    wire                   csr_jump_to_trap;
    wire    [`RV_XLEN-1:0] csr_trap_entry_addr;
    wire    [`RV_XLEN-1:0] csr_trap_rtn_addr;
    wire             [1:0] csr_mode;
    wire    [`RV_XLEN-1:0] csr_trap_cause;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign pfu_hpl_o        = csr_mode;
    //
    assign ids_stall_o      = exs_stall;
    assign ids_regd_addr_o  = ids_regd_addr_q;
    //
    assign lsq_hpl_o        = csr_mode;
    assign lsq_funct3_o     = funct3_q;
    assign lsq_regd_addr_o  = ids_regd_addr_q;
    assign lsq_regs2_data_o = ids_regs2_data_q;
    assign lsq_addr_o       = alu_data_out;
    // core tracer
    assign mit_en_o              = ex_stage_en;
    assign mit_commit_o          = execute_commit;
    assign mit_pc_o              = ids_pc_q;
    assign mit_ins_o             = ids_ins_q;
    assign mit_regs2_data_o      = ids_regs2_data_q;
    assign mit_alu_dout_o        = alu_data_out;
    assign mit_mode_o            = csr_mode;
    assign mit_trap_o            = csr_jump_to_trap;
    assign mit_trap_cause_o      = csr_trap_cause;
    assign mit_trap_entry_addr_o = csr_trap_entry_addr;
    assign mit_trap_rtn_addr_o   = csr_trap_rtn_addr;


    //--------------------------------------------------------------
    // hart vectoring logic
    //--------------------------------------------------------------
    assign jump = (execute_commit & (ids_jump_q | ids_trap_rtn_q | ids_fencei_q)) | csr_jump_to_trap;
    //
    always @ (*) begin
        if (csr_jump_to_trap) begin
            pfu_jump_addr_o = csr_trap_entry_addr;
        end else if (ids_trap_rtn_q) begin
            pfu_jump_addr_o = csr_trap_rtn_addr;
        end else if (ids_fencei_q) begin
            pfu_jump_addr_o = pc_inc_q;
        end else begin
            pfu_jump_addr_o = { alu_data_out[`RV_XLEN-1:1], 1'b0 };
        end
    end


    //--------------------------------------------------------------
    // execute commit signals
    //--------------------------------------------------------------
    assign pfu_jump_o = ex_stage_en & jump;
    //
    assign ids_regd_cncl_load_o = ex_stage_en & ~execute_commit & ids_valid_q & lq_wr_q;
    assign ids_regd_wr_o        = ex_stage_en &  execute_commit & regd_wr_q;
    //
    assign lsq_lq_wr_o = ex_stage_en & execute_commit & lq_wr_q;
    assign lsq_sq_wr_o = ex_stage_en & execute_commit & sq_wr_q;
    //
    assign csr_wr       = ex_stage_en & execute_commit & ids_csr_wr_q;
    assign csr_wr_mode  = funct3_q[1:0];
    assign csr_trap_rtn = execute_commit & ids_trap_rtn_q;


    //--------------------------------------------------------------
    // exception signaling logic
    //--------------------------------------------------------------
    assign excp_ecall = ids_ecall_q;
    assign excp_ferr  = ids_ins_ferr_q;
    assign excp_uerr  = ids_ins_uerr_q;
`ifdef RV_CONFIG_STDEXT_C
    assign excp_maif  = 1'b0;
`else
    assign excp_maif  = ids_jump_q & alu_data_out[1];
`endif
    //
    always @ (*) begin
        excp_mala = 1'b0;
        excp_masa = 1'b0;
        if (funct3_q == 3'b001 && alu_data_out[0] != 1'b0) begin
            excp_mala = lq_wr_q;
            excp_masa = sq_wr_q;
        end else if (funct3_q == 3'b010 && alu_data_out[1:0] != 2'b00) begin
            excp_mala = lq_wr_q;
            excp_masa = sq_wr_q;
        end
    end
    //
    always @ (*) begin
        excp_ilgl = 1'b0;
        if (ids_csr_rd_q | ids_csr_wr_q) begin
            excp_ilgl = csr_badcsr_q | csr_badpriv_q | csr_badwrite_q;
        end
        //
        if (ids_trap_rtn_q) begin
            if (ids_trap_rtn_mode_q > csr_mode) begin // if xRET && x > priv_mode
                excp_ilgl = 1'b1;
            end
        end
    end


    //--------------------------------------------------------------
    // instruction qualification logic
    //--------------------------------------------------------------
    assign ex_valid       = ids_valid_q & sofid_run;
    assign execute_commit = ex_valid & (alu_cmp_out | ~ids_cond_q) & ~csr_jump_to_trap;
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            sofid_q <= `RV_SOFID_RUN;
        end else begin
            if (ex_stage_en) begin
                if (jump) begin
                    sofid_q <= `RV_SOFID_JUMP;
                end else if (ids_valid_i && ids_sofid_i == sofid_q) begin
                    sofid_q <= `RV_SOFID_RUN;
                end
            end
        end
    end
    always @ (*) begin
        if (sofid_q == `RV_SOFID_RUN) begin
            sofid_run = 1'b1;
        end else begin
            sofid_run = 1'b0;
        end
    end


    //--------------------------------------------------------------
    // delay stage
    //--------------------------------------------------------------
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            ids_valid_q <= 1'b0;
        end else begin
            if (ex_stage_en) begin
                ids_ins_q           <= ids_ins_i;
                ids_valid_q         <= ids_valid_i;
                ids_ins_uerr_q      <= ids_ins_uerr_i;
                ids_ins_ferr_q      <= ids_ins_ferr_i;
                ids_fencei_q        <= ids_fencei_i;
                ids_wfi_q           <= ids_wfi_i;
                ids_jump_q          <= ids_jump_i;
                ids_ecall_q         <= ids_ecall_i;
                ids_trap_rtn_q      <= ids_trap_rtn_i;
                ids_trap_rtn_mode_q <= ids_trap_rtn_mode_i;
                ids_cond_q          <= ids_cond_i;
                // zone decode
                lq_wr_q   <= 1'b0;
                sq_wr_q   <= 1'b0;
                regd_wr_q <= 1'b0;
                case (ids_zone_i)
                    `RV_ZONE_LOADQ   : lq_wr_q   <= 1'b1;
                    `RV_ZONE_STOREQ  : sq_wr_q   <= 1'b1;
                    `RV_ZONE_REGFILE : regd_wr_q <= 1'b1;
                    default : begin
                    end
                endcase
                //
                ids_csr_rd_q      <= ids_csr_rd_i;
                ids_csr_wr_q      <= ids_csr_wr_i;
                ids_csr_addr_q    <= ids_csr_addr_i;
                ids_csr_wr_data_q <= ids_csr_wr_data_i;
                ids_link_q        <= ids_link_i;
                ids_pc_q          <= ids_pc_i;
                pc_inc_q          <= ids_pc_i + { { `RV_XLEN-3 {1'b0} }, ids_ins_size_i, 1'b0 };
                ids_regs2_data_q  <= ids_regs2_data_i;
                ids_regd_addr_q   <= ids_regd_addr_i;
                funct3_q          <= ids_funct3_i;
                //
                csr_rd_data_q     <= csr_rd_data_d;
                csr_badpriv_q     <= csr_badpriv_d;
                csr_badwrite_q    <= csr_badwrite_d;
                csr_badcsr_q      <= csr_badcsr_d;
            end
        end
    end


    //--------------------------------------------------------------
    // wfi latch
    //--------------------------------------------------------------
    assign sleeping_o = wfi_latch_q;
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(fclk_i, reset_i) begin
        if (reset_i) begin
            wfi_latch_q <= 1'b0;
        end else begin
            if (csr_interrupt) begin
                wfi_latch_q <= 1'b0;
            end else if (ex_stage_en) begin
                if (execute_commit & ids_wfi_q) begin
                    wfi_latch_q <= 1'b1;
                end
            end
        end
    end


    //--------------------------------------------------------------
    // ex stage stall controller
    //--------------------------------------------------------------
    assign ex_stage_en = ~exs_stall;
    //
    always @ (*) begin
        exs_stall = wfi_latch_q;
        if (execute_commit) begin
            if ( ( lsq_full_i & (lq_wr_q | sq_wr_q)) |
                 (~lsq_empty_i & ids_fencei_q) ) begin
                exs_stall = 1'b1;
            end
        end
    end


    //--------------------------------------------------------------
    // regd data out mux
    //--------------------------------------------------------------
    always @ (*) begin
        if (ids_csr_rd_q) begin
            ids_regd_data_o = csr_rd_data_q;
        end else begin
            ids_regd_data_o = alu_pcinc_mux_out;
        end
    end


    //--------------------------------------------------------------
    // alu pcinc mux
    //--------------------------------------------------------------
    always @ (*) begin
        if (ids_link_q) begin
            alu_pcinc_mux_out = pc_inc_q;
        end else begin
            alu_pcinc_mux_out = alu_data_out;
        end
    end


    //--------------------------------------------------------------
    // alu
    //--------------------------------------------------------------
    merlin_alu i_merlin_alu (
            //
            .clk_i        (clk_i),
            .stage_en_i   (ex_stage_en),
            .reset_i      (reset_i),
            //
            .op_left_i    (ids_operand_left_i),
            .op_right_i   (ids_operand_right_i),
            .op_result_o  (alu_data_out),
            .op_opcode_i  (ids_alu_op_i),
            //
            .cmp_left_i   (ids_regs1_data_i),
            .cmp_right_i  (ids_cmp_right_i),
            .cmp_result_o (alu_cmp_out),
            .cmp_opcode_i (ids_funct3_i)
        );


    //--------------------------------------------------------------
    // control and status register file
    //--------------------------------------------------------------
    merlin_cs_regs i_merlin_cs_regs (
            //
            .clk_i             (clk_i),
            .reset_i           (reset_i),
            // access request / error reporting interface
            .access_rd_i       (ids_csr_rd_i),
            .access_wr_i       (ids_csr_wr_i),
            .access_addr_i     (ids_csr_addr_i),
            .access_badcsr_o   (csr_badcsr_d),
            .access_badwrite_o (csr_badwrite_d),
            .access_badpriv_o  (csr_badpriv_d),
            .access_rd_data_o  (csr_rd_data_d),
            // write-back interface
            .wr_i              (csr_wr),
            .wr_mode_i         (csr_wr_mode),
            .wr_addr_i         (ids_csr_addr_q),
            .wr_data_i         (ids_csr_wr_data_q),
            // exception, interrupt, and hart vectoring interface
            .ex_valid_i        (ex_valid & ex_stage_en),
            .irqm_extern_i     (irqm_extern_i),
            .irqm_softw_i      (irqm_softw_i),
            .irqm_timer_i      (irqm_timer_i),
            .irqs_extern_i     (irqs_extern_i),
            .excp_ferr_i       (excp_ferr),
            .excp_uerr_i       (excp_uerr),
            .excp_maif_i       (excp_maif),
            .excp_mala_i       (excp_mala),
            .excp_masa_i       (excp_masa),
            .excp_ilgl_i       (excp_ilgl),
            .excp_ecall_i      (excp_ecall),
            .excp_pc_i         (ids_pc_q),
            .excp_ins_i        (ids_ins_q),
            //
            .interrupt_o       (csr_interrupt),
            //
            .trap_call_o       (csr_jump_to_trap),    // jump to trap
            .trap_call_addr_o  (csr_trap_entry_addr), // address to jump to
            .trap_call_cause_o (csr_trap_cause),      // cause of trap
            .trap_call_value_o (),                    // trap call value ( [m|s|u]tval )
            .trap_rtn_i        (csr_trap_rtn),        // return from trap
            .trap_rtn_mode_i   (ids_trap_rtn_mode_q), // mode of return ( [m|s|u]ret )
            .trap_rtn_addr_o   (csr_trap_rtn_addr),   // address to jump (return) to
            // static i/o
            .mode_o            (csr_mode)
        );
endmodule
