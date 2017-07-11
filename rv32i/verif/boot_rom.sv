module boot_rom
    (
        // global
        input  logic                 clk,
        input  logic                 resetb,
        // instruction port
        output logic                 treqready,
        input  logic                 treqvalid,
        input  logic           [1:0] treqpriv,
        input  logic          [31:0] treqaddr,
        input  logic                 trspready,
        output logic                 trspvalid,
        output logic                 trsprerr,
        output logic          [31:0] trspdata
    );

    //--------------------------------------------------------------

    logic        gate;
    logic [7:0] mem[0:2048];

    //--------------------------------------------------------------

    assign treqready = gate;

    always @ (posedge clk)
    begin
        if ($random() % 10 != 0) begin
            gate <= 1'b1;
        end else begin
            gate <= 1'b0;
        end
        gate <= 1'b1;
    end

    integer i;

    initial $readmemh("mem.hex", mem);
    //
    //
    logic [9:0] reqaddr;
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

