`timescale 1ns/10ps

module ssram
    (
        // global
        input  wire        clk_i,
        input  wire        clk_en_i,
        input  wire        reset_i,
        //
        output wire        treqready_o,
        input  wire        treqvalid_i,
        input  wire        treqdvalid_i,
        input  wire [31:0] treqaddr_i,
        input  wire [31:0] treqdata_i,
        input  wire        trspready_i,
        output reg         trspvalid_o,
        output reg  [31:0] trspdata_o
    );

    //--------------------------------------------------------------

    parameter               C_SSRAM_SZBX = 22;
    parameter               C_SSRAM_SZB  = 2**C_SSRAM_SZBX;
    //
    parameter               C_VIRTUAL_UART = 32'h80000000;
    //
    reg               [7:0] mem[0:C_SSRAM_SZB-1];
    wire [C_SSRAM_SZBX-1:0] reqaddr;

    //--------------------------------------------------------------

    assign treqready_o = treqvalid_i;

    initial
    begin
        $display("********************************************************");
        $display("SSRAM Size = %0d Ki Bytes.", 2**(C_SSRAM_SZBX-10));
        $display("\nWrites to address 0x%08X will be interpreted as\nASCII characters and will be printed to the console.", C_VIRTUAL_UART);
        $display("\nWrites to address 0xFFFFFFFC will be end the simulation.");
        $display("********************************************************");
        $readmemh("mem.hex", mem);
    end


    //
    //
    assign reqaddr = treqaddr_i[C_SSRAM_SZBX-1:0];
    always @ (posedge clk_i or posedge reset_i)
    begin
        if (reset_i) begin
            trspvalid_o <= 1'b0;
            trspdata_o  <= 32'hbaadf00d;
        end else if (clk_en_i) begin
            if (treqvalid_i) begin
                trspvalid_o <= 1'b0;
                if (treqdvalid_i) begin
                    if (treqaddr_i == C_VIRTUAL_UART) begin
                        $write("%c", treqdata_i[7:0]);
                        $fflush();
                    end else if (treqaddr_i == 32'hfffffffc) begin
                        $display();
                        $display();
                        $display("(%0tns) Program wrote to address 0xFFFFFFFC => End of test!", $time/100.0);
                        $display("******************** SIMULATION END ********************");
                        $finish();
                    end else if (treqaddr_i == reqaddr) begin
                        mem[reqaddr+3] <= treqdata_i[31:24];
                        mem[reqaddr+2] <= treqdata_i[23:16];
                        mem[reqaddr+1] <= treqdata_i[15: 8];
                        mem[reqaddr+0] <= treqdata_i[ 7: 0];
                        `ifdef TESTBENCH_DBG_MSG
                            $display("SSRAM Write: ADDR=0x%08X, DATA=0x%08X", treqaddr_i, treqdata_i);
                        `endif
                    end else begin
                        $display("FATAL ERROR (%0t): Memory Write Out Of Range! Address 0x%08X", $time, treqaddr_i);
                        $fatal();
                    end
                end else begin
                    trspvalid_o <= 1'b1;
                    if (treqaddr_i == reqaddr) begin
                        trspdata_o  <= { mem[reqaddr+3], mem[reqaddr+2], mem[reqaddr+1], mem[reqaddr+0] };
                        `ifdef TESTBENCH_DBG_MSG
                            $display("SSRAM Read : ADDR=0x%08X, DATA=0x%08X", treqaddr_i, { mem[reqaddr+3], mem[reqaddr+2], mem[reqaddr+1], mem[reqaddr+0] });
                        `endif
                    end else begin
                        $display("FATAL ERROR (%0t): Memory Read Out Of Range! Address 0x%08X", $time, treqaddr_i);
                        $fatal();
                    end
                end
            end else begin
                trspvalid_o <= 1'b0;
                trspdata_o  <= 32'hbaadf00d;
            end
        end
    end
endmodule

