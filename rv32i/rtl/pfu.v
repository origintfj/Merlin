/*
 * Author         : Tom Stanway-Mayers
 * Description    : Pre-Fetch Unit
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module pfu
    #(
        parameter C_FIFO_DEPTH_X = 2, // depth >= read latency + 2
        parameter C_RESET_VECTOR = { `RV_XLEN {1'b0} }
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
        output wire    [`RV_XLEN-1:0] ireqaddr_o, // TODO - consider bypassing the pc on a jump
        output wire                   irspready_o,
        input  wire                   irspvalid_i,
        input  wire                   irsprerr_i,
        input  wire    [`RV_XLEN-1:0] irspdata_i,
        // decoder interface
        output wire                   ids_dav_o,      // new fetch available
        input  wire                   ids_ack_i,      // ack this fetch
        input  wire             [1:0] ids_ack_size_i, // size of this ack TODO
        output wire [`RV_SOFID_RANGE] ids_sofid_o,    // first fetch since vectoring
        output wire            [31:0] ids_ins_o,      // instruction fetched
        output wire                   ids_ferr_o,     // this instruction fetch resulted in error
        output wire    [`RV_XLEN-1:0] ids_pc_o,       // address of this instruction
        // ex stage vectoring interface
        input  wire                   exs_pc_wr_i,
        input  wire    [`RV_XLEN-1:0] exs_pc_din_i,
        // pfu stage interface
        input  wire             [1:0] exs_hpl_i
    );

    //--------------------------------------------------------------

    // interface assignments
    // ibus debt
    reg                     ibus_debt;
    wire                    request;
    wire                    response;
    // fifo level counter
    reg  [C_FIFO_DEPTH_X:0] fifo_level_q;
    reg                     fifo_accepting;
    // program counter
    reg      [`RV_XLEN-1:0] pc_q;
    reg      [`RV_XLEN-1:0] request_addr_q;
    // vectoring flag register
    reg                     vectoring_q;
    // sofid register
    reg   [`RV_SOFID_RANGE] sofid_q;
    // fifo
    parameter C_SOFID_SZ     = `RV_SOFID_SZ;
    parameter C_FIFO_WIDTH   = C_SOFID_SZ + 1 + `RV_XLEN + `RV_XLEN;
    //
    parameter C_SOFID_LSB    = 1 + 2 * `RV_XLEN;
    parameter C_FERR_LSB     =     2 * `RV_XLEN;
    parameter C_FIFO_PC_LSB  =         `RV_XLEN;
    parameter C_FIFO_INS_LSB =                0;
    //
    wire                    fifo_empty;
    wire [C_FIFO_WIDTH-1:0] fifo_din;
    wire [C_FIFO_WIDTH-1:0] fifo_dout;
    wire     [`RV_XLEN-1:0] fifo_dout_data;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign ireqhpl_o   = exs_hpl_i;
    assign ireqvalid_o = fifo_accepting & ~exs_pc_wr_i & (~ibus_debt | response);
    assign ireqaddr_o  = { pc_q[`RV_XLEN-1:`RV_XLEN_X-3], { `RV_XLEN_X-3 {1'b0} } };
    assign irspready_o = 1'b1; //irspvalid_i; // always ready
    //
    assign ids_dav_o = ~fifo_empty;
    assign ids_ins_o =  fifo_dout_data[31:0];


    //--------------------------------------------------------------
    // ibus debt
    //--------------------------------------------------------------
    assign request  = ireqvalid_o & ireqready_i;
    assign response = irspvalid_i & irspready_o;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
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
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            fifo_level_q <= { 1'b1, { C_FIFO_DEPTH_X {1'b0} } };
        end else if (clk_en_i) begin
//*
            if (exs_pc_wr_i) begin
                fifo_level_q <= { 1'b1, { C_FIFO_DEPTH_X {1'b0} } };
            end else
/**/
            if (request & ~ids_ack_i) begin
                fifo_level_q <= fifo_level_q - { { C_FIFO_DEPTH_X {1'b0} }, 1'b1 };
            end else if (~request & ids_ack_i) begin
                fifo_level_q <= fifo_level_q + { { C_FIFO_DEPTH_X {1'b0} }, 1'b1 };
            end
        end
    end
    always @ (*)
    begin
        if (|fifo_level_q) begin
            fifo_accepting = 1'b1;
        end else begin
            fifo_accepting = 1'b0;
        end
    end


    //--------------------------------------------------------------
    // program counter
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            pc_q <= C_RESET_VECTOR;
        end else if (clk_en_i) begin
            if (exs_pc_wr_i) begin
                pc_q <= exs_pc_din_i;
            end else if (request) begin
                pc_q <= pc_q + { { `RV_XLEN-(`RV_XLEN_X-2) {1'b0} }, 1'b1, { `RV_XLEN_X-3 {1'b0} } };
            end
        end
    end
    always @ (posedge clk_i)
    begin
        if (request) begin
            request_addr_q <= pc_q;
        end
    end


    //--------------------------------------------------------------
    // vectoring flag register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
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
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            sofid_q <= `RV_SOFID_RUN;
        end else if (clk_en_i) begin
            if (vectoring_q & request) begin
                sofid_q <= `RV_SOFID_JUMP;
            end else if (response) begin
                sofid_q <= `RV_SOFID_RUN;
            end
        end
    end


    //--------------------------------------------------------------
    // fifo
    //--------------------------------------------------------------
    assign fifo_din[   C_SOFID_LSB +: C_SOFID_SZ] = sofid_q; // TODO
    assign fifo_din[    C_FERR_LSB +: 1]          = irsprerr_i;
    assign fifo_din[ C_FIFO_PC_LSB +: `RV_XLEN]   = request_addr_q;
    assign fifo_din[C_FIFO_INS_LSB +: `RV_XLEN]   = irspdata_i;
    //
    assign ids_sofid_o    = fifo_dout[   C_SOFID_LSB +: C_SOFID_SZ];
    assign ids_ferr_o     = fifo_dout[    C_FERR_LSB +: 1];
    assign ids_pc_o       = fifo_dout[ C_FIFO_PC_LSB +: `RV_XLEN];
    assign fifo_dout_data = fifo_dout[C_FIFO_INS_LSB +: `RV_XLEN];
    //
    fifo
        #(
            .C_FIFO_WIDTH   (C_FIFO_WIDTH),
            .C_FIFO_DEPTH_X (C_FIFO_DEPTH_X)
        ) i_fifo (
            // global
            .clk_i          (clk_i),
            .clk_en_i       (clk_en_i),
            .resetb_i       (resetb_i),
            // control and status
            .flush_i        (exs_pc_wr_i | vectoring_q),
            .empty_o        (fifo_empty),
            .full_o         (),
            // write port
            .wr_i           (response),
            .din_i          (fifo_din),
            // read port
            .rd_i           (ids_ack_i),
            .dout_o         (fifo_dout)
        );
endmodule

