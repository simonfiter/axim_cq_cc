`timescale 1ns/1ps

module axim_alignment_tb;
    reg aclk = 0;
    always #5 aclk = ~aclk;
    reg aresetn = 0;
    reg mstr_awvalid = 0, mstr_wvalid = 0, mstr_arvalid = 0;
    reg [63:0] mstr_awaddr = 0, mstr_araddr = 0;
    reg [7:0] mstr_awlen = 0, mstr_arlen = 0;
    reg [255:0] mstr_wdata = 0;
    reg [31:0] mstr_wstrb = 0;
    reg mstr_wlast = 0, mstr_bready = 0, mstr_rready = 0;
    wire mstr_awready, mstr_wready, mstr_arready;
    wire mstr_bvalid, mstr_rvalid, mstr_rlast;
    wire [1:0] mstr_bresp, mstr_rresp;
    wire [255:0] mstr_rdata;
    reg axis_cq_tready = 1;
    wire [255:0] axis_cq_tdata;
    wire [7:0] axis_cq_tkeep;
    wire [84:0] axis_cq_tuser;
    wire axis_cq_tvalid, axis_cq_tlast;
    reg [255:0] axis_cc_tdata = 0;
    reg [7:0] axis_cc_tkeep = 0;
    reg axis_cc_tlast = 0, axis_cc_tvalid = 0;
    wire axis_cc_tready;
    integer i;
    integer log_fd;
    reg cq_in_packet = 0, cc_in_packet = 0;

    always @(posedge aclk) begin
        if (!aresetn) begin
            cq_in_packet <= 0;
            cc_in_packet <= 0;
        end else begin
            if (mstr_awvalid && mstr_awready)
                $fdisplay(log_fd, "%0t AXI_AW addr=%h len=%0d", $time,
                          mstr_awaddr, mstr_awlen);
            if (mstr_wvalid && mstr_wready)
                $fdisplay(log_fd, "%0t AXI_W strb=%h last=%b data=%h", $time,
                          mstr_wstrb, mstr_wlast, mstr_wdata);
            if (mstr_arvalid && mstr_arready)
                $fdisplay(log_fd, "%0t AXI_AR addr=%h len=%0d", $time,
                          mstr_araddr, mstr_arlen);
            if (axis_cq_tvalid && axis_cq_tready) begin
                if (!cq_in_packet)
                    $fdisplay(log_fd, "%0t CQ_DESC type=%s addr=%h dw=%0d first_be=%h last_be=%h keep=%h", $time,
                              axis_cq_tdata[78:75] == 4'b0001 ? "Memory Write" : "Memory Read",
                              {axis_cq_tdata[63:2], 2'b0}, axis_cq_tdata[74:64],
                              axis_cq_tuser[3:0], axis_cq_tuser[7:4],
                              axis_cq_tkeep);
                else
                    $fdisplay(log_fd, "%0t CQ_PAYLOAD keep=%h byte_en=%h last=%b data=%h", $time,
                              axis_cq_tkeep, axis_cq_tuser[39:8],
                              axis_cq_tlast, axis_cq_tdata);
                cq_in_packet <= !axis_cq_tlast;
            end
            if (axis_cc_tvalid && axis_cc_tready) begin
                if (!cc_in_packet)
                    $fdisplay(log_fd, "%0t CC_DESC lower_addr=%0d byte_count=%0d dw=%0d keep=%h", $time,
                              axis_cc_tdata[6:0], axis_cc_tdata[28:16],
                              axis_cc_tdata[42:32], axis_cc_tkeep);
                else
                    $fdisplay(log_fd, "%0t CC_PAYLOAD keep=%h last=%b data=%h", $time,
                              axis_cc_tkeep, axis_cc_tlast, axis_cc_tdata);
                cc_in_packet <= !axis_cc_tlast;
            end
            if (mstr_bvalid && mstr_bready)
                $fdisplay(log_fd, "%0t AXI_B resp=%0d", $time, mstr_bresp);
            if (mstr_rvalid && mstr_rready)
                $fdisplay(log_fd, "%0t AXI_R resp=%0d last=%b data=%h", $time,
                          mstr_rresp, mstr_rlast, mstr_rdata);
        end
    end

    axim2s dut (
        .aclk(aclk), .aresetn(aresetn),
        .mstr_awid(6'd1), .mstr_awvalid(mstr_awvalid),
        .mstr_awaddr(mstr_awaddr), .mstr_awlen(mstr_awlen),
        .mstr_awsize(3'd5), .mstr_awburst(2'b01),
        .mstr_awmisc_info(50'h0001_0000_0000),
        .mstr_awmisc_info_vfunc_active(1'b0),
        .mstr_awmisc_info_vfunc_num(8'd0),
        .mstr_awmisc_info_func_num(3'd0),
        .mstr_awmisc_info_ats(2'd0), .mstr_awmisc_info_tph(11'd0),
        .mstr_awmisc_info_ido(1'b0), .mstr_awready(mstr_awready),
        .mstr_wvalid(mstr_wvalid), .mstr_wlast(mstr_wlast),
        .mstr_wdata(mstr_wdata), .mstr_wstrb(mstr_wstrb),
        .mstr_wready(mstr_wready), .mstr_bvalid(mstr_bvalid),
        .mstr_bresp(mstr_bresp), .mstr_bready(mstr_bready),
        .mstr_arid(6'd2), .mstr_arvalid(mstr_arvalid),
        .mstr_araddr(mstr_araddr), .mstr_arlen(mstr_arlen),
        .mstr_arsize(3'd5), .mstr_arburst(2'b01),
        .mstr_armisc_info(50'h0002_0000_0000),
        .mstr_armisc_info_zeroread(1'b0),
        .mstr_armisc_info_vfunc_active(1'b0),
        .mstr_armisc_info_vfunc_num(8'd0),
        .mstr_armisc_info_func_num(3'd0),
        .mstr_armisc_info_ats(2'd0), .mstr_armisc_info_tph(11'd0),
        .mstr_armisc_info_ido(1'b0), .mstr_arready(mstr_arready),
        .mstr_rvalid(mstr_rvalid), .mstr_rlast(mstr_rlast),
        .mstr_rdata(mstr_rdata), .mstr_rresp(mstr_rresp),
        .mstr_rready(mstr_rready),
        .axis_cq_tready(axis_cq_tready), .axis_cq_tvalid(axis_cq_tvalid),
        .axis_cq_tlast(axis_cq_tlast), .axis_cq_tdata(axis_cq_tdata),
        .axis_cq_tkeep(axis_cq_tkeep), .axis_cq_tuser(axis_cq_tuser),
        .axis_cc_tdata(axis_cc_tdata), .axis_cc_tkeep(axis_cc_tkeep),
        .axis_cc_tlast(axis_cc_tlast), .axis_cc_tvalid(axis_cc_tvalid),
        .axis_cc_tready(axis_cc_tready)
    );

    task automatic send_w(input [255:0] data, input [31:0] strb, input bit last);
        begin
            @(negedge aclk);
            mstr_wdata = data;
            mstr_wstrb = strb;
            mstr_wlast = last;
            mstr_wvalid = 1;
            do @(posedge aclk); while (!mstr_wready);
            @(negedge aclk);
            mstr_wvalid = 0;
        end
    endtask

    task automatic send_cc(input [255:0] data, input [7:0] keep,
                           input bit last);
        begin
            @(negedge aclk);
            axis_cc_tdata = data;
            axis_cc_tkeep = keep;
            axis_cc_tlast = last;
            axis_cc_tvalid = 1;
            do @(posedge aclk); while (!axis_cc_tready);
            @(negedge aclk);
            axis_cc_tvalid = 0;
        end
    endtask

    task automatic check_write(input [63:0] addr, input [7:0] len,
                               input [31:0] first_strb,
                               input [31:0] last_strb,
                               input [10:0] dw_count,
                               input [7:0] be);
        reg [255:0] data [0:31];
        reg [31:0] strb [0:31];
        reg [255:0] expected_data;
        reg [31:0] expected_byte_en;
        reg [7:0] expected_keep;
        integer beat, lane, offset, source, count;
        begin
            $display("WRITE addr=%h len=%0d", addr, len);
            @(negedge aclk);
            mstr_awaddr = addr;
            mstr_awlen = len;
            mstr_awvalid = 1;
            do @(posedge aclk); while (!mstr_awready);
            @(negedge aclk);
            mstr_awvalid = 0;
            $display("AW accepted at %0t", $time);
            for (beat = 0; beat <= len; beat = beat + 1) begin
                for (lane = 0; lane < 8; lane = lane + 1)
                    data[beat][lane*32 +: 32] = $urandom;
                strb[beat] = beat == 0 ? first_strb :
                             beat == len ? last_strb : 32'hffff_ffff;
                send_w(data[beat], strb[beat], beat == len);
            end
            $display("W accepted at %0t", $time);
            do @(posedge aclk); while (!axis_cq_tvalid);
            if (axis_cq_tdata[74:64] !== dw_count ||
                axis_cq_tdata[63:2] !== addr[63:2] ||
                axis_cq_tkeep !== 8'hff || axis_cq_tuser[7:0] !== be ||
                axis_cq_tdata[255:128] !== 0 || axis_cq_tlast ||
                !axis_cq_tuser[40] || axis_cq_tuser[39:8] !== 0)
                $fatal(1, "address-aligned CQ write descriptor mismatch");
            offset = 0;
            while (offset < dw_count) begin
                expected_data = 0;
                expected_byte_en = 0;
                expected_keep = offset == 0 ? 8'h01 : 0;
                count = 0;
                for (lane = (offset == 0 ? 1 : 0); lane < 8; lane = lane + 1) begin
                    if (offset + count < dw_count) begin
                        source = addr[4:2] + offset + count;
                        expected_data[lane*32 +: 32] =
                            data[source/8][(source%8)*32 +: 32];
                        expected_byte_en[lane*4 +: 4] =
                            strb[source/8][(source%8)*4 +: 4];
                        expected_keep[lane] = 1;
                        count = count + 1;
                    end
                end
                @(posedge aclk);
                if (axis_cq_tvalid !== 1'b1 ||
                    axis_cq_tdata !== expected_data ||
                    axis_cq_tkeep !== expected_keep ||
                    axis_cq_tuser[39:8] !== expected_byte_en ||
                    axis_cq_tuser[40] || axis_cq_tuser[7:0] !== 0 ||
                    axis_cq_tlast !== (offset + count == dw_count))
                    $fatal(1, "address-aligned CQ write payload mismatch");
                offset = offset + count;
            end
            do @(posedge aclk); while (!mstr_bvalid);
            $display("B at %0t", $time);
            if (mstr_bresp !== 2'b00)
                $fatal(1, "write response mismatch");
            @(negedge aclk);
            mstr_bready = 1;
            @(posedge aclk);
            @(negedge aclk);
            mstr_bready = 0;
        end
    endtask

    task automatic check_read;
        reg [255:0] header, payload;
        begin
            $display("READ start at %0t", $time);
            @(negedge aclk);
            mstr_araddr = 64'h2003;
            mstr_arlen = 0;
            mstr_arvalid = 1;
            do @(posedge aclk); while (!mstr_arready);
            $display("AR accepted at %0t", $time);
            @(negedge aclk);
            mstr_arvalid = 0;
            do @(posedge aclk); while (!axis_cq_tvalid);
            $display("Read CQ at %0t", $time);
            if (axis_cq_tdata[74:64] !== 11'd8 ||
                axis_cq_tuser[7:0] !== 8'hf8 ||
                axis_cq_tkeep !== 8'h0f || !axis_cq_tlast)
                $fatal(1, "address-aligned CQ read descriptor mismatch");
            header = 0;
            header[6:0] = 7'd3;
            header[28:16] = 13'd29;
            header[42:32] = 11'd8;
            header[63:48] = 16'h0200;
            send_cc(header, 8'h07, 0);
            $display("CC header at %0t", $time);
            payload = 0;
            for (i = 0; i < 8; i = i + 1)
                payload[i*32 +: 32] = 32'hcafe_0000 + i;
            send_cc(payload, 8'hff, 1);
            $display("CC payload at %0t", $time);
            do @(posedge aclk); while (!mstr_rvalid);
            if (mstr_rresp !== 2'b00 || !mstr_rlast ||
                mstr_rdata !== payload)
                $fatal(1, "address-aligned AXI read response mismatch");
            @(negedge aclk);
            mstr_rready = 1;
            @(posedge aclk);
            @(negedge aclk);
            mstr_rready = 0;
        end
    endtask

    task automatic check_split_read;
        reg [255:0] header, payload;
        integer lane;
        begin
            @(negedge aclk);
            mstr_araddr = 64'h2025;
            mstr_arlen = 1;
            mstr_arvalid = 1;
            do @(posedge aclk); while (!mstr_arready);
            @(negedge aclk);
            mstr_arvalid = 0;
            do @(posedge aclk); while (!axis_cq_tvalid);
            if (axis_cq_tdata[74:64] !== 11'd15 ||
                axis_cq_tuser[7:0] !== 8'hfe || !axis_cq_tlast)
                $fatal(1, "split read CQ descriptor mismatch");

            header = 0;
            header[6:0] = 7'h25;
            header[28:16] = 13'd59;
            header[42:32] = 11'd3;
            header[63:48] = 16'h0200;
            send_cc(header, 8'h07, 0);
            payload = 0;
            for (lane = 1; lane <= 3; lane = lane + 1)
                payload[lane*32 +: 32] = 32'hcafe_1000 + lane - 1;
            send_cc(payload, 8'h0f, 1);

            header = 0;
            header[6:0] = 7'h30;
            header[28:16] = 13'd48;
            header[42:32] = 11'd12;
            header[63:48] = 16'h0200;
            send_cc(header, 8'h07, 0);
            payload = 0;
            for (lane = 4; lane < 8; lane = lane + 1)
                payload[lane*32 +: 32] = 32'hcafe_1000 + lane - 1;
            send_cc(payload, 8'hff, 0);
            payload = 0;
            for (lane = 0; lane < 8; lane = lane + 1)
                payload[lane*32 +: 32] = 32'hcafe_1007 + lane;
            send_cc(payload, 8'hff, 1);

            do @(posedge aclk); while (!mstr_rvalid);
            if (mstr_rresp !== 2'b00 || mstr_rlast)
                $fatal(1, "first split AXI R status mismatch");
            for (lane = 1; lane < 8; lane = lane + 1)
                if (mstr_rdata[lane*32 +: 32] !==
                    32'hcafe_1000 + lane - 1)
                    $fatal(1, "first split AXI R lane mismatch");
            @(negedge aclk);
            mstr_rready = 1;
            @(posedge aclk);
            @(negedge aclk);
            mstr_rready = 0;
            @(posedge aclk);
            if (!mstr_rvalid || !mstr_rlast ||
                mstr_rresp !== 2'b00)
                $fatal(1, "last split AXI R status mismatch");
            for (lane = 0; lane < 8; lane = lane + 1)
                if (mstr_rdata[lane*32 +: 32] !==
                    32'hcafe_1007 + lane)
                    $fatal(1, "last split AXI R lane mismatch");
            @(negedge aclk);
            mstr_rready = 1;
            @(posedge aclk);
            @(negedge aclk);
            mstr_rready = 0;
        end
    endtask

    task automatic check_last_byte_read;
        reg [255:0] header, payload;
        begin
            @(negedge aclk);
            mstr_araddr = 64'h203f;
            mstr_arlen = 0;
            mstr_arvalid = 1;
            do @(posedge aclk); while (!mstr_arready);
            @(negedge aclk);
            mstr_arvalid = 0;
            do @(posedge aclk); while (!axis_cq_tvalid);
            if (axis_cq_tdata[74:64] !== 11'd1 ||
                axis_cq_tuser[7:0] !== 8'h08)
                $fatal(1, "one-byte read descriptor mismatch");
            header = 0;
            header[6:0] = 7'h3f;
            header[28:16] = 13'd1;
            header[42:32] = 11'd1;
            header[63:48] = 16'h0200;
            send_cc(header, 8'h07, 0);
            payload = 0;
            payload[255:224] = 32'hcafe_ffff;
            send_cc(payload, 8'hff, 1);
            do @(posedge aclk); while (!mstr_rvalid);
            if (!mstr_rlast || mstr_rresp !== 2'b00 ||
                mstr_rdata[255:224] !== 32'hcafe_ffff)
                $fatal(1, "one-byte read response mismatch");
            @(negedge aclk);
            mstr_rready = 1;
            @(posedge aclk);
            @(negedge aclk);
            mstr_rready = 0;
        end
    endtask

    initial begin
        log_fd = $fopen("tmp/axim_alignment_transactions.log", "w");
        if (!log_fd) $fatal(1, "cannot open alignment transaction log");
        $dumpfile("tmp/axim_alignment_tb.vcd");
        $dumpvars(0, axim_alignment_tb);
        repeat (3) @(negedge aclk);
        aresetn = 1;
        check_write(64'h1003, 0, 32'h0000_00f8, 0,
                    11'd2, 8'hf8);
        check_write(64'h101c, 1, 32'hf000_0000, 32'h0000_003f,
                    11'd3, 8'h3f);
        check_write(64'h103f, 0, 32'h8000_0000, 0,
                    11'd1, 8'h08);
        // Seven Dwords fit exactly in the first payload beat; eight spill.
        check_write(64'h1100, 0, 32'h0fff_ffff, 0, 11'd7, 8'hff);
        check_write(64'h1100, 0, 32'hffff_ffff, 0, 11'd8, 8'hff);
        // Figure 26: 7 + 8 + 6 Dwords, ending with keep=0x3f.
        check_write(64'h1104, 2, 32'hffff_fff0, 32'h00ff_ffff,
                    11'd21, 8'hff);
        check_write(64'h1400, 31, 32'hffff_ffff, 32'hffff_ffff,
                    11'd256, 8'hff);
        // All AXI byte offsets, with randomized data and varying burst lengths.
        for (i = 0; i < 32; i = i + 1)
            check_write(64'h1800 + ($urandom_range(0, 7) << 5) + i,
                        i % 4, 32'hffff_ffff << i, 32'hffff_ffff,
                        ((i % 4) + 1)*8 - (i/4),
                        (i == 28 ? 8'h0f : (8'hf0 | (4'hf << (i%4)))));
        check_read();
        check_split_read();
        check_last_byte_read();
        $fclose(log_fd);
        $display("ALIGNMENT TEST PASSED");
        $finish;
    end

    initial begin
        #50000;
        $fatal(1, "alignment test timeout");
    end
endmodule
