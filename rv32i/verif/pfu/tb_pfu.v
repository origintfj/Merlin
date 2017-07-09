`include "riscv_defs.v"

module tb_core;
    //--------------------------------------------------------------

    parameter C_IRQV_SZ = 32;

    reg                 clk    = 1'b1;
    reg                 resetb = 1'b0;
    // response
    wire                request;
    reg                 ireqready;
    reg                 irspvalid;
    wire                irsprerr;
    reg  [`RV_XLEN-1:0] irspdata;
    // verification fifo
    wire [`RV_XLEN-1:0] fifo_dout;
    // id stage
    wire                ids_ack;
    reg                 ids_ack_rand;
    // hvec
    wire                hvec_wr;
    reg  [`RV_XLEN-1:0] hvec_pc;
    reg                 hvec_rand;
    // pfu
    wire                ireqvalid;
    wire [`RV_XLEN-1:0] ireqaddr;
    wire                irspready;
    wire                ids_dav;
    wire [`RV_XLEN-1:0] ids_ins;
    wire [`RV_XLEN-1:0] ids_pc;
    wire                hvec_pc_ready;
    //

    //--------------------------------------------------------------

    // general setup
    //
    initial
    begin
        $dumpfile("wave.lxt");
        $dumpvars(0, tb_core);
        #(200_000);
        $finish();
    end


    // generate a clock
    //
    always
    begin
        #50;
        clk = ~clk;
    end


    // generate a reset
    //
    always @ (posedge clk)
    begin
        resetb <= 1'b1;
    end


    // response
    //
    assign irsprerr = 1'b0; // TODO
    assign request  = ireqvalid & ireqready;
    //
    always @ (posedge clk or negedge resetb)
    begin
        if (~resetb) begin
        end else begin
            if (ireqvalid) begin
                ireqready <= $random();
            end
        end
        //
        if (request) begin
            if (ireqaddr[1:0] === 2'b0); else $error("Misaligned address."); // TODO assert
            irspvalid <= 1'b1;
            irspdata  <= ireqaddr;
        end else begin
            irspvalid <= 1'b0;
        end
    end


    // verification fifo
    //
    fifo
        #(
            .C_FIFO_WIDTH   (`RV_XLEN),
            .C_FIFO_DEPTH_X (4)
        ) i_fifo (
            // global
            .clk_i          (clk),
            .clk_en_i       (1'b1),
            .resetb_i       (resetb),
            // control and status
            .flush_i        (1'b0),
            .empty_o        (),
            .full_o         (),
            // write port
            .wr_i           (request),
            .din_i          (ireqaddr),
            // read port
            .rd_i           (ids_ack),
            .dout_o         (fifo_dout)
        );


    // id stage
    //
    assign ids_ack = (ids_dav ? ids_ack_rand : 1'b0);
    //
    always @ (posedge clk)
    begin
        if (ids_ack) begin // new ins this cycle
            if (fifo_dout === ids_ins && fifo_dout === ids_pc) begin
            end else begin
                $error("Incorrect data returned by PFU");
                $fatal();
            end
        end
        //
        ids_ack_rand <= $random();
    end


    // hvec
    //
    assign hvec_wr = hvec_rand & hvec_pc_ready;
    always @ (posedge clk or negedge resetb)
    begin
        if (~resetb) begin
            hvec_rand <= 1'b0;
        end else begin
            hvec_pc <= { $random(), 2'b0 };
            if (hvec_pc_ready) begin
                if ($random() % 10 == 0) begin
                    hvec_rand <= 1'b1;
                end else begin
                    hvec_rand <= 1'b0;
                end
            end
        end
    end


    // prefetch unit
    //
    pfu
        #(
            .C_BUS_SZX      (5), // bus width base 2 exponent
            .C_FIFO_DEPTH_X (2), // pfu fifo depth base 2 exponent
            .C_RESET_VECTOR (32'h00000000)
        ) i_pfu (
            // global
            .clk_i           (clk),
            .clk_en_i        (1'b1),
            .resetb_i        (resetb),
            // instruction cache interface
            .ireqready_i     (ireqready),
            .ireqvalid_o     (ireqvalid),
            .ireqhpl_o       (),
            .ireqaddr_o      (ireqaddr),
            .irspready_o     (irspready),
            .irspvalid_i     (irspvalid),
            .irsprerr_i      (irsprerr),
            .irspdata_i      (irspdata),
            // decoder interface
            .ids_dav_o       (ids_dav),   // new fetch available
            .ids_ack_i       (ids_ack),//ids_ack),   // ack this fetch
            .ids_sofid_o     (),          // first fetch since vectoring
            .ids_ins_o       (ids_ins),   // instruction fetched
            .ids_ferr_o      (),          // this instruction fetch resulted in error
            .ids_pc_o        (ids_pc),    // address of this instruction
            // vectoring and exception controller interface
            .hvec_pc_ready_o (hvec_pc_ready),
            .hvec_pc_wr_i    (hvec_wr),
            .hvec_pc_din_i   (hvec_pc),
            // pfu stage interface
            .exs_hpl_i       (2'b0)
        );
endmodule

