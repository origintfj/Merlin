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
        input  wire                reset_i,
        // access request / error reporting interface
        input  wire                access_rd_i,
        input  wire                access_wr_i,
        input  wire         [11:0] access_addr_i,
        output wire                access_badcsr_o,
        output wire                access_badwrite_o,
        output wire                access_badpriv_o,
        output reg  [`RV_XLEN-1:0] access_rd_data_o,
        // write-back interface
        input  wire                wr_i, // already gated by the exceptions in the exception interface
        input  wire          [1:0] wr_mode_i,
        input  wire         [11:0] wr_addr_i,
        input  wire [`RV_XLEN-1:0] wr_data_i,
        // exception, interrupt, and hart vectoring interface
        input  wire                ex_valid_i,
        input  wire                irqm_extern_i,
        input  wire                irqm_softw_i,
        input  wire                irqm_timer_i,
        input  wire                irqs_extern_i,
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
        output wire                trap_call_o,       // jump to trap
        output wire [`RV_XLEN-1:0] trap_call_addr_o,  // address to jump to
        output wire [`RV_XLEN-1:0] trap_call_cause_o, // cause of trap
        output reg  [`RV_XLEN-1:0] trap_call_value_o, // trap call value ( [m|s|u]tval )
        input  wire                trap_rtn_i,        // return from trap
        input  wire          [1:0] trap_rtn_mode_i,   // mode of return ( [m|s|u]ret )
        output reg  [`RV_XLEN-1:0] trap_rtn_addr_o,   // address to jump (return) to
        // static i/o
        output wire          [1:0] mode_o             // current processor mode
    );

    //--------------------------------------------------------------

    // interface assignments
    // access restriction logic
    // csr read
    reg                 access_badcsr;
    // mstatus / sstatus / ustatus
    wire [`RV_XLEN-1:0] mstatus;
    wire [`RV_XLEN-1:0] sstatus;
    wire [`RV_XLEN-1:0] ustatus;
    //
    reg           [1:0] mode_d;
    reg           [1:0] mstatus_mpp_d;
    reg                 mstatus_spp_d;
    reg                 mstatus_mpie_d;
    reg                 mstatus_spie_d;
    reg                 mstatus_upie_d;
    reg                 mstatus_mie_d;
    reg                 mstatus_sie_d;
    reg                 mstatus_uie_d;
    //
    reg           [1:0] mode_q;
    reg           [1:0] mstatus_mpp_q;
    reg                 mstatus_spp_q;
    reg                 mstatus_mpie_q;
    reg                 mstatus_spie_q;
    reg                 mstatus_upie_q;
    reg                 mstatus_mie_q;
    reg                 mstatus_sie_q;
    reg                 mstatus_uie_q;
    // medeleg
    wire [`RV_XLEN-1:0] medeleg;
    //
    reg                 medeleg_ecfs_d;
    reg                 medeleg_ecfu_d;
    reg                 medeleg_saf_d;
    reg                 medeleg_sam_d;
    reg                 medeleg_laf_d;
    reg                 medeleg_lam_d;
    reg                 medeleg_ii_d;
    reg                 medeleg_iaf_d;
    reg                 medeleg_iam_d;
    //
    reg                 medeleg_ecfs_q;
    reg                 medeleg_ecfu_q;
    reg                 medeleg_saf_q;
    reg                 medeleg_sam_q;
    reg                 medeleg_laf_q;
    reg                 medeleg_lam_q;
    reg                 medeleg_ii_q;
    reg                 medeleg_iaf_q;
    reg                 medeleg_iam_q;
    // sedeleg
    wire [`RV_XLEN-1:0] sedeleg;
    //
    reg                 sedeleg_ecfu_d;
    reg                 sedeleg_saf_d;
    reg                 sedeleg_sam_d;
    reg                 sedeleg_laf_d;
    reg                 sedeleg_lam_d;
    reg                 sedeleg_ii_d;
    reg                 sedeleg_iaf_d;
    reg                 sedeleg_iam_d;
    //
    reg                 sedeleg_ecfu_q;
    reg                 sedeleg_saf_q;
    reg                 sedeleg_sam_q;
    reg                 sedeleg_laf_q;
    reg                 sedeleg_lam_q;
    reg                 sedeleg_ii_q;
    reg                 sedeleg_iaf_q;
    reg                 sedeleg_iam_q;
    // mideleg
    wire [`RV_XLEN-1:0] mideleg;
    //
    reg                 mideleg_usi_d;
    reg                 mideleg_ssi_d;
    reg                 mideleg_uti_d;
    reg                 mideleg_sti_d;
    reg                 mideleg_uei_d;
    reg                 mideleg_sei_d;
    //
    reg                 mideleg_usi_q;
    reg                 mideleg_ssi_q;
    reg                 mideleg_uti_q;
    reg                 mideleg_sti_q;
    reg                 mideleg_uei_q;
    reg                 mideleg_sei_q;
    // sideleg
    wire [`RV_XLEN-1:0] sideleg;
    //
    reg                 sideleg_usi_d;
    reg                 sideleg_uti_d;
    reg                 sideleg_uei_d;
    //
    reg                 sideleg_usi_q;
    reg                 sideleg_uti_q;
    reg                 sideleg_uei_q;
    // mtvec
    wire [`RV_XLEN-1:0] mtvec;
    //
    reg  [`RV_XLEN-3:0] mtvec_d;
    reg           [1:0] mtvec_mode_d;
    //
    reg  [`RV_XLEN-3:0] mtvec_q;
    reg           [1:0] mtvec_mode_q;
    // stvec
    wire [`RV_XLEN-1:0] stvec;
    //
    reg  [`RV_XLEN-3:0] stvec_d;
    reg           [1:0] stvec_mode_d;
    //
    reg  [`RV_XLEN-3:0] stvec_q;
    reg           [1:0] stvec_mode_q;
    // utvec
    wire [`RV_XLEN-1:0] utvec;
    //
    reg  [`RV_XLEN-3:0] utvec_d;
    reg           [1:0] utvec_mode_d;
    //
    reg  [`RV_XLEN-3:0] utvec_q;
    reg           [1:0] utvec_mode_q;
    // mie / sie / uie
    wire [`RV_XLEN-1:0] mie;
    wire [`RV_XLEN-1:0] sie;
    wire [`RV_XLEN-1:0] uie;
    //
    reg                 mie_meie_d;
    reg                 mie_seie_d;
    reg                 mie_ueie_d;
    reg                 mie_mtie_d;
    reg                 mie_stie_d;
    reg                 mie_utie_d;
    reg                 mie_msie_d;
    reg                 mie_ssie_d;
    reg                 mie_usie_d;
    //
    reg                 mie_meie_q;
    reg                 mie_seie_q;
    reg                 mie_ueie_q;
    reg                 mie_mtie_q;
    reg                 mie_stie_q;
    reg                 mie_utie_q;
    reg                 mie_msie_q;
    reg                 mie_ssie_q;
    reg                 mie_usie_q;
    // mip / sip / uip
    wire [`RV_XLEN-1:0] mip;
    wire [`RV_XLEN-1:0] sip;
    wire [`RV_XLEN-1:0] uip;
    //
    wire                mip_meip;
    wire                mip_mtip;
    wire                mip_msip;
    wire                mip_seip;
    wire                mip_stip;
    wire                mip_ssip;
    wire                mip_ueip;
    wire                mip_utip;
    wire                mip_usip;
    //
    reg                 mip_seip_d;
    reg                 mip_ueip_d;
    reg                 mip_stip_d;
    reg                 mip_utip_d;
    reg                 mip_ssip_d;
    reg                 mip_usip_d;
    //
    reg                 mip_seip_q;
    reg                 mip_ueip_q;
    reg                 mip_stip_q;
    reg                 mip_utip_q;
    reg                 mip_ssip_q;
    reg                 mip_usip_q;
    // mscratch
    wire [`RV_XLEN-1:0] mscratch;
    //
    reg  [`RV_XLEN-1:0] mscratch_d;
    //
    reg  [`RV_XLEN-1:0] mscratch_q;
    // sscratch
    wire [`RV_XLEN-1:0] sscratch;
    //
    reg  [`RV_XLEN-1:0] sscratch_d;
    //
    reg  [`RV_XLEN-1:0] sscratch_q;
    // uscratch
    wire [`RV_XLEN-1:0] uscratch;
    //
    reg  [`RV_XLEN-1:0] uscratch_d;
    //
    reg  [`RV_XLEN-1:0] uscratch_q;
    // mepc
    wire [`RV_XLEN-1:0] mepc;
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] mepc_d;
`else
    reg  [`RV_XLEN-3:0] mepc_d;
