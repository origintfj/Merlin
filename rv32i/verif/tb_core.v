module tb_core;
    //--------------------------------------------------------------

    parameter C_IRQV_SZ = 32;

    logic clk    = 1'b1;
    logic resetb = 1'b0;

    logic        ireqready;
    logic        ireqvalid;
    logic [31:0] ireqaddr;
    logic        irspready;
    logic        irspvalid;
    logic        irsprerr;
    logic [31:0] irspdata;

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


    // merlin rv32i core
    //
    merlin32i
        #(
            .C_IRQV_SZ           (C_IRQV_SZ),
            .C_RESET_VECTOR      ('0)
        ) i_merlin32i (
            // global
            .clk_i               (clk),
            .clk_en_i            (1'b1),
            .resetb_i            (resetb),
            // hardware interrupt interface
            .irqv_i              ({ C_IRQV_SZ {1'b0} }),
            // instruction port
            .ireqready_i         (ireqready),
            .ireqvalid_o         (ireqvalid),
            .ireqhpl_o           (),
            .ireqaddr_o          (ireqaddr),
            .irspready_o         (irspready),
            .irspvalid_i         (irspvalid),
            .irsprerr_i          (irsprerr),
            .irspdata_i          (irspdata),
            // data port
            .dreqready_i         (1'b0),
            .dreqvalid_o         (),
            .dreqhpl_o           (),
            .dreqaddr_o          (),
            .drspready_o         (),
            .drspvalid_i         (1'b0),
            .drsprerr_i          (1'b0),
            .drspwerr_i          (1'b0),
            .drspdata_i          (32'b0)
            // debug interface
            // TODO - debug interface
        );


    //
    //
    boot_rom i_boot_rom
        (
            // global
            .clk       (clk),
            .resetb    (resetb),
            // instruction port
            .treqready (ireqready),
            .treqvalid (ireqvalid),
            .treqpriv  (2'b0),
            .treqaddr  (ireqaddr),
            .trspready (irspready),
            .trspvalid (irspvalid),
            .trsprerr  (irsprerr),
            .trspdata  (irspdata)
        );
endmodule

