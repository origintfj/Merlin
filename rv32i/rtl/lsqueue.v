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
        output wire                lsq_reg_wr_o, // TODO should this be clk_en_i gated?
        output wire          [4:0] lsq_reg_addr_o,
        output wire [`RV_XLEN-1:0] lsq_reg_data_o,
        // execution stage interface
        output wire                exs_full_o,
        input  wire                exs_lq_wr_i,
        input  wire                exs_sq_wr_i,
        input  wire          [1:0] exs_hpl_i,
        input  wire          [2:0] exs_funct3_i,
        input  wire          [4:0] exs_regd_addr_i,
        input  wire [`RV_XLEN-1:0] exs_regs2_data_i,
        input  wire [`RV_XLEN-1:0] exs_addr_i,
        // data port
        input  wire                dreqready_i,
        output wire                dreqvalid_o,
        output wire                dreqdvalid_o,
        output wire          [1:0] dreqhpl_o, // TODO
        output wire [`RV_XLEN-1:0] dreqaddr_o,
        output wire [`RV_XLEN-1:0] dreqdata_o,
        output wire                drspready_o,
        input  wire                drspvalid_i,
        input  wire                drsprerr_i,
        input  wire                drspwerr_i,
        input  wire [`RV_XLEN-1:0] drspdata_i,
        // hart vectoring and exception controller interface TODO
        output wire                hvec_laf_o,    // load access fault
        output wire                hvec_saf_o,    // store access fault
        output wire [`RV_XLEN-1:0] hvec_badaddr_o // bad address
    );

    //--------------------------------------------------------------

    // interface assignments
    wire                             response;
    // request fifo
    parameter C_REQ_FIFO_WIDTH = `RV_XLEN + `RV_XLEN + 3 + 2 + 1;
    wire                             req_fifo_rd;
    wire                             req_fifo_wr;
    reg       [C_REQ_FIFO_WIDTH-1:0] req_fifo_wr_data;
    wire                             req_fifo_empty;
    wire                             req_fifo_full;
    wire      [C_REQ_FIFO_WIDTH-1:0] req_fifo_rd_data;
    // response control fifo
    parameter C_RSP_CTRL_FIFO_WIDTH = 5 + 3;
    wire                             rsp_ctrl_fifo_full;
    wire [C_RSP_CTRL_FIFO_WIDTH-1:0] rsp_ctrl_fifo_rd_data;
    // response data fifo
    wire                             rsp_data_fifo_empty;
    wire                             rsp_data_fifo_full;
    wire                             rsp_data_fifo_wr;
    wire              [`RV_XLEN-1:0] rsp_data_fifo_rd_data;

    //--------------------------------------------------------------

    // interface assignments
    assign lsq_reg_wr_o   = ~rsp_data_fifo_empty;
    assign lsq_reg_addr_o =  rsp_ctrl_fifo_rd_data[3 +: 5];
    assign lsq_reg_data_o =  rsp_data_fifo_rd_data; // TODO rsp_ctrl_fifo_rd_data[0 +: 3] is rsp funct3
    //
    assign exs_full_o     =  req_fifo_full | rsp_ctrl_fifo_full;
    //
    assign dreqvalid_o    = ~req_fifo_empty & ~rsp_ctrl_fifo_full;
    assign dreqdvalid_o   =  req_fifo_rd_data[0];
    assign dreqhpl_o      =  req_fifo_rd_data[2:1];
    assign dreqaddr_o     =  req_fifo_rd_data[           6 +: `RV_XLEN];
    assign dreqdata_o     =  req_fifo_rd_data[`RV_XLEN + 6 +: `RV_XLEN]; // TODO req_fifo_rd_data[3 +: 3] is req funct3
    assign drspready_o    = ~rsp_data_fifo_full;
    assign response       =  drspvalid_i & drspready_o;
    //
    assign hvec_laf_o     =  response & drsprerr_i;
    assign hvec_saf_o     =  response & drspwerr_i;
    assign hvec_badaddr_o =  drspdata_i;


    // request fifo
    //
    assign req_fifo_rd = dreqready_i & ~req_fifo_empty;
    assign req_fifo_wr = exs_lq_wr_i &  exs_sq_wr_i;
    //
    always @ (*)
    begin
        if (exs_lq_wr_i) begin
            req_fifo_wr_data = { exs_addr_i, { `RV_XLEN-5 {1'b0} }, exs_regd_addr_i, exs_funct3_i, exs_hpl_i, exs_sq_wr_i };
        end else begin
            req_fifo_wr_data = { exs_addr_i, exs_regs2_data_i, exs_funct3_i, exs_hpl_i, exs_sq_wr_i };
        end
    end
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
            .full_o         (req_fifo_full),
            // write port
            .wr_i           (req_fifo_wr),
            .din_i          (req_fifo_wr_data),
            // read port
            .rd_i           (req_fifo_rd),
            .dout_o         (req_fifo_rd_data)
        );


    // response control fifo
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
            .empty_o        (),
            .full_o         (rsp_ctrl_fifo_full),
            // write port
            .wr_i           (req_fifo_rd & ~req_fifo_rd_data[0]),
            .din_i          (req_fifo_rd_data[3 +: 5 + 3]), // <regd_addr><funct3>
            // read port
            .rd_i           (lsq_reg_wr_o | (response & drsprerr_i)),
            .dout_o         (rsp_ctrl_fifo_rd_data)
        );


    // response data fifo
    //
    assign rsp_data_fifo_wr = response & ~(drsprerr_i & drspwerr_i);
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
            .wr_i           (rsp_data_fifo_wr),
            .din_i          (drspdata_i),
            // read port
            .rd_i           (lsq_reg_wr_o),
            .dout_o         (rsp_data_fifo_rd_data)
        );
endmodule

