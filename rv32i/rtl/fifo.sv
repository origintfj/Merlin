module fifo
    #(
        parameter C_FIFO_WIDTH   = 1,
        parameter C_FIFO_DEPTH_X = 1,
        //
        parameter C_FIFO_DEPTH = 2**C_FIFO_DEPTH_X
    )
    (
        // global
        input  logic                    clk_i,
        input  logic                    clk_en_i,
        input  logic                    resetb_i,
        // control and status
        input  logic                    flush_i,
        output logic                    empty_o,
        output logic                    full_o,
        // write port
        input  logic                    wr_i,
        input  logic [C_FIFO_WIDTH-1:0] din_i,
        // read port
        input  logic                    rd_i,
        output logic [C_FIFO_WIDTH-1:0] dout_o
    );

    //--------------------------------------------------------------

    logic [C_FIFO_WIDTH-1:0] mem[C_FIFO_DEPTH-1:0];

    logic [C_FIFO_DEPTH_X:0] rd_ptr_q;
    logic [C_FIFO_DEPTH_X:0] wr_ptr_q;

    //--------------------------------------------------------------


    assign dout_o = mem[rd_ptr_q[C_FIFO_DEPTH_X-1:0]];


    // status signals
    //
    always @ (*)
    begin
        empty_o = 1'b0;
        full_o  = 1'b0;
        if (rd_ptr_q == wr_ptr_q) begin
            if (rd_ptr_q[C_FIFO_DEPTH_X] == wr_ptr_q[C_FIFO_DEPTH_X]) begin
                empty_o = 1'b1;
            end else begin
                full_o  = 1'b1;
            end
        end
    end


    // pointers
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            rd_ptr_q <= '0;
            wr_ptr_q <= '0;
        end else if (clk_en_i) begin
            if (flush_i) begin
                rd_ptr_q <= '0;
                wr_ptr_q <= '0;
            end else begin
                if (rd_i) begin
                    rd_ptr_q <= rd_ptr_q + 1;
                end
                if (wr_i) begin
                    wr_ptr_q <= wr_ptr_q + 1;
                end
            end
        end
    end


    // memory
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (wr_i) begin
                mem[wr_ptr_q[C_FIFO_DEPTH_X-1:0]] <= din_i;
            end
        end
    end
endmodule

