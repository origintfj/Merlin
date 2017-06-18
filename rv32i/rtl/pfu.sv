// TODO - sofr required on reset

/******************************************************
 * Module   : Prefetch Unit (PFU)
 * Language :
 * Engineer : Tom Stanway-Mayers
 ******************************************************/
// TODO can a request be dropped if it has not been accepted? At the moment
    // the PFU will drop requests which have not been accepted if vectoring

module pfu
    #(
        parameter C_BUS_SZX      = 1, // bus width base 2 exponent
        parameter C_FIFO_DEPTH_X = 2, // depth >= read latency + 2
        parameter C_RESET_VECTOR = '0,
        //
        parameter C_BUS_SZ = 2**C_BUS_SZX
    )
    (
        // global
        input  logic                clk_i,
        input  logic                clk_en_i,
        input  logic                resetb_i,
        // instruction cache interface
        input  logic                ireqready_i,
        output logic                ireqvalid_o,
        output logic          [1:0] ireqhpl_o, // HART priv. level
        output logic [C_BUS_SZ-1:0] ireqaddr_o,
        output logic                irspready_o,
        input  logic                irspvalid_i,
        input  logic                irsprerr_i,
        input  logic [C_BUS_SZ-1:0] irspdata_i,
        // vectoring and exception controller interface
        output logic                vic_pc_ready_o,
        input  logic                vic_pc_wr_i,
        input  logic [C_BUS_SZ-1:0] vic_pc_din_i,
        output logic [C_BUS_SZ-1:0] vic_link_addr_o,
        // decoder interface
        output logic                decoder_dav_o,   // new fetch available
        input  logic                decoder_ack_i,   // ack this fetch
        output logic                decoder_sofr_o,  // first fetch since vectoring
        output logic [C_BUS_SZ-1:0] decoder_ins_o,   // instruction fetched
        output logic                decoder_ferr_o,  // this instruction fetch resulted in error
        output logic                decoder_maif_o,  // misaligned instruction fetch error TODO could vector immediatly
        output logic [C_BUS_SZ-1:0] decoder_pc_o     // address of this instruction
    );

    //--------------------------------------------------------------

    // interface drivers
    // instruction fetch arbitration logic
    logic                    request;
    logic                    response;
    logic                    response_pending_q;
    logic [C_FIFO_DEPTH_X:0] fetch_level_q;
    // pfu fifo
    parameter C_FIFO_WIDTH   = 3 + 2 * C_BUS_SZ;
    //
    parameter C_SOFR_LSB     = 2 + 2 * C_BUS_SZ;
    parameter C_FERR_LSB     = 1 + 2 * C_BUS_SZ;
    parameter C_MAIF_LSB     =     2 * C_BUS_SZ;
    parameter C_FIFO_PC_LSB  =         C_BUS_SZ;
    parameter C_FIFO_INS_LSB =                0;
    //
    logic                    fifo_empty;
    logic [C_FIFO_WIDTH-1:0] fifo_din;
    logic [C_FIFO_WIDTH-1:0] fifo_dout;
    // program counter
    logic     [C_BUS_SZ-1:0] jump_tgt_address;
    logic     [C_BUS_SZ-1:0] pc_d;
    logic     [C_BUS_SZ-1:0] pc_q;
    // request address capture register
    logic     [C_BUS_SZ-1:0] ireqaddr_q;
    // instruction fetch token generation
    logic                    sofr_q;
    logic                    maif_q;

    //--------------------------------------------------------------

    // interface drivers
    assign ireqhpl_o   = 2'b0; // TODO
    assign irspready_o = clk_en_i;
    //
    assign vic_pc_ready_o = transaction_boundary;


    // instruction fetch arbitration logic
    //
    assign ireqvalid_o = clk_en_i & transaction_boundary & ~fetch_level_q[C_FIFO_DEPTH_X];
    //
    assign request              = ireqready_i & ireqvalid_o; // request made this cycle
    assign response             = irspready_o & irspvalid_i; // response received this cycle
    assign transaction_boundary = ~response_pending_q | response;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            response_pending_q <= 1'b0;
            fetch_level_q      <= '0;
        end else if (clk_en_i) begin
            // response pending counter
            if (request & ~response) begin
                response_pending_q <= 1'b1;
            end else if (~request & response) begin
                response_pending_q <= 1'b0;
            end
            // request level counter
            if (vic_pc_wr_i) begin
                if (request) begin
                    fetch_level_q <= 1;
                end else begin
                    fetch_level_q <= '0;
                end
            end else if (request & ~decoder_ack_i) begin
                fetch_level_q <= fetch_level_q + 1; // request only
            end else if (~request & decoder_ack_i) begin
                fetch_level_q <= fetch_level_q - 1; // decoder ack only
            end
        end
    end


    // pfu fifo
    //
    assign decoder_dav_o = ~fifo_empty;
    // combine befor fifo ingress
    assign fifo_din[C_SOFR_LSB]                 = sofr_q;
    assign fifo_din[C_FERR_LSB]                 = irsprerr_i;
    assign fifo_din[C_MAIF_LSB]                 = maif_q;
    assign fifo_din[ C_FIFO_PC_LSB +: C_BUS_SZ] = ireqaddr_q;
    assign fifo_din[C_FIFO_INS_LSB +: C_BUS_SZ] = irspdata_i;
    // seperate after fifo egress
    assign decoder_sofr_o = fifo_dout[C_SOFR_LSB];
    assign decoder_ferr_o = fifo_dout[C_FERR_LSB];
    assign decoder_maif_o = fifo_dout[C_MAIF_LSB];
    assign decoder_pc_o   = fifo_dout[ C_FIFO_PC_LSB +: C_BUS_SZ];
    assign decoder_ins_o  = fifo_dout[C_FIFO_INS_LSB +: C_BUS_SZ];
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
            .flush_i        (vic_pc_wr_i),
            .empty_o        (fifo_empty),
            .full_o         (),
            // write port
            .wr_i           (response),
            .din_i          (fifo_din),
            // read port
            .rd_i           (decoder_ack_i),
            .dout_o         (fifo_dout)
        );


    // program counter
    //
    assign jump_tgt_address = { vic_pc_din_i[C_BUS_SZ-1:2], 2'b0 };
    assign vic_link_addr_o  = pc_q;
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            pc_q <= C_RESET_VECTOR;
        end else if (clk_en_i) begin
            if (request) begin
                pc_q <= ireqaddr_o + 4;
            end else if (vic_pc_wr_i) begin
                pc_q <= jump_tgt_address;
            end
        end
    end
    //
    always @ (*)
    begin
        if (vic_pc_wr_i) begin
            ireqaddr_o = jump_tgt_address;
        end else begin
            ireqaddr_o = pc_q;
        end
    end


    // request address capture register
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (request) begin
                ireqaddr_q <= ireqaddr_o;
            end
        end
    end


    // instruction fetch token generation
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            sofr_q <= 1'b0;
            maif_q <= 1'b0;
        end else if (clk_en_i) begin
            if (vic_pc_wr_i) begin
                sofr_q <= 1'b1;
                maif_q <= |(vic_pc_din_i[1:0]);
            end else if (response) begin
                sofr_q <= 1'b0;
                maif_q <= 1'b0;
            end
        end
    end
    //assert vic_pc_ready_o vic_pc_wr_i == 1'b0
endmodule

