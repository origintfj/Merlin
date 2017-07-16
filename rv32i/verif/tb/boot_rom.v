module boot_rom
    (
        // global
        input  wire                  clk,
        input  wire                  resetb,
        // instruction port
        output wire                  treqready,
        input  wire                  treqvalid,
        input  wire            [1:0] treqpriv,
        input  wire           [31:0] treqaddr,
        input  wire                  trspready,
        output reg                   trspvalid,
        output reg                   trsprerr,
        output reg            [31:0] trspdata
    );

    //--------------------------------------------------------------

    parameter               C_ROM_SZBX = 22;
    parameter               C_ROM_SZB  = 2**C_ROM_SZBX;
    //
    reg                     gate;
    //
    reg               [7:0] mem[0:C_ROM_SZB-1];
    wire   [C_ROM_SZBX-1:0] reqaddr;
    //

    //--------------------------------------------------------------

    initial
    begin
        $display("********************************************************");
        $display("ROM Size = %0d Ki Bytes.", 2**(C_ROM_SZBX-10));
        $display("********************************************************");
        $readmemh("mem.hex", mem);
    end


    //
    //
    assign treqready = gate;


    //
    //
    always @ (posedge clk)
    begin
        if ($random() % 10 != 0) begin
            gate <= 1'b1;
        end else begin
            gate <= 1'b0;
        end
        gate <= 1'b1;
    end


    //
    //
    assign reqaddr = treqaddr[C_ROM_SZBX-1:0];
    always @ (posedge clk or negedge resetb)
    begin
        if (~resetb) begin
            trspvalid <= 1'b0;
            trsprerr  <= 1'b0;
            trspdata  <= 32'hbaadf00d;
        end else begin
            trspvalid <= gate & treqvalid;
            trspdata  <= { mem[reqaddr+3], mem[reqaddr+2], mem[reqaddr+1], mem[reqaddr+0] };
        end
    end
endmodule

