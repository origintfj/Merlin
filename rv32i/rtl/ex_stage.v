module ex_stage
    #(
        parameter C_XLEN = 32
    )
    (
        // global
        input  wire                 clk_i,
        input  wire                 clk_en_i,
        input  wire                 resetb_i,
        // instruction decoder stage interface
        input  wire                 ids_valid_i,
        output wire                 ids_stall_o,
        input  wire                 ids_sofr_i, // TODO
        input  wire                 ids_ins_uerr_i, // TODO
        input  wire                 ids_ins_ferr_i, // TODO
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
        output reg                  ids_regd_wr_o,
        output wire           [4:0] ids_regd_addr_o,
        output reg     [C_XLEN-1:0] ids_regd_data_o,
        // hart vectoring and exception controller interface TODO
        output wire                 hvec_jump_o,
        output wire    [C_XLEN-1:0] hvec_jump_addr_o,
/*
        output logic                hvec_vec_strobe_o,
        output logic   [C_XLEN-1:0] hvec_vec_o,
        output logic   [C_XLEN-1:0] hvec_pc_o,
*/
        // load/store queue interface
        input  wire                 lsq_lq_full_i, // TODO
        output reg                  lsq_lq_wr_o,
        output reg                  lsq_sq_wr_o,
        output wire           [2:0] lsq_funct3_o,
        output wire           [4:0] lsq_regd_addr_o,
        output wire    [C_XLEN-1:0] lsq_regs2_data_o,
        output wire    [C_XLEN-1:0] lsq_addr_o
    );

    //--------------------------------------------------------------

    // ex stage qualifier logic
    wire              ex_commit;
    // delay stage
    reg               ids_valid_q;
    reg               ids_jump_q; // TODO use this signal
    reg               ids_cond_q;
    reg               lq_wr_q;
    reg               sq_wr_q;
    reg               regd_wr_q;
    reg               csr_access_q;
    reg               link_q;
    reg  [C_XLEN-1:0] pc_inc_q;
    reg  [C_XLEN-1:0] regs2_data_q;
    reg         [4:0] regd_addr_q;
    reg         [2:0] funct3_q;
    // ex stage stall controller
    wire              ex_stage_en;
    reg               exs_stall;
    // regd data out mux
    // alu pcinc mux
    reg  [C_XLEN-1:0] alu_pcinc_mux_out;
    // alu
    wire [C_XLEN-1:0] alu_data_out;
    wire              alu_cond_out;
    // cs registers
    wire              csr_access;
    wire [C_XLEN-1:0] csr_data_out;


    //--------------------------------------------------------------

    // interface assignments
    assign ids_stall_o      = exs_stall;
    assign ids_regd_addr_o  = regd_addr_q;
    //
    assign hvec_jump_o      = ex_commit & ids_jump_q;
    assign hvec_jump_addr_o = alu_data_out;
    //
    assign lsq_funct3_o     = funct3_q;
    assign lsq_regd_addr_o  = regd_addr_q;
    assign lsq_regs2_data_o = regs2_data_q;
    assign lsq_addr_o       = alu_data_out;


    // ex stage qualifier logic
    //
    assign ex_commit = ex_stage_en & ids_valid_q & (alu_cond_out | ~ids_cond_q);


    // delay stage
    //
    assign lsq_lq_wr_o   = ex_commit & lq_wr_q;
    assign lsq_sq_wr_o   = ex_commit & sq_wr_q;
    assign ids_regd_wr_o = ex_commit & regd_wr_q;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            ids_valid_q <= 1'b0;
        end else if (clk_en_i) begin
            if (ex_stage_en) begin
                ids_valid_q <= ids_valid_i;
                ids_jump_q  <= ids_jump_i;
                ids_cond_q  <= ids_cond_i;
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
                csr_access_q <= ids_csr_access_i;
                link_q       <= ids_link_i;
                pc_inc_q     <= ids_pc_i + 4; // TODO for compressed instructions this may change
                regs2_data_q <= ids_regs2_data_i;
                regd_addr_q  <= ids_regd_addr_i;
                funct3_q     <= ids_funct3_i;
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
        if (lsq_lq_full_i) begin
            if (lq_wr_q | sq_wr_q) begin
                exs_stall = 1'b1;
            end
        end
    end


    // regd data out mux
    //
    always @ (*)
    begin
        if (csr_access_q) begin
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
            .cmp_result_o (alu_cond_out),
            .cmp_opcode_i (ids_funct3_i)
        );


    // cs registers
    //
    assign csr_access = ids_csr_access_i & ids_valid_i;
    //
    cs_registers
        #(
            .C_XLEN       (C_XLEN)
        ) i_cs_registers (
            //
            .clk_i        (clk_i),
            .clk_en_i     (clk_en_i & ex_stage_en),
            .resetb_i     (resetb_i),
            // read/write interface
            .access_i     (csr_access),
            .addr_i       (ids_csr_addr_i),
            .data_i       (ids_csr_wr_data_i),
            .data_o       (csr_data_out)
            // static i/o
        );
endmodule