`endif
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] mepc_q;
`else
    reg  [`RV_XLEN-3:0] mepc_q;
`endif
    // sepc
    wire [`RV_XLEN-1:0] sepc;
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] sepc_d;
`else
    reg  [`RV_XLEN-3:0] sepc_d;
`endif
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] sepc_q;
`else
    reg  [`RV_XLEN-3:0] sepc_q;
`endif
    // uepc
    wire [`RV_XLEN-1:0] uepc;
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] uepc_d;
`else
    reg  [`RV_XLEN-3:0] uepc_d;
`endif
    //
`ifdef RV_CONFIG_STDEXT_C
    reg  [`RV_XLEN-2:0] uepc_q;
`else
    reg  [`RV_XLEN-3:0] uepc_q;
`endif
    // mcause
    wire [`RV_XLEN-1:0] mcause;
    //
    reg                 mcause_int_d;
    reg           [3:0] mcause_code_d;
    //
    reg                 mcause_int_q;
    reg           [3:0] mcause_code_q;
    // scause
    wire [`RV_XLEN-1:0] scause;
    //
    reg                 scause_int_d;
    reg           [3:0] scause_code_d;
    //
    reg                 scause_int_q;
    reg           [3:0] scause_code_q;
    // ucause
    wire [`RV_XLEN-1:0] ucause;
    //
    reg                 ucause_int_d;
    reg           [3:0] ucause_code_d;
    //
    reg                 ucause_int_q;
    reg           [3:0] ucause_code_q;
    // mtval
    wire [`RV_XLEN-1:0] mtval;
    //
    reg  [`RV_XLEN-1:0] mtval_d;
    //
    reg  [`RV_XLEN-1:0] mtval_q;
    // stval
    wire [`RV_XLEN-1:0] stval;
    //
    reg  [`RV_XLEN-1:0] stval_d;
    //
    reg  [`RV_XLEN-1:0] stval_q;
    // utval
    wire [`RV_XLEN-1:0] utval;
    //
    reg  [`RV_XLEN-1:0] utval_d;
    //
    reg  [`RV_XLEN-1:0] utval_q;
    // interrupt and exception logic
    wire                m_int_e;
    wire                m_int_t;
    wire                m_int_s;
    wire                s_int_e;
    wire                s_int_t;
    wire                s_int_s;
    wire                u_int_e;
    wire                u_int_t;
    wire                u_int_s;
    //
    reg                 interrupt;
    reg           [3:0] interrupt_cause;
    reg           [1:0] interrupt_mode;
    //
    reg                 exception;
    reg           [3:0] exception_cause;
    reg           [1:0] exception_mode;
    // trap call logic
    wire          [3:0] trap_call_cause_code;
    wire          [1:0] trap_call_mode;
    reg                 trap_call_vectored;
    reg  [`RV_XLEN-3:0] trap_call_base;
    // trap return address mux

    //--------------------------------------------------------------


    //--------------------------------------------------------------
    // read/modify/write functions
    //--------------------------------------------------------------
    function read_modify_write1;
        input field_q;
        input field_modifier;

        begin
            read_modify_write1 = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_write1 = field_q |  field_modifier;
                2'b11 : read_modify_write1 = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction
    //
    function [1:0] read_modify_write2;
        input [1:0] field_q;
        input [1:0] field_modifier;

        begin
            read_modify_write2 = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_write2 = field_q |  field_modifier;
                2'b11 : read_modify_write2 = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction
    //
    function [3:0] read_modify_write4;
        input [3:0] field_q;
        input [3:0] field_modifier;

        begin
            read_modify_write4 = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_write4 = field_q |  field_modifier;
                2'b11 : read_modify_write4 = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction
    //
`ifdef RV_CONFIG_STDEXT_C
    function [`RV_XLEN-2:0] read_modify_writem1;
        input [`RV_XLEN-2:0] field_q;
        input [`RV_XLEN-2:0] field_modifier;

        begin
            read_modify_writem1 = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_writem1 = field_q |  field_modifier;
                2'b11 : read_modify_writem1 = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction
`endif
    //
    function [`RV_XLEN-3:0] read_modify_writem2;
        input [`RV_XLEN-3:0] field_q;
        input [`RV_XLEN-3:0] field_modifier;

        begin
            read_modify_writem2 = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_writem2 = field_q |  field_modifier;
                2'b11 : read_modify_writem2 = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction
    //
    function [`RV_XLEN-1:0] read_modify_write;
        input [`RV_XLEN-1:0] field_q;
        input [`RV_XLEN-1:0] field_modifier;

        begin
            read_modify_write = field_modifier;
            case (wr_mode_i)
                2'b10 : read_modify_write = field_q |  field_modifier;
                2'b11 : read_modify_write = field_q & ~field_modifier;
                default : begin
                end
            endcase
        end
    endfunction


    //--------------------------------------------------------------
    // interface assignments
    //--------------------------------------------------------------
    assign interrupt_o = interrupt;
    assign mode_o      = mode_q;


    //--------------------------------------------------------------
    // access restriction logic
    //--------------------------------------------------------------
    assign access_badcsr_o   = access_badcsr;
    assign access_badwrite_o = (access_addr_i[11:10] == 2'b11 ? access_wr_i : 1'b0);
    assign access_badpriv_o  = (access_addr_i[9:8] > mode_d ? 1'b1 : 1'b0);


    //--------------------------------------------------------------
    // csr read
    //--------------------------------------------------------------
    always @ (*) begin
        access_badcsr    = 1'b0;
        access_rd_data_o = { `RV_XLEN {1'bx} };
        case (access_addr_i)
            // user trap setup
            12'h000 : access_rd_data_o = ustatus;
            12'h004 : access_rd_data_o = uie;
            12'h005 : access_rd_data_o = utvec;
            // user trap handling
            12'h040 : access_rd_data_o = uscratch;
            12'h041 : access_rd_data_o = uepc;
            12'h042 : access_rd_data_o = ucause;
            12'h043 : access_rd_data_o = utval;
            12'h044 : access_rd_data_o = uip;
            // supervisor trap setup
            12'h100 : access_rd_data_o = sstatus;
            12'h102 : access_rd_data_o = sedeleg;
            12'h103 : access_rd_data_o = sideleg;
            12'h104 : access_rd_data_o = sie;
            12'h105 : access_rd_data_o = stvec;
//            12'h106 : access_rd_data_o = ;
            // supervisor trap handling
            12'h140 : access_rd_data_o = sscratch;
            12'h141 : access_rd_data_o = sepc;
            12'h142 : access_rd_data_o = scause;
            12'h143 : access_rd_data_o = stval;
            12'h144 : access_rd_data_o = sip;
            // machine information registers
//            12'hf00 : access_rd_data_o = ;
//            12'hf00 : access_rd_data_o = ;
//            12'hf00 : access_rd_data_o = ;
//            12'hf00 : access_rd_data_o = ;
            // machine trap setup
            12'h300 : access_rd_data_o = mstatus;
//            12'h301 : access_rd_data_o = ;
            12'h302 : access_rd_data_o = medeleg;
            12'h303 : access_rd_data_o = mideleg;
            12'h304 : access_rd_data_o = mie;
            12'h305 : access_rd_data_o = mtvec;
//            12'h306 : access_rd_data_o = ;
            // machine trap handling
            12'h340 : access_rd_data_o = mscratch;
            12'h341 : access_rd_data_o = mepc;
            12'h342 : access_rd_data_o = mcause;
            12'h343 : access_rd_data_o = mtval;
            12'h344 : access_rd_data_o = mip;
            default : access_badcsr  = 1'b1;
        endcase
    end


    //--------------------------------------------------------------
    // mstatus / sstatus / ustatus
    //--------------------------------------------------------------
    assign mstatus = {
`ifdef RV_CONFIG_STDEXT_64
            1'b0,           // SD     - XS/FS signal dirty state
            27'b0,          // *WPRI*
            2'b10,          // SXL    - supervisor XLEN (hardwired to 64-bit)
            2'b10,          // UXL    - user XLEN (hardwired to 64-bit)
            1'b0,           // *WPRI*
`else // 32-bit is the only supported alternative at the moment
            1'b0,           // SD     - XS/FS signal dirty state
`endif
            8'b0,           // *WPRI*
            1'b0,           // TSR    - trap sret
            1'b0,           // TW     - timeout wait
            1'b0,           // TVM    - trap virtual memory
            1'b0,           // MXR    - make executable readable
            1'b0,           // SUM    - permit supervisor user mem access
            1'b0,           // MPRV   - modify memory privilege
            2'b0,           // XS     - user mode extension status
            2'b0,           // FS     - fpu status
            mstatus_mpp_d,  // MPP    - machine previous privilege
            2'b0,           // *WPRI*
            mstatus_spp_d,  // SPP    - supervisor previous privilege
            mstatus_mpie_d, // MPIE   - machine previous interrupt enable
            1'b0,           // *WPRI*
            mstatus_spie_d, // SPIE   - supervisor previous interrupt enable
            mstatus_upie_d, // UPIE   - user previous interrupt enable
            mstatus_mie_d,  // MIE    - machine interrupt enable
            1'b0,           // *WPRI*
            mstatus_sie_d,  // SIE    - supervisor interrupt enable
            mstatus_uie_d   // UIE    - user interrupt enable
        };
    assign sstatus = {
`ifdef RV_CONFIG_STDEXT_64
            1'b0,           // SD     - XS/FS signal dirty state
            27'b0,          // *WPRI*
            2'b00,          // SXL    - supervisor XLEN
            2'b10,          // UXL    - user XLEN (hardwired to 64-bit)
            1'b0,           // *WPRI*
`else // 32-bit is the only supported alternative at the moment
            1'b0,           // SD     - XS/FS signal dirty state
`endif
            8'b0,           // *WPRI*
            1'b0,           // TSR    - trap sret
            1'b0,           // TW     - timeout wait
            1'b0,           // TVM    - trap virtual memory
            1'b0,           // MXR    - make executable readable
            1'b0,           // SUM    - permit supervisor user mem access
            1'b0,           // MPRV   - modify memory privilege
            2'b0,           // XS     - user mode extension status
            2'b0,           // FS     - fpu status
            2'b0,           // MPP    - machine previous privilege
            2'b0,           // *WPRI*
            mstatus_spp_d,  // SPP    - supervisor previous privilege
            1'b0,           // MPIE   - machine previous interrupt enable
            1'b0,           // *WPRI*
            mstatus_spie_d, // SPIE   - supervisor previous interrupt enable
            mstatus_upie_d, // UPIE   - user previous interrupt enable
            1'b0,           // MIE    - machine interrupt enable
            1'b0,           // *WPRI*
            mstatus_sie_d,  // SIE    - supervisor interrupt enable
            mstatus_uie_d   // UIE    - user interrupt enable
        };
    assign ustatus = {
`ifdef RV_CONFIG_STDEXT_64
            1'b0,           // SD     - XS/FS signal dirty state
            27'b0,          // *WPRI*
            2'b00,          // SXL    - supervisor XLEN
            2'b00,          // UXL    - user XLEN
            1'b0,           // *WPRI*
`else // 32-bit is the only supported alternative at the moment
            1'b0,           // SD     - XS/FS signal dirty state
`endif
            8'b0,           // *WPRI*
            1'b0,           // TSR    - trap sret
            1'b0,           // TW     - timeout wait
            1'b0,           // TVM    - trap virtual memory
            1'b0,           // MXR    - make executable readable
            1'b0,           // SUM    - permit supervisor user mem access
            1'b0,           // MPRV   - modify memory privilege
            2'b0,           // XS     - user mode extension status
            2'b0,           // FS     - fpu status
            2'b0,           // MPP    - machine previous privilege
            2'b0,           // *WPRI*
            1'b0,           // SPP    - supervisor previous privilege
            1'b0,           // MPIE   - machine previous interrupt enable
            1'b0,           // *WPRI*
            1'b0,           // SPIE   - supervisor previous interrupt enable
            mstatus_upie_d, // UPIE   - user previous interrupt enable
            1'b0,           // MIE    - machine interrupt enable
            1'b0,           // *WPRI*
            1'b0,           // SIE    - supervisor interrupt enable
            mstatus_uie_d   // UIE    - user interrupt enable
        };
    //
    always @ (*) begin
        mode_d         = mode_q;
        mstatus_mpp_d  = mstatus_mpp_q;
        mstatus_spp_d  = mstatus_spp_q;
        mstatus_mpie_d = mstatus_mpie_q;
        mstatus_spie_d = mstatus_spie_q;
        mstatus_upie_d = mstatus_upie_q;
        mstatus_mie_d  = mstatus_mie_q;
        mstatus_sie_d  = mstatus_sie_q;
        mstatus_uie_d  = mstatus_uie_q;
        if (trap_call_o) begin
            case (trap_call_mode)
                `RV_CSR_MODE_MACHINE : begin
                    mstatus_mpp_d  = mode_q;
                    mstatus_mpie_d = mstatus_mie_q;
                    mstatus_mie_d  = 1'b0;
                end
                `RV_CSR_MODE_SUPERVISOR : begin
                    mstatus_spp_d  = |mode_q; // 0 iff was user mode, 1 otherwise
                    mstatus_spie_d = mstatus_sie_q;
                    mstatus_sie_d  = 1'b0;
                end
                `RV_CSR_MODE_USER : begin
                    mstatus_upie_d = mstatus_uie_q;
                    mstatus_uie_d  = 1'b0;
                end
                default : begin
                end
            endcase
        end else if (trap_rtn_i) begin
            mstatus_mpp_d = `RV_CSR_MODE_USER;
            mstatus_spp_d = 1'b0;
            case (trap_rtn_mode_i)
                `RV_CSR_MODE_MACHINE : begin
                    mode_d         = mstatus_mpp_q;
                    mstatus_mie_d  = mstatus_mpie_q;
                    mstatus_mpie_d = 1'b1;
                end
                `RV_CSR_MODE_SUPERVISOR : begin
                    if (mstatus_spp_q == 1'b0) begin
                        mode_d = `RV_CSR_MODE_USER;
                    end
                    mstatus_sie_d  = mstatus_spie_q;
                    mstatus_spie_d = 1'b1;
                end
                `RV_CSR_MODE_USER : begin
                    mstatus_uie_d  = mstatus_upie_q;
                    mstatus_upie_d = 1'b1;
                end
                default : begin
                end
            endcase
        end else if (wr_i) begin
            case (wr_addr_i)
                12'h300 : begin // mstatus
                    mstatus_mpp_d  = read_modify_write2(mstatus_mpp_q,  wr_data_i[12:11]);
                    mstatus_spp_d  = read_modify_write1(mstatus_spp_q,  wr_data_i[8]);
                    mstatus_mpie_d = read_modify_write1(mstatus_mpie_q, wr_data_i[7]);
                    mstatus_spie_d = read_modify_write1(mstatus_spie_q, wr_data_i[5]);
                    mstatus_upie_d = read_modify_write1(mstatus_upie_q, wr_data_i[4]);
                    mstatus_mie_d  = read_modify_write1(mstatus_mie_q,  wr_data_i[3]);
                    mstatus_sie_d  = read_modify_write1(mstatus_sie_q,  wr_data_i[1]);
                    mstatus_uie_d  = read_modify_write1(mstatus_uie_q,  wr_data_i[0]);
                end
                12'h100 : begin // sstatus
                    mstatus_spp_d  = read_modify_write1(mstatus_spp_q,  wr_data_i[8]);
                    mstatus_spie_d = read_modify_write1(mstatus_spie_q, wr_data_i[5]);
                    mstatus_upie_d = read_modify_write1(mstatus_upie_q, wr_data_i[4]);
                    mstatus_sie_d  = read_modify_write1(mstatus_sie_q,  wr_data_i[1]);
                    mstatus_uie_d  = read_modify_write1(mstatus_uie_q,  wr_data_i[0]);
                end
                12'h000 : begin // ustatus
                    mstatus_upie_d = read_modify_write1(mstatus_upie_q, wr_data_i[4]);
                    mstatus_uie_d  = read_modify_write1(mstatus_uie_q,  wr_data_i[0]);
                end
            endcase
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            mode_q         <= `RV_CSR_MODE_MACHINE;
            mstatus_mpp_q  <= 2'b0;
            mstatus_spp_q  <= 1'b0;
            mstatus_mpie_q <= 1'b0;
            mstatus_spie_q <= 1'b0;
            mstatus_upie_q <= 1'b0;
            mstatus_mie_q  <= 1'b0;
            mstatus_sie_q  <= 1'b0;
            mstatus_uie_q  <= 1'b0;
        end else begin
            mode_q         <= mode_d;
            mstatus_mpp_q  <= mstatus_mpp_d;
            mstatus_spp_q  <= mstatus_spp_d;
            mstatus_mpie_q <= mstatus_mpie_d;
            mstatus_spie_q <= mstatus_spie_d;
            mstatus_upie_q <= mstatus_upie_d;
            mstatus_mie_q  <= mstatus_mie_d;
            mstatus_sie_q  <= mstatus_sie_d;
            mstatus_uie_q  <= mstatus_uie_d;
        end
    end


    //--------------------------------------------------------------
    // medeleg
    //--------------------------------------------------------------
    assign medeleg = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WARL*
`else // 32-bit is the only supported alternative at the moment
`endif
            16'b0,          // *WARL*
            1'b0,           // store/amo page fault
            1'b0,           // *WARL*
            1'b0,           // load page fault
            1'b0,           // instruction page fault
            1'b0,           // environment call from m-mode (cannot be delegated!)
            1'b0,           // *WARL*
            medeleg_ecfs_d, // environment call from s-mode
            medeleg_ecfu_d, // environment call from u-mode
            medeleg_saf_d,  // store/amo access fault
            medeleg_sam_d,  // store/amo address misaligned
            medeleg_laf_d,  // load access fault
            medeleg_lam_d,  // load address misaligned
            1'b0,           // breakpoint
            medeleg_ii_d,   // illegal instruction
            medeleg_iaf_d,  // instruction access fault
            medeleg_iam_d   // instruction address misaligned
        };
    //
    always @ (*) begin
        medeleg_ecfs_d = medeleg_ecfs_q;
        medeleg_ecfu_d = medeleg_ecfu_q;
        medeleg_saf_d  = medeleg_saf_q;
        medeleg_sam_d  = medeleg_sam_q;
        medeleg_laf_d  = medeleg_laf_q;
        medeleg_lam_d  = medeleg_lam_q;
        medeleg_ii_d   = medeleg_ii_q;
        medeleg_iaf_d  = medeleg_iaf_q;
        medeleg_iam_d  = medeleg_iam_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h302) begin
                medeleg_ecfs_d = read_modify_write1(medeleg_ecfs_q, wr_data_i[9]);
                medeleg_ecfu_d = read_modify_write1(medeleg_ecfu_q, wr_data_i[8]);
                medeleg_saf_d  = read_modify_write1(medeleg_saf_q,  wr_data_i[7]);
                medeleg_sam_d  = read_modify_write1(medeleg_sam_q,  wr_data_i[6]);
                medeleg_laf_d  = read_modify_write1(medeleg_laf_q,  wr_data_i[5]);
                medeleg_lam_d  = read_modify_write1(medeleg_lam_q,  wr_data_i[4]);
                medeleg_ii_d   = read_modify_write1(medeleg_ii_q,   wr_data_i[2]);
                medeleg_iaf_d  = read_modify_write1(medeleg_iaf_q,  wr_data_i[1]);
                medeleg_iam_d  = read_modify_write1(medeleg_iam_q,  wr_data_i[0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            medeleg_ecfs_q <= 1'b0;
            medeleg_ecfu_q <= 1'b0;
            medeleg_saf_q  <= 1'b0;
            medeleg_sam_q  <= 1'b0;
            medeleg_laf_q  <= 1'b0;
            medeleg_lam_q  <= 1'b0;
            medeleg_ii_q   <= 1'b0;
            medeleg_iaf_q  <= 1'b0;
            medeleg_iam_q  <= 1'b0;
        end else begin
            medeleg_ecfs_q <= medeleg_ecfs_d;
            medeleg_ecfu_q <= medeleg_ecfu_d;
            medeleg_saf_q  <= medeleg_saf_d;
            medeleg_sam_q  <= medeleg_sam_d;
            medeleg_laf_q  <= medeleg_laf_d;
            medeleg_lam_q  <= medeleg_lam_d;
            medeleg_ii_q   <= medeleg_ii_d;
            medeleg_iaf_q  <= medeleg_iaf_d;
            medeleg_iam_q  <= medeleg_iam_d;
        end
    end


    //--------------------------------------------------------------
    // sedeleg
    //--------------------------------------------------------------
    assign sedeleg = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WARL*
`else // 32-bit is the only supported alternative at the moment
`endif
            16'b0,          // *WARL*
            1'b0,           // store/amo page fault
            1'b0,           // *WARL*
            1'b0,           // load page fault
            1'b0,           // instruction page fault
            1'b0,           // environment call from m-mode (cannot be delegated!)
            1'b0,           // *WARL*
            1'b0,           // environment call from s-mode (cannot be delegated!)
            sedeleg_ecfu_d, // environment call from u-mode
            sedeleg_saf_d,  // store/amo access fault
            sedeleg_sam_d,  // store/amo address misaligned
            sedeleg_laf_d,  // load access fault
            sedeleg_lam_d,  // load address misaligned
            1'b0,           // breakpoint
            sedeleg_ii_d,   // illegal instruction
            sedeleg_iaf_d,  // instruction access fault
            sedeleg_iam_d   // instruction address misaligned
        };
    //
    always @ (*) begin
        sedeleg_ecfu_d = sedeleg_ecfu_q;
        sedeleg_saf_d  = sedeleg_saf_q;
        sedeleg_sam_d  = sedeleg_sam_q;
        sedeleg_laf_d  = sedeleg_laf_q;
        sedeleg_lam_d  = sedeleg_lam_q;
        sedeleg_ii_d   = sedeleg_ii_q;
        sedeleg_iaf_d  = sedeleg_iaf_q;
        sedeleg_iam_d  = sedeleg_iam_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h102) begin
                sedeleg_ecfu_d = read_modify_write1(sedeleg_ecfu_q, wr_data_i[8]);
                sedeleg_saf_d  = read_modify_write1(sedeleg_saf_q,  wr_data_i[7]);
                sedeleg_sam_d  = read_modify_write1(sedeleg_sam_q,  wr_data_i[6]);
                sedeleg_laf_d  = read_modify_write1(sedeleg_laf_q,  wr_data_i[5]);
                sedeleg_lam_d  = read_modify_write1(sedeleg_lam_q,  wr_data_i[4]);
                sedeleg_ii_d   = read_modify_write1(sedeleg_ii_q,   wr_data_i[2]);
                sedeleg_iaf_d  = read_modify_write1(sedeleg_iaf_q,  wr_data_i[1]);
                sedeleg_iam_d  = read_modify_write1(sedeleg_iam_q,  wr_data_i[0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            sedeleg_ecfu_q <= 1'b0;
            sedeleg_saf_q  <= 1'b0;
            sedeleg_sam_q  <= 1'b0;
            sedeleg_laf_q  <= 1'b0;
            sedeleg_lam_q  <= 1'b0;
            sedeleg_ii_q   <= 1'b0;
            sedeleg_iaf_q  <= 1'b0;
            sedeleg_iam_q  <= 1'b0;
        end else begin
            sedeleg_ecfu_q <= sedeleg_ecfu_d;
            sedeleg_saf_q  <= sedeleg_saf_d;
            sedeleg_sam_q  <= sedeleg_sam_d;
            sedeleg_laf_q  <= sedeleg_laf_d;
            sedeleg_lam_q  <= sedeleg_lam_d;
            sedeleg_ii_q   <= sedeleg_ii_d;
            sedeleg_iaf_q  <= sedeleg_iaf_d;
            sedeleg_iam_q  <= sedeleg_iam_d;
        end
    end


    //--------------------------------------------------------------
    // mideleg
    //--------------------------------------------------------------
    assign mideleg = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WARL*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WARL*
            1'b0,           // machine external interrupt
            1'b0,           // *WARL*
            mideleg_sei_d,  // supervisor external interrupt
            mideleg_uei_d,  // user external interrupt
            1'b0,           // machine timer interrupt
            1'b0,           // *WARL*
            mideleg_sti_d,  // supervisor timer interrupt
            mideleg_uti_d,  // user timer interrupt
            1'b0,           // machine software interrupt
            1'b0,           // *WARL*
            mideleg_ssi_d,  // supervisor software interrupt
            mideleg_usi_d   // user software interrupt
        };
    //
    always @ (*) begin
        mideleg_usi_d = mideleg_usi_q;
        mideleg_ssi_d = mideleg_ssi_q;
        mideleg_uti_d = mideleg_uti_q;
        mideleg_sti_d = mideleg_sti_q;
        mideleg_uei_d = mideleg_uei_q;
        mideleg_sei_d = mideleg_sei_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h303) begin
                mideleg_usi_d = read_modify_write1(mideleg_usi_q, wr_data_i[0]);
                mideleg_ssi_d = read_modify_write1(mideleg_ssi_q, wr_data_i[1]);
                mideleg_uti_d = read_modify_write1(mideleg_uti_q, wr_data_i[4]);
                mideleg_sti_d = read_modify_write1(mideleg_sti_q, wr_data_i[5]);
                mideleg_uei_d = read_modify_write1(mideleg_uei_q, wr_data_i[8]);
                mideleg_sei_d = read_modify_write1(mideleg_sei_q, wr_data_i[9]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            mideleg_usi_q <= 1'b0;
            mideleg_ssi_q <= 1'b0;
            mideleg_uti_q <= 1'b0;
            mideleg_sti_q <= 1'b0;
            mideleg_uei_q <= 1'b0;
            mideleg_sei_q <= 1'b0;
        end else begin
            mideleg_usi_q <= mideleg_usi_d;
            mideleg_ssi_q <= mideleg_ssi_d;
            mideleg_uti_q <= mideleg_uti_d;
            mideleg_sti_q <= mideleg_sti_d;
            mideleg_uei_q <= mideleg_uei_d;
            mideleg_sei_q <= mideleg_sei_d;
        end
    end


    //--------------------------------------------------------------
    // sideleg
    //--------------------------------------------------------------
    assign sideleg = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WARL*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WARL*
            1'b0,           // machine external interrupt
            1'b0,           // *WARL*
            1'b0,           // supervisor external interrupt
            sideleg_uei_d,  // user external interrupt
            1'b0,           // machine timer interrupt
            1'b0,           // *WARL*
            1'b0,           // supervisor timer interrupt
            sideleg_uti_d,  // user timer interrupt
            1'b0,           // machine software interrupt
            1'b0,           // *WARL*
            1'b0,           // supervisor software interrupt
            sideleg_usi_d   // user software interrupt
        };
    //
    always @ (*) begin
        sideleg_usi_d = sideleg_usi_q;
        sideleg_uti_d = sideleg_uti_q;
        sideleg_uei_d = sideleg_uei_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h103) begin
                sideleg_usi_d = read_modify_write1(sideleg_usi_q, wr_data_i[0]);
                sideleg_uti_d = read_modify_write1(sideleg_uti_q, wr_data_i[4]);
                sideleg_uei_d = read_modify_write1(sideleg_uei_q, wr_data_i[8]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            sideleg_usi_q <= 1'b0;
            sideleg_uti_q <= 1'b0;
            sideleg_uei_q <= 1'b0;
        end else begin
            sideleg_usi_q <= sideleg_usi_d;
            sideleg_uti_q <= sideleg_uti_d;
            sideleg_uei_q <= sideleg_uei_d;
        end
    end


    //--------------------------------------------------------------
    // mtvec
    //--------------------------------------------------------------
    /*
     * NOTE: In vectored mode icause replaces the bottom 4 bits of base field.
     *       See "trap call logic"
     */
    assign mtvec = {
            mtvec_d,        // 32-bit aligned trap vector base address
            mtvec_mode_d    // trap vector mode (0 => direct, 1 => vectored, others => reserved)
        };
    //
    always @ (*) begin
        mtvec_d      = mtvec_q;
        mtvec_mode_d = mtvec_mode_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h305) begin
                mtvec_d      = read_modify_writem2(mtvec_q,      wr_data_i[`RV_XLEN-1:2]);
                mtvec_mode_d = read_modify_write2(mtvec_mode_q, wr_data_i[1:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            mtvec_q      <= `RV_RESET_VECTOR; // TODO
            mtvec_mode_q <= `RV_CSR_TVEC_MODE_DIRECT;
        end else begin
            mtvec_q      <= mtvec_d;
            mtvec_mode_q <= mtvec_mode_d;
        end
    end


    //--------------------------------------------------------------
    // stvec
    //--------------------------------------------------------------
    /*
     * NOTE: In vectored mode icause replaces the bottom 4 bits of base field.
     *       See "trap call logic"
     */
    assign stvec = {
            stvec_d,        // 32-bit aligned trap vector base address
            stvec_mode_d    // trap vector mode (0 => direct, 1 => vectored, others => reserved)
        };
    //
    always @ (*) begin
        stvec_d      = stvec_q;
        stvec_mode_d = stvec_mode_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h105) begin
                stvec_d      = read_modify_writem2(stvec_q,      wr_data_i[`RV_XLEN-1:2]);
                stvec_mode_d = read_modify_write2(stvec_mode_q, wr_data_i[1:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        stvec_q      <= stvec_d;
        stvec_mode_q <= stvec_mode_d;
    end


    //--------------------------------------------------------------
    // utvec
    //--------------------------------------------------------------
    /*
     * NOTE: In vectored mode icause replaces the bottom 4 bits of base field.
     *       See "trap call logic"
     */
    assign utvec = {
            utvec_d,        // 32-bit aligned trap vector base address
            utvec_mode_d    // trap vector mode (0 => direct, 1 => vectored, others => reserved)
        };
    //
    always @ (*) begin
        utvec_d      = utvec_q;
        utvec_mode_d = utvec_mode_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h005) begin
                utvec_d      = read_modify_writem2(utvec_q,      wr_data_i[`RV_XLEN-1:2]);
                utvec_mode_d = read_modify_write2(utvec_mode_q, wr_data_i[1:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        utvec_q      <= utvec_d;
        utvec_mode_q <= utvec_mode_d;
    end


    //--------------------------------------------------------------
    // mie / sie / uie
    //--------------------------------------------------------------
    assign mie = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            mie_meie_d,     // machine external interrupt enable
            1'b0,           // *WPRI*
            mie_seie_d,     // supervisor external interrupt enable
            mie_ueie_d,     // user external interrupt enable
            mie_mtie_d,     // machine timer interrupt enable
            1'b0,           // *WPRI*
            mie_stie_d,     // supervisor timer interrupt enable
            mie_utie_d,     // user timer interrupt enable
            mie_msie_d,     // machine software interrupt enable
            1'b0,           // *WPRI*
            mie_ssie_d,     // supervisor software interrupt enable
            mie_usie_d      // user software interrupt enable
        };
    //
    assign sie = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            1'b0,           // machine external interrupt enable
            1'b0,           // *WPRI*
            mie_seie_d,     // supervisor external interrupt enable
            mie_ueie_d,     // user external interrupt enable
            1'b0,           // machine timer interrupt enable
            1'b0,           // *WPRI*
            mie_stie_d,     // supervisor timer interrupt enable
            mie_utie_d,     // user timer interrupt enable
            1'b0,           // machine software interrupt enable
            1'b0,           // *WPRI*
            mie_ssie_d,     // supervisor software interrupt enable
            mie_usie_d      // user software interrupt enable
        };
    //
    assign uie = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            1'b0,           // machine external interrupt enable
            1'b0,           // *WPRI*
            1'b0,           // supervisor external interrupt enable
            mie_ueie_d,     // user external interrupt enable
            1'b0,           // machine timer interrupt enable
            1'b0,           // *WPRI*
            1'b0,           // supervisor timer interrupt enable
            mie_utie_d,     // user timer interrupt enable
            1'b0,           // machine software interrupt enable
            1'b0,           // *WPRI*
            1'b0,           // supervisor software interrupt enable
            mie_usie_d      // user software interrupt enable
        };
    //
    always @ (*) begin
        mie_meie_d = mie_meie_q;
        mie_seie_d = mie_seie_q;
        mie_ueie_d = mie_ueie_q;
        mie_mtie_d = mie_mtie_q;
        mie_stie_d = mie_stie_q;
        mie_utie_d = mie_utie_q;
        mie_msie_d = mie_msie_q;
        mie_ssie_d = mie_ssie_q;
        mie_usie_d = mie_usie_q;
        if (wr_i) begin
            case (wr_addr_i)
                12'h304 : begin // mie
                    mie_meie_d = read_modify_write1(mie_meie_q, wr_data_i[11]);
                    mie_seie_d = read_modify_write1(mie_seie_q, wr_data_i[9]);
                    mie_ueie_d = read_modify_write1(mie_ueie_q, wr_data_i[8]);
                    mie_mtie_d = read_modify_write1(mie_mtie_q, wr_data_i[7]);
                    mie_stie_d = read_modify_write1(mie_stie_q, wr_data_i[5]);
                    mie_utie_d = read_modify_write1(mie_utie_q, wr_data_i[4]);
                    mie_msie_d = read_modify_write1(mie_msie_q, wr_data_i[3]);
                    mie_ssie_d = read_modify_write1(mie_ssie_q, wr_data_i[1]);
                    mie_usie_d = read_modify_write1(mie_usie_q, wr_data_i[0]);
                end
                12'h104 : begin // sie
                    mie_seie_d = read_modify_write1(mie_seie_q, wr_data_i[9]);
                    mie_ueie_d = read_modify_write1(mie_ueie_q, wr_data_i[8]);
                    mie_stie_d = read_modify_write1(mie_stie_q, wr_data_i[5]);
                    mie_utie_d = read_modify_write1(mie_utie_q, wr_data_i[4]);
                    mie_ssie_d = read_modify_write1(mie_ssie_q, wr_data_i[1]);
                    mie_usie_d = read_modify_write1(mie_usie_q, wr_data_i[0]);
                end
                12'h004 : begin // uie
                    mie_ueie_d = read_modify_write1(mie_ueie_q, wr_data_i[8]);
                    mie_utie_d = read_modify_write1(mie_utie_q, wr_data_i[4]);
                    mie_usie_d = read_modify_write1(mie_usie_q, wr_data_i[0]);
                end
            endcase
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            mie_meie_q <= 1'b0;
            mie_seie_q <= 1'b0;
            mie_ueie_q <= 1'b0;
            mie_mtie_q <= 1'b0;
            mie_stie_q <= 1'b0;
            mie_utie_q <= 1'b0;
            mie_msie_q <= 1'b0;
            mie_ssie_q <= 1'b0;
            mie_usie_q <= 1'b0;
        end else begin
            mie_meie_q <= mie_meie_d;
            mie_seie_q <= mie_seie_d;
            mie_ueie_q <= mie_ueie_d;
            mie_mtie_q <= mie_mtie_d;
            mie_stie_q <= mie_stie_d;
            mie_utie_q <= mie_utie_d;
            mie_msie_q <= mie_msie_d;
            mie_ssie_q <= mie_ssie_d;
            mie_usie_q <= mie_usie_d;
        end
    end


    //--------------------------------------------------------------
    // mip / sip / uip
    //--------------------------------------------------------------
    assign mip = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            mip_meip,       // machine external interrupt pending
            1'b0,           // *WPRI*
            mip_seip,       // supervisor external interrupt pending
            mip_ueip,       // user external interrupt pending
            mip_mtip,       // machine timer interrupt pending
            1'b0,           // *WPRI*
            mip_stip,       // supervisor timer interrupt pending
            mip_utip,       // user timer interrupt pending
            mip_msip,       // machine software interrupt pending
            1'b0,           // *WPRI*
            mip_ssip,       // supervisor software interrupt pending
            mip_usip        // user software interrupt pending
        };
    //
    assign sip = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            1'b0,           // machine external interrupt pending
            1'b0,           // *WPRI*
            mip_seip,       // supervisor external interrupt pending
            mip_ueip,       // user external interrupt pending
            1'b0,           // machine timer interrupt pending
            1'b0,           // *WPRI*
            mip_stip,       // supervisor timer interrupt pending
            mip_utip,       // user timer interrupt pending
            1'b0,           // machine software interrupt pending
            1'b0,           // *WPRI*
            mip_ssip,       // supervisor software interrupt pending
            mip_usip        // user software interrupt pending
        };
    //
    assign uip = {
`ifdef RV_CONFIG_STDEXT_64
            32'b0,          // *WPRI*
`else // 32-bit is the only supported alternative at the moment
`endif
            20'b0,          // *WPRI*
            1'b0,           // machine external interrupt pending
            1'b0,           // *WPRI*
            1'b0,           // supervisor external interrupt pending
            mip_ueip,       // user external interrupt pending
            1'b0,           // machine timer interrupt pending
            1'b0,           // *WPRI*
            1'b0,           // supervisor timer interrupt pending
            mip_utip,       // user timer interrupt pending
            1'b0,           // machine software interrupt pending
            1'b0,           // *WPRI*
            1'b0,           // supervisor software interrupt pending
            mip_usip        // user software interrupt pending
        };
    //
    assign mip_meip = (             irqm_extern_i);
    assign mip_mtip = (             irqm_timer_i );
    assign mip_msip = (             irqm_softw_i );
    assign mip_seip = (mip_seip_d | irqs_extern_i);
    assign mip_stip = (mip_stip_d                );
    assign mip_ssip = (mip_ssip_d                );
    assign mip_ueip = (mip_ueip_d                );
    assign mip_utip = (mip_utip_d                );
    assign mip_usip = (mip_usip_d                );
    //
    always @ (*) begin
        mip_seip_d = mip_seip_q;
        mip_ueip_d = mip_ueip_q;
        mip_stip_d = mip_stip_q;
        mip_utip_d = mip_utip_q;
        mip_ssip_d = mip_ssip_q;
        mip_usip_d = mip_usip_q;
        if (wr_i) begin
            case (wr_addr_i)
                12'h344 : begin // mip
                    mip_seip_d = read_modify_write1(mip_seip_q, wr_data_i[9]);
                    mip_ueip_d = read_modify_write1(mip_ueip_q, wr_data_i[8]);
                    mip_stip_d = read_modify_write1(mip_stip_q, wr_data_i[5]);
                    mip_utip_d = read_modify_write1(mip_utip_q, wr_data_i[4]);
                    mip_ssip_d = read_modify_write1(mip_ssip_q, wr_data_i[1]);
                    mip_usip_d = read_modify_write1(mip_usip_q, wr_data_i[0]);
                end
                12'h144 : begin // sip
                    mip_ueip_d = read_modify_write1(mip_ueip_q, wr_data_i[8]);
                    mip_utip_d = read_modify_write1(mip_utip_q, wr_data_i[4]);
                    mip_ssip_d = read_modify_write1(mip_ssip_q, wr_data_i[1]);
                    mip_usip_d = read_modify_write1(mip_usip_q, wr_data_i[0]);
                end
                12'h044 : begin // uip
                    mip_usip_d = read_modify_write1(mip_usip_q, wr_data_i[0]);
                end
            endcase
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
            mip_seip_q <= 1'b0;
            mip_ueip_q <= 1'b0;
            mip_stip_q <= 1'b0;
            mip_utip_q <= 1'b0;
            mip_ssip_q <= 1'b0;
            mip_usip_q <= 1'b0;
        end else begin
            mip_seip_q <= mip_seip_d;
            mip_ueip_q <= mip_ueip_d;
            mip_stip_q <= mip_stip_d;
            mip_utip_q <= mip_utip_d;
            mip_ssip_q <= mip_ssip_d;
            mip_usip_q <= mip_usip_d;
        end
    end


    //--------------------------------------------------------------
    // mscratch
    //--------------------------------------------------------------
    assign mscratch = mscratch_d; // scratch register
    //
    always @ (*) begin
        mscratch_d = mscratch_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h340) begin
                mscratch_d = read_modify_write(mscratch_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        mscratch_q <= mscratch_d;
    end


    //--------------------------------------------------------------
    // sscratch
    //--------------------------------------------------------------
    assign sscratch = sscratch_d; // scratch register
    //
    always @ (*) begin
        sscratch_d = sscratch_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h140) begin
                sscratch_d = read_modify_write(sscratch_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        sscratch_q <= sscratch_d;
    end


    //--------------------------------------------------------------
    // uscratch
    //--------------------------------------------------------------
    assign uscratch = uscratch_d; // scratch register
    //
    always @ (*) begin
        uscratch_d = uscratch_q;
        if (wr_i) begin
            if (wr_addr_i == 12'h040) begin
                uscratch_d = read_modify_write(uscratch_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        uscratch_q <= uscratch_d;
    end


    //--------------------------------------------------------------
    // mepc
    //--------------------------------------------------------------
    assign mepc = {
        mepc_d, // exception program counter
`ifdef RV_CONFIG_STDEXT_C
`else
        1'b0,
`endif
        1'b0
        };
    //
    always @ (*) begin
        mepc_d = mepc_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_MACHINE) begin
