module cs_registers
    #(
        parameter C_VENDOR_ID,
        parameter C_ARCHITECTURE_ID,
        parameter C_IMPLEMENTATION_ID,
        parameter C_HART_ID
    )
    (
        // global
        input  logic            clk_i,
        input  logic            clk_en_i,
        input  logic            resetb_i,
        // csr read/write interface
        input  logic            csr_wr_en_i,
        input  logic            csr_rd_en_i, // TODO
        input  logic     [11:0] csr_addr_i,
        input  logic [XLEN-1:0] csr_wr_data_i,
        output logic [XLEN-1:0] csr_rd_data_o
    );

    //--------------------------------------------------------------

    // user trap setup
    logic [C_XLEN-1:0] ustatus_q;
    logic [C_XLEN-1:0] uie_q;
    logic [C_XLEN-1:0] utvec_q;
    // user trap handling
    logic [C_XLEN-1:0] uscratch_q;
    logic [C_XLEN-1:0] uepc_q;
    logic [C_XLEN-1:0] ucause_q;
    logic [C_XLEN-1:0] ubadaddr_q;
    logic [C_XLEN-1:0] uip_q;
    // user floating-point csrs
    logic [C_XLEN-1:0] fflags_q;
    logic [C_XLEN-1:0] frm_q;
    logic [C_XLEN-1:0] fcsr_q;
    // user counter/timers
    // TODO
    // supervisor trap setup
    logic [C_XLEN-1:0] sstatus_q;
    logic [C_XLEN-1:0] sedeleg_q;
    logic [C_XLEN-1:0] sideleg_q;
    logic [C_XLEN-1:0] sie_q;
    logic [C_XLEN-1:0] stvec_q;
    // supervisor trap handling
    logic [C_XLEN-1:0] sscratch_q;
    logic [C_XLEN-1:0] sepc_q;
    logic [C_XLEN-1:0] scause_q;
    logic [C_XLEN-1:0] sbadaddr_q;
    logic [C_XLEN-1:0] sip_q;
    // supervisor protection and translation
    logic [C_XLEN-1:0] sptbr_q;
    // hypervisor trap setup
    logic [C_XLEN-1:0] hstatus_q;
    logic [C_XLEN-1:0] hedeleg_q;
    logic [C_XLEN-1:0] hideleg_q;
    logic [C_XLEN-1:0] hie_q;
    logic [C_XLEN-1:0] htvec_q;
    // hypervisor trap handling
    logic [C_XLEN-1:0] hscratch_q;
    logic [C_XLEN-1:0] hepc_q;
    logic [C_XLEN-1:0] hcause_q;
    logic [C_XLEN-1:0] hbadaddr_q;
    logic [C_XLEN-1:0] hip_q;
    // hypervisor protection and translation
    // TODO
    // machine information registers
    // NOTE - constants
    // machine trap setup
    logic [C_XLEN-1:0] mstatus_q;
    logic [C_XLEN-1:0] misa_q;
    logic [C_XLEN-1:0] medeleg_q;
    logic [C_XLEN-1:0] mideleg_q;
    logic [C_XLEN-1:0] mie_q;
    logic [C_XLEN-3:0] mtvec_q;
    // machine trap handling
    logic [C_XLEN-1:0] mscratch_q;
    logic [C_XLEN-1:0] mepc_q;
    logic [C_XLEN-1:0] mcause_q;
    logic [C_XLEN-1:0] mbadaddr_q;
    logic [C_XLEN-1:0] mip_q;
    // machine protection and translation
    logic [C_XLEN-1:0] mbase_q;
    logic [C_XLEN-1:0] mbound_q;
    logic [C_XLEN-1:0] mibase_q;
    logic [C_XLEN-1:0] mibound_q;
    logic [C_XLEN-1:0] mdbase_q;
    logic [C_XLEN-1:0] mdbound_q;
    // machine counter/timers
    // TODO
    // machine counter setup
    // TODO
    // debug/trace registers
    logic [C_XLEN-1:0] tselect_q;
    logic [C_XLEN-1:0] tdata1_q;
    logic [C_XLEN-1:0] tdata2_q;
    logic [C_XLEN-1:0] tdata3_q;
    // debug mode registers
    logic [C_XLEN-1:0] dcsr_q;
    logic [C_XLEN-1:0] dpc_q;
    logic [C_XLEN-1:0] dscratch_q;

    //--------------------------------------------------------------


    // csr reads
    //
    always_comb
    begin
        unique case (csr_addr_i) begin
            12'h000 : csr_rd_data = ustatus_q;
            12'h004 : csr_rd_data = uie_q;
            12'h005 : csr_rd_data = utvec_q;
            12'h040 : csr_rd_data = uscratch_q;
            12'h041 : csr_rd_data = uepc_q;
            12'h042 : csr_rd_data = ucause_q;
            12'h043 : csr_rd_data = ubadaddr_q;
            12'h044 : csr_rd_data = uip_q;
            12'h001 : csr_rd_data = fflags_q;
            12'h002 : csr_rd_data = frm_q;
            12'h003 : csr_rd_data = fcsr_q;
            12'h100 : csr_rd_data = sstatus_q;
            12'h102 : csr_rd_data = sedeleg_q;
            12'h103 : csr_rd_data = sideleg_q;
            12'h104 : csr_rd_data = sie_q;
            12'h105 : csr_rd_data = stvec_q;
            12'h140 : csr_rd_data = sscratch_q;
            12'h141 : csr_rd_data = sepc_q;
            12'h142 : csr_rd_data = scause_q;
            12'h143 : csr_rd_data = sbadaddr_q;
            12'h144 : csr_rd_data = sip_q;
            12'h180 : csr_rd_data = sptbr_q;
            12'h200 : csr_rd_data = hstatus_q;
            12'h202 : csr_rd_data = hedeleg_q;
            12'h203 : csr_rd_data = hideleg_q;
            12'h204 : csr_rd_data = hie_q;
            12'h205 : csr_rd_data = htvec_q;
            12'h240 : csr_rd_data = hscratch_q;
            12'h241 : csr_rd_data = hepc_q;
            12'h242 : csr_rd_data = hcause_q;
            12'h243 : csr_rd_data = hbadaddr_q;
            12'h244 : csr_rd_data = hip_q;
            12'hf11 : csr_rd_data = C_VENDOR_ID; // vendor id
            12'hf12 : csr_rd_data = C_ARCHITECTURE_ID; // architecture id
            12'hf13 : csr_rd_data = C_IMPLEMENTATION_ID; // implementation id
            12'hf14 : csr_rd_data = C_HART_ID; // hart id
            12'h300 : csr_rd_data = mstatus_q; // TODO
            12'h301 : csr_rd_data = misa_q; // TODO
            12'h302 : csr_rd_data = medeleg_q;
            12'h303 : csr_rd_data = mideleg_q;
            12'h304 : csr_rd_data = mie_q;
            12'h305 : csr_rd_data = { mtvec_q, 2'b0 };
            12'h340 : csr_rd_data = mscratch_q;
            12'h341 : csr_rd_data = mepc_q;
            12'h342 : csr_rd_data = mcause_q;
            12'h343 : csr_rd_data = mbadaddr_q;
            12'h344 : csr_rd_data = mip_q;
            12'h380 : csr_rd_data = mbase_q;
            12'h381 : csr_rd_data = mbound_q;
            12'h382 : csr_rd_data = mibase_q;
            12'h383 : csr_rd_data = mibound_q;
            12'h384 : csr_rd_data = mdbase_q;
            12'h385 : csr_rd_data = mdbound_q;
            12'h7a0 : csr_rd_data = tselect_q;
            12'h7a1 : csr_rd_data = tdata1_q;
            12'h7a2 : csr_rd_data = tdata2_q;
            12'h7a3 : csr_rd_data = tdata3_q;
            12'h7b0 : csr_rd_data = dcsr_q;
            12'h7b1 : csr_rd_data = dpc_q;
            12'h7b2 : csr_rd_data = dscratch_q;
            default : csr_rd_data = 32'bx;
        end
    end


    // csr writes
    //
    always_ff @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            // TODO reset all the csrs
        end else if (clk_en_i) begin
            unique case (csr_addr_i) begin
                12'h000 : ustatus_q  <= csr_wr_data;
                12'h004 : uie_q      <= csr_wr_data;
                12'h005 : utvec_q    <= csr_wr_data;
                12'h040 : uscratch_q <= csr_wr_data;
                12'h041 : uepc_q     <= csr_wr_data;
                12'h042 : ucause_q   <= csr_wr_data;
                12'h043 : ubadaddr_q <= csr_wr_data;
                12'h044 : uip_q      <= csr_wr_data;
                12'h001 : fflags_q   <= csr_wr_data;
                12'h002 : frm_q      <= csr_wr_data;
                12'h003 : fcsr_q     <= csr_wr_data;
                12'h100 : sstatus_q  <= csr_wr_data;
                12'h102 : sedeleg_q  <= csr_wr_data;
                12'h103 : sideleg_q  <= csr_wr_data;
                12'h104 : sie_q      <= csr_wr_data;
                12'h105 : stvec_q    <= csr_wr_data;
                12'h140 : sscratch_q <= csr_wr_data;
                12'h141 : sepc_q     <= csr_wr_data;
                12'h142 : scause_q   <= csr_wr_data;
                12'h143 : sbadaddr_q <= csr_wr_data;
                12'h144 : sip_q      <= csr_wr_data;
                12'h180 : sptbr_q    <= csr_wr_data;
                12'h200 : hstatus_q  <= csr_wr_data;
                12'h202 : hedeleg_q  <= csr_wr_data;
                12'h203 : hideleg_q  <= csr_wr_data;
                12'h204 : hie_q      <= csr_wr_data;
                12'h205 : htvec_q    <= csr_wr_data;
                12'h240 : hscratch_q <= csr_wr_data;
                12'h241 : hepc_q     <= csr_wr_data;
                12'h242 : hcause_q   <= csr_wr_data;
                12'h243 : hbadaddr_q <= csr_wr_data;
                12'h244 : hip_q      <= csr_wr_data;
                // vendor id
                // architecture id
                // implementation id
                // hart id
                12'h300 : mstatus_q  <= csr_wr_data;
                12'h301 : misa_q     <= csr_wr_data;
                12'h302 : medeleg_q  <= csr_wr_data;
                12'h303 : mideleg_q  <= csr_wr_data;
                12'h304 : mie_q      <= csr_wr_data;
                12'h305 : mtvec_q    <= csr_wr_data[XLEN-1:2];
                12'h340 : mscratch_q <= csr_wr_data;
                12'h341 : mepc_q     <= csr_wr_data;
                12'h342 : mcause_q   <= csr_wr_data;
                12'h343 : mbadaddr_q <= csr_wr_data;
                12'h344 : mip_q      <= csr_wr_data;
                12'h380 : mbase_q    <= csr_wr_data;
                12'h381 : mbound_q   <= csr_wr_data;
                12'h382 : mibase_q   <= csr_wr_data;
                12'h383 : mibound_q  <= csr_wr_data;
                12'h384 : mdbase_q   <= csr_wr_data;
                12'h385 : mdbound_q  <= csr_wr_data;
                12'h7a0 : tselect_q  <= csr_wr_data;
                12'h7a1 : tdata1_q   <= csr_wr_data;
                12'h7a2 : tdata2_q   <= csr_wr_data;
                12'h7a3 : tdata3_q   <= csr_wr_data;
                12'h7b0 : dcsr_q     <= csr_wr_data;
                12'h7b1 : dpc_q      <= csr_wr_data;
                12'h7b2 : dscratch_q <= csr_wr_data;
            end
        end
    end
endmodule;

