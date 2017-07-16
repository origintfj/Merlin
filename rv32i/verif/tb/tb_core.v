`timescale 1ns / 10ps

module tb_core;
    //--------------------------------------------------------------

    parameter C_IRQV_SZ = 32;

    reg         clk    = 1'b1;
    reg         resetb = 1'b0;

    wire        ireqready;
    wire        ireqvalid;
    wire [31:0] ireqaddr;
    wire        irspready;
    wire        irspvalid;
    wire        irsprerr;
    wire [31:0] irspdata;

    wire        dreqready;
    wire        dreqvalid;
    wire        dreqdvalid;
    wire [31:0] dreqaddr;
    wire [31:0] dreqdata;
    wire        drspready;
    wire        drspvalid;
    wire [31:0] drspdata;
    //--------------------------------------------------------------

    // general setup
    //
    initial
    begin
        $display("********************************************************");
        $dumpfile("wave.lxt");
        $dumpvars(0, tb_core);

        $display("******************* SIMULATION START *******************");
        $display();
        $display();

        #(1_000_000_000);

        $display();
        $display();
        //$display("*******************  SIMULATION END! *******************");
        //$finish();

        $display("*******************   FAIL - TIMEOUT   *******************");
        $fatal();
    end


    // generate a clock
    //
    always
    begin
        #10;
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
            .dreqready_i         (dreqready),
            .dreqvalid_o         (dreqvalid),
            .dreqsize_o          (),
            .dreqdvalid_o        (dreqdvalid),
            .dreqhpl_o           (),
            .dreqaddr_o          (dreqaddr),
            .dreqdata_o          (dreqdata),
            .drspready_o         (drspready),
            .drspvalid_i         (drspvalid),
            .drsprerr_i          (1'b0),
            .drspwerr_i          (1'b0),
            .drspdata_i          (drspdata)
            // debug interface
            // TODO - debug interface
        );


    // boot rom
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


    // sram
    //
    ssram i_ssram
        (
            // global
            .clk_i        (clk),
            .clk_en_i     (1'b1),
            .resetb_i     (resetb),
            //
            .treqready_o  (dreqready),
            .treqvalid_i  (dreqvalid),
            .treqdvalid_i (dreqdvalid),
            .treqaddr_i   (dreqaddr),
            .treqdata_i   (dreqdata),
            .trspready_i  (drspready),
            .trspvalid_o  (drspvalid),
            .trspdata_o   (drspdata)
        );
endmodule

