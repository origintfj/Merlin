/*
 * Author         : Tom Stanway-Mayers
 * Description    : Core Tracer
 * Version:       :
 * License        : Apache License Version 2.0, January 2004
 * License URL    : http://www.apache.org/licenses/
 */

`include "riscv_defs.v"

module merlin_rv32ic_trace_logger
    (
        // global
        input wire                clk_i,
        input wire                clk_en_i,
        input wire                reset_i,
        // tracer interface
        input wire                ex_stage_en_i,
        input wire                execute_commit_i,
        input wire [`RV_XLEN-1:0] ins_addr_i,
        input wire         [31:0] ins_value_i,
        input wire [`RV_XLEN-1:0] regs2_data_i,
        input wire [`RV_XLEN-1:0] alu_dout_i,
        input wire          [1:0] csr_mode_i,
        input wire                csr_jump_to_trap_i,
        input wire [`RV_XLEN-1:0] csr_trap_cause_i,
        input wire [`RV_XLEN-1:0] csr_trap_entry_addr_i,
        input wire [`RV_XLEN-1:0] csr_trap_rtn_addr_i
    );

    //--------------------------------------------------------------

    // program variables
    integer                logfile;
    integer                stack_depth;
    integer                trap_depth;
    integer                i;
    // rv32ic instruction expander
    wire            [31:0] rv32i_ins_expanded;
    wire                   ins_expanded_valid;
    // instruction mux
    wire            [31:0] rv32i_ins;
    // decoder
    wire                   wfi;
    wire                   trap_rtn;
    wire             [4:0] regd_addr;
    wire                   regs1_tgt;
    wire             [4:0] regs1_addr;
    wire             [4:0] regs2_addr;
    wire    [`RV_XLEN-1:0] imm;
    wire             [1:0] trap_rtn_mode;
    wire [`RV_ALUOP_RANGE] alu_op;
    wire             [2:0] funct3;
    wire                   csr_rd;
    wire                   csr_wr;
    wire            [11:0] csr_addr;
    // logging process

    //--------------------------------------------------------------

    initial begin
        stack_depth = 0;
        trap_depth  = 0;
        logfile     = $fopen("merlin_htt.log", "w");

                        //  [    0]           0 [3] 0x00000000 (00010137): lui   x2, 0x00010000
        $fwrite(logfile, "T|x2 ADDI|TIME       |CPM|ADDR      |INSTRUCTION\n");
    end

    //--------------------------------------------------------------
    // rv32ic instruction expander
    //--------------------------------------------------------------
    merlin_rv32ic_expander i_merlin_rv32ic_expander (
            .ins_i     (ins_value_i[15:0]),
            .ins_rvc_o (ins_expanded_valid),
            .ins_err_o (),
            .ins_o     (rv32i_ins_expanded)
        );


    //--------------------------------------------------------------
    // instruction mux
    //--------------------------------------------------------------
    assign rv32i_ins = (ins_expanded_valid ? rv32i_ins_expanded : ins_value_i);


    //--------------------------------------------------------------
    // decoder
    //--------------------------------------------------------------
    merlin_rv32i_decoder i_merlin_rv32i_decoder
        (
            // instruction decoder interface
                // ingress side
            .ins_i                 (rv32i_ins),
                // egress side
            .ins_err_o             (),
            .fencei_o              (),
            .wfi_o                 (wfi),
            .jump_o                (),
            .ecall_o               (),
            .trap_rtn_o            (trap_rtn),
            .trap_rtn_mode_o       (trap_rtn_mode),
            .zone_o                (),
            .regd_tgt_o            (),
            .regd_addr_o           (regd_addr),
            .regs1_rd_o            (),
            .regs1_addr_o          (regs1_addr),
            .regs2_rd_o            (),
            .regs2_addr_o          (regs2_addr),
            .imm_o                 (imm),
            .link_o                (),
            .sels1_pc_o            (),
            .sel_csr_wr_data_imm_o (),
            .sels2_imm_o           (),
            .selcmps2_imm_o        (),
            .aluop_o               (alu_op),
            .funct3_o              (funct3),
            .csr_rd_o              (csr_rd),
            .csr_wr_o              (csr_wr),
            .csr_addr_o            (csr_addr),
            .conditional_o         ()
        );


    //--------------------------------------------------------------
    // logging process
    //--------------------------------------------------------------
    always @ `RV_SYNC_LOGIC_CLOCK_RESET(clk_i, reset_i) begin
        if (reset_i) begin
        end else if (clk_en_i & ex_stage_en_i) begin
            if (csr_jump_to_trap_i) begin
                $fwrite(logfile, "%1d [%5d]", trap_depth, stack_depth);
                $fwrite(logfile, "%12t ", $time());
                $fwrite(logfile, "[%0d] ", csr_mode_i);
                if (ins_expanded_valid) begin
                    $fwrite(logfile, "0x%8x (    %04x): ", ins_addr_i, ins_value_i[15:0]);
                end else begin
                    $fwrite(logfile, "0x%8x (%08x): ", ins_addr_i, ins_value_i);
                end
                //
                $fwrite(logfile, "JUMP TO TRAP - ");
                case (csr_trap_cause_i)
                    `RV_CSR_INTR_CAUSE_US : begin
                        $fwrite(logfile, "U-MODE SWI ");
                    end
                    `RV_CSR_INTR_CAUSE_SS : begin
                        $fwrite(logfile, "S-MODE SWI ");
                    end
                    `RV_CSR_INTR_CAUSE_MS : begin
                        $fwrite(logfile, "M-MODE SWI ");
                    end
                    `RV_CSR_INTR_CAUSE_UT : begin
                        $fwrite(logfile, "U-MODE Timer ");
                    end
                    `RV_CSR_INTR_CAUSE_ST : begin
                        $fwrite(logfile, "S-MODE Timer ");
                    end
                    `RV_CSR_INTR_CAUSE_MT : begin
                        $fwrite(logfile, "M-MODE Timer ");
                    end
                    `RV_CSR_INTR_CAUSE_UE : begin
                        $fwrite(logfile, "U-MODE Ext. ");
                    end
                    `RV_CSR_INTR_CAUSE_SE : begin
                        $fwrite(logfile, "S-MODE Ext. ");
                    end
                    `RV_CSR_INTR_CAUSE_ME : begin
                        $fwrite(logfile, "M-MODE Ext. ");
                    end
                    `RV_CSR_EXCP_CAUSE_INS_ADDR_MISALIGNED : begin
                        $fwrite(logfile, "MAIF ");
                    end
                    `RV_CSR_EXCP_CAUSE_INS_ACCESS_FAULT : begin
                        $fwrite(logfile, "FERR ");
                    end
                    `RV_CSR_EXCP_CAUSE_ILLEGAL_INS : begin
                        $fwrite(logfile, "ILGL ");
                    end
/*
                    `RV_CSR_EXCP_CAUSE_BREAKPOINT : begin
                        $fwrite(logfile, "BREAK ");
                    end
*/
                    `RV_CSR_EXCP_CAUSE_LOAD_ADDR_MISALIGNED : begin
                        $fwrite(logfile, "MALA ");
                    end
                    `RV_CSR_EXCP_CAUSE_LOAD_ACCESS_FAULT : begin
                        $fwrite(logfile, "LAF ");
                    end
                    `RV_CSR_EXCP_CAUSE_STORE_ADDR_MISALIGNED : begin
                        $fwrite(logfile, "MASA ");
                    end
                    `RV_CSR_EXCP_CAUSE_STORE_ACCESS_FAULT : begin
                        $fwrite(logfile, "SAF ");
                    end
                    `RV_CSR_EXCP_CAUSE_ECALL_FROM_UMODE : begin
                        $fwrite(logfile, "U-MODE ecall ");
                    end
                    `RV_CSR_EXCP_CAUSE_ECALL_FROM_SMODE : begin
                        $fwrite(logfile, "S-MODE ecall ");
                    end
                    `RV_CSR_EXCP_CAUSE_ECALL_FROM_MMODE : begin
                        $fwrite(logfile, "M-MODE ecall ");
                    end
/*
                    `RV_CSR_EXCP_CAUSE_INS_PAGE_FAULT : begin
                        $fwrite(logfile, "IPAGE_FAULT ");
                    end
                    `RV_CSR_EXCP_CAUSE_LOAD_PAGE_FAULT : begin
                        $fwrite(logfile, "LPAGE_FAULT ");
                    end
                    `RV_CSR_EXCP_CAUSE_STORE_PAGE_FAULT : begin
                        $fwrite(logfile, "SPAGE_FAULT ");
                    end
*/
                    default : begin
                        $fwrite(logfile, "0x%08x", csr_trap_cause_i);
                    end
                endcase
                $fwrite(logfile, "(0x%8x)", csr_trap_entry_addr_i);
                $fwrite(logfile, "\n");
                trap_depth = trap_depth + 1;
            end else if (execute_commit_i) begin
                $fwrite(logfile, "%1d [%5d]", trap_depth, stack_depth);
                $fwrite(logfile, "%12t ", $time());
                $fwrite(logfile, "[%0d] ", csr_mode_i);
                if (ins_expanded_valid) begin
                    $fwrite(logfile, "0x%8x (    %04x): ", ins_addr_i, ins_value_i[15:0]);
                end else begin
                    $fwrite(logfile, "0x%8x (%08x): ", ins_addr_i, ins_value_i);
                end
                //
                if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_LUI) begin
                    $fwrite(logfile, "lui   x%0d, 0x%08x", regd_addr, imm);
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_AUIPC) begin
                    $fwrite(logfile, "auipc x%0d, 0x%08x", regd_addr, imm);
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_JAL) begin
                    $fwrite(logfile, "jal   x%0d, %0d (0x%x)", regd_addr, $signed(imm), alu_dout_i);
                    if (regd_addr == 5'd1) begin // if link register - treat as function call
                        $fwrite(logfile, " (CALL)");
                    end
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_JALR) begin
                    $fwrite(logfile, "jalr  x%0d, x%0d, %0d (0x%x)", regd_addr, regs1_addr, $signed(imm), alu_dout_i);
                    if (regs1_addr == 5'd1 && imm == 32'b0) begin // if link register - treat as function return
                        $fwrite(logfile, " (RTN)");
                    end
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_BRANCH) begin
                    case (funct3)
                        3'b000 : begin
                            $fwrite(logfile, "beq   x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                        3'b001 : begin
                            $fwrite(logfile, "bne   x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                        3'b100 : begin
                            $fwrite(logfile, "blt   x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                        3'b101 : begin
                            $fwrite(logfile, "bge   x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                        3'b110 : begin
                            $fwrite(logfile, "bltu  x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                        3'b111 : begin
                            $fwrite(logfile, "bgeu  x%0d, x%0d, %0d (0x%x)", regs1_addr, regs2_addr, $signed(imm), alu_dout_i);
                        end
                    endcase
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_LOAD) begin
                    case (funct3)
                        3'b000 : begin
                            $fwrite(logfile, "lb    x%0d, %0d(x%0d)", regd_addr, $signed(imm), regs1_addr);
                        end
                        3'b001 : begin
                            $fwrite(logfile, "lh    x%0d, %0d(x%0d)", regd_addr, $signed(imm), regs1_addr);
                        end
                        3'b010 : begin
                            $fwrite(logfile, "lw    x%0d, %0d(x%0d)", regd_addr, $signed(imm), regs1_addr);
                        end
                        3'b100 : begin
                            $fwrite(logfile, "lbu   x%0d, %0d(x%0d)", regd_addr, $signed(imm), regs1_addr);
                        end
                        3'b101 : begin
                            $fwrite(logfile, "lhu   x%0d, %0d(x%0d)", regd_addr, $signed(imm), regs1_addr);
                        end
                    endcase
                    $fwrite(logfile, "    *0x%08x", alu_dout_i);
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_STORE) begin
                    case (funct3)
                        3'b000 : begin
                            $fwrite(logfile, "sb    x%0d, %0d(x%0d)", regs2_addr, $signed(imm), regs1_addr);
                        end
                        3'b001 : begin
                            $fwrite(logfile, "sh    x%0d, %0d(x%0d)", regs2_addr, $signed(imm), regs1_addr);
                        end
                        3'b010 : begin
                            $fwrite(logfile, "sw    x%0d, %0d(x%0d)", regs2_addr, $signed(imm), regs1_addr);
                        end
                    endcase
                    $fwrite(logfile, "    *0x%08x = 0x%08x", alu_dout_i, regs2_data_i);
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_OPIMM) begin
                    case (alu_op)
                        `RV_ALUOP_ADD : begin
                            if (rv32i_ins == 32'h00000013) begin
                                $fwrite(logfile, "nop");
                            end else begin
                                $fwrite(logfile, "addi  x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                            end
                            if (regd_addr == 5'd2 && regs1_addr == 5'd2) begin
                                stack_depth = stack_depth + $signed(imm);
                            end
                        end
                        `RV_ALUOP_SLL : begin
                            $fwrite(logfile, "slli  x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                        end
                        `RV_ALUOP_SLT : begin
                            $fwrite(logfile, "slti  x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                        end
                        `RV_ALUOP_SLTU : begin
                            $fwrite(logfile, "sltui x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                        end
                        `RV_ALUOP_XOR : begin
                            $fwrite(logfile, "xori  x%0d, x%0d, 0x%08x", regd_addr, regs1_addr, imm);
                        end
                        `RV_ALUOP_SRL : begin
                            $fwrite(logfile, "srli  x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                        end
                        `RV_ALUOP_SRA : begin
                            $fwrite(logfile, "srai  x%0d, x%0d, %0d", regd_addr, regs1_addr, $signed(imm));
                        end
                        `RV_ALUOP_OR : begin
                            $fwrite(logfile, "ori   x%0d, x%0d, 0x%08x", regd_addr, regs1_addr, imm);
                        end
                        `RV_ALUOP_AND : begin
                            $fwrite(logfile, "andi  x%0d, x%0d, 0x%08x", regd_addr, regs1_addr, imm);
                        end
                    endcase
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_OP) begin
                    case (alu_op)
                        `RV_ALUOP_ADD : begin
                            $fwrite(logfile, "add   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SUB : begin
                            $fwrite(logfile, "sub   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SLL : begin
                            $fwrite(logfile, "sll   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SLT : begin
                            $fwrite(logfile, "slt   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SLTU : begin
                            $fwrite(logfile, "sltu  x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_XOR : begin
                            $fwrite(logfile, "xor   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SRL : begin
                            $fwrite(logfile, "srl   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_SRA : begin
                            $fwrite(logfile, "sra   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_OR : begin
                            $fwrite(logfile, "or    x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                        `RV_ALUOP_AND : begin
                            $fwrite(logfile, "and   x%0d, x%0d, x%0d", regd_addr, regs1_addr, regs2_addr);
                        end
                    endcase
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_MISCMEM) begin
                    if (funct3 == 3'b001) begin // fence.i
                        $fwrite(logfile, "fence.i");
                    end
                end else if (rv32i_ins[6:0] == `RV_MAJOR_OPCODE_SYSTEM) begin
                    if (csr_rd & csr_wr) begin
                        $fwrite(logfile, "x%0d = csr[0x%02x], csr[0x%02x] = x%0d", regd_addr, csr_addr, csr_addr, regs1_addr);
                    end else if (csr_rd) begin
                        $fwrite(logfile, "x%0d = csr[0x%02x]", regd_addr, csr_addr[7:0]);
                    end else if (csr_wr) begin
                        $fwrite(logfile, "csr[0x%02x] = x%0d", csr_addr[7:0], regs1_addr);
                    end else if (trap_rtn) begin
                        trap_depth = trap_depth - 1;
                        case (trap_rtn_mode)
                            2'b00 : begin
                                $fwrite(logfile, "uret  (0x%8x)", csr_trap_rtn_addr_i);
                            end
                            2'b01 : begin
                                $fwrite(logfile, "sret  (0x%8x)", csr_trap_rtn_addr_i);
                            end
                            2'b11 : begin
                                $fwrite(logfile, "mret  (0x%8x)", csr_trap_rtn_addr_i);
                            end
                        endcase
                    end else if (wfi) begin
                        $fwrite(logfile, "wfi");
                    end
                end
                $fwrite(logfile, "\n");
            end
        end
    end
endmodule
