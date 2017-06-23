module hvec
    #(
        parameter C_XLEN = 32
    )
    (
        // global
        input  wire                 clk_i,
        input  wire                 clk_en_i,
        input  wire                 resetb_i,
        // external interrupt interface
        // pfu interface
        input  wire                 pfu_pc_ready_i,
        output reg                  pfu_pc_wr_o,
        output reg     [C_XLEN-1:0] pfu_pc_o,
        // ex stage interface
        input  wire                 exs_jump_i,
        input  wire    [C_XLEN-1:0] exs_jump_addr_i
        // lsq interface
    );

    //--------------------------------------------------------------

    // jump address register
    reg [C_XLEN-1:0] jump_addr_q;
    // jump fsm
    parameter JUMP_STATE_IDLE    = 1'b0;
    parameter JUMP_STATE_WAITING = 1'b1;
    //
    reg              jump_fsm_c_state;
    reg              jump_fsm_n_state;
    //
    reg              jump_addr_reg_en;
    reg              jump_addr_reg_bypass;
    


    //--------------------------------------------------------------

    // jump address register
    //
    always @ (posedge clk_i)
    begin
        if (clk_en_i) begin
            if (jump_addr_reg_en) begin
                jump_addr_q <= exs_jump_addr_i;
            end
        end
    end
    always @ (*)
    begin
        if (jump_addr_reg_bypass) begin
            pfu_pc_o = exs_jump_addr_i;
        end else begin
            pfu_pc_o = jump_addr_q;
        end
    end


    // jump fsm
    //
    always @ (*)
    begin
        //
        pfu_pc_wr_o          = 1'b0;
        //
        jump_addr_reg_en     = 1'b0;
        jump_addr_reg_bypass = 1'b0;
        //
        jump_fsm_n_state = jump_fsm_c_state;
        case (jump_fsm_c_state)
            JUMP_STATE_IDLE : begin
                jump_addr_reg_bypass = 1'b1;
                if (pfu_pc_ready_i) begin
                    if (exs_jump_i) begin
                        pfu_pc_wr_o = 1'b1;
                    end
                end else begin
                    if (exs_jump_i) begin
                        jump_addr_reg_en = 1'b1;
                        jump_fsm_n_state = JUMP_STATE_WAITING;
                    end
                end
            end
            JUMP_STATE_WAITING : begin
                jump_addr_reg_bypass = 1'b0;
                if (pfu_pc_ready_i) begin
                    pfu_pc_wr_o      = 1'b1;
                    jump_fsm_n_state = JUMP_STATE_IDLE;
                end
            end
        endcase
    end
    always @ (posedge clk_i or negedge resetb_i)
    begin
        if (~resetb_i) begin
            jump_fsm_c_state <= JUMP_STATE_IDLE;
        end else if (clk_en_i) begin
            jump_fsm_c_state <= jump_fsm_n_state;
        end
    end
endmodule

