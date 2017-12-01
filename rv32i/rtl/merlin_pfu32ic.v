/*
 * Author         : Tom Stanway-Mayers
 * Description    : Pre-Fetch Unit
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module merlin_pfu32ic
    #(
        parameter C_FIFO_PASSTHROUGH = 0,
        parameter C_FIFO_DEPTH_X     = 2, // depth >= read latency + 2
        parameter C_RESET_VECTOR     = 32'b0
    )
    (
        // global
        input  wire                   clk_i,
        input  wire                   clk_en_i,
        input  wire                   resetb_i,
        // instruction cache interface
        input  wire                   ireqready_i,
        output wire                   ireqvalid_o,
        output wire             [1:0] ireqhpl_o,
        output wire            [31:0] ireqaddr_o, // TODO - consider bypassing the pc on a jump
        output wire                   irspready_o,
        input  wire                   irspvalid_i,
        input  wire                   irsprerr_i,
        input  wire            [31:0] irspdata_i,
        // decoder interface
        output wire                   ids_dav_o,      // new fetch available
        input  wire                   ids_ack_i,      // ack this fetch
        input  wire             [1:0] ids_ack_size_i, // size of this ack
        output reg  [`RV_SOFID_RANGE] ids_sofid_o,    // first fetch since vectoring
        output reg             [31:0] ids_ins_o,      // instruction fetched
        output wire                   ids_ferr_o,     // this instruction fetch resulted in error
        output wire            [31:0] ids_pc_o,       // address of this instruction
        // ex stage vectoring interface
        input  wire                   exs_pc_wr_i,
        input  wire            [31:0] exs_pc_din_i,
        // pfu stage interface
        input  wire             [1:0] exs_hpl_i
    );

    //--------------------------------------------------------------

    // interface assignments
    // request gate register
    reg                          request_gate;
    // ibus debt
    reg                          ibus_debt;
    wire                         request;
    wire                         response;
    // fifo level counter
    reg       [C_FIFO_DEPTH_X:0] fifo_level_q;
    reg                          fifo_accepting;
    // program counter
    reg                   [31:0] pc_q;
    reg                   [31:0] request_addr_q;
    // vectoring flag register
    reg                          vectoring_q;
    // sofid register
    reg                          sofid_q;
    // line fifo
    parameter C_FIFO_LINE_WIDTH = 1 + 30;
    //
    parameter C_FERR_LSB        = 30;
    parameter C_FIFO_PC_LSB     =  0;
    //
    wire                         fifo_line_rd;
    wire                         fifo_line_empty;
    wire [C_FIFO_LINE_WIDTH-1:0] fifo_line_din;
    wire [C_FIFO_LINE_WIDTH-1:0] fifo_line_dout;
    // atom fifo
    genvar                       genvar_i;
    wire                   [1:0] fifo_atom_empty;
    wire                   [1:0] fifo_atom_wr_mask;
    wire                   [1:0] fifo_atom_rd_mask;
    wire                   [1:0] fifo_atom_din_sof;
    wire                  [16:0] fifo_atom_dout[1:0];
    wire                  [15:0] fifo_atom_dout_ins[1:0];
    wire                   [1:0] fifo_atom_dout_sof;
    // base pointer
    reg                          atom_base_q;
    reg                          atom_base;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign ireqhpl_o   = exs_hpl_i;
    assign ireqvalid_o = fifo_accepting & ~exs_pc_wr_i & (~ibus_debt | response) & request_gate;
    assign ireqaddr_o  = { pc_q[31:2], 2'b0 };
    assign irspready_o = 1'b1; //irspvalid_i; // always ready
    //
    assign ids_dav_o = ~(|fifo_atom_empty);


    //--------------------------------------------------------------
    // request gate register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            request_gate <= 1'b0;
        end else if (clk_en_i) begin
            request_gate <= 1'b1;
        end
    end


    //--------------------------------------------------------------
    // ibus debt
    //--------------------------------------------------------------
    assign request  = ireqvalid_o & ireqready_i;
    assign response = irspvalid_i & irspready_o;
    //
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            ibus_debt <= 1'b0;
        end else if (clk_en_i) begin
            if (request & ~response) begin
                ibus_debt <= 1'b1;
            end else if (~request & response) begin
                ibus_debt <= 1'b0;
            end
        end
    end


    //--------------------------------------------------------------
    // fifo level counter
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            fifo_level_q <= { 1'b1, { C_FIFO_DEPTH_X {1'b0} } };
        end else if (clk_en_i) begin
            if (exs_pc_wr_i) begin
                fifo_level_q <= { 1'b1, { C_FIFO_DEPTH_X {1'b0} } };
            end else if (request & ~fifo_line_rd) begin
                fifo_level_q <= fifo_level_q - { { C_FIFO_DEPTH_X {1'b0} }, 1'b1 };
            end else if (~request & fifo_line_rd) begin
                fifo_level_q <= fifo_level_q + { { C_FIFO_DEPTH_X {1'b0} }, 1'b1 };
            end
        end
    end
    always @ (*) begin
        if (|fifo_level_q) begin
            fifo_accepting = 1'b1;
        end else begin
            fifo_accepting = 1'b0;
        end
    end


    //--------------------------------------------------------------
    // program counter
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            pc_q <= C_RESET_VECTOR;
        end else if (clk_en_i) begin
            if (exs_pc_wr_i) begin
                pc_q <= exs_pc_din_i;
            end else if (request) begin
                pc_q <= pc_q + 32'd4;
            end
        end
    end
    always @ (posedge clk_i) begin
        if (request) begin
            request_addr_q <= pc_q;
        end
    end


    //--------------------------------------------------------------
    // vectoring flag register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            vectoring_q <= 1'b0;
        end else if (clk_en_i) begin
            if (exs_pc_wr_i) begin
                vectoring_q <= 1'b1;
            end else if (request) begin
                vectoring_q <= 1'b0;
            end
        end
    end


    //--------------------------------------------------------------
    // sofid register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            sofid_q <= 1'b0;
        end else if (clk_en_i) begin
            if (vectoring_q & request) begin
                sofid_q <= 1'b1;
            end else if (response) begin
                sofid_q <= 1'b0;
            end
        end
    end


    //--------------------------------------------------------------
    // line fifo
    //--------------------------------------------------------------
    assign fifo_line_rd = ids_ack_i & (atom_base | ids_ack_size_i[1]);
    assign fifo_line_din[   C_FERR_LSB +:  1] = irsprerr_i;
    assign fifo_line_din[C_FIFO_PC_LSB +: 30] = request_addr_q[31:2];
    //
    assign ids_ferr_o    = fifo_line_dout[C_FERR_LSB +: 1];
    assign ids_pc_o      = { fifo_line_dout[C_FIFO_PC_LSB +: 30], atom_base, 1'b0 };
    //
    merlin_fifo
        #(
            .C_FIFO_PASSTHROUGH (C_FIFO_PASSTHROUGH),
            .C_FIFO_WIDTH       (C_FIFO_LINE_WIDTH),
            .C_FIFO_DEPTH_X     (C_FIFO_DEPTH_X)
        ) i_line_merlin_fifo (
            // global
            .clk_i              (clk_i),
            .clk_en_i           (clk_en_i),
            .resetb_i           (resetb_i),
            // control and status
            .flush_i            (exs_pc_wr_i | vectoring_q),
            .empty_o            (fifo_line_empty),
            .full_o             (),
            // write port
            .wr_i               (response),
            .din_i              (fifo_line_din),
            // read port
            .rd_i               (fifo_line_rd),
            .dout_o             (fifo_line_dout)
        );


    //--------------------------------------------------------------
    // atom fifo
    //--------------------------------------------------------------
    assign fifo_atom_wr_mask = { 1'b1, ~sofid_q | (sofid_q & ~request_addr_q[1]) };
    assign fifo_atom_rd_mask = { atom_base | ids_ack_size_i[1], ~atom_base | ids_ack_size_i[1] };
    assign fifo_atom_din_sof = { (sofid_q & request_addr_q[1]), (sofid_q & ~request_addr_q[1]) };
    //
    generate
    for (genvar_i = 0; genvar_i < 2; genvar_i = genvar_i + 1) begin : atom_fifo
        assign fifo_atom_dout_ins[genvar_i] = fifo_atom_dout[genvar_i][15:0];
        assign fifo_atom_dout_sof[genvar_i] = fifo_atom_dout[genvar_i][16];
        //
        merlin_fifo
            #(
                .C_FIFO_PASSTHROUGH (C_FIFO_PASSTHROUGH),
                .C_FIFO_WIDTH       (17), // <last> <first> <instruction atom>
                .C_FIFO_DEPTH_X     (C_FIFO_DEPTH_X)
            ) i_atom_merlin_fifo (
                // global
                .clk_i              (clk_i),
                .clk_en_i           (clk_en_i),
                .resetb_i           (resetb_i),
                // control and status
                .flush_i            (exs_pc_wr_i | vectoring_q),
                .empty_o            (fifo_atom_empty[genvar_i]),
                .full_o             (),
                // write port
                .wr_i               (response & fifo_atom_wr_mask[genvar_i]),
                .din_i              ({ fifo_atom_din_sof[genvar_i], irspdata_i[16*genvar_i +: 16] }),
                // read port
                .rd_i               (ids_ack_i & fifo_atom_rd_mask[genvar_i]),
                .dout_o             (fifo_atom_dout[genvar_i])
            );
    end
    endgenerate


    //--------------------------------------------------------------
    // base pointer
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i) begin
        if (~resetb_i) begin
            atom_base_q <= 1'b0; // NOTE: don't care
        end else if (ids_ack_i) begin
            if (|fifo_atom_dout_sof) begin
                if (~ids_ack_size_i[1]) begin // ack 16
                    atom_base_q <= ~fifo_atom_dout_sof[1];
                end else begin // ack 32
                    atom_base_q <= fifo_atom_dout_sof[1];
                end
            end else begin
                if (~ids_ack_size_i[1]) begin // ack 16
                    atom_base_q <= ~atom_base_q;
                end
            end
        end
    end
    //
    always @ (*) begin
        if (|fifo_atom_dout_sof) begin
            atom_base = fifo_atom_dout_sof[1];
        end else begin
            atom_base = atom_base_q;
        end
    end


    //--------------------------------------------------------------
    // instruction output mux
    //--------------------------------------------------------------
    always @ (*) begin
        if (atom_base == 1'b0) begin
            ids_ins_o = { fifo_atom_dout_ins[1], fifo_atom_dout_ins[0] };
        end else begin
            ids_ins_o = { fifo_atom_dout_ins[0], fifo_atom_dout_ins[1] };
        end

        if (|fifo_atom_dout_sof) begin
            ids_sofid_o = `RV_SOFID_JUMP;
        end else begin
            ids_sofid_o = `RV_SOFID_RUN;
        end
    end
endmodule

