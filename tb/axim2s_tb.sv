`timescale 1ns/1ps

module axim2s_tb;
    localparam ID_W = 6;
    localparam DATA_W = 256;

    reg aclk = 1'b0;
    reg aresetn = 1'b0;
    always #5 aclk = ~aclk;

    reg [ID_W-1:0] mstr_awid;
    reg [63:0] mstr_awaddr;
    reg [7:0] mstr_awlen;
    reg [2:0] mstr_awsize;
    reg [1:0] mstr_awburst;
    reg [3:0] mstr_awlock;
    reg [3:0] mstr_awcache;
    reg [2:0] mstr_awprot;
    reg [3:0] mstr_awqos;
    reg [49:0] mstr_awmisc_info;
    reg [63:0] mstr_awmisc_info_hdr_34dw;
    reg [1:0] mstr_awmisc_info_fmt;
    reg [9:0] mstr_awmisc_info_dwlen;
    reg mstr_awmisc_info_ep;
    reg mstr_awmisc_info_last_dcmp_tlp;
    reg [1:0] mstr_awmisc_info_ats;
    reg mstr_awmisc_info_nw;
    reg [2:0] mstr_awmisc_info_func_num;
    reg [7:0] mstr_awmisc_info_vfunc_num;
    reg mstr_awmisc_info_vfunc_active;
    reg [10:0] mstr_awmisc_info_tph;
    reg mstr_awmisc_info_ido;
    wire mstr_awready;
    reg mstr_awvalid;

    reg mstr_wvalid;
    reg mstr_wlast;
    reg [DATA_W-1:0] mstr_wdata;
    reg [31:0] mstr_wstrb;
    wire mstr_wready;

    wire [ID_W-1:0] mstr_bid;
    wire mstr_bvalid;
    wire [1:0] mstr_bresp;
    wire [2:0] mstr_bmisc_info_cpl_stat;
    reg mstr_bready;

    reg [ID_W-1:0] mstr_arid;
    reg mstr_arvalid;
    reg [63:0] mstr_araddr;
    reg [7:0] mstr_arlen;
    reg [2:0] mstr_arsize;
    reg [1:0] mstr_arburst;
    reg [3:0] mstr_arlock;
    reg [3:0] mstr_arqos;
    reg [3:0] mstr_arcache;
    reg [2:0] mstr_arprot;
    reg [49:0] mstr_armisc_info;
    reg mstr_armisc_info_last_dcmp_tlp;
    reg mstr_armisc_info_nw;
    reg [1:0] mstr_armisc_info_ats;
    reg [2:0] mstr_armisc_info_func_num;
    reg [7:0] mstr_armisc_info_vfunc_num;
    reg mstr_armisc_info_vfunc_active;
    reg [10:0] mstr_armisc_info_tph;
    reg mstr_armisc_info_ido;
    reg mstr_armisc_info_zeroread;
    wire mstr_arready;

    wire [ID_W-1:0] mstr_rid;
    wire mstr_rvalid;
    wire mstr_rlast;
    wire [DATA_W-1:0] mstr_rdata;
    wire [1:0] mstr_rresp;
    wire [12:0] mstr_rmisc_info;
    wire [2:0] mstr_rmisc_info_cpl_stat;
    reg mstr_rready;

    wire [DATA_W-1:0] axis_cq_tdata;
    wire [7:0] axis_cq_tkeep;
    wire axis_cq_tlast;
    reg axis_cq_tready;
    wire [84:0] axis_cq_tuser;
    wire axis_cq_tvalid;

    reg [DATA_W-1:0] axis_cc_tdata;
    reg [7:0] axis_cc_tkeep;
    reg axis_cc_tlast;
    wire axis_cc_tready;
    reg [32:0] axis_cc_tuser;
    reg axis_cc_tvalid;

    axim2s dut (.*);

    integer log_fd;
    integer errors = 0;
    integer axi_txn = 0;
    integer random_seed;
    integer regression_index;
    reg cq_in_packet = 1'b0;
    reg cc_in_packet = 1'b0;

    function automatic [31:0] payload_dw(input integer txn, input integer index);
        payload_dw = 32'hd000_0000 ^ (txn << 16) ^ index;
    endfunction

    function automatic [255:0] payload_beat(input integer txn, input integer beat);
        integer lane;
        begin
            for (lane = 0; lane < 8; lane = lane + 1)
                payload_beat[lane*32 +: 32] = payload_dw(txn, beat*8 + lane);
        end
    endfunction

    task automatic fail(input string message);
        begin
            errors = errors + 1;
            $display("ERROR @ %0t: %s", $time, message);
        end
    endtask

    task automatic check(input bit condition, input string message);
        if (!condition) fail(message);
    endtask

    task automatic set_write_sideband(input integer txn, input bit use_vf);
        begin
            mstr_awmisc_info = '0;
            mstr_awmisc_info[47:40] = 8'h40 + txn;
            mstr_awmisc_info[39:24] = 16'h1200 + txn;
            mstr_awmisc_info[18:16] = txn[2:0];
            mstr_awmisc_info[15:14] = txn[1:0];
            mstr_awmisc_info[8:6] = (txn + 1) & 3'h7;
            mstr_awmisc_info_ats = txn[1:0];
            mstr_awmisc_info_func_num = txn[2:0];
            mstr_awmisc_info_vfunc_num = txn + 3;
            mstr_awmisc_info_vfunc_active = use_vf;
            mstr_awmisc_info_tph = 11'h155 ^ txn;
            mstr_awmisc_info_ido = txn[0];
        end
    endtask

    task automatic set_read_sideband(input integer txn, input bit use_vf);
        begin
            mstr_armisc_info = '0;
            mstr_armisc_info[47:40] = 8'h80 + txn;
            mstr_armisc_info[39:24] = 16'h3400 + txn;
            mstr_armisc_info[18:16] = txn[2:0];
            mstr_armisc_info[15:14] = txn[1:0];
            mstr_armisc_info[8:6] = (txn + 2) & 3'h7;
            mstr_armisc_info_ats = txn[1:0];
            mstr_armisc_info_func_num = txn[2:0];
            mstr_armisc_info_vfunc_num = txn + 5;
            mstr_armisc_info_vfunc_active = use_vf;
            mstr_armisc_info_tph = 11'h2aa ^ txn;
            mstr_armisc_info_ido = ~txn[0];
        end
    endtask

    task automatic drive_aw(input integer txn, input integer beats,
                            input [63:0] addr, input integer delay_cycles,
                            input bit use_vf);
        integer n;
        begin
            for (n = 0; n < delay_cycles; n = n + 1) @(posedge aclk);
            @(negedge aclk);
            mstr_awid = txn[ID_W-1:0];
            mstr_awaddr = addr;
            mstr_awlen = beats - 1;
            set_write_sideband(txn, use_vf);
            mstr_awvalid = 1'b1;
            do @(posedge aclk); while (!mstr_awready);
            @(negedge aclk);
            mstr_awvalid = 1'b0;
        end
    endtask

    task automatic drive_w(input integer txn, input integer beats,
                           input integer initial_delay, input bit random_gaps);
        integer beat;
        integer n;
        begin
            for (n = 0; n < initial_delay; n = n + 1) @(posedge aclk);
            for (beat = 0; beat < beats; beat = beat + 1) begin
                if (random_gaps && beat != 0) begin
                    n = $urandom_range(0, 2);
                    repeat (n) @(posedge aclk);
                end
                @(negedge aclk);
                mstr_wdata = payload_beat(txn, beat);
                mstr_wlast = (beat == beats-1);
                mstr_wvalid = 1'b1;
                do @(posedge aclk); while (!mstr_wready);
                @(negedge aclk);
                mstr_wvalid = 1'b0;
            end
        end
    endtask

    task automatic expect_cq_header(input bit is_write, input integer txn,
                                    input integer beats, input [63:0] addr,
                                    input bit use_vf);
        reg [127:0] desc;
        reg [7:0] expected_function;
        reg [10:0] expected_tph;
        begin
            do @(posedge aclk); while (!(axis_cq_tvalid && axis_cq_tready));
            desc = axis_cq_tdata[127:0];
            expected_function = use_vf ? (8 + txn + (is_write ? 3 : 5)) : txn[2:0];
            expected_tph = (is_write ? 11'h155 : 11'h2aa) ^ txn;
            check(axis_cq_tkeep == 8'h0f, "CQ descriptor keep must mark four descriptor DWs");
            check(axis_cq_tuser[40], "CQ descriptor must assert SOP");
            check(axis_cq_tuser[7:0] == 8'hff, "CQ first/last byte enable mismatch");
            check({axis_cq_tuser[52:45], axis_cq_tuser[44:43], axis_cq_tuser[42]} == expected_tph,
                  "CQ TPH sideband mismatch");
            check(desc[78:75] == (is_write ? 4'b0001 : 4'b0000), "CQ request type mismatch");
            check(desc[63:2] == addr[63:2], "CQ address mismatch");
            check(desc[74:64] == beats*8, "CQ DW count mismatch");
            check(desc[1:0] == txn[1:0], "CQ address type mismatch");
            check(desc[103:96] == (is_write ? 8'h40+txn : 8'h80+txn), "CQ Tag mismatch");
            check(desc[95:80] == (is_write ? 16'h1200+txn : 16'h3400+txn), "CQ Requester ID mismatch");
            check(desc[111:104] == expected_function, "CQ target function mismatch");
            check(desc[114:112] == ((txn + (is_write ? 1 : 2)) & 3'h7), "CQ traffic type mismatch");
            check(desc[123:121] == txn[2:0], "CQ traffic class mismatch");
            check(desc[126:124] == {is_write ? txn[0] : ~txn[0], txn[1:0]}, "CQ attributes mismatch");
            check(axis_cq_tlast == !is_write, "CQ descriptor tlast mismatch");
        end
    endtask

    task automatic check_simultaneous_grant(input bit expect_read);
        begin
            @(negedge aclk);
            mstr_awvalid = 1'b1;
            mstr_arvalid = 1'b1;
            #1;
            check(mstr_awready == !expect_read, "simultaneous AW/AR write grant mismatch");
            check(mstr_arready == expect_read, "simultaneous AW/AR read grant mismatch");
            mstr_awvalid = 1'b0;
            mstr_arvalid = 1'b0;
        end
    endtask

    task automatic expect_cq_write_data(input integer txn, input integer beats);
        integer beat;
        begin
            for (beat = 0; beat < beats; beat = beat + 1) begin
                do @(posedge aclk); while (!(axis_cq_tvalid && axis_cq_tready));
                check(axis_cq_tdata === payload_beat(txn, beat), "CQ write payload mismatch");
                check(axis_cq_tkeep == 8'hff, "CQ payload keep mismatch");
                check(axis_cq_tuser[39:8] == 32'hffff_ffff, "CQ payload byte enable mismatch");
                check(axis_cq_tlast == (beat == beats-1), "CQ payload tlast mismatch");
            end
        end
    endtask

    task automatic finish_b(input integer txn, input integer stall_cycles);
        integer n;
        begin
            mstr_bready = 1'b0;
            do @(posedge aclk); while (!mstr_bvalid);
            for (n = 0; n < stall_cycles; n = n + 1) @(posedge aclk);
            check(mstr_bid == txn[ID_W-1:0], "B ID mismatch");
            check(mstr_bresp == 2'b00, "B response is not OKAY");
            check(mstr_bmisc_info_cpl_stat == 3'b000, "B completion status mismatch");
            @(negedge aclk); mstr_bready = 1'b1;
            @(posedge aclk);
            @(negedge aclk); mstr_bready = 1'b0;
        end
    endtask

    task automatic run_write(input integer txn, input integer beats,
                             input [63:0] addr, input bit w_before_aw,
                             input bit use_vf);
        begin
            $display("WRITE txn=%0d beats=%0d addr=%h", txn, beats, addr);
            fork
                drive_aw(txn, beats, addr, w_before_aw ? 3 : 0, use_vf);
                drive_w(txn, beats, w_before_aw ? 0 : 2, 1'b1);
                begin
                    expect_cq_header(1'b1, txn, beats, addr, use_vf);
                    expect_cq_write_data(txn, beats);
                end
            join
            finish_b(txn, 2);
        end
    endtask

    task automatic drive_ar(input integer txn, input integer beats,
                            input [63:0] addr, input bit use_vf);
        begin
            @(negedge aclk);
            mstr_arid = txn[ID_W-1:0];
            mstr_araddr = addr;
            mstr_arlen = beats - 1;
            set_read_sideband(txn, use_vf);
            mstr_arvalid = 1'b1;
            do @(posedge aclk); while (!mstr_arready);
            @(negedge aclk);
            mstr_arvalid = 1'b0;
        end
    endtask

    task automatic send_cc_beat(input [255:0] data, input [7:0] keep,
                                input bit last, input integer gap_cycles);
        integer n;
        begin
            for (n = 0; n < gap_cycles; n = n + 1) @(posedge aclk);
            @(negedge aclk);
            axis_cc_tdata = data;
            axis_cc_tkeep = keep;
            axis_cc_tlast = last;
            axis_cc_tvalid = 1'b1;
            do @(posedge aclk); while (!axis_cc_tready);
            @(negedge aclk);
            axis_cc_tvalid = 1'b0;
        end
    endtask

    task automatic send_completion(input integer txn, input integer total_beats,
                                    input integer start_dw, input integer count_dw,
                                    input [2:0] status, input bit poison);
        reg [255:0] desc;
        reg [255:0] data;
        reg [7:0] keep;
        integer offset;
        integer lane;
        integer this_dw;
        begin
            desc = '0;
            desc[6:0] = start_dw*4;
            desc[28:16] = total_beats*32 - start_dw*4;
            desc[42:32] = count_dw;
            desc[45:43] = status;
            desc[46] = poison;
            desc[63:48] = 16'h3400 + txn;
            desc[71:64] = 8'h80 + txn;
            send_cc_beat(desc, 8'h07, status != 3'b000, $urandom_range(0, 2));
            if (status == 3'b000) begin
                offset = 0;
                while (offset < count_dw) begin
                    data = '0;
                    keep = '0;
                    this_dw = ((count_dw-offset) > 8) ? 8 : (count_dw-offset);
                    for (lane = 0; lane < this_dw; lane = lane + 1) begin
                        data[lane*32 +: 32] = payload_dw(txn, start_dw+offset+lane);
                        keep[lane] = 1'b1;
                    end
                    send_cc_beat(data, keep, (offset+this_dw == count_dw),
                                 $urandom_range(0, 2));
                    offset = offset + this_dw;
                end
            end
        end
    endtask

    task automatic collect_r(input integer txn, input integer beats,
                             input [1:0] expected_resp,
                             input [2:0] expected_status,
                             input bit expected_poison);
        integer beat;
        integer stall;
        begin
            mstr_rready = 1'b0;
            for (beat = 0; beat < beats; beat = beat + 1) begin
                do @(posedge aclk); while (!mstr_rvalid);
                stall = $urandom_range(0, 3);
                repeat (stall) @(posedge aclk);
                check(mstr_rid == txn[ID_W-1:0], "R ID mismatch");
                check(mstr_rresp == expected_resp, "R response mismatch");
                check(mstr_rmisc_info_cpl_stat == expected_status, "R completion status mismatch");
                check(mstr_rmisc_info[7] == expected_poison, "R poison flag mismatch");
                check(mstr_rlast == (beat == beats-1), "R last mismatch");
                if (expected_resp == 2'b00)
                    check(mstr_rdata === payload_beat(txn, beat), "R payload mismatch");
                @(negedge aclk); mstr_rready = 1'b1;
                @(posedge aclk);
                @(negedge aclk); mstr_rready = 1'b0;
            end
        end
    endtask

    task automatic run_read(input integer txn, input integer beats,
                            input [63:0] addr, input integer split_dw,
                            input bit use_vf, input bit poison);
        integer total_dw;
        begin
            total_dw = beats*8;
            $display("READ txn=%0d beats=%0d addr=%h split_dw=%0d", txn, beats, addr, split_dw);
            fork
                drive_ar(txn, beats, addr, use_vf);
                expect_cq_header(1'b0, txn, beats, addr, use_vf);
            join
            if (split_dw > 0 && split_dw < total_dw) begin
                send_completion(txn, beats, 0, split_dw, 3'b000, poison);
                send_completion(txn, beats, split_dw, total_dw-split_dw, 3'b000, 1'b0);
            end else begin
                send_completion(txn, beats, 0, total_dw, 3'b000, poison);
            end
            collect_r(txn, beats, 2'b00, 3'b000, poison);
        end
    endtask

    task automatic run_error_read(input integer txn, input [2:0] status,
                                  input [1:0] response);
        reg [63:0] addr;
        begin
            addr = 64'h0000_0000_6000_0000 + txn*32;
            fork
                drive_ar(txn, 1, addr, 1'b0);
                expect_cq_header(1'b0, txn, 1, addr, 1'b0);
            join
            send_completion(txn, 1, 0, 0, status, 1'b0);
            collect_r(txn, 1, response, status, 1'b0);
        end
    endtask

    task automatic reset_dut;
        begin
            aresetn = 1'b0;
            repeat (4) @(posedge aclk);
            @(negedge aclk); aresetn = 1'b1;
            repeat (2) @(posedge aclk);
        end
    endtask

    // Transaction logger.  Each entry is emitted only for a valid handshake.
    always @(posedge aclk) begin
        if (aresetn) begin
            if (mstr_awvalid && mstr_awready)
                $fdisplay(log_fd, "%0t AXI_AW id=%0d addr=%h beats=%0d tag=%02h requester=%04h function=%0d",
                          $time, mstr_awid, mstr_awaddr, mstr_awlen+1,
                          mstr_awmisc_info[47:40], mstr_awmisc_info[39:24],
                          mstr_awmisc_info_vfunc_active ? 8+mstr_awmisc_info_vfunc_num : mstr_awmisc_info_func_num);
            if (mstr_wvalid && mstr_wready)
                $fdisplay(log_fd, "%0t AXI_W last=%0b strb=%h data=%h", $time, mstr_wlast, mstr_wstrb, mstr_wdata);
            if (mstr_arvalid && mstr_arready)
                $fdisplay(log_fd, "%0t AXI_AR id=%0d addr=%h beats=%0d tag=%02h requester=%04h function=%0d",
                          $time, mstr_arid, mstr_araddr, mstr_arlen+1,
                          mstr_armisc_info[47:40], mstr_armisc_info[39:24],
                          mstr_armisc_info_vfunc_active ? 8+mstr_armisc_info_vfunc_num : mstr_armisc_info_func_num);
            if (mstr_bvalid && mstr_bready)
                $fdisplay(log_fd, "%0t AXI_B id=%0d resp=%0d pcie_status=%0d", $time, mstr_bid, mstr_bresp, mstr_bmisc_info_cpl_stat);
            if (mstr_rvalid && mstr_rready)
                $fdisplay(log_fd, "%0t AXI_R id=%0d resp=%0d pcie_status=%0d poison=%0b last=%0b data=%h",
                          $time, mstr_rid, mstr_rresp, mstr_rmisc_info_cpl_stat, mstr_rmisc_info[7], mstr_rlast, mstr_rdata);
            if (axis_cq_tvalid && axis_cq_tready) begin
                if (!cq_in_packet)
                    $fdisplay(log_fd, "%0t CQ_DESC type=%s addr=%h dw_count=%0d requester=%04h tag=%02h function=%0d tc=%0d attr=%0d ats=%0d last=%0b",
                              $time, axis_cq_tdata[78:75] == 4'b0001 ? "Memory Write" : "Memory Read",
                              {axis_cq_tdata[63:2],2'b00}, axis_cq_tdata[74:64], axis_cq_tdata[95:80],
                              axis_cq_tdata[103:96], axis_cq_tdata[111:104], axis_cq_tdata[123:121],
                              axis_cq_tdata[126:124], axis_cq_tdata[1:0], axis_cq_tlast);
                else
                    $fdisplay(log_fd, "%0t CQ_PAYLOAD keep=%h byte_enable=%h last=%0b data=%h",
                              $time, axis_cq_tkeep, axis_cq_tuser[39:8], axis_cq_tlast, axis_cq_tdata);
                cq_in_packet <= !axis_cq_tlast;
            end
            if (axis_cc_tvalid && axis_cc_tready) begin
                if (!cc_in_packet)
                    $fdisplay(log_fd, "%0t CC_DESC type=Completion lower_addr=%0d byte_count=%0d dw_count=%0d status=%0d requester=%04h tag=%02h poison=%0b last=%0b",
                              $time, axis_cc_tdata[6:0], axis_cc_tdata[28:16], axis_cc_tdata[42:32],
                              axis_cc_tdata[45:43], axis_cc_tdata[63:48], axis_cc_tdata[71:64],
                              axis_cc_tdata[46], axis_cc_tlast);
                else
                    $fdisplay(log_fd, "%0t CC_PAYLOAD keep=%h last=%0b data=%h", $time, axis_cc_tkeep, axis_cc_tlast, axis_cc_tdata);
                cc_in_packet <= !axis_cc_tlast;
            end
        end else begin
            cq_in_packet <= 1'b0;
            cc_in_packet <= 1'b0;
        end
    end

    reg cq_stalled;
    reg [255:0] cq_hold_data;
    reg [7:0] cq_hold_keep;
    reg cq_hold_last;
    reg [84:0] cq_hold_user;
    reg b_stalled;
    reg [ID_W-1:0] b_hold_id;
    reg [1:0] b_hold_resp;
    reg [2:0] b_hold_status;
    reg r_stalled;
    reg [ID_W-1:0] r_hold_id;
    reg [255:0] r_hold_data;
    reg [1:0] r_hold_resp;
    reg [2:0] r_hold_status;
    reg r_hold_last;

    always @(posedge aclk) begin
        if (!aresetn) begin
            cq_stalled <= 1'b0;
            b_stalled <= 1'b0;
            r_stalled <= 1'b0;
        end else begin
            if (cq_stalled)
                check(axis_cq_tvalid && axis_cq_tdata === cq_hold_data &&
                      axis_cq_tkeep === cq_hold_keep && axis_cq_tlast === cq_hold_last &&
                      axis_cq_tuser === cq_hold_user, "CQ changed while stalled");
            cq_stalled <= axis_cq_tvalid && !axis_cq_tready;
            cq_hold_data <= axis_cq_tdata;
            cq_hold_keep <= axis_cq_tkeep;
            cq_hold_last <= axis_cq_tlast;
            cq_hold_user <= axis_cq_tuser;

            if (b_stalled)
                check(mstr_bvalid && mstr_bid === b_hold_id && mstr_bresp === b_hold_resp &&
                      mstr_bmisc_info_cpl_stat === b_hold_status, "B changed while stalled");
            b_stalled <= mstr_bvalid && !mstr_bready;
            b_hold_id <= mstr_bid;
            b_hold_resp <= mstr_bresp;
            b_hold_status <= mstr_bmisc_info_cpl_stat;

            if (r_stalled)
                check(mstr_rvalid && mstr_rid === r_hold_id && mstr_rdata === r_hold_data &&
                      mstr_rresp === r_hold_resp && mstr_rmisc_info_cpl_stat === r_hold_status &&
                      mstr_rlast === r_hold_last, "R changed while stalled");
            r_stalled <= mstr_rvalid && !mstr_rready;
            r_hold_id <= mstr_rid;
            r_hold_data <= mstr_rdata;
            r_hold_resp <= mstr_rresp;
            r_hold_status <= mstr_rmisc_info_cpl_stat;
            r_hold_last <= mstr_rlast;
        end
    end

    // Random CQ backpressure is enabled throughout active testing.
    always @(negedge aclk) begin
        if (!aresetn)
            axis_cq_tready <= 1'b0;
        else
            axis_cq_tready <= $urandom_range(0, 1);
    end

    initial begin
        mstr_awid = '0; mstr_awaddr = '0; mstr_awlen = '0; mstr_awsize = 3'd5;
        mstr_awburst = 2'b01; mstr_awlock = '0; mstr_awcache = '0; mstr_awprot = '0;
        mstr_awqos = '0; mstr_awmisc_info = '0; mstr_awmisc_info_hdr_34dw = '0;
        mstr_awmisc_info_fmt = '0; mstr_awmisc_info_dwlen = '0; mstr_awmisc_info_ep = 1'b0;
        mstr_awmisc_info_last_dcmp_tlp = 1'b0; mstr_awmisc_info_ats = '0;
        mstr_awmisc_info_nw = 1'b0; mstr_awmisc_info_func_num = '0;
        mstr_awmisc_info_vfunc_num = '0; mstr_awmisc_info_vfunc_active = 1'b0;
        mstr_awmisc_info_tph = '0; mstr_awmisc_info_ido = 1'b0; mstr_awvalid = 1'b0;
        mstr_wvalid = 1'b0; mstr_wlast = 1'b0; mstr_wdata = '0; mstr_wstrb = '1;
        mstr_bready = 1'b0;
        mstr_arid = '0; mstr_arvalid = 1'b0; mstr_araddr = '0; mstr_arlen = '0;
        mstr_arsize = 3'd5; mstr_arburst = 2'b01; mstr_arlock = '0; mstr_arqos = '0;
        mstr_arcache = '0; mstr_arprot = '0; mstr_armisc_info = '0;
        mstr_armisc_info_last_dcmp_tlp = 1'b0; mstr_armisc_info_nw = 1'b0;
        mstr_armisc_info_ats = '0; mstr_armisc_info_func_num = '0;
        mstr_armisc_info_vfunc_num = '0; mstr_armisc_info_vfunc_active = 1'b0;
        mstr_armisc_info_tph = '0; mstr_armisc_info_ido = 1'b0;
        mstr_armisc_info_zeroread = 1'b0; mstr_rready = 1'b0;
        axis_cq_tready = 1'b0; axis_cc_tdata = '0; axis_cc_tkeep = '0;
        axis_cc_tlast = 1'b0; axis_cc_tuser = '0; axis_cc_tvalid = 1'b0;

        log_fd = $fopen("tmp/transactions.log", "w");
        if (!log_fd) $fatal(1, "cannot open transaction log");
        $dumpfile("tmp/axim2s_tb.vcd");
        $dumpvars(0, axim2s_tb);
        random_seed = 32'h1a2b3c4d;
        random_seed = $urandom(random_seed);
        $fdisplay(log_fd, "RANDOM_SEED=%08h", random_seed);

        reset_dut();
        check(!axis_cq_tvalid && !mstr_bvalid && !mstr_rvalid, "outputs valid after reset");

        run_write(1, 1, 64'h0000_0000_1000_0020, 1'b1, 1'b0);
        run_write(2, 4, 64'h0000_0000_2000_0040, 1'b0, 1'b1);
        run_read(3, 1, 64'h0000_0000_3000_0060, 0, 1'b0, 1'b0);
        run_read(4, 3, 64'h0000_0000_4000_0080, 8, 1'b1, 1'b1);
        run_error_read(5, 3'b001, 2'b11);
        run_error_read(6, 3'b100, 2'b10);

        // Discard a partially collected write with reset, then prove recovery.
        fork
            drive_aw(7, 3, 64'h0000_0000_7000_0000, 0, 1'b0);
            begin
                @(posedge mstr_wready);
                @(negedge aclk);
                mstr_wdata = payload_beat(7, 0);
                mstr_wvalid = 1'b1;
                @(posedge aclk);
                @(negedge aclk);
                mstr_wvalid = 1'b0;
            end
        join
        @(negedge aclk); aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1'b1;
        repeat (2) @(posedge aclk);
        run_write(8, 2, 64'h0000_0000_8000_0000, 1'b0, 1'b0);
        check_simultaneous_grant(1'b1);

        // Small randomized regression with several transactions per case.
        run_write(9, $urandom_range(1, 6), 64'h0000_0000_9000_0000 + ($urandom_range(0,31) << 5), 1'b1, 1'b1);
        check_simultaneous_grant(1'b1);
        run_read(10, 2, 64'h0000_0000_a000_0000 + ($urandom_range(0,31) << 5), 8, 1'b0, 1'b0);
        check_simultaneous_grant(1'b0);
        for (regression_index = 11; regression_index < 17; regression_index = regression_index + 1) begin
            if (regression_index[0])
                run_write(regression_index, $urandom_range(1, 6),
                          64'h0000_0000_b000_0000 + ($urandom_range(0,255) << 5),
                          $urandom_range(0,1), $urandom_range(0,1));
            else
                run_read(regression_index, $urandom_range(1, 4),
                         64'h0000_0000_c000_0000 + ($urandom_range(0,255) << 5),
                         0, $urandom_range(0,1), $urandom_range(0,1));
        end

        repeat (5) @(posedge aclk);
        $fclose(log_fd);
        if (errors == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "TEST FAILED with %0d errors", errors);
        end
    end

    initial begin
        #200000;
        $fatal(1, "simulation timeout");
    end
endmodule
