// TODO - implement the remaining CSRs including the ie registers
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
        // read / error reporting interface
        input  wire         [11:0] addr_i,
        output reg                 bad_csr_addr_o,
        output reg                 readonly_csr_o,
        output reg                 priv_too_low_o,
        input  wire                rd_i,
        output reg  [`RV_XLEN-1:0] rd_data_o,
        // write-back interface
        input  wire                wr_i, // already gated by the exceptions in the exception interface
        input  wire          [1:0] wr_mode_i,
        input  wire         [11:0] wr_addr_i,
        input  wire [`RV_XLEN-1:0] wr_data_i,
        // exception, interrupt, and hart vectoring interface
        input  wire                jump_to_trap_i,
        input  wire [`RV_XLEN-1:0] excp_cause_i, // encoded exception/interrupt cause
        input  wire [`RV_XLEN-1:0] excp_pc_i,    // exception pc
        input  wire                trap_rtn_i,
        input  wire          [1:0] trap_rtn_mode_i,
        output reg  [`RV_XLEN-1:0] trap_entry_addr_o,
        output reg  [`RV_XLEN-1:0] trap_rtn_addr_o,
        // static i/o
        output wire          [1:0] mode_o
    );

    //--------------------------------------------------------------

    // interface assignments
    // access restriction logic
    reg                   [1:0] addr_typecode_q;
    reg                   [1:0] addr_privcode_q;
    // trap delegation/target mode decoder
    wire   [`RV_EDELEG_SZX-1:0] edeleg_index;
    reg                   [1:0] target_mode;
    // target trap base address mux
    reg                         trap_mode_vectored;
    reg          [`RV_XLEN-1:0] trap_base_addr;
    // trap return address mux
    // read decode and o/p register
    reg                         rd_invalid_address;
    reg          [`RV_XLEN-1:0] rd_data;
    // write decode and registers
    reg          [`RV_XLEN-1:0] wr_data;
    //
    reg                   [1:0] mode_q;
    //
    reg          [`RV_XLEN-1:0] utvec_q;
    reg          [`RV_XLEN-1:0] uscratch_q;
    reg         [`RV_EPC_RANGE] uepc_q;
    reg       [`RV_CAUSE_RANGE] ucause_q;
    //
    reg      [`RV_EDELEG_RANGE] sedeleg_q;
    reg          [`RV_XLEN-1:0] stvec_q;
    reg          [`RV_XLEN-1:0] sscratch_q;
    reg         [`RV_EPC_RANGE] sepc_q;
    reg       [`RV_CAUSE_RANGE] scause_q;
    //
    reg          [`RV_XLEN-1:0] mstatus_q;
    reg      [`RV_EDELEG_RANGE] medeleg_q;
    reg          [`RV_XLEN-1:0] mtvec_q;
    reg          [`RV_XLEN-1:0] mscratch_q;
    reg         [`RV_EPC_RANGE] mepc_q;
    reg       [`RV_CAUSE_RANGE] mcause_q;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign mode_o = mode_q;


    //--------------------------------------------------------------
    // access restriction logic
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (addr_typecode_q == 2'b11) begin // read-only
            readonly_csr_o = 1'b1;
        end else begin
            readonly_csr_o = 1'b0;
        end
        //
        if (addr_privcode_q > mode_q) begin // priv. level too low
            priv_too_low_o = 1'b1;
        end else begin
            priv_too_low_o = 1'b0;
        end
    end
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (exs_en_i) begin
                bad_csr_addr_o  <= rd_invalid_address;
                addr_typecode_q <= addr_i[11:10];
                addr_privcode_q <= addr_i[9:8];
            end
        end
    end


    //--------------------------------------------------------------
    // trap delegation/target mode decoder
    //--------------------------------------------------------------
    assign edeleg_index = excp_cause_i[`RV_EDELEG_SZX-1:0];
    //
    always @ (*)
    begin
        case (mode_q)
            `RV_MODE_SUPERVISOR : begin
                if (medeleg_q[edeleg_index] == 1'b1) begin
                    target_mode = `RV_MODE_SUPERVISOR;
                end else begin
                    target_mode = `RV_MODE_MACHINE;
                end
            end
            `RV_MODE_USER : begin
                if (medeleg_q[edeleg_index] == 1'b1) begin
                    if (sedeleg_q[edeleg_index] == 1'b1) begin
                        target_mode = `RV_MODE_USER;
                    end else begin
                        target_mode = `RV_MODE_SUPERVISOR;
                    end
                end else begin
                    target_mode = `RV_MODE_MACHINE;
                end
            end
            default : begin
                target_mode = `RV_MODE_MACHINE;
            end
        endcase
    end


    //--------------------------------------------------------------
    // target trap base address mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        trap_mode_vectored = 1'b0;
        case (target_mode)
            `RV_MODE_MACHINE : begin
                trap_base_addr = { mtvec_q[`RV_TVEC_BASE_RANGE], `RV_TVEC_BASE_LOB };
                if (mtvec_q[`RV_TVEC_MODE_RANGE] == `RV_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            `RV_MODE_SUPERVISOR : begin
                trap_base_addr = { stvec_q[`RV_TVEC_BASE_RANGE], `RV_TVEC_BASE_LOB };
                if (stvec_q[`RV_TVEC_MODE_RANGE] == `RV_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            `RV_MODE_USER : begin
                trap_base_addr = { utvec_q[`RV_TVEC_BASE_RANGE], `RV_TVEC_BASE_LOB };
                if (utvec_q[`RV_TVEC_MODE_RANGE] == `RV_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            default : begin
                trap_base_addr = { `RV_XLEN {1'b0} }; // NOTE: Don't actually care!
            end
        endcase
        //
        if (excp_cause_i[`RV_XLEN-1] & trap_mode_vectored) begin
            trap_entry_addr_o = { { trap_base_addr[`RV_XLEN-1:2] + excp_cause_i[`RV_XLEN-3:0] }, 2'b0 };
        end else begin
            trap_entry_addr_o = trap_base_addr;
        end
    end


    //--------------------------------------------------------------
    // trap return address mux
    //--------------------------------------------------------------
    always @ (*)
    begin
        case (trap_rtn_mode_i)
            `RV_MODE_MACHINE    : trap_rtn_addr_o = { mepc_q, `RV_EPC_LOB };
            `RV_MODE_SUPERVISOR : trap_rtn_addr_o = { sepc_q, `RV_EPC_LOB };
            `RV_MODE_USER       : trap_rtn_addr_o = { uepc_q, `RV_EPC_LOB };
            default             : trap_rtn_addr_o = { `RV_XLEN {1'b0} }; // NOTE: Don't actually care!
        endcase
    end


    //--------------------------------------------------------------
    // read decode and o/p register
    //--------------------------------------------------------------
    always @ (*)
    begin
        rd_data            = 32'bx;
        rd_invalid_address = 1'b0;
        case (addr_i)
            // User CSRs
            12'h000 : rd_data = mstatus_q & `RV_USTATUS_ACCESS_MASK; // Restricted view of mstatus
            //12'h004 : rd_data = uie_q;
            12'h005 : rd_data = utvec_q;
            12'h040 : rd_data = uscratch_q;
            12'h041 : rd_data = { uepc_q, `RV_EPC_LOB }; // uepc
            12'h042 : rd_data = ucause_q; // ucause
            //12'h043 : rd_data = utval_q;
            //12'h044 : rd_data = uip_q;
            // Supervisor CSRs
            12'h100 : rd_data = mstatus_q & `RV_SSTATUS_ACCESS_MASK; // Restricted view of mstatus
            12'h102 : rd_data = { `RV_EDELEG_HOB, sedeleg_q } & `RV_SEDELEG_LEGAL_MASK;
            //12'h103 : rd_data = sideleg_q;
            //12'h104 : rd_data = sie_q;
            12'h105 : rd_data = stvec_q;
            //12'h106 : rd_data = scounteren_q;
            12'h140 : rd_data = sscratch_q;
            12'h141 : rd_data = { sepc_q, `RV_EPC_LOB }; // sepc
            12'h142 : rd_data = scause_q; // scause
            //12'h143 : rd_data = stval_q;
            //12'h144 : rd_data = sip_q;
            // Machine CSRs
            12'h300 : rd_data = mstatus_q & `RV_MSTATUS_ACCESS_MASK; // mstatus
            //12'h301 : rd_data = ; // misa
            12'h302 : rd_data = { `RV_EDELEG_HOB, medeleg_q } & `RV_MEDELEG_LEGAL_MASK;
            //12'h303 : rd_data = ; // mideleg
            //12'h304 : rd_data = ; // mie
            12'h305 : rd_data = mtvec_q; // mtvec
            //12'h306 : rd_data = ; // mcounteren
            12'h340 : rd_data = mscratch_q; // mscratch
            12'h341 : rd_data = { mepc_q, `RV_EPC_LOB }; // mepc
            12'h342 : rd_data = mcause_q; // mcause
            //12'h343 : rd_data = ; // mtval
            //12'h344 : rd_data = ; // mip
            12'hf11 : rd_data = `RV_VENDOR_ID;
            12'hf12 : rd_data = `RV_ARCHITECTURE_ID;
            12'hf13 : rd_data = `RV_IMPLEMENTATION_ID;
            12'hf14 : rd_data = `RV_HART_ID;
            default : begin
                rd_invalid_address = 1'b1;
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


    //--------------------------------------------------------------
    // write decode and registers
    //--------------------------------------------------------------
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
            //utvec_q;
            //uscratch_q;
            //uepc_q;
            //ucause_q;
            //
            //sedeleg_q;
            //stvec_q;
            //sscratch_q;
            //sepc_q;
            //scause_q;
            //
            mstatus_q  <= { `RV_XLEN {1'b0} }; // NOTE all interrupts disabled
            medeleg_q  <= 16'b0;
            mtvec_q    <= `RV_RESET_VECTOR & { { `RV_XLEN-2 {1'b1} }, 2'b00 }; // NOTE default exception entry mode = direct
            mscratch_q <= { `RV_XLEN {1'b0} };
            //mepc_q;
            //mcause_q;
        end else if (clk_en_i) begin
            if (exs_en_i) begin
                if (jump_to_trap_i) begin // take over any pending interrupt
                    // processor priv. mode register
                    mode_q <= `RV_MODE_MACHINE;
                    // accessible CSRs
                    case (target_mode)
                        `RV_MODE_MACHINE : begin
                            mstatus_q[`RV_MSTATUS_MPP_RANGE]  <= mode_q;
                            mstatus_q[`RV_MSTATUS_MPIE_INDEX] <= mstatus_q[`RV_MSTATUS_MIE_INDEX];
                            mstatus_q[`RV_MSTATUS_MIE_INDEX]  <= 1'b0;
                            mepc_q   <= excp_pc_i[`RV_EPC_RANGE];
                            mcause_q <= excp_cause_i;
                        end
                        `RV_MODE_SUPERVISOR : begin
                            mstatus_q[`RV_MSTATUS_SPP_INDEX]  <= |mode_q; // 0 iff was user mode, 1 otherwise
                            mstatus_q[`RV_MSTATUS_SPIE_INDEX] <= mstatus_q[`RV_MSTATUS_SIE_INDEX];
                            mstatus_q[`RV_MSTATUS_SIE_INDEX]  <= 1'b0;
                            sepc_q   <= excp_pc_i[`RV_EPC_RANGE];
                            scause_q <= excp_cause_i;
                        end
                        `RV_MODE_USER : begin
                            mstatus_q[`RV_MSTATUS_UPIE_INDEX] <= mstatus_q[`RV_MSTATUS_UIE_INDEX];
                            mstatus_q[`RV_MSTATUS_UIE_INDEX]  <= 1'b0;
                            uepc_q   <= excp_pc_i[`RV_EPC_RANGE];
                            ucause_q <= excp_cause_i;
                        end
                    endcase
                end else if (trap_rtn_i) begin
                    mstatus_q[`RV_MSTATUS_MPP_RANGE] <= `RV_MODE_USER;
                    case (trap_rtn_mode_i)
                        `RV_MODE_MACHINE : begin
                            mode_q                            <= mstatus_q[`RV_MSTATUS_MPP_RANGE];
                            mstatus_q[`RV_MSTATUS_MIE_INDEX]  <= mstatus_q[`RV_MSTATUS_MPIE_INDEX];
                            mstatus_q[`RV_MSTATUS_MPIE_INDEX] <= 1'b1;
                        end
                        `RV_MODE_SUPERVISOR : begin
                            if (mstatus_q[`RV_MSTATUS_SPP_INDEX] == 1'b0) begin
                                mode_q <= `RV_MODE_USER;
                            end
                            mstatus_q[`RV_MSTATUS_SIE_INDEX]  <= mstatus_q[`RV_MSTATUS_SPIE_INDEX];
                            mstatus_q[`RV_MSTATUS_SPIE_INDEX] <= 1'b1;
                        end
                        `RV_MODE_USER : begin
                            mstatus_q[`RV_MSTATUS_UIE_INDEX]  <= mstatus_q[`RV_MSTATUS_UPIE_INDEX];
                            mstatus_q[`RV_MSTATUS_UPIE_INDEX] <= 1'b1;
                        end
                    endcase
                end else if (wr_i) begin
                    case (wr_addr_i)
                        // User CSRs
                        12'h000 : mstatus_q  <= (wr_data & `RV_USTATUS_ACCESS_MASK) | (mstatus_q & ~`RV_USTATUS_ACCESS_MASK);
                        12'h005 : utvec_q    <= wr_data & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        12'h040 : uscratch_q <= wr_data;
                        12'h041 : uepc_q     <= wr_data[`RV_EPC_RANGE];
                        12'h042 : ucause_q   <= wr_data; // WLRL
                        // Supervisor CSRs
                        12'h100 : mstatus_q  <= (wr_data & `RV_SSTATUS_ACCESS_MASK) | (mstatus_q & ~`RV_SSTATUS_ACCESS_MASK);
                        12'h102 : sedeleg_q  <= wr_data[`RV_EDELEG_RANGE] & `RV_SEDELEG_LEGAL_MASK;
                        12'h105 : stvec_q    <= wr_data & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        12'h140 : sscratch_q <= wr_data;
                        12'h141 : sepc_q     <= wr_data[`RV_EPC_RANGE];
                        12'h142 : scause_q   <= wr_data; // WLRL
                        // Machine CSRs
                        12'h300 : mstatus_q  <= (wr_data & `RV_MSTATUS_ACCESS_MASK);
                        12'h302 : medeleg_q  <= wr_data[`RV_EDELEG_RANGE] & `RV_MEDELEG_LEGAL_MASK;
                        12'h305 : mtvec_q    <= wr_data & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        12'h340 : mscratch_q <= wr_data;
                        12'h341 : mepc_q     <= wr_data[`RV_EPC_RANGE];
                        12'h342 : mcause_q   <= wr_data; // WLRL
                        default : begin
                        end
                    endcase;
                end
            end
        end
    end
endmodule
