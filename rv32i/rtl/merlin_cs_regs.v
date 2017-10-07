/*
 * Author         : Tom Stanway-Mayers
 * Description    : CSR file and Priv. Arch. Implementation
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

// TODO - implement the remaining CSRs

/* ==== CRS Field Specifications ====
 * WIRI:
 * WPRI:
 * WLRL:
 *  Exceptions are not raised on illegal writes (optional)
 *  Will return last written value regardless of legality
 * WARL:
 */

`include "riscv_defs.v"

module merlin_cs_regs
    (
        //
        input  wire                clk_i,
        input  wire                clk_en_i,
        input  wire                resetb_i,
        // stage enable
        input  wire                exs_en_i,
        // access request / error reporting interface
        input  wire                access_i,
        input  wire         [11:0] addr_i,
        output reg                 bad_csr_addr_o,
        output reg                 readonly_csr_o,
        output reg                 priv_too_low_o,
        output reg  [`RV_XLEN-1:0] rd_data_o,
        // write-back interface
        input  wire                wr_i, // already gated by the exceptions in the exception interface
        input  wire         [11:0] wr_addr_i,
        input  wire [`RV_XLEN-1:0] wr_data_i,
        // exception, interrupt, and hart vectoring interface
        input  wire                ex_valid_i,
        input  wire                irqm_extern_i,
        input  wire                irqm_softw_i,
        input  wire                irqm_timer_i,
        input  wire                irqs_extern_i,
        input  wire                irqs_softw_i,
        input  wire                irqs_timer_i,
        input  wire                irqu_extern_i,
        input  wire                irqu_softw_i,
        input  wire                irqu_timer_i,
        input  wire                excp_ferr_i,
        input  wire                excp_uerr_i,
        input  wire                excp_maif_i,
        input  wire                excp_mala_i,
        input  wire                excp_masa_i,
        input  wire                excp_ilgl_i,
        input  wire                excp_ecall_i,
        input  wire [`RV_XLEN-1:0] excp_pc_i,
        input  wire [`RV_XLEN-1:0] excp_ins_i,
        //
        output wire                interrupt_o,
        //
        output wire                jump_to_trap_o,
        output reg  [`RV_XLEN-1:0] trap_entry_addr_o,
        input  wire                trap_rtn_i,
        input  wire          [1:0] trap_rtn_mode_i,
        output reg  [`RV_XLEN-1:0] trap_rtn_addr_o,
        // static i/o
        output wire          [1:0] mode_o, // TODO - make sure the mode @ time of trap call/rtn
        // tracer port
        output wire [`RV_XLEN-1:0] trap_cause_o
    );

    //--------------------------------------------------------------

    // interface assignments
    // interrupt logic
    wire       [`RV_CSR_IP_RANGE] raw_irqv;
    wire       [`RV_CSR_IP_RANGE] irqv;
    wire                   [11:0] irqv_mask;
    reg                           interrupt;
    // interrupt cause encoder
    reg            [`RV_XLEN-1:0] icause;
    // exception cause encoder
    reg            [`RV_XLEN-1:0] ecause;
    // trap value encoder
    reg            [`RV_XLEN-1:0] trap_value;
    // trap cause select
    reg            [`RV_XLEN-1:0] trap_cause;
    // access restriction logic
    reg                     [1:0] addr_typecode_q;
    reg                     [1:0] addr_privcode_q;
    // trap delegation/target mode decoder
    wire [`RV_CSR_EDELEG_SZX-1:0] deleg_index;
    reg                     [1:0] target_mode;
    // target trap base address mux
    reg                           trap_mode_vectored;
    reg            [`RV_XLEN-1:0] trap_base_addr;
    // trap return address mux
    // read decode and o/p register
    reg                           rd_invalid_address;
    reg            [`RV_XLEN-1:0] rd_data;
    // write decode and registers
    //
    reg                     [1:0] mode_q;
    //
    reg            [`RV_XLEN-1:0] utvec_q;
    reg            [`RV_XLEN-1:0] uscratch_q;
    reg       [`RV_CSR_EPC_RANGE] uepc_q;
    reg            [`RV_XLEN-1:0] ucause_q;
    reg            [`RV_XLEN-1:0] utval_q;
    //
    reg    [`RV_CSR_EDELEG_RANGE] sedeleg_q;
    reg    [`RV_CSR_IDELEG_RANGE] sideleg_q;
    reg            [`RV_XLEN-1:0] stvec_q;
    reg            [`RV_XLEN-1:0] sscratch_q;
    reg       [`RV_CSR_EPC_RANGE] sepc_q;
    reg            [`RV_XLEN-1:0] scause_q;
    reg            [`RV_XLEN-1:0] stval_q;
    //
    reg            [`RV_XLEN-1:0] mstatus_q;
    reg    [`RV_CSR_EDELEG_RANGE] medeleg_q;
    reg    [`RV_CSR_IDELEG_RANGE] mideleg_q;
    reg        [`RV_CSR_IE_RANGE] mie_q;
    reg            [`RV_XLEN-1:0] mtvec_q;
    reg            [`RV_XLEN-1:0] mscratch_q;
    reg       [`RV_CSR_EPC_RANGE] mepc_q;
    reg            [`RV_XLEN-1:0] mcause_q;
    reg            [`RV_XLEN-1:0] mtval_q;
    reg        [`RV_CSR_IP_RANGE] mip_q;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign mode_o = mode_q;


    //--------------------------------------------------------------
    // interrupt logic
    //--------------------------------------------------------------
    assign raw_irqv = { irqm_extern_i, 1'b0, irqs_extern_i, irqu_extern_i,
                        irqm_timer_i,  1'b0, irqs_timer_i,  irqu_timer_i,
                        irqm_softw_i,  1'b0, irqs_softw_i,  irqu_softw_i } | mip_q;
    //
    assign irqv_mask   = { mstatus_q[3:0], mstatus_q[3:0], mstatus_q[3:0] };
    assign irqv        = raw_irqv & mie_q & irqv_mask;
    assign interrupt_o = interrupt;
    //
    always @ (*)
    begin
        case (mode_q)
            `RV_CSR_MODE_MACHINE    : interrupt = |(irqv & 12'h888);
            `RV_CSR_MODE_SUPERVISOR : interrupt = |(irqv & 12'haaa);
            `RV_CSR_MODE_USER       : interrupt = |(irqv);
            default                 : interrupt = 1'b0;
        endcase
    end


    //--------------------------------------------------------------
    // interrupt cause encoder
    //--------------------------------------------------------------
    /*
     * Traps should be taken with the following priority:
     *   1) external interrupts
     *   2) software interrupts
     *   3) timer interrupts
     *   4) synchronous traps
     */
    always @ (*)
    begin
        // NOTE: IMPORTANT: This desision tree must be ordered correctly
        if (|(irqv[11:8]) == 1'b1) begin // external interrupt
            if (irqv[11] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_ME;
            end else if (irqv[9] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_SE;
            end else begin //if (irqv[8] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_UE;
            end
        end else if (|(irqv[3:0]) == 1'b1) begin // software interrupt
            if (irqv[7] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_MS;
            end else if (irqv[5] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_SS;
            end else begin //if (irqv[4] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_US;
            end
        end else begin //if (|(irqv[7:4]) == 1'b1) begin // timer interrupt
            if (irqv[3] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_MT;
            end else if (irqv[1] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_ST;
            end else begin //if (irqv[0] == 1'b1) begin
                icause = `RV_CSR_INTR_CAUSE_UT;
            end
        end
    end


    //--------------------------------------------------------------
    // exception cause encoder
    //--------------------------------------------------------------
    /*
     * Exception cause encoding:
     *   0000 - miaf
     *   0100 - mala
     *   0110 - masa
     *
     *   0001 - ferr
     *   0010 - ilgl
     *
     *   1000 - ecall(u)
     *   1001 - ecall(s)
     *   1011 - ecall(m)
     */
    always @ (*)
    begin
        if (excp_ferr_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT;
        end else if (excp_uerr_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
        end else if (excp_ilgl_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
        end else if (excp_maif_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED;
        end else if (excp_mala_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED;
        end else if (excp_masa_i) begin
            ecause = `RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED;
        end else begin //if (excp_ecall_i) begin // NOTE: this is noly the cause if the instruction hasn't generated any other exceptions
            case (mode_q)
                `RV_CSR_MODE_MACHINE    : ecause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_MMODE;
                `RV_CSR_MODE_SUPERVISOR : ecause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_SMODE;
                `RV_CSR_MODE_USER       : ecause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_UMODE;
                default                 : ecause = { `RV_XLEN {1'b0} }; // NOTE: don't actually care
            endcase
        end
    end


    //--------------------------------------------------------------
    // trap value encoder
    //--------------------------------------------------------------
    always @ (*)
    begin
        if (interrupt) begin // TODO hardware breakpoint | page fault
            trap_value = { `RV_XLEN {1'b0} };
        end else if (excp_maif_i | excp_mala_i | excp_masa_i) begin
            trap_value = excp_pc_i;
        end else if (excp_uerr_i | excp_ilgl_i) begin
            trap_value = excp_ins_i;
        end else begin
            trap_value = { `RV_XLEN {1'b0} };
        end
    end


    //--------------------------------------------------------------
    // trap cause select
    //--------------------------------------------------------------
    /*
     * Traps should be taken with the following priority:
     *   1) external interrupts
     *   2) software interrupts
     *   3) timer interrupts
     *   4) synchronous traps
     */
    assign jump_to_trap_o = ex_valid_i &
                            (
                                interrupt    |
                                excp_ecall_i |
                                excp_ferr_i  |
                                excp_uerr_i  |
                                excp_maif_i  |
                                excp_mala_i  |
                                excp_masa_i  |
                                excp_ilgl_i
                            );
    assign trap_cause_o = trap_cause;
    //
    always @ (*)
    begin
        if (interrupt) begin
            trap_cause = icause;
        end else begin
            trap_cause = ecause;
        end
    end


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
            if (exs_en_i & access_i) begin
                bad_csr_addr_o  <= rd_invalid_address;
                addr_typecode_q <= addr_i[11:10];
                addr_privcode_q <= addr_i[9:8];
            end
        end
    end


    //--------------------------------------------------------------
    // trap delegation/target mode decoder
    //--------------------------------------------------------------
    assign deleg_index = trap_cause[`RV_CSR_EDELEG_SZX-1:0];
    //
    always @ (*)
    begin
        case (mode_q)
            `RV_CSR_MODE_SUPERVISOR : begin
                if (interrupt == 1'b1) begin // interrupt
                    if (mideleg_q[deleg_index] == 1'b1) begin
                        target_mode = `RV_CSR_MODE_SUPERVISOR;
                    end else begin
                        target_mode = `RV_CSR_MODE_MACHINE;
                    end
                end else begin // exception
                    if (medeleg_q[deleg_index] == 1'b1) begin
                        target_mode = `RV_CSR_MODE_SUPERVISOR;
                    end else begin
                        target_mode = `RV_CSR_MODE_MACHINE;
                    end
                end
            end
            `RV_CSR_MODE_USER : begin
                if (interrupt == 1'b1) begin // interrupt
                    if (mideleg_q[deleg_index] == 1'b1) begin
                        if (sideleg_q[deleg_index] == 1'b1) begin
                            target_mode = `RV_CSR_MODE_USER;
                        end else begin
                            target_mode = `RV_CSR_MODE_SUPERVISOR;
                        end
                    end else begin
                        target_mode = `RV_CSR_MODE_MACHINE;
                    end
                end else begin // exception
                    if (medeleg_q[deleg_index] == 1'b1) begin
                        if (sedeleg_q[deleg_index] == 1'b1) begin
                            target_mode = `RV_CSR_MODE_USER;
                        end else begin
                            target_mode = `RV_CSR_MODE_SUPERVISOR;
                        end
                    end else begin
                        target_mode = `RV_CSR_MODE_MACHINE;
                    end
                end
            end
            default : begin
                target_mode = `RV_CSR_MODE_MACHINE;
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
            `RV_CSR_MODE_MACHINE : begin
                trap_base_addr = { mtvec_q[`RV_CSR_TVEC_BASE_RANGE], `RV_CSR_TVEC_BASE_LOB };
                if (mtvec_q[`RV_CSR_TVEC_MODE_RANGE] == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            `RV_CSR_MODE_SUPERVISOR : begin
                trap_base_addr = { stvec_q[`RV_CSR_TVEC_BASE_RANGE], `RV_CSR_TVEC_BASE_LOB };
                if (stvec_q[`RV_CSR_TVEC_MODE_RANGE] == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            `RV_CSR_MODE_USER : begin
                trap_base_addr = { utvec_q[`RV_CSR_TVEC_BASE_RANGE], `RV_CSR_TVEC_BASE_LOB };
                if (utvec_q[`RV_CSR_TVEC_MODE_RANGE] == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_mode_vectored = 1'b1;
                end
            end
            default : begin
                trap_base_addr = { `RV_XLEN {1'b0} }; // NOTE: Don't actually care!
            end
        endcase
        //
        if (interrupt & trap_mode_vectored) begin
            trap_entry_addr_o = { { trap_base_addr[`RV_XLEN-1:2] + icause[`RV_XLEN-3:0] }, 2'b0 };
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
            `RV_CSR_MODE_MACHINE    : trap_rtn_addr_o = { mepc_q, `RV_CSR_EPC_LOB };
            `RV_CSR_MODE_SUPERVISOR : trap_rtn_addr_o = { sepc_q, `RV_CSR_EPC_LOB };
            `RV_CSR_MODE_USER       : trap_rtn_addr_o = { uepc_q, `RV_CSR_EPC_LOB };
            default                 : trap_rtn_addr_o = { `RV_XLEN {1'b0} }; // NOTE: Don't actually care!
        endcase
    end


    //--------------------------------------------------------------
    // read decode and o/p register
    //--------------------------------------------------------------
    always @ (*)
    begin
        rd_data            = 32'b0; // zero fields by default
        rd_invalid_address = 1'b0;
        case (addr_i)
            // User CSRs
            12'h000 : rd_data = mstatus_q & `RV_CSR_USTATUS_RW_MASK;
            12'h004 : rd_data = { `RV_CSR_IE_HOB, (mie_q & `RV_CSR_UIE_RW_MASK) };
            12'h005 : rd_data = utvec_q;
            12'h040 : rd_data = uscratch_q;
            12'h041 : rd_data = { uepc_q, `RV_CSR_EPC_LOB };
            12'h042 : rd_data = ucause_q;
            12'h043 : rd_data = utval_q;
            12'h044 : rd_data = { `RV_CSR_IP_HOB, ((mip_q | (raw_irqv & mideleg_q & sideleg_q)) & `RV_CSR_UIP_RD_MASK) };
            // Supervisor CSRs
            12'h100 : rd_data = mstatus_q & `RV_CSR_SSTATUS_RW_MASK;
            12'h102 : rd_data = { `RV_CSR_EDELEG_HOB, (sedeleg_q & `RV_CSR_SEDELEG_RW_MASK) };
            12'h103 : rd_data = { `RV_CSR_IDELEG_HOB, (sideleg_q & `RV_CSR_SIDELEG_RW_MASK) };
            12'h104 : rd_data = {     `RV_CSR_IE_HOB,         (mie_q & `RV_CSR_SIE_RW_MASK) };
            12'h105 : rd_data = stvec_q;
            //12'h106 : rd_data = scounteren_q;
            12'h140 : rd_data = sscratch_q;
            12'h141 : rd_data = { sepc_q, `RV_CSR_EPC_LOB };
            12'h142 : rd_data = scause_q;
            12'h143 : rd_data = stval_q;
            12'h144 : rd_data = { `RV_CSR_IP_HOB, ((mip_q | (raw_irqv & mideleg_q)) & `RV_CSR_SIP_RD_MASK) };
            // Machine CSRs
            12'h300 : rd_data = mstatus_q & `RV_CSR_MSTATUS_RW_MASK;
            12'h301 : rd_data = { `RV_XLEN {1'b0} };
            12'h302 : rd_data = { `RV_CSR_EDELEG_HOB, (medeleg_q & `RV_CSR_MEDELEG_RW_MASK) };
            12'h303 : rd_data = { `RV_CSR_IDELEG_HOB, (mideleg_q & `RV_CSR_MIDELEG_RW_MASK) };
            12'h304 : rd_data = {     `RV_CSR_IE_HOB,         (mie_q & `RV_CSR_MIE_RW_MASK) };
            12'h305 : rd_data = mtvec_q;
            //12'h306 : rd_data = ; // mcounteren
            12'h340 : rd_data = mscratch_q;
            12'h341 : rd_data = { mepc_q, `RV_CSR_EPC_LOB };
            12'h342 : rd_data = mcause_q;
            12'h343 : rd_data = mtval_q;
            12'h344 : rd_data = { `RV_CSR_IP_HOB, ((mip_q | raw_irqv) & `RV_CSR_MIP_RD_MASK) };
            12'hf11 : rd_data = `RV_VENDOR_ID;
            12'hf12 : rd_data = `RV_ARCHITECTURE_ID;
            12'hf13 : rd_data = `RV_IMPLEMENTATION_ID;
            12'hf14 : rd_data = `RV_HART_ID;
            default : begin
                rd_invalid_address = 1'b1;
            end
        endcase
    end
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (exs_en_i & access_i) begin
                rd_data_o <= rd_data;
            end
        end
    end


    //--------------------------------------------------------------
    // write decode and registers
    //--------------------------------------------------------------
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            // processor priv. mode register
            mode_q     <= `RV_CSR_MODE_MACHINE;
            // accessible CSRs
            //utvec_q
            //uscratch_q
            //uepc_q
            //ucause_q
            //utval_q
            //ucause_q
            //
            //sedeleg_q
            //sideleg_q
            //stvec_q
            //scounteren_q
            //sscratch_q
            //sepc_q
            //scause_q
            //stval_q
            //
            mstatus_q  <= `RV_CSR_STATUS_RESET_VALUE;
            //misa_q
            medeleg_q  <= `RV_CSR_EDELEG_RESET_VALUE;
            mideleg_q  <= `RV_CSR_IDELEG_RESET_VALUE;
            mie_q      <= `RV_CSR_MIE_RESET_VALUE;
            mtvec_q    <= `RV_RESET_VECTOR & { { `RV_XLEN-2 {1'b1} }, 2'b00 }; // NOTE default exception entry mode = direct
            //mcounteren_q
            //mscratch_q
            //mepc_q
            //mcause_q
            //mtval_q
            mip_q      <= `RV_CSR_MIP_RESET_VALUE;
        end else if (clk_en_i) begin
            if (exs_en_i) begin
                if (jump_to_trap_o) begin // take over any pending interrupt
                    // processor priv. mode register
                    mode_q <= `RV_CSR_MODE_MACHINE;
                    // accessible CSRs
                    case (target_mode)
                        `RV_CSR_MODE_MACHINE : begin
                            mstatus_q[`RV_CSR_STATUS_MPP_RANGE]  <= mode_q;
                            mstatus_q[`RV_CSR_STATUS_MPIE_INDEX] <= mstatus_q[`RV_CSR_STATUS_MIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_MIE_INDEX]  <= 1'b0;
                            mepc_q   <= excp_pc_i[`RV_CSR_EPC_RANGE];
                            mcause_q <= trap_cause;
                            mtval_q  <= trap_value;
                        end
                        `RV_CSR_MODE_SUPERVISOR : begin
                            mstatus_q[`RV_CSR_STATUS_SPP_INDEX]  <= |mode_q; // 0 iff was user mode, 1 otherwise
                            mstatus_q[`RV_CSR_STATUS_SPIE_INDEX] <= mstatus_q[`RV_CSR_STATUS_SIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_SIE_INDEX]  <= 1'b0;
                            sepc_q   <= excp_pc_i[`RV_CSR_EPC_RANGE];
                            scause_q <= trap_cause;
                            stval_q  <= trap_value;
                        end
                        `RV_CSR_MODE_USER : begin
                            mstatus_q[`RV_CSR_STATUS_UPIE_INDEX] <= mstatus_q[`RV_CSR_STATUS_UIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_UIE_INDEX]  <= 1'b0;
                            uepc_q   <= excp_pc_i[`RV_CSR_EPC_RANGE];
                            ucause_q <= trap_cause;
                            utval_q  <= trap_value;
                        end
                        default : begin
                        end
                    endcase
                end else if (trap_rtn_i) begin
                    mstatus_q[`RV_CSR_STATUS_MPP_RANGE] <= `RV_CSR_MODE_USER;
                    case (trap_rtn_mode_i)
                        `RV_CSR_MODE_MACHINE : begin
                            mode_q                               <= mstatus_q[`RV_CSR_STATUS_MPP_RANGE];
                            mstatus_q[`RV_CSR_STATUS_MIE_INDEX]  <= mstatus_q[`RV_CSR_STATUS_MPIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_MPIE_INDEX] <= 1'b1;
                        end
                        `RV_CSR_MODE_SUPERVISOR : begin
                            if (mstatus_q[`RV_CSR_STATUS_SPP_INDEX] == 1'b0) begin
                                mode_q <= `RV_CSR_MODE_USER;
                            end
                            mstatus_q[`RV_CSR_STATUS_SIE_INDEX]  <= mstatus_q[`RV_CSR_STATUS_SPIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_SPIE_INDEX] <= 1'b1;
                        end
                        `RV_CSR_MODE_USER : begin
                            mstatus_q[`RV_CSR_STATUS_UIE_INDEX]  <= mstatus_q[`RV_CSR_STATUS_UPIE_INDEX];
                            mstatus_q[`RV_CSR_STATUS_UPIE_INDEX] <= 1'b1;
                        end
                        default : begin
                        end
                    endcase
                end else if (wr_i) begin
                    case (wr_addr_i)
                        // User CSRs
                        12'h000 : mstatus_q  <= (wr_data_i & `RV_CSR_USTATUS_RW_MASK) | (mstatus_q & ~`RV_CSR_USTATUS_RW_MASK);
                        12'h004 : mie_q      <= (wr_data_i[`RV_CSR_IE_RANGE] & `RV_CSR_UIE_RW_MASK) | (mie_q & ~`RV_CSR_UIE_RW_MASK);
                        12'h005 : utvec_q    <= wr_data_i & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        12'h040 : uscratch_q <= wr_data_i;
                        12'h041 : uepc_q     <= wr_data_i[`RV_CSR_EPC_RANGE];
                        12'h042 : ucause_q   <= wr_data_i;
                        12'h043 : utval_q    <= wr_data_i;
                        12'h044 : mip_q      <= (wr_data_i[`RV_CSR_IP_RANGE] & `RV_CSR_UIP_WR_MASK) | (mip_q & ~`RV_CSR_UIP_WR_MASK);
                        // Supervisor CSRs
                        12'h100 : mstatus_q  <= (wr_data_i & `RV_CSR_SSTATUS_RW_MASK) | (mstatus_q & ~`RV_CSR_SSTATUS_RW_MASK);
                        12'h102 : sedeleg_q  <= wr_data_i[`RV_CSR_EDELEG_RANGE] & `RV_CSR_SEDELEG_RW_MASK;
                        12'h103 : sideleg_q  <= wr_data_i[`RV_CSR_IDELEG_RANGE] & `RV_CSR_SIDELEG_RW_MASK;
                        12'h104 : mie_q      <= (wr_data_i[`RV_CSR_IE_RANGE] & `RV_CSR_SIE_RW_MASK) | (mie_q & ~`RV_CSR_SIE_RW_MASK);
                        12'h105 : stvec_q    <= wr_data_i & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        //12'h106 : scounteren_q <=
                        12'h140 : sscratch_q <= wr_data_i;
                        12'h141 : sepc_q     <= wr_data_i[`RV_CSR_EPC_RANGE];
                        12'h142 : scause_q   <= wr_data_i; // WLRL
                        12'h143 : stval_q    <= wr_data_i;
                        12'h144 : mip_q      <= (wr_data_i[`RV_CSR_IP_RANGE] & `RV_CSR_SIP_WR_MASK) | (mip_q & ~`RV_CSR_SIP_WR_MASK);
                        // Machine CSRs
                        12'h300 : mstatus_q  <= (wr_data_i & `RV_CSR_MSTATUS_RW_MASK);
                        //12'h301 : misa_q     <=
                        12'h302 : medeleg_q  <= wr_data_i[`RV_CSR_EDELEG_RANGE] & `RV_CSR_MEDELEG_RW_MASK;
                        12'h303 : mideleg_q  <= wr_data_i[`RV_CSR_IDELEG_RANGE] & `RV_CSR_MIDELEG_RW_MASK;
                        12'h304 : mie_q      <= wr_data_i[`RV_CSR_IE_RANGE] & `RV_CSR_MIE_RW_MASK;
                        12'h305 : mtvec_q    <= wr_data_i & { { `RV_XLEN-2 {1'b1} }, 2'b01 }; // NOTE vec. mode >=2 reserved
                        //12'h306 : mcounteren_q
                        12'h340 : mscratch_q <= wr_data_i;
                        12'h341 : mepc_q     <= wr_data_i[`RV_CSR_EPC_RANGE];
                        12'h342 : mcause_q   <= wr_data_i;
                        12'h343 : mtval_q    <= wr_data_i;
                        12'h344 : mip_q      <= wr_data_i[`RV_CSR_IP_RANGE] & `RV_CSR_MIP_WR_MASK;
                        default : begin
                        end
                    endcase
                end
            end
        end
    end
endmodule