`ifdef RV_CONFIG_STDEXT_C
            mepc_d = excp_pc_i[`RV_XLEN-1:1];
`else
            mepc_d = excp_pc_i[`RV_XLEN-1:2];
`endif
        end else if (wr_i) begin
            if (wr_addr_i == 12'h341) begin
`ifdef RV_CONFIG_STDEXT_C
                mepc_d = read_modify_writem1(mepc_q, wr_data_i[`RV_XLEN-1:1]);
`else
                mepc_d = read_modify_writem2(mepc_q, wr_data_i[`RV_XLEN-1:2]);
`endif
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        mepc_q <= mepc_d;
    end


    //--------------------------------------------------------------
    // sepc
    //--------------------------------------------------------------
    assign sepc = {
        sepc_d, // exception program counter
`ifdef RV_CONFIG_STDEXT_C
`else
        1'b0,
`endif
        1'b0
        };
    //
    always @ (*) begin
        sepc_d = sepc_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_SUPERVISOR) begin
`ifdef RV_CONFIG_STDEXT_C
            sepc_d = excp_pc_i[`RV_XLEN-1:1];
`else
            sepc_d = excp_pc_i[`RV_XLEN-1:2];
`endif
        end else if (wr_i) begin
            if (wr_addr_i == 12'h141) begin
`ifdef RV_CONFIG_STDEXT_C
                sepc_d = read_modify_writem1(sepc_q, wr_data_i[`RV_XLEN-1:1]);
`else
                sepc_d = read_modify_writem2(sepc_q, wr_data_i[`RV_XLEN-1:2]);
`endif
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        sepc_q <= sepc_d;
    end


    //--------------------------------------------------------------
    // uepc
    //--------------------------------------------------------------
    assign uepc = {
        uepc_d, // exception program counter
`ifdef RV_CONFIG_STDEXT_C
`else
        1'b0,
`endif
        1'b0
        };
    //
    always @ (*) begin
        uepc_d = uepc_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_USER) begin
`ifdef RV_CONFIG_STDEXT_C
            uepc_d = excp_pc_i[`RV_XLEN-1:1];
`else
            uepc_d = excp_pc_i[`RV_XLEN-1:2];
