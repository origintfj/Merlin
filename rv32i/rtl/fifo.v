module fifo
    #(
        parameter C_FIFO_WIDTH   = 1,
        parameter C_FIFO_DEPTH_X = 1,
        //
        parameter C_FIFO_DEPTH = 2**C_FIFO_DEPTH_X
    )
    (
        // global
        input  wire                     clk_i,
        input  wire                     clk_en_i,
        input  wire                     resetb_i,
        // control and status
        input  wire                     flush_i,
        output reg                      empty_o,
        output reg                      full_o,
        // write port
        input  wire                     wr_i,
        input  wire  [C_FIFO_WIDTH-1:0] din_i,
        // read port
        input  wire                     rd_i,
        output wire  [C_FIFO_WIDTH-1:0] dout_o
    );

    //--------------------------------------------------------------

    // pointers
    reg [C_FIFO_DEPTH_X:0] rd_ptr_q;
    reg [C_FIFO_DEPTH_X:0] wr_ptr_q;
    // memory
    reg [C_FIFO_WIDTH-1:0] mem[C_FIFO_DEPTH-1:0];

    //--------------------------------------------------------------


    assign dout_o = mem[rd_ptr_q[C_FIFO_DEPTH_X-1:0]];


    // status signals
    //
    always @ (*)
    begin
        empty_o = 1'b0;
        full_o  = 1'b0;
        if (rd_ptr_q[C_FIFO_DEPTH_X-1:0] == wr_ptr_q[C_FIFO_DEPTH_X-1:0]) begin
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
            rd_ptr_q <= { C_FIFO_DEPTH_X+1 {1'b0} };
            wr_ptr_q <= { C_FIFO_DEPTH_X+1 {1'b0} };
        end else if (clk_en_i) begin
            if (flush_i) begin
                rd_ptr_q <= { C_FIFO_DEPTH_X+1 {1'b0} };
                wr_ptr_q <= { C_FIFO_DEPTH_X+1 {1'b0} };
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

