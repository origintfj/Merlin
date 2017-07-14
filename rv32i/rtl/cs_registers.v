/* ==== CRS Field Specifications ====
 * WIRI:
 * WPRI:
 * WLRL:
 *  Exceptions are not raised on illegal writes (optional)
 *  Will return last written value regardless of legality
 * WARL:
 */

`include "riscv_defs.v"

module cs_registers // TODO
    (
        //
        input  wire                clk_i,
        input  wire                clk_en_i,
        input  wire                resetb_i,
        // stage enable
        input  wire                exs_en_i,
        // read and exception query interface
        input  wire                rd_i,
        input  wire         [11:0] rd_addr_i,
        output reg  [`RV_XLEN-1:0] rd_data_o,
        output reg                 rd_illegal_rd_o,
        output reg                 rd_illegal_wr_o,
        // write-back interface
        input  wire                wr_i, // already gated by the exceptions in the exception interface
        input  wire          [1:0] wr_mode_i,
        input  wire         [11:0] wr_addr_i,
        input  wire [`RV_XLEN-1:0] wr_data_i,
        // exception interface
        input  wire                excp_ferr_i, // instruction fetch error
        input  wire                excp_uerr_i, // undefined instruction
        input  wire                excp_maif_i, // missaligned instruction fetch
        input  wire                excp_mala_i, // missaligned load address
        input  wire                excp_masa_i, // missaligned store address
        input  wire                excp_ilgl_i, // illegal instruction
        input  wire [`RV_XLEN-1:0] excp_pc_i,   // exception pc
        // hart vectoring interface
        input  wire                trap_rtn_i,
        input  wire          [1:0] trap_rtn_mode_i,
        output wire [`RV_XLEN-1:0] trap_entry_addr_o,
        output wire [`RV_XLEN-1:0] trap_rtn_addr_o,
        // static i/o
        output wire          [1:0] hpl_o
    );

    //--------------------------------------------------------------

    wire            [1:0] target_mode;
    // mcause encoder
    wire                  exception;
    reg    [`RV_XLEN-1:0] excp_cause;
    // read decode and o/p register
    reg    [`RV_XLEN-1:0] rd_data;
    // write decode and registers
    wire                  wren;
    reg    [`RV_XLEN-1:0] wr_data;
    //
    reg             [1:0] mode_q;
    //
    reg            [12:0] mstatus_q;
    reg    [`RV_XLEN-1:0] medeleg_q;
    reg    [`RV_XLEN-1:0] mtvec_q;
    reg    [`RV_XLEN-1:0] mscratch_q;
    reg  [`RV_MEPC_RANGE] mepc_q;
    reg  [`RV_MEPC_RANGE] mcause_q;

    //--------------------------------------------------------------

    // TODO
    //
    assign rd_illegal_rd_o = 1'b0;
    assign rd_illegal_wr_o = 1'b0;
    assign target_mode = `RV_MODE_MACHINE;
    assign trap_entry_addr_o = mtvec_q;
    assign trap_rtn_addr_o = { mepc_q, `RV_MEPC_LOB };


    // interface assignments
    //
    assign hpl_o = mode_q;


    // mcause encoder
    //
    assign exception = excp_ferr_i |
                       excp_uerr_i |
                       excp_maif_i |
                       excp_mala_i |
                       excp_masa_i |
                       excp_ilgl_i;
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
            12'h341 : rd_data = { mepc_q, `RV_MEPC_LOB }; // mepc
            12'h342 : rd_data = mcause_q; // mcause
            //12'h343 : rd_data = ; // mtval
            //12'h344 : rd_data = ; // mip
            default : begin // TODO - use to implement register existence check?
            end
        endcase;
    end
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (exs_en_i & rd_i) begin
                rd_data_o <= rd_data;
            end
        end
    end


    // write decode and registers
    //
    assign wren = wr_i;
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
            // processor priv. mode register
            mode_q     <= `RV_MODE_MACHINE;
            // accessible CSRs
            mstatus_q  <= 13'b0; // NOTE all interrupts disabled
            medeleg_q  <= 16'b0;
            mtvec_q    <= `RV_RESET_VECTOR & { { `RV_XLEN-2 {1'b1} }, 2'b00 }; // NOTE default exception entry mode = direct
            mscratch_q <= { `RV_XLEN {1'b0} };
        end else if (clk_en_i) begin
            if (exs_en_i) begin
                if (exception) begin // take over any pending interrupt
                    // processor priv. mode register
                    mode_q <= `RV_MODE_MACHINE;
                    // accessible CSRs
                    case (target_mode) // TODO - assign this based on the delegation
                        `RV_MODE_MACHINE : begin
                            mstatus_q[`RV_MSTATUS_MPP_RANGE]  <= mode_q;
                            mstatus_q[`RV_MSTATUS_MPIE_INDEX] <= mstatus_q[`RV_MSTATUS_MIE_INDEX];
                            mstatus_q[`RV_MSTATUS_MIE_INDEX]  <= 1'b0;
                        end
                        `RV_MODE_SUPERVISOR : begin
                            mstatus_q[`RV_MSTATUS_SPP_INDEX]  <= |mode_q; // 0 iff was user mode, 1 otherwise
                            mstatus_q[`RV_MSTATUS_SPIE_INDEX] <= mstatus_q[`RV_MSTATUS_SIE_INDEX];
                            mstatus_q[`RV_MSTATUS_SIE_INDEX]  <= 1'b0;
                        end
                        `RV_MODE_USER : begin
                            mstatus_q[`RV_MSTATUS_UPIE_INDEX] <= mstatus_q[`RV_MSTATUS_UIE_INDEX];
                            mstatus_q[`RV_MSTATUS_UIE_INDEX]  <= 1'b0;
                        end
                    endcase
                    mepc_q   <= excp_pc_i[`RV_MEPC_RANGE];
                    mcause_q <= excp_cause;
                end else if (1'b0) begin // TODO if interrupt
                end else if (wren) begin
                    case (wr_addr_i)
                        12'h300 : mstatus_q  <= wr_data;
                        12'h302 : medeleg_q  <= wr_data[15:0] & `RV_MEDELEG_LEGAL_MASK;
                        12'h305 : mtvec_q    <= wr_data & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE mode >=2 reserved
                        12'h340 : mscratch_q <= wr_data;
                        12'h341 : mepc_q     <= wr_data[`RV_MEPC_RANGE];
                        12'h342 : mcause_q   <= wr_data; // WLRL
                        default : begin // TODO - use to implement register existence check?
                        end
                    endcase;
                end
            end
        end
    end
endmodule
