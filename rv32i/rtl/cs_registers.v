`include "riscv_defs.v"

module cs_registers // TODO
    (
        //
        input  wire                clk_i,
        input  wire                clk_en_i,
        input  wire                resetb_i,
        // read and exception query interface
        input  wire                rd_i,
        input  wire         [11:0] rd_addr_i,
        output reg  [`RV_XLEN-1:0] rd_data_o,
        output reg                 rd_illegal_rd_o,
        output reg                 rd_illegal_wr_o,
        // write-back interface
        input  wire                wr_i, // the write will be ignored if it triggers an exception
        input  wire          [1:0] wr_mode_i,
        input  wire         [11:0] wr_addr_i,
        input  wire [`RV_XLEN-1:0] wr_data_i,
        // hart vectoring and exception controller
        input  wire                excp_ferr_i, // instruction fetch error
        input  wire                excp_uerr_i, // undefined instruction
        input  wire                excp_maif_i, // missaligned instruction fetch
        input  wire                excp_mala_i, // missaligned load address
        input  wire                excp_masa_i, // missaligned store address
        input  wire                excp_ilgl_i, // illegal instruction
        // static i/o
        output wire          [1:0] hpl_o
    );

    //--------------------------------------------------------------

    // mcause encoder
    reg  [`RV_XLEN-1:0] excp_cause;
    // read decode and o/p register
    reg  [`RV_XLEN-1:0] rd_data;
    // write decode and registers
    reg          [12:0] mstatus_q;
    reg  [`RV_XLEN-1:0] medeleg_q;
    reg  [`RV_XLEN-1:0] mtvec_q;
    reg  [`RV_XLEN-1:0] mscratch_q;
    // processor priv. mode register
    reg           [1:0] mode_q;

    //--------------------------------------------------------------

    // interface assignments
    //
    assign hpl_o = mode_q;


    // mcause encoder
    //
    always @ (*)
    begin
        if (excp_ferr_i) begin
            excp_cause = `EXCP_MCAUSE_INS_ACCESS_FAULT;
        end else if (excp_uerr_i) begin
            excp_cause = `EXCP_MCAUSE_ILLEGAL_INS; // TODO - do undefined instructions trigger illegal exceptions?
        end else if (excp_maif_i) begin
            excp_cause = `EXCP_MCAUSE_INS_ADDR_MISALIGNED;
        end else if (excp_mala_i) begin
            excp_cause = `EXCP_MCAUSE_LOAD_ADDR_MISALIGNED;
        end else if (excp_masa_i) begin
            excp_cause = `EXCP_MCAUSE_STORE_ADDR_MISALIGNED;
        end else if (excp_ilgl_i) begin
            excp_cause = `EXCP_MCAUSE_ILLEGAL_INS;
        end else begin
            excp_cause = { `RV_XLEN {1'b0} }; // NOTE: don't actually care
        end
    end


    // read decode and o/p register
    //
    always @ (*)
    begin
        rd_data = 32'bx;
        case (rd_addr_i)
            12'hf11 : rd_data = `RV_VENDOR_ID;
            12'hf12 : rd_data = `RV_ARCHITECTURE_ID;
            12'hf13 : rd_data = `RV_IMPLEMENTATION_ID;
            12'hf14 : rd_data = `RV_HART_ID;
            12'h300 : rd_data = { { (`RV_XLEN-13) {1'b0} }, mstatus_q }; // mstatus
            //12'h301 : rd_data = ; // misa
            12'h302 : rd_data = { 16'b0, medeleg_q };
            //12'h303 : rd_data = ; // mideleg
            //12'h304 : rd_data = ; // mie
            12'h305 : rd_data = mtvec_q; // mtvec
            //12'h306 : rd_data = ; // mcounteren
            12'h340 : rd_data = mscratch_q; // mscratch
            //12'h341 : rd_data = ; // mepc
            //12'h342 : rd_data = ; // mcause
            //12'h343 : rd_data = ; // mtval
            //12'h344 : rd_data = ; // mip
            default : begin // TODO - use to implement register existence check?
            end
        endcase;
    end
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (rd_i) begin
                rd_data_o <= rd_data;
            end
        end
    end


    // write decode and registers
    //
    always @ (*)
    begin
        wr_data = wr_data_i;
        case (wr_mode_i)
            2'b01 : wr_data = wr_data_i;
            2'b10 : wr_data = rd_data |  wr_data_i;
            2'b11 : wr_data = rd_data & ~wr_data_i;
            default : begin
            end
        endcase;
    end
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            mstatus_q  <= 13'b0; // NOTE all interrupts disabled
            medeleg_q  <= 16'b0;
            mtvec_q    <= RV_RESET_VECTOR & { `RV_XLEN-2 {1'b1}, 2'b00 }; // NOTE default exception entry mode = direct
            mscratch_q <= { `RV_XLEN {1'b0} };
        end else if (clk_en_i) begin
            if (wren) begin
                case (wr_addr_i)
                    12'h300 : mstatus_q  <= wr_data;
                    12'h302 : medeleg_q  <= wr_data[15:0] & `RV_MEDELEG_LEGAL_MASK;
                    12'h305 : mtvec_q    <= wr_data & { `RV_XLEN-2 {1'b1}, 2'b01 }; // NOTE mode >=2 reserved
                    12'h340 : mscratch_q <= wr_data;
                    default : begin // TODO - use to implement register existence check?
                    end
                endcase;
            end
        end
    end


    // processor priv. mode register
    //
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            mode_q <= 2'b11; // TODO 2'b10 is reserved 00 is user, 01 is supervisor
        end else if (clk_en_i) begin
        end
    end
endmodule
