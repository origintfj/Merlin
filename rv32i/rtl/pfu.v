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
        output reg                    ireqvalid_o,
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
        output wire    [`RV_XLEN-1:0] ids_ins_o,      // instruction fetched
        output wire                   ids_ferr_o,     // this instruction fetch resulted in error
        output wire    [`RV_XLEN-1:0] ids_pc_o,       // address of this instruction
        // vectoring and exception controller interface
        output reg                    hvec_pc_ready_o,
        input  wire                   hvec_pc_wr_i,
        input  wire    [`RV_XLEN-1:0] hvec_pc_din_i,
        // pfu stage interface
        input  wire             [1:0] exs_hpl_i
    );

    //--------------------------------------------------------------

    // interface assignments
    // bus interface fsm
    parameter C_STATE_SZ       = 2;
    //
    parameter C_STATE_IDLE     = 2'b00;
    parameter C_STATE_REQ_WAIT = 2'b01;
    parameter C_STATE_RSP_WAIT = 2'b10;
    //
    reg    [C_STATE_SZ-1:0] c_state;
    reg    [C_STATE_SZ-1:0] n_state;
    //
    reg                     request_accepted;
    // fifo level counter
    reg  [C_FIFO_DEPTH_X:0] fifo_level_q;
    reg                     fifo_accepting;
    // program counter
    reg      [`RV_XLEN-1:0] pc_q;
    reg      [`RV_XLEN-1:0] request_addr_q;
    // sofid register
    reg                     hvec_pc_wr_q;
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

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign ireqhpl_o   = exs_hpl_i;
    assign ireqaddr_o  = pc_q;
    assign irspready_o = irspvalid_i; // always ready
    //
    assign ids_dav_o = ~fifo_empty;


    //--------------------------------------------------------------
    // bus interface fsm
    //--------------------------------------------------------------
    always @ (*)
    begin
        ireqvalid_o      = 1'b0;
        //
        hvec_pc_ready_o  = 1'b0;
        //
        request_accepted = 1'b0;
        //
        n_state = c_state;
        case (c_state)
            C_STATE_IDLE : begin
                if (fifo_accepting) begin
                    ireqvalid_o = 1'b1;
                    if (ireqready_i) begin
                        request_accepted = 1'b1;
                        n_state          = C_STATE_RSP_WAIT;
                    end else begin
                        n_state = C_STATE_REQ_WAIT;
                    end
                end
            end
            C_STATE_REQ_WAIT : begin
                ireqvalid_o = 1'b1;
                if (ireqready_i) begin // TODO assert cannot get a rsp in this state
                    request_accepted = 1'b1;
                    n_state          = C_STATE_RSP_WAIT;
                end
            end
            C_STATE_RSP_WAIT : begin
                if (irspvalid_i) begin
                    if (fifo_accepting) begin
                        hvec_pc_ready_o = 1'b1;
                        ireqvalid_o     = 1'b1;
                        if (ireqready_i) begin
                            request_accepted = 1'b1;
                        end else begin
                            n_state = C_STATE_REQ_WAIT;
                        end
                    end else begin
                        n_state = C_STATE_IDLE;
                    end
                end
            end
        endcase
    end
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            c_state <= C_STATE_IDLE;
        end else if (clk_en_i) begin
            c_state <= n_state;
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
/*
            if (hvec_pc_wr_i) begin
                fifo_level_q <= { 1'b1, { C_FIFO_DEPTH_X {1'b0} } };
            end else if (request_accepted & ~ids_ack_i) begin
*/
            if (request_accepted & ~ids_ack_i) begin
                fifo_level_q <= fifo_level_q - { { C_FIFO_DEPTH_X {1'b0} }, 1'b1 };
            end else if (~request_accepted & ids_ack_i) begin
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
            if (hvec_pc_wr_i) begin
                pc_q <= hvec_pc_din_i;
            end else if (request_accepted) begin
                pc_q <= pc_q + 4;
            end
        end
    end
    always @ (posedge clk_i)
    begin
        if (request_accepted) begin
            request_addr_q <= pc_q;
        end
    end


    //--------------------------------------------------------------
    // sofid register
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            sofid_q <= `RV_SOFID_RUN;
            hvec_pc_wr_q <= 1'b0;
        end else if (clk_en_i) begin
            hvec_pc_wr_q <= hvec_pc_wr_i;
            if (hvec_pc_wr_q) begin
                sofid_q <= `RV_SOFID_JUMP;
            end else if (irspvalid_i) begin
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
    assign ids_sofid_o = fifo_dout[   C_SOFID_LSB +: C_SOFID_SZ];
    assign ids_ferr_o  = fifo_dout[    C_FERR_LSB +: 1];
    assign ids_pc_o    = fifo_dout[ C_FIFO_PC_LSB +: `RV_XLEN];
    assign ids_ins_o   = fifo_dout[C_FIFO_INS_LSB +: `RV_XLEN];
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
            .flush_i        (1'b0),//hvec_pc_wr_i),
            .empty_o        (fifo_empty),
            .full_o         (),
            // write port
            .wr_i           (irspvalid_i),// & ~hvec_pc_wr_i),
            .din_i          (fifo_din),
            // read port
            .rd_i           (ids_ack_i),
            .dout_o         (fifo_dout)
        );
endmodule

