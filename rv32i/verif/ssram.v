module ssram
    (
        // global
        input  wire        clk_i,
        input  wire        clk_en_i,
        input  wire        resetb_i,
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

    reg    [7:0] mem[0:2048];
    wire  [10:0] reqaddr;

    //--------------------------------------------------------------

    assign treqready_o = treqvalid_i;

    initial $readmemh("mem.hex", mem);

    //
    //
    assign reqaddr = treqaddr_i[10:0];
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            trspvalid_o <= 1'b0;
            trspdata_o  <= 32'hbaadf00d;
        end else if (clk_en_i) begin
            if (treqvalid_i) begin
                if (treqdvalid_i) begin
                    trspvalid_o  <= 1'b0;
                    mem[reqaddr+3] <= treqdata_i[31:24];
                    mem[reqaddr+2] <= treqdata_i[23:16];
                    mem[reqaddr+1] <= treqdata_i[15: 8];
                    mem[reqaddr+0] <= treqdata_i[ 7: 0];
                    `ifdef TESTBENCH_DBG_MSG
                        $display("SSRAM Write: ADDR=0x%08X, DATA=0x%08X", treqaddr_i, treqdata_i);
                    `endif
                    if (treqaddr_i == 32'h600) begin
                        $write("%c", treqdata_i[7:0]);
                    end
                end else begin
                    trspvalid_o <= 1'b1;
                    trspdata_o  <= { mem[reqaddr+3], mem[reqaddr+2], mem[reqaddr+1], mem[reqaddr+0] };
                    `ifdef TESTBENCH_DBG_MSG
                        $display("SSRAM Read : ADDR=0x%08X, DATA=0x%08X", treqaddr_i, { mem[reqaddr+3], mem[reqaddr+2], mem[reqaddr+1], mem[reqaddr+0] });
                    `endif
                end
            end else begin
                trspvalid_o <= 1'b0;
                trspdata_o  <= 32'hbaadf00d;
            end
        end
    end
endmodule