`endif
        end else if (wr_i) begin
            if (wr_addr_i == 12'h041) begin
`ifdef RV_CONFIG_STDEXT_C
                uepc_d = read_modify_writem1(uepc_q, wr_data_i[`RV_XLEN-1:1]);
`else
                uepc_d = read_modify_writem2(uepc_q, wr_data_i[`RV_XLEN-1:2]);
`endif
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        uepc_q <= uepc_d;
    end


    //--------------------------------------------------------------
    // mcause
    //--------------------------------------------------------------
    assign mcause = {
        mcause_int_d,          // interrupt
        { `RV_XLEN-5 {1'b0} }, // *WLRL*
        mcause_code_d          // cause code
        };
    //
    always @ (*) begin
        mcause_int_d  = mcause_int_q;
        mcause_code_d = mcause_code_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_MACHINE) begin
            mcause_int_d  = interrupt;
            mcause_code_d = trap_call_cause_code;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h342) begin
                mcause_int_d  = read_modify_write1(mcause_int_q,  wr_data_i[`RV_XLEN-1]);
                mcause_code_d = read_modify_write4(mcause_code_q, wr_data_i[3:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        mcause_int_q  <= mcause_int_d;
        mcause_code_q <= mcause_code_d;
    end


    //--------------------------------------------------------------
    // scause
    //--------------------------------------------------------------
    assign scause = {
        scause_int_d,          // interrupt
        { `RV_XLEN-5 {1'b0} }, // *WLRL*
        scause_code_d          // cause code
        };
    //
    always @ (*) begin
        scause_int_d  = scause_int_q;
        scause_code_d = scause_code_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_SUPERVISOR) begin
            scause_int_d  = interrupt;
            scause_code_d = trap_call_cause_code;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h142) begin
                scause_int_d  = read_modify_write1(scause_int_q,  wr_data_i[`RV_XLEN-1]);
                scause_code_d = read_modify_write4(scause_code_q, wr_data_i[3:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        scause_int_q  <= scause_int_d;
        scause_code_q <= scause_code_d;
    end


    //--------------------------------------------------------------
    // ucause
    //--------------------------------------------------------------
    assign ucause = {
        ucause_int_d,          // interrupt
        { `RV_XLEN-5 {1'b0} }, // *WLRL*
        ucause_code_d          // cause code
        };
    //
    always @ (*) begin
        ucause_int_d  = ucause_int_q;
        ucause_code_d = ucause_code_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_USER) begin
            ucause_int_d  = interrupt;
            ucause_code_d = trap_call_cause_code;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h042) begin
                ucause_int_d  = read_modify_write1(ucause_int_q,  wr_data_i[`RV_XLEN-1]);
                ucause_code_d = read_modify_write4(ucause_code_q, wr_data_i[3:0]);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        ucause_int_q  <= ucause_int_d;
        ucause_code_q <= ucause_code_d;
    end


    //--------------------------------------------------------------
    // mtval
    //--------------------------------------------------------------
    assign mtval = mtval_d; // trap value
    //
    always @ (*) begin
        mtval_d = mtval_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_MACHINE) begin
            mtval_d = trap_call_value_o;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h343) begin
                mtval_d = read_modify_write(mtval_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        mtval_q <= mtval_d;
    end


    //--------------------------------------------------------------
    // stval
    //--------------------------------------------------------------
    assign stval = stval_d; // trap value
    //
    always @ (*) begin
        stval_d = stval_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_SUPERVISOR) begin
            stval_d = trap_call_value_o;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h343) begin
                stval_d = read_modify_write(stval_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        stval_q <= stval_d;
    end


    //--------------------------------------------------------------
    // utval
    //--------------------------------------------------------------
    assign utval = utval_d; // trap value
    //
    always @ (*) begin
        utval_d = utval_q;
        if (trap_call_o && trap_call_mode == `RV_CSR_MODE_USER) begin
            utval_d = trap_call_value_o;
        end else if (wr_i) begin
            if (wr_addr_i == 12'h343) begin
                utval_d = read_modify_write(utval_q, wr_data_i);
            end
        end
    end
    //
    always @ `RV_SYNC_LOGIC_CLOCK(clk_i) begin
        utval_q <= utval_d;
    end


    //--------------------------------------------------------------
    // interrupt and exception logic
    //--------------------------------------------------------------
    /*
     * Traps should be taken with the following priority:
     *   1) external interrupts
     *   2) software interrupts
     *   3) timer interrupts
     *   4) synchronous traps
     */
    assign m_int_e = mip_meip & mie_meie_q;
    assign m_int_t = mip_mtip & mie_mtie_q;
    assign m_int_s = mip_msip & mie_msie_q;
    assign s_int_e = mip_seip & mie_seie_q;
    assign s_int_t = mip_stip & mie_stie_q;
    assign s_int_s = mip_ssip & mie_ssie_q;
    assign u_int_e = mip_ueip & mie_ueie_q;
    assign u_int_t = mip_utip & mie_utie_q;
    assign u_int_s = mip_usip & mie_usie_q;
    // interrupt logic
    always @ (*) begin
        interrupt       = 1'b0;
        interrupt_cause = 4'bx;
        interrupt_mode  = `RV_CSR_MODE_MACHINE;
        case (mode_q)
            `RV_CSR_MODE_MACHINE : begin
                interrupt = (mstatus_mie_q & (m_int_e |
                                              m_int_t |
                                              m_int_s ));
                // interrupt cause encoder
                if (m_int_e) begin          // machine external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_ME;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (m_int_s) begin // machine software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MS;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else begin              // machine timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MT;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end
            end
            `RV_CSR_MODE_SUPERVISOR : begin
                interrupt = (                (m_int_e | m_int_t | m_int_s)) |
                            (mstatus_sie_q & (s_int_e | s_int_t | s_int_s)) ;
                // interrupt cause and mode encoder
                if (m_int_e) begin          // machine external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_ME;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (m_int_s) begin // machine software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MS;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (m_int_t) begin // machine timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MT;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (s_int_e) begin // supervisor external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_SE;
                    interrupt_mode  = (mideleg_sei_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (s_int_s) begin // supervisor software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_SS;
                    interrupt_mode  = (mideleg_ssi_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else begin              // supervisor timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_ST;
                    interrupt_mode  = (mideleg_sti_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end
            end
            `RV_CSR_MODE_USER : begin
                interrupt = (                (m_int_e | m_int_t | m_int_s)) |
                            (                (s_int_e | s_int_t | s_int_s)) |
                            (mstatus_uie_q & (u_int_e | u_int_t | u_int_s)) ;
                // interrupt cause and mode encoder
                if (m_int_e) begin          // machine external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_ME;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (m_int_s) begin // machine software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MS;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (m_int_t) begin // machine timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_MT;
                    interrupt_mode  = `RV_CSR_MODE_MACHINE;
                end else if (s_int_e) begin // supervisor external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_SE;
                    interrupt_mode  = (mideleg_sei_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (s_int_s) begin // supervisor software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_SS;
                    interrupt_mode  = (mideleg_ssi_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (s_int_t) begin // supervisor timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_ST;
                    interrupt_mode  = (mideleg_sti_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (u_int_e) begin // user external interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_UE;
                    interrupt_mode  = (mideleg_uei_q ? (sideleg_uei_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (u_int_s) begin // user software interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_US;
                    interrupt_mode  = (mideleg_usi_q ? (sideleg_usi_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else begin              // user timer interrupt
                    interrupt_cause = `RV_CSR_INTR_CAUSE_UT;
                    interrupt_mode  = (mideleg_uti_q ? (sideleg_uti_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end
            end
            default : begin
            end
        endcase
    end
    // exception logic
    always @ (*) begin
        exception       = 1'b0;
        exception_cause = 4'bx;
        exception_mode  = `RV_CSR_MODE_MACHINE;
        case (mode_q)
            `RV_CSR_MODE_MACHINE : begin
                // exception cause and mode encoder
                if (excp_ferr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_uerr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_ilgl_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_maif_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_mala_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_masa_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end else if (excp_ecall_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_MMODE;
                    exception_mode  = `RV_CSR_MODE_MACHINE;
                end
            end
            `RV_CSR_MODE_SUPERVISOR : begin
                // exception cause and mode encoder
                if (excp_ferr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT;
                    exception_mode  = (medeleg_iaf_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_uerr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = (medeleg_ii_q ? `RV_CSR_MODE_SUPERVISOR
                                                    : `RV_CSR_MODE_MACHINE)
                                                    ;
                end else if (excp_ilgl_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = (medeleg_ii_q ? `RV_CSR_MODE_SUPERVISOR
                                                    : `RV_CSR_MODE_MACHINE)
                                                    ;
                end else if (excp_maif_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_iam_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_mala_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_lam_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_masa_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_sam_q ? `RV_CSR_MODE_SUPERVISOR
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_ecall_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_SMODE;
                    exception_mode  = (medeleg_ecfs_q ? `RV_CSR_MODE_SUPERVISOR
                                                      : `RV_CSR_MODE_MACHINE)
                                                      ;
                end
            end
            `RV_CSR_MODE_USER : begin
                // exception cause and mode encoder
                if (excp_ferr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT;
                    exception_mode  = (medeleg_iaf_q ? (sedeleg_iaf_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_uerr_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = (medeleg_ii_q ? (sedeleg_ii_q ? `RV_CSR_MODE_USER
                                                                    : `RV_CSR_MODE_SUPERVISOR)
                                                    : `RV_CSR_MODE_MACHINE)
                                                    ;
                end else if (excp_ilgl_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ILLEGAL_INS;
                    exception_mode  = (medeleg_ii_q ? (sedeleg_ii_q ? `RV_CSR_MODE_USER
                                                                    : `RV_CSR_MODE_SUPERVISOR)
                                                    : `RV_CSR_MODE_MACHINE)
                                                    ;
                end else if (excp_maif_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_iam_q ? (sedeleg_iam_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_mala_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_lam_q ? (sedeleg_lam_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_masa_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED;
                    exception_mode  = (medeleg_sam_q ? (sedeleg_sam_q ? `RV_CSR_MODE_USER
                                                                      : `RV_CSR_MODE_SUPERVISOR)
                                                     : `RV_CSR_MODE_MACHINE)
                                                     ;
                end else if (excp_ecall_i) begin
                    exception       = 1'b1;
                    exception_cause = `RV_CSR_EXCP_CAUSE_ECALL_FROM_UMODE;
                    exception_mode  = (medeleg_ecfu_q ? (sedeleg_ecfu_q ? `RV_CSR_MODE_USER
                                                                        : `RV_CSR_MODE_SUPERVISOR)
                                                      : `RV_CSR_MODE_MACHINE)
                                                      ;
                end
            end
            default : begin
            end
        endcase
    end


    //--------------------------------------------------------------
    // trap call logic
    //--------------------------------------------------------------
    /*
     * Traps should be taken with the following priority:
     *   1) external interrupts
     *   2) software interrupts
     *   3) timer interrupts
     *   4) synchronous traps
     */
    assign trap_call_o       = ex_valid_i & (interrupt | exception);
    assign trap_call_cause_o = { interrupt, { `RV_XLEN-5 {1'b0} }, trap_call_cause_code };
    assign trap_call_addr_o  = (trap_call_vectored ? { trap_call_base[`RV_XLEN-1:4], interrupt_cause, 2'b0 }
                                                   : { trap_call_base,                                2'b0 })
                                                   ;
    assign trap_call_cause_code = (interrupt ? interrupt_cause
                                             : exception_cause)
                                             ;
    assign trap_call_mode       = (interrupt ? interrupt_mode
                                             : exception_mode)
                                             ;
    // trap value encoder
    always @ (*) begin
        if (interrupt) begin // TODO hardware breakpoint | page fault
            trap_call_value_o = { `RV_XLEN {1'b0} };
        end else if (excp_maif_i | excp_mala_i | excp_masa_i) begin
            trap_call_value_o = excp_pc_i;
        end else if (excp_uerr_i | excp_ilgl_i) begin
            trap_call_value_o = excp_ins_i;
        end else begin
            trap_call_value_o = { `RV_XLEN {1'b0} };
        end
    end
    // trap call base address and offset mode decoder
    always @ (*) begin
        trap_call_vectored  = 1'b0;
        trap_call_base = { `RV_XLEN-2 {1'bx} };
        case (trap_call_mode)
            `RV_CSR_MODE_MACHINE : begin
                trap_call_base = mtvec_q;
                if (mtvec_mode_q == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_call_vectored = interrupt;
                end
            end
            `RV_CSR_MODE_SUPERVISOR : begin
                trap_call_base = stvec_q;
                if (stvec_mode_q == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_call_vectored = interrupt;
                end
            end
            `RV_CSR_MODE_USER : begin
                trap_call_base = utvec_q;
                if (utvec_mode_q == `RV_CSR_TVEC_MODE_VECTORED) begin
                    trap_call_vectored = interrupt;
                end
            end
            default : begin
            end
        endcase
    end


    //--------------------------------------------------------------
    // trap return address mux
    //--------------------------------------------------------------
    always @ (*) begin
        trap_rtn_addr_o = { `RV_XLEN {1'bx} };
        case (trap_rtn_mode_i)
`ifdef RV_CONFIG_STDEXT_C
            `RV_CSR_MODE_MACHINE    : trap_rtn_addr_o = { mepc_q, 1'b0 };
            `RV_CSR_MODE_SUPERVISOR : trap_rtn_addr_o = { sepc_q, 1'b0 };
            `RV_CSR_MODE_USER       : trap_rtn_addr_o = { uepc_q, 1'b0 };
`else
            `RV_CSR_MODE_MACHINE    : trap_rtn_addr_o = { mepc_q, 2'b0 };
            `RV_CSR_MODE_SUPERVISOR : trap_rtn_addr_o = { sepc_q, 2'b0 };
            `RV_CSR_MODE_USER       : trap_rtn_addr_o = { uepc_q, 2'b0 };
`endif
            default : begin
            end
        endcase
    end
endmodule
