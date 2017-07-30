/*
 * Author         : Tom Stanway-Mayers
 * Description    : Execute Stage
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

// TODO can branches also cause miss-aligned instruction fetch exceptions? or
// only jumps
`include "riscv_defs.v"

module ex_stage
    (
        // global
        input  wire                     clk_i,
        input  wire                     clk_en_i,
        input  wire                     resetb_i,
        // external interface
        input  wire                     irqm_extern_i,
        input  wire                     irqm_softw_i,
        input  wire                     irqm_timer_i,
        input  wire                     irqs_extern_i,
        input  wire                     irqs_softw_i,
        input  wire                     irqs_timer_i,
        input  wire                     irqu_extern_i,
        input  wire                     irqu_softw_i,
        input  wire                     irqu_timer_i,
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
        output wire      [`RV_XLEN-1:0] lsq_addr_o
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
    reg     [`RV_XLEN-1:0] csr_wr_data;
    wire    [`RV_XLEN-1:0] csr_data_out;
    wire                   csr_bad_addr;
    wire                   csr_readonly;
    wire                   csr_priv_too_low;
    wire                   csr_jump_to_trap;
    wire    [`RV_XLEN-1:0] csr_trap_entry_addr;
    wire    [`RV_XLEN-1:0] csr_trap_rtn_addr;
    wire             [1:0] csr_mode;

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


    //--------------------------------------------------------------
    // hart vectoring logic
    //--------------------------------------------------------------
    assign jump = (execute_commit & (ids_jump_q | ids_trap_rtn_q | ids_fencei_q)) | csr_jump_to_trap;
    //
    always @ (*)
    begin
        if (csr_jump_to_trap) begin
            pfu_jump_addr_o = csr_trap_entry_addr;
        end else if (ids_trap_rtn_q) begin
            pfu_jump_addr_o = csr_trap_rtn_addr;
        end else if (ids_fencei_q) begin
            pfu_jump_addr_o = pc_inc_q;
        end else begin
            pfu_jump_addr_o = alu_data_out;
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
    assign csr_wr       = execute_commit & ids_csr_wr_q;
    assign csr_wr_mode  = funct3_q[1:0];
    assign csr_trap_rtn = execute_commit & ids_trap_rtn_q;


    //--------------------------------------------------------------
    // exception signaling logic
    //--------------------------------------------------------------
    assign excp_ecall = ids_ecall_q;
    assign excp_ferr  = ids_ins_ferr_q;
    assign excp_uerr  = ids_ins_uerr_q;
    assign excp_maif  = ids_jump_q & (|(alu_data_out[1:0])); // TODO this will change for compressed instructions
    //
    always @ (*)
    begin
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
    always @ (*)
    begin
        excp_ilgl = 1'b0;
        if (ids_csr_rd_q) begin
            excp_ilgl = csr_bad_addr | csr_priv_too_low;
        end
        //
        if (ids_csr_wr_q) begin
            excp_ilgl = csr_bad_addr | csr_priv_too_low | csr_readonly;
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
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            sofid_q <= `RV_SOFID_RUN;
        end else if (clk_en_i) begin
            if (ex_stage_en) begin
                if (jump) begin
                    sofid_q <= `RV_SOFID_JUMP;
                end else if (ids_valid_i && ids_sofid_i == sofid_q) begin
                    sofid_q <= `RV_SOFID_RUN;
                end
            end
        end
    end
    always @ (*)
    begin
        if (sofid_q == `RV_SOFID_RUN) begin
            sofid_run = 1'b1;
        end else begin
            sofid_run = 1'b0;
        end
    end


    //--------------------------------------------------------------
    // delay stage
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            ids_valid_q <= 1'b0;
        end else if (clk_en_i) begin
            if (ex_stage_en) begin
                ids_ins_q           <= ids_ins_i;
                ids_valid_q         <= ids_valid_i;
                ids_ins_uerr_q      <= ids_ins_uerr_i;
                ids_ins_ferr_q      <= ids_ins_ferr_i;
                ids_fencei_q        <= ids_fencei_i;
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
            end
        end
    end


    //--------------------------------------------------------------
    // ex stage stall controller
    //--------------------------------------------------------------
    assign ex_stage_en = ~exs_stall;
    //
    always @ (*)
    begin
        exs_stall = 1'b0;
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
    always @ (*)
    begin
        if (ids_csr_rd_q) begin
            ids_regd_data_o = csr_data_out;
        end else begin
            ids_regd_data_o = alu_pcinc_mux_out;
        end
    end


    //--------------------------------------------------------------
    // alu pcinc mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (ids_link_q) begin
            alu_pcinc_mux_out = pc_inc_q;
        end else begin
            alu_pcinc_mux_out = alu_data_out;
        end
    end


    //--------------------------------------------------------------
    // alu
    //--------------------------------------------------------------
    alu i_alu (
            //
            .clk_i        (clk_i),
            .clk_en_i     (clk_en_i & ex_stage_en),
            .resetb_i     (resetb_i),
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
    // cs register file and write data logic
    //--------------------------------------------------------------
    always @ (*)
    begin
        csr_wr_data = ids_csr_wr_data_q;
        case (csr_wr_mode)
            2'b01 : csr_wr_data = ids_csr_wr_data_q;
            2'b10 : csr_wr_data = csr_data_out |  ids_csr_wr_data_q;
            2'b11 : csr_wr_data = csr_data_out & ~ids_csr_wr_data_q;
            default : begin
            end
        endcase;
    end
    //
    cs_registers i_cs_registers (
            //
            .clk_i             (clk_i),
            .clk_en_i          (clk_en_i),
            .resetb_i          (resetb_i),
            //
            .exs_en_i          (ex_stage_en),
            // access request / error reporting interface
            .access_i          (ids_csr_rd_i | ids_csr_wr_i),
            .addr_i            (ids_csr_addr_i),
            .bad_csr_addr_o    (csr_bad_addr),
            .readonly_csr_o    (csr_readonly),
            .priv_too_low_o    (csr_priv_too_low),
            .rd_data_o         (csr_data_out),
            // write-back interface
            .wr_i              (csr_wr),
            .wr_addr_i         (ids_csr_addr_q),
            .wr_data_i         (csr_wr_data),
            // exception, interrupt, and hart vectoring interface
            .ex_valid_i        (ex_valid),
            .irqm_extern_i     (irqm_extern_i),
            .irqm_softw_i      (irqm_softw_i),
            .irqm_timer_i      (irqm_timer_i),
            .irqs_extern_i     (irqs_extern_i),
            .irqs_softw_i      (irqs_softw_i),
            .irqs_timer_i      (irqs_timer_i),
            .irqu_extern_i     (irqu_extern_i),
            .irqu_softw_i      (irqu_softw_i),
            .irqu_timer_i      (irqu_timer_i),
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
            .jump_to_trap_o    (csr_jump_to_trap),
            .trap_entry_addr_o (csr_trap_entry_addr),
            .trap_rtn_i        (csr_trap_rtn),
            .trap_rtn_mode_i   (ids_trap_rtn_mode_q),
            .trap_rtn_addr_o   (csr_trap_rtn_addr),
            // static i/o
            .mode_o            (csr_mode)
        );
endmodule
