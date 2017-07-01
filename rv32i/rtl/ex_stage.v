// TODO can branches also cause miss-aligned instruction fetch exceptions? or
// only jumps
//

`include "riscv_defs.v"

module ex_stage
    (
        // global
        input  wire                 clk_i,
        input  wire                 clk_en_i,
        input  wire                 resetb_i,
        // pfu stage interface
        output wire           [1:0] pfu_hpl_o,
        // instruction decoder stage interface
        input  wire                 ids_valid_i,
        output wire                 ids_stall_o,
        input  wire  [`SOFID_RANGE] ids_sofid_i,
        input  wire                 ids_ins_uerr_i,
        input  wire                 ids_ins_ferr_i,
        input  wire                 ids_jump_i,
        input  wire                 ids_cond_i,
        input  wire   [`ZONE_RANGE] ids_zone_i,
        input  wire                 ids_link_i,
        input  wire  [`RV_XLEN-1:0] ids_pc_i,
        input  wire  [`ALUOP_RANGE] ids_alu_op_i,
        input  wire  [`RV_XLEN-1:0] ids_operand_left_i,
        input  wire  [`RV_XLEN-1:0] ids_operand_right_i,
        input  wire  [`RV_XLEN-1:0] ids_regs1_data_i,
        input  wire  [`RV_XLEN-1:0] ids_regs2_data_i,
        input  wire           [4:0] ids_regd_addr_i,
        input  wire           [2:0] ids_funct3_i,
        input  wire                 ids_csr_rd_i,
        input  wire                 ids_csr_wr_i,
        input  wire          [11:0] ids_csr_addr_i,
        input  wire  [`RV_XLEN-1:0] ids_csr_wr_data_i,
            // write-back interface
        output wire                 ids_regd_cncl_load_o,
        output wire                 ids_regd_wr_o,
        output wire           [4:0] ids_regd_addr_o,
        output reg   [`RV_XLEN-1:0] ids_regd_data_o,
        // hart vectoring and exception controller interface TODO
        output wire                 hvec_ferr_o, // instruction fetch error
        output wire                 hvec_uerr_o, // undefined instruction
        output wire                 hvec_maif_o, // missaligned instruction fetch
        output wire                 hvec_mala_o, // missaligned load address
        output wire                 hvec_masa_o, // missaligned store address
        output wire                 hvec_ilgl_o, // illegal instruction
        output wire                 hvec_jump_o,
        output wire  [`RV_XLEN-1:0] hvec_jump_addr_o,
        // load/store queue interface
        input  wire                 lsq_full_i,
        output wire                 lsq_lq_wr_o,
        output wire                 lsq_sq_wr_o,
        output wire           [2:0] lsq_funct3_o,
        output wire           [4:0] lsq_regd_addr_o,
        output wire  [`RV_XLEN-1:0] lsq_regs2_data_o,
        output wire  [`RV_XLEN-1:0] lsq_addr_o
    );

    //--------------------------------------------------------------

    // interface assignments
    // execute commit signals
    wire                csr_wr;
    // instruction specific exceptions
    wire                commit_gating_exception;
    wire                excp_ferr;
    wire                excp_uerr;
    wire                excp_maif;
    reg                 excp_mala;
    reg                 excp_masa;
    wire                excp_csr_illegal_access;
    // ex stage qualifier logic
    wire                ex_valid;
    wire                execute_commit;
    reg  [`SOFID_RANGE] sofid_q;
    reg                 sofid_run;
    // delay stage
    reg                 ids_valid_q;
    reg                 ids_ins_uerr_q;
    reg                 ids_ins_ferr_q;
    reg                 ids_jump_q;
    reg                 ids_cond_q;
    reg                 lq_wr_q;
    reg                 sq_wr_q;
    reg                 regd_wr_q;
    reg                 ids_csr_rd_q;
    reg                 ids_csr_wr_q;
    reg          [11:0] ids_csr_addr_q;
    reg  [`RV_XLEN-1:0] ids_csr_wr_data_q;
    reg                 link_q;
    reg  [`RV_XLEN-1:0] pc_inc_q;
    reg  [`RV_XLEN-1:0] regs2_data_q;
    reg           [4:0] regd_addr_q;
    reg           [2:0] funct3_q;
    // ex stage stall controller
    wire                ex_stage_en;
    reg                 exs_stall;
    // regd data out mux
    // alu pcinc mux
    reg  [`RV_XLEN-1:0] alu_pcinc_mux_out;
    // alu
    wire [`RV_XLEN-1:0] alu_data_out;
    wire                alu_cmp_out;
    // cs registers
    wire [`RV_XLEN-1:0] csr_data_out;
    wire                csr_rd_illegal;
    wire                csr_wr_illegal;

    //--------------------------------------------------------------

    // interface assignments
    assign ids_stall_o      = exs_stall;
    assign ids_regd_addr_o  = regd_addr_q;
    //
    assign hvec_ferr_o      = ex_stage_en & excp_ferr;
    assign hvec_uerr_o      = ex_stage_en & excp_uerr;
    assign hvec_maif_o      = ex_stage_en & excp_maif;
    assign hvec_mala_o      = ex_stage_en & excp_mala;
    assign hvec_masa_o      = ex_stage_en & excp_masa;
    assign hvec_ilgl_o      = ex_stage_en & excp_csr_illegal_access;
        //
    assign hvec_jump_addr_o = alu_data_out;
    //
    assign lsq_funct3_o     = funct3_q;
    assign lsq_regd_addr_o  = regd_addr_q;
    assign lsq_regs2_data_o = regs2_data_q;
    assign lsq_addr_o       = alu_data_out;


    // execute commit signals
    //
    assign hvec_jump_o = ex_stage_en & execute_commit & ids_jump_q;
    //
    assign ids_regd_cncl_load_o = ex_stage_en & ~execute_commit & ids_valid_q & lq_wr_q;
    assign ids_regd_wr_o        = ex_stage_en &  execute_commit & regd_wr_q;
    //
    assign lsq_lq_wr_o = ex_stage_en & execute_commit & lq_wr_q;
    assign lsq_sq_wr_o = ex_stage_en & execute_commit & sq_wr_q;
    //
    assign csr_wr = ex_stage_en & execute_commit & ids_csr_wr_q;


    // instruction specific exceptions
    //
    assign commit_gating_exception = excp_ferr |
                                     excp_uerr |
                                     excp_maif |
                                     excp_mala |
                                     excp_masa |
                                     excp_csr_illegal_access;
    //
    assign excp_ferr = ex_valid & ids_ins_ferr_q;
    assign excp_uerr = ex_valid & ids_ins_uerr_q;
    assign excp_maif = ex_valid & ids_jump_q & (|(alu_data_out[1:0])); // TODO this will change for compressed instructions
    //
    always @ (*)
    begin
        excp_mala = 1'b0;
        excp_masa = 1'b0;
        if (ex_valid) begin
            if (funct3_q == 3'b001 && alu_data_out[0] != 1'b0) begin
                excp_mala = lq_wr_q;
                excp_masa = sq_wr_q;
            end else if (funct3_q == 3'b010 && alu_data_out[1:0] != 2'b00) begin
                excp_mala = lq_wr_q;
                excp_masa = sq_wr_q;
            end
        end
    end
    //
    assign excp_csr_illegal_access = ex_valid & ((csr_rd_illegal & ids_csr_rd_q) | (csr_wr_illegal & ids_csr_wr_q));


    // ex stage qualifier logic
    //
    assign ex_valid       = ids_valid_q & sofid_run & (alu_cmp_out | ~ids_cond_q);
    assign execute_commit = ex_valid & ~commit_gating_exception;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            sofid_q <= `SOFID_RUN;
        end else if (clk_en_i) begin
            if (ex_stage_en) begin
                if (ex_valid & ids_jump_q) begin
                    sofid_q <= `SOFID_JUMP;
                end else if (ids_valid_i && ids_sofid_i == sofid_q) begin
                    sofid_q <= `SOFID_RUN;
                end
            end
        end
    end
    always @ (*)
    begin
        if (sofid_q == `SOFID_RUN) begin
            sofid_run = 1'b1;
        end else begin
            sofid_run = 1'b0;
        end
    end


    // delay stage
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            ids_valid_q <= 1'b0;
        end else if (clk_en_i) begin
            if (ex_stage_en) begin
                ids_valid_q    <= ids_valid_i;
                ids_ins_uerr_q <= ids_ins_uerr_i;
                ids_ins_ferr_q <= ids_ins_ferr_i;
                ids_jump_q     <= ids_jump_i;
                ids_cond_q     <= ids_cond_i;
                // zone decode
                lq_wr_q   <= 1'b0;
                sq_wr_q   <= 1'b0;
                regd_wr_q <= 1'b0;
                case (ids_zone_i)
                    `ZONE_LOADQ   : lq_wr_q   <= 1'b1;
                    `ZONE_STOREQ  : sq_wr_q   <= 1'b1;
                    `ZONE_REGFILE : regd_wr_q <= 1'b1;
                endcase
                //
                ids_csr_rd_q      <= ids_csr_rd_i;
                ids_csr_wr_q      <= ids_csr_wr_i;
                ids_csr_addr_q    <= ids_csr_addr_i;
                ids_csr_wr_data_q <= ids_csr_wr_data_i;
                link_q            <= ids_link_i;
                pc_inc_q          <= ids_pc_i + 4; // TODO for compressed instructions this may change
                regs2_data_q      <= ids_regs2_data_i;
                regd_addr_q       <= ids_regd_addr_i;
                funct3_q          <= ids_funct3_i;
            end
        end
    end


    // ex stage stall controller
    //
    assign ex_stage_en = ~exs_stall;
    //
    always @ (*)
    begin
        exs_stall = 1'b0;
        if (execute_commit) begin
            if (lsq_full_i & (lq_wr_q | sq_wr_q)) begin
                exs_stall = 1'b1;
            end
        end
    end


    // regd data out mux
    //
    always @ (*)
    begin
        if (ids_csr_rd_q) begin
            ids_regd_data_o = csr_data_out;
        end else begin
            ids_regd_data_o = alu_pcinc_mux_out;
        end
    end


    // alu pcinc mux
    //
    always @ (*)
    begin
        if (link_q) begin
            alu_pcinc_mux_out = pc_inc_q;
        end else begin
            alu_pcinc_mux_out = alu_data_out;
        end
    end


    // alu
    //
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
            .cmp_right_i  (ids_regs2_data_i),
            .cmp_result_o (alu_cmp_out),
            .cmp_opcode_i (ids_funct3_i)
        );


    // cs registers
    //
    cs_registers i_cs_registers (
            //
            .clk_i              (clk_i),
            .clk_en_i           (clk_en_i),
            .resetb_i           (resetb_i),
            // read and exception query interface
            .rd_i               (ids_csr_rd_i),
            .rd_addr_i          (ids_csr_addr_i),
            .rd_data_o          (csr_data_out),
            .rd_illegal_rd_o    (csr_rd_illegal),
            .rd_illegal_wr_o    (csr_wr_illegal),
            // write-back interface
            .wr_i               (csr_wr),
            .wr_addr_i          (ids_csr_addr_q),
            .wr_data_i          (ids_csr_wr_data_q),
            // static i/o
            .hpl_o              (pfu_hpl_o)
        );
endmodule
