// TODO can branches also cause miss-aligned instruction fetch exceptions? or
// only jumps
//

`include "riscv_defs.v"

module ex_stage
    #(
        parameter C_XLEN = 32
    )
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
        input  wire    [C_XLEN-1:0] ids_pc_i,
        input  wire  [`ALUOP_RANGE] ids_alu_op_i,
        input  wire    [C_XLEN-1:0] ids_operand_left_i,
        input  wire    [C_XLEN-1:0] ids_operand_right_i,
        input  wire    [C_XLEN-1:0] ids_regs1_data_i,
        input  wire    [C_XLEN-1:0] ids_regs2_data_i,
        input  wire           [4:0] ids_regd_addr_i,
        input  wire           [2:0] ids_funct3_i,
        input  wire                 ids_csr_access_i,
        input  wire          [11:0] ids_csr_addr_i,
        input  wire    [C_XLEN-1:0] ids_csr_wr_data_i,
            // write-back interface
        output reg                  ids_regd_cncl_load_o,
        output reg                  ids_regd_wr_o,
        output wire           [4:0] ids_regd_addr_o,
        output reg     [C_XLEN-1:0] ids_regd_data_o,
        // hart vectoring and exception controller interface TODO
        output wire                 hvec_ferr_o,
        output wire                 hvec_uerr_o,
        output wire                 hvec_maif_o,
        output wire                 hvec_ldx0_o,
        output wire                 hvec_ilgl_o,
        output wire                 hvec_jump_o,
        output wire    [C_XLEN-1:0] hvec_jump_addr_o,
        // load/store queue interface
        input  wire                 lsq_full_i,
        output reg                  lsq_lq_wr_o,
        output reg                  lsq_sq_wr_o,
        output wire           [2:0] lsq_funct3_o,
        output wire           [4:0] lsq_regd_addr_o,
        output wire    [C_XLEN-1:0] lsq_regs2_data_o,
        output wire    [C_XLEN-1:0] lsq_addr_o
    );

    //--------------------------------------------------------------

    // instruction specific exceptions
    wire                commit_gating_exception;
    wire                excp_ferr;
    wire                excp_uerr;
    wire                excp_maif;
    reg                 excp_load_x0;
    wire                excp_csr_illegal_access;
    // ex stage qualifier logic
    wire                ex_valid;
    wire                execute;
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
    reg                 ids_csr_access_q;
    reg          [11:0] ids_csr_addr_q;
    reg    [C_XLEN-1:0] ids_csr_wr_data_q;
    reg                 link_q;
    reg    [C_XLEN-1:0] pc_inc_q;
    reg    [C_XLEN-1:0] regs2_data_q;
    reg           [4:0] regd_addr_q;
    reg           [2:0] funct3_q;
    reg                 csr_illegal_rd_q;
    // ex stage stall controller
    wire                ex_stage_en;
    reg                 exs_stall;
    // regd data out mux
    // alu pcinc mux
    reg    [C_XLEN-1:0] alu_pcinc_mux_out;
    // alu
    wire   [C_XLEN-1:0] alu_data_out;
    wire                alu_cmp_out;
    // cs registers
    wire                csr_rd;
    wire                csr_wr;
    wire   [C_XLEN-1:0] csr_data_out;
    wire                csr_illegal_rd;
    wire                csr_illegal_wr;

    //--------------------------------------------------------------

    // interface assignments
    assign ids_stall_o          = exs_stall;
    assign ids_regd_cncl_load_o = ex_stage_en & ~execute_commit & ids_valid_q & lq_wr_q;
    assign ids_regd_wr_o        = ex_stage_en &  execute_commit & regd_wr_q;
    assign ids_regd_addr_o      = regd_addr_q;
    //
    assign hvec_ferr_o      = ex_stage_en & excp_ferr;
    assign hvec_uerr_o      = ex_stage_en & excp_uerr;
    assign hvec_maif_o      = ex_stage_en & excp_maif;
    assign hvec_ldx0_o      = ex_stage_en & excp_load_x0;
    assign hvec_ilgl_o      = ex_stage_en & excp_csr_illegal_access;
        //
    assign hvec_jump_o      = ex_stage_en & execute_commit & ids_jump_q;
    assign hvec_jump_addr_o = alu_data_out;
    //
    assign lsq_lq_wr_o      = ex_stage_en & execute_commit & lq_wr_q;
    assign lsq_sq_wr_o      = ex_stage_en & execute_commit & sq_wr_q;
    assign lsq_funct3_o     = funct3_q;
    assign lsq_regd_addr_o  = regd_addr_q;
    assign lsq_regs2_data_o = regs2_data_q;
    assign lsq_addr_o       = alu_data_out;


    // instruction specific exceptions
    //
    assign commit_gating_exception = excp_ferr |
                                     excp_uerr |
                                     excp_maif |
                                     excp_csr_illegal_access;
    //
    assign excp_ferr = execute & ids_ins_ferr_q;
    assign excp_uerr = execute & ids_ins_uerr_q;
    assign excp_maif = execute & ids_jump_q & (|(alu_data_out[1:0])); // TODO this will change for compressed instructions
    //
    always @ (*) begin // ex_load_x0 is not a commit gating exception
        excp_load_x0 = 1'b0;
        if (execute && lq_wr_q && regd_addr_q == 5'b0) begin
            excp_load_x0 = 1'b1;
        end
    end
    //
    assign excp_csr_illegal_access = execute & (csr_illegal_rd_q | csr_illegal_wr);


    // ex stage qualifier logic
    //
    assign ex_valid       = ids_valid_q & (alu_cmp_out | ~ids_cond_q);
    assign execute        = ex_valid & sofid_run;
    assign execute_commit = execute & ~commit_gating_exception;
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
                ids_csr_access_q  <= ids_csr_access_i;
                ids_csr_addr_q    <= ids_csr_addr_i;
                ids_csr_wr_data_q <= ids_csr_wr_data_i;
                link_q            <= ids_link_i;
                pc_inc_q          <= ids_pc_i + 4; // TODO for compressed instructions this may change
                regs2_data_q      <= ids_regs2_data_i;
                regd_addr_q       <= ids_regd_addr_i;
                funct3_q          <= ids_funct3_i;
                csr_illegal_rd_q  <= csr_illegal_rd;
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
        if (ids_csr_access_q) begin
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
    alu
        #(
            .C_XLEN       (C_XLEN)
        ) i_alu (
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
    assign csr_rd = ids_csr_access_i;// & ex_stage_en & ids_valid_i;
    assign csr_wr = ids_csr_access_q & ex_stage_en & execute;
    //
    cs_registers
        #(
            .C_XLEN           (C_XLEN)
        ) i_cs_registers (
            //
            .clk_i            (clk_i),
            .clk_en_i         (clk_en_i & ex_stage_en),
            .resetb_i         (resetb_i),
            // read/write interface
            .rd_i             (csr_rd),
            .rd_addr_i        (ids_csr_addr_i),
            .rd_data_o        (csr_data_out),
            .wr_i             (csr_wr), // the write will be ignored if it triggers an exception
            .wr_addr_i        (ids_csr_addr_q),
            .wr_data_i        (ids_csr_wr_data_q),
            // static i/o
            .illegal_rd_o     (csr_illegal_rd), // this o/p is valid in the same cycle as the request
            .illegal_wr_o     (csr_illegal_wr), // this o/p is valid in the same cycle as the request
            .hpl_o            (pfu_hpl_o)
        );
endmodule
