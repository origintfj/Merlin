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

    //
    reg        gate;
    //
    wire [9:0] reqaddr;
    reg  [7:0] mem[0:2048];

    //--------------------------------------------------------------

    initial $readmemh("mem.hex", mem);


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
    assign reqaddr = treqaddr[10:0];
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

