`timescale 1ns / 10ps

module tb_core;
    //--------------------------------------------------------------

    parameter C_IRQV_SZ = 32;

    reg         clk;
    wire        reset;
    reg   [1:0] reset_pipe;

    // hardware interrupt generator
    reg  [11:0] intr_counter_q;
    reg         intr_extern;

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
`ifdef RV_ASSERTS_ON
    wire [31:0] rom_data;
`endif
    //--------------------------------------------------------------

    parameter C_TIMEOUT = 0;

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

        if (C_TIMEOUT) begin
            #(C_TIMEOUT*1000);
            $display();
            $display();
            $display("*******************   FAIL - TIMEOUT   *******************");
            $display("Time = %0tus.", $time/100000);
            $fatal();
        end
    end


    // generate a clock
    //
    initial begin
        clk = 1'b0;
        reset_pipe = 2'b0;
    end
    //
    always begin
        #10;
        clk = ~clk;
    end


    // generate a reset
    //
    assign reset = ~reset_pipe[0];
    //
    initial begin
        reset_pipe = 2'b0;
    end
    //
    always @ (posedge clk) begin
        reset_pipe <= { 1'b1, reset_pipe[1] };
    end


    // hardware interrupt generator
    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            intr_counter_q <= 12'b0;
            intr_extern    <= 1'b0;
        end else begin
            if ((dreqvalid & dreqvalid == 1'b1) && (dreqaddr == 32'h00000004)) begin
                // for some reason using addr 0 causes the compiler to insert an ebreak
                intr_counter_q <= 12'b0;
                intr_extern    <= 1'b0;
            end else if (intr_counter_q == 1024) begin//{ 12 {1'b1} }) begin
                intr_extern <= 1'b1;
            end else begin
                intr_counter_q <= intr_counter_q + 1;
            end
        end
    end


    // merlin core
    //
    merlin
`ifndef GATES
        #(
            .C_RESET_VECTOR      (32'b0)
        )
`endif
        i_merlin (
            // global
            .clk_i               (clk),
            .clk_en_i            (1'b1),
            .reset_i             (reset),
            // hardware interrupt interface
            .irqm_extern_i       (intr_extern),
            .irqm_softw_i        (1'b0),
            .irqm_timer_i        (1'b0),
            .irqs_extern_i       (1'b0),
            .irqs_softw_i        (1'b0),
            .irqs_timer_i        (1'b0),
            .irqu_extern_i       (1'b0),
            .irqu_softw_i        (1'b0),
            .irqu_timer_i        (1'b0),
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
            .dreqwrite_o         (dreqdvalid),
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
            .reset     (reset),
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
            .reset_i      (reset),
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


    // assersions
    //
`ifdef RV_ASSERTS_ON
    assign rom_data[ 7: 0] = i_boot_rom.mem[i_merlin.pfu_ids_pc + 0];
    assign rom_data[15: 8] = i_boot_rom.mem[i_merlin.pfu_ids_pc + 1];
    assign rom_data[23:16] = i_boot_rom.mem[i_merlin.pfu_ids_pc + 2];
    assign rom_data[31:24] = i_boot_rom.mem[i_merlin.pfu_ids_pc + 3];
    always @ (posedge clk or posedge reset) begin
        if (reset) begin
        end else begin
            if (i_merlin.pfu_ids_dav == 1'b1) begin
                if (i_merlin.pfu_ids_ins != rom_data) begin
                    $display("ERROR: PFU data output missmatch, Got 0x%08X, Expected 0x%08X.", i_merlin.pfu_ids_ins, rom_data);
                end
            end
        end
    end
`endif
endmodule

