// NOTE: RV_XLEN must be in { 32, 64 } TODO - enforce
// TODO generalise the 'response data formatter'
//
`include "riscv_defs.v"

module lsqueue
    #(
        parameter C_FIFO_DEPTH_X = 2
    )
    (
        // global
        input  wire                clk_i,
        input  wire                clk_en_i,
        input  wire                resetb_i,
        // instruction decoder stage interface
        output wire                lsq_reg_wr_o,
        output wire          [4:0] lsq_reg_addr_o,
        output reg  [`RV_XLEN-1:0] lsq_reg_data_o,
        // execution stage interface
        output wire                exs_full_o,
        output wire                exs_empty_o,
        input  wire                exs_lq_wr_i,
        input  wire                exs_sq_wr_i,
        input  wire          [1:0] exs_hpl_i,
        input  wire          [2:0] exs_funct3_i,
        input  wire          [4:0] exs_regd_addr_i,
        input  wire [`RV_XLEN-1:0] exs_regs2_data_i,
        input  wire [`RV_XLEN-1:0] exs_addr_i,
            // imprecise exceptions
        output wire                plic_int_laf_o,     // load access fault
        output wire                plic_int_saf_o,     // store access fault
        output wire [`RV_XLEN-1:0] plic_int_rspdata_o, // response data
        // data port
        input  wire                dreqready_i,
        output wire                dreqvalid_o,
        output wire          [1:0] dreqsize_o,
        output wire                dreqwrite_o,
        output wire          [1:0] dreqhpl_o,
        output wire [`RV_XLEN-1:0] dreqaddr_o,
        output wire [`RV_XLEN-1:0] dreqdata_o,
        output wire                drspready_o,
        input  wire                drspvalid_i,
        input  wire                drsprerr_i,
        input  wire                drspwerr_i,
        input  wire [`RV_XLEN-1:0] drspdata_i
    );

    //--------------------------------------------------------------

    // top-level assignments
    wire                             request;
    // request fifo
    parameter C_REQ_FIFO_WIDTH = `RV_XLEN + `RV_XLEN + 3 + 2 + 1;
    wire                             req_fifo_wr;
    reg       [C_REQ_FIFO_WIDTH-1:0] req_fifo_wr_data;
    wire      [C_REQ_FIFO_WIDTH-1:0] req_fifo_rd_data;
    wire                             req_fifo_empty;
    wire              [`RV_XLEN-1:0] req_fifo_rd_data_addr;
    wire              [`RV_XLEN-1:0] req_fifo_rd_data_data;
    wire                       [4:0] req_fifo_rd_data_regd;
    wire                       [2:0] req_fifo_rd_data_funct3;
    wire                       [1:0] req_fifo_rd_data_hpl;
    wire                             req_fifo_rd_data_wr;
    // response control fifo
    parameter C_RSP_CTRL_FIFO_WIDTH = `RV_XLEN_X-3 + 5 + 3;
    wire            [`RV_XLEN_X-4:0] req_ctrl_fifo_rd_data_alignment;
    wire                       [2:0] req_ctrl_fifo_rd_data_funct3;
    wire                             rsp_ctrl_fifo_empty;
    wire                             rsp_ctrl_fifo_full;
    wire [C_RSP_CTRL_FIFO_WIDTH-1:0] req_ctrl_fifo_wr_data;
    wire [C_RSP_CTRL_FIFO_WIDTH-1:0] req_ctrl_fifo_rd_data;
    // response data fifo
    wire                             rsp_data_fifo_empty;
    wire                             rsp_data_fifo_full;
    wire              [`RV_XLEN-1:0] rsp_data_fifo_wr_data;
    wire              [`RV_XLEN-1:0] rsp_data_fifo_rd_data;
    // response data formatter
    reg               [`RV_XLEN-1:0] rsp_data_justified;

    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // top-level assignments
    //--------------------------------------------------------------
    assign request = dreqvalid_o & dreqready_i;
    //
    assign lsq_reg_wr_o = ~rsp_data_fifo_empty;
    //
    assign exs_empty_o = rsp_ctrl_fifo_empty & req_fifo_empty;
    //
    assign plic_int_laf_o     = drspready_o & drsprerr_i;
    assign plic_int_saf_o     = drspready_o & drspwerr_i;
    assign plic_int_rspdata_o = drspdata_i;
    //
    assign dreqvalid_o  = ~req_fifo_empty & ~rsp_ctrl_fifo_full;
    assign dreqsize_o   =  req_fifo_rd_data_funct3[1:0];
    assign dreqwrite_o  =  req_fifo_rd_data_wr;
    assign dreqhpl_o    =  req_fifo_rd_data_hpl;
    assign dreqaddr_o   =  req_fifo_rd_data_addr;
    assign dreqdata_o   =  req_fifo_rd_data_data;
    //
    assign drspready_o = drspvalid_i & (~rsp_data_fifo_full | drspwerr_i);


    //--------------------------------------------------------------
    // request fifo
    //--------------------------------------------------------------
    assign req_fifo_wr = exs_lq_wr_i | exs_sq_wr_i;
    //
    always @ (*)
    begin
        if (exs_lq_wr_i) begin
            req_fifo_wr_data = { exs_addr_i,
                                 { `RV_XLEN-5 {1'b0} }, exs_regd_addr_i,
                                 exs_funct3_i,
                                 exs_hpl_i,
                                 exs_sq_wr_i };
        end else begin
            req_fifo_wr_data = { exs_addr_i,
                                 exs_regs2_data_i,
                                 exs_funct3_i,
                                 exs_hpl_i,
                                 exs_sq_wr_i };
        end
    end
    //
    assign req_fifo_rd_data_addr   = req_fifo_rd_data[`RV_XLEN + 3 + 2 + 1 +: `RV_XLEN];
    assign req_fifo_rd_data_data   = req_fifo_rd_data[           3 + 2 + 1 +: `RV_XLEN];
    assign req_fifo_rd_data_regd   = req_fifo_rd_data[           3 + 2 + 1 +:        5];
    assign req_fifo_rd_data_funct3 = req_fifo_rd_data[               2 + 1 +:        3];
    assign req_fifo_rd_data_hpl    = req_fifo_rd_data[                   1 +:        2];
    assign req_fifo_rd_data_wr     = req_fifo_rd_data[0];
    //
    fifo
        #(
            .C_FIFO_WIDTH   (C_REQ_FIFO_WIDTH),
            .C_FIFO_DEPTH_X (C_FIFO_DEPTH_X)
        ) i_req_fifo (
            // global
            .clk_i          (clk_i),
            .clk_en_i       (clk_en_i),
            .resetb_i       (resetb_i),
            // control and status
            .flush_i        (1'b0),
            .empty_o        (req_fifo_empty),
            .full_o         (exs_full_o),
            // write port
            .wr_i           (req_fifo_wr),
            .din_i          (req_fifo_wr_data),
            // read port
            .rd_i           (request),
            .dout_o         (req_fifo_rd_data)
        );


    //--------------------------------------------------------------
    // response control fifo
    //--------------------------------------------------------------
    assign req_ctrl_fifo_wr_data = { req_fifo_rd_data_addr[`RV_XLEN_X-3:0], req_fifo_rd_data_regd, req_fifo_rd_data_funct3 };
    //
    assign req_ctrl_fifo_rd_data_alignment = req_ctrl_fifo_rd_data[8 +: `RV_XLEN_X-3];
    assign lsq_reg_addr_o                  = req_ctrl_fifo_rd_data[3 +: 5];
    assign req_ctrl_fifo_rd_data_funct3    = req_ctrl_fifo_rd_data[0 +: 3];
    //
    fifo
        #(
            .C_FIFO_WIDTH   (C_RSP_CTRL_FIFO_WIDTH),
            .C_FIFO_DEPTH_X (C_FIFO_DEPTH_X)
        ) i_rsp_ctrl_fifo (
            // global
            .clk_i          (clk_i),
            .clk_en_i       (clk_en_i),
            .resetb_i       (resetb_i),
            // control and status
            .flush_i        (1'b0),
            .empty_o        (rsp_ctrl_fifo_empty),
            .full_o         (rsp_ctrl_fifo_full),
            // write port
            .wr_i           (request & ~req_fifo_rd_data_wr),
            .din_i          (req_ctrl_fifo_wr_data), // <regd_addr><funct3>
            // read port
            .rd_i           (lsq_reg_wr_o),
            .dout_o         (req_ctrl_fifo_rd_data)
        );


    //--------------------------------------------------------------
    // response data fifo
    //--------------------------------------------------------------
    assign rsp_data_fifo_wr_data = (drsprerr_i ? { `RV_XLEN {1'b0} } : drspdata_i); // if read error -> return 0
    //
    fifo
        #(
            .C_FIFO_WIDTH   (`RV_XLEN),
            .C_FIFO_DEPTH_X (C_FIFO_DEPTH_X)
        ) i_rsp_data_fifo (
            // global
            .clk_i          (clk_i),
            .clk_en_i       (clk_en_i),
            .resetb_i       (resetb_i),
            // control and status
            .flush_i        (1'b0),
            .empty_o        (rsp_data_fifo_empty),
            .full_o         (rsp_data_fifo_full),
            // write port
            .wr_i           (drspready_o & ~drspwerr_i),
            .din_i          (rsp_data_fifo_wr_data),
            // read port
            .rd_i           (lsq_reg_wr_o),
            .dout_o         (rsp_data_fifo_rd_data)
        );


    //--------------------------------------------------------------
    // response data formatter
    //--------------------------------------------------------------
    always @ (*)
    begin
        case (req_ctrl_fifo_rd_data_funct3)
            3'b000 : begin // LB
                if (rsp_data_fifo_rd_data[7]) begin
                    lsq_reg_data_o = { { `RV_XLEN-8 {1'b1} }, rsp_data_fifo_rd_data[7:0] };
                end else begin
                    lsq_reg_data_o = { { `RV_XLEN-8 {1'b0} }, rsp_data_fifo_rd_data[7:0] };
                end
            end
            3'b001 : begin // LH
                if (rsp_data_fifo_rd_data[15]) begin
                    lsq_reg_data_o = { { `RV_XLEN-16 {1'b1} }, rsp_data_fifo_rd_data[15:0] };
                end else begin
                    lsq_reg_data_o = { { `RV_XLEN-16 {1'b0} }, rsp_data_fifo_rd_data[15:0] };
                end
            end
/*
            3'b010 : begin // LW
                if (rsp_data_fifo_rd_data[31]) begin
                    lsq_reg_data_o = { { `RV_XLEN-32 {1'b1} }, rsp_data_fifo_rd_data[31:0] };
                end else begin
                    lsq_reg_data_o = { { `RV_XLEN-32 {1'b0} }, rsp_data_fifo_rd_data[31:0] };
                end
            end
            3'b011 : begin // LD
                lsq_reg_data_o = rsp_data_fifo_rd_data;
            end
*/
            3'b100 : begin // LBU
                lsq_reg_data_o = { { `RV_XLEN-8 {1'b0} }, rsp_data_fifo_rd_data[7:0] };
            end
            3'b101 : begin // LHU
                lsq_reg_data_o = { { `RV_XLEN-16 {1'b0} }, rsp_data_fifo_rd_data[15:0] };
            end
/*
            3'b110 : begin // LWU
                lsq_reg_data_o = { { `RV_XLEN-32 {1'b0} }, rsp_data_fifo_rd_data[31:0] };
            end
*/
            default : begin
                lsq_reg_data_o = rsp_data_fifo_rd_data;
            end
        endcase
    end
    //
    always @ (*)
    begin
        case (req_ctrl_fifo_rd_data_alignment)
            2'b01   : rsp_data_justified = {  8'b0, rsp_data_fifo_rd_data[`RV_XLEN-1: 8] };
            2'b10   : rsp_data_justified = { 16'b0, rsp_data_fifo_rd_data[`RV_XLEN-1:16] };
            2'b11   : rsp_data_justified = { 24'b0, rsp_data_fifo_rd_data[`RV_XLEN-1:24] };
            default : rsp_data_justified = rsp_data_fifo_rd_data;
        endcase
    end
endmodule
