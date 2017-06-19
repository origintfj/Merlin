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
        input  logic                ids_dav_i, // TODO
        output logic                ids_ack_o, // TODO
        input  logic                ids_cond_i, // TODO
        input  t_zone               ids_zone_i,
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
        output logic                hvec_vec_strobe_o,
        output logic   [C_XLEN-1:0] hvec_vec_o,
        output logic   [C_XLEN-1:0] hvec_pc_o,
        // load/store queue interface
        input  logic                lsq_lq_full_i, // TODO
        output reg                  lsq_lq_wr_o,
        output reg                  lsq_sq_wr_o,
        output wire           [2:0] lsq_funct3_o,
        output wire           [4:0] lsq_regd_addr_o,
        output wire    [C_XLEN-1:0] lsq_regs2_data_o,
        output wire    [C_XLEN-1:0] lsq_addr_o
    );

    //--------------------------------------------------------------

    // delay stage
    reg               csr_access_q;
    reg               link_q;
    reg  [C_XLEN-1:0] pc_inc_q;
    reg  [C_XLEN-1:0] regs2_data_q;
    reg         [4:0] regd_addr_q;
    reg         [2:0] funct3_q;
    // regd data out mux
    // alu pcinc mux
    reg  [C_XLEN-1:0] alu_pcinc_mux_out;
    // alu
    wire [C_XLEN-1:0] alu_data_out;
    // cs registers
    wire [C_XLEN-1:0] csr_data_out;


    //--------------------------------------------------------------

    assign ids_regd_addr_o  = regd_addr_q;
    //
    assign lsq_funct3_o     = funct3_q;
    assign lsq_regd_addr_o  = regd_addr_q;
    assign lsq_regs2_data_o = regs2_data_q;
    assign lsq_addr_o       = alu_data_out;

    // delay stage
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            lsq_lq_wr_o   <= 1'b0;
            lsq_sq_wr_o   <= 1'b0;
            ids_regd_wr_o <= 1'b0;
        end else if (clk_en_i) begin
            // zone decode
            lsq_lq_wr_o   <= 1'b0;
            lsq_sq_wr_o   <= 1'b0;
            ids_regd_wr_o <= 1'b0;
            case (ids_zone_i)
                ZONE_LOADQ   : lsq_lq_wr_o   <= 1'b1;
                ZONE_STOREQ  : lsq_sq_wr_o   <= 1'b1;
                ZONE_REGFILE : ids_regd_wr_o <= 1'b1;
            endcase
            //
            csr_access_q <= isd_csr_access_i;
            link_q       <= ids_link_i;
            pc_inc_q     <= ids_pc_i + 4; // TODO for compressed instructions this will change
            regs2_data_q <= ids_regs2_data_i;
            regd_addr_q  <= ids_regd_addr_i;
            funct3_q     <= ids_funct3_i;
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
    alu alu_i
        #(
            .C_XLEN       (C_XLEN)
        )
        (
            //
            .clk_i        (clk_i),
            .clk_en_i     (clk_en_i),
            .resetb_i     (resetb_i),
            //
            .op_left_i    (ids_operand_left_i),
            .op_right_i   (ids_operand_right_i),
            .op_result_o  (alu_data_out),
            .op_opcode_i  (ids_alu_op_i),
            //
            .cmp_left_i   (ids_regs1_data_i),
            .cmp_right_i  (ids_regs2_data_i),
            .cmp_result_o (), // TODO
            .cmp_opcode_i (ids_funct3_i)
        );


    // cs registers
    //
    cs_registers cs_registers_i
        (
            //
            .clk_i        (clk_i),
            .clk_en_i     (clk_en_i),
            .resetb_i     (resetb_i),
            // read/write interface
            .access_i     (ids_csr_access_i),
            .addr         (ids_csr_addr_i),
            .din          (ids_csr_wr_data_i),
            .dout         (csr_data_out)
            // static i/o
        );
endmodule
