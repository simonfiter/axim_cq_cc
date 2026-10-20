`timescale 1ns/1ps

module axim_ready_tb;
    reg aclk = 0;
    always #5 aclk = ~aclk;
    reg aresetn = 0;
    reg mstr_awvalid = 0;
    reg mstr_wvalid = 0;
    reg mstr_arvalid = 0;
    wire mstr_awready, mstr_wready, mstr_arready;
    wire mstr_bvalid, axis_cq_tvalid, axis_cq_tlast;
    wire [255:0] axis_cq_tdata;
    integer cycles;

    axim2s dut (
        .aclk(aclk), .aresetn(aresetn),
        .mstr_awid(6'd1), .mstr_awvalid(mstr_awvalid),
        .mstr_awaddr(64'h1000), .mstr_awlen(8'd0),
        .mstr_awsize(3'd5), .mstr_awburst(2'b01),
        .mstr_awmisc_info(50'h1_f100_0000_0000),
        .mstr_awmisc_info_vfunc_active(1'b0),
        .mstr_awmisc_info_vfunc_num(8'd0),
        .mstr_awmisc_info_func_num(3'd0),
        .mstr_awmisc_info_ats(2'd0), .mstr_awmisc_info_tph(11'd0),
        .mstr_awmisc_info_ido(1'b0), .mstr_awready(mstr_awready),
        .mstr_wvalid(mstr_wvalid), .mstr_wlast(1'b1),
        .mstr_wdata(256'd0), .mstr_wstrb(32'hffff_ffff),
        .mstr_wready(mstr_wready), .mstr_bvalid(mstr_bvalid),
        .mstr_bready(1'b1),
        .mstr_arid(6'd2), .mstr_arvalid(mstr_arvalid),
        .mstr_araddr(64'h2000), .mstr_arlen(8'd0),
        .mstr_arsize(3'd5), .mstr_arburst(2'b01),
        .mstr_armisc_info(50'h1_f100_0000_0000),
        .mstr_armisc_info_zeroread(1'b0),
        .mstr_armisc_info_vfunc_active(1'b0),
        .mstr_armisc_info_vfunc_num(8'd0),
        .mstr_armisc_info_func_num(3'd0),
        .mstr_armisc_info_ats(2'd0), .mstr_armisc_info_tph(11'd0),
        .mstr_armisc_info_ido(1'b0), .mstr_arready(mstr_arready),
        .axis_cq_tready(1'b1), .axis_cq_tvalid(axis_cq_tvalid),
        .axis_cq_tlast(axis_cq_tlast), .axis_cq_tdata(axis_cq_tdata),
        .axis_cc_tvalid(1'b0)
    );

    initial begin
        repeat (3) @(negedge aclk);
        aresetn = 1;
        #1;
        if (mstr_awready !== 1'b1 || mstr_arready !== 1'b1)
            $fatal(1, "idle AW/AR ready must be high before valid");

        // The source waits for READY before asserting VALID.
        @(negedge aclk);
        mstr_awvalid = 1;
        @(posedge aclk);
        if (mstr_awready !== 1'b1)
            $fatal(1, "AW did not handshake");
        @(negedge aclk);
        mstr_awvalid = 0;
        mstr_wvalid = 1;
        @(posedge aclk);
        if (mstr_wready !== 1'b1)
            $fatal(1, "W did not handshake");
        @(negedge aclk);
        mstr_wvalid = 0;
        cycles = 0;
        while (mstr_bvalid !== 1'b1 && cycles < 12) begin
            @(negedge aclk);
            cycles = cycles + 1;
        end
        if (mstr_bvalid !== 1'b1)
            $fatal(1, "write response timeout");
        @(negedge aclk);
        #1;
        if (mstr_arready !== 1'b1)
            $fatal(1, "idle AR ready did not recover");
        mstr_arvalid = 1;
        @(posedge aclk);
        if (mstr_arready !== 1'b1)
            $fatal(1, "AR did not handshake");
        @(negedge aclk);
        mstr_arvalid = 0;
        cycles = 0;
        while (axis_cq_tvalid !== 1'b1 && cycles < 4) begin
            @(negedge aclk);
            cycles = cycles + 1;
        end
        if (axis_cq_tvalid !== 1'b1 || axis_cq_tlast !== 1'b1 ||
            axis_cq_tdata[78:75] !== 4'b0000)
            $fatal(1, "read request did not reach CQ");
        $display("READY TEST PASSED");
        $finish;
    end
endmodule
