module axim2s 
#(
    // AMBA-specific AXI4 parameters
    parameter MSTR_ID_WD                = 6,   //`CC_MSTR_BUS_ID_WIDTH;
    parameter MSTR_DATA_WD              = 256, //`MASTER_BUS_DATA_WIDTH;
    parameter MSTR_WSTRB_WD             = 32,  //`MSTR_BUS_WSTRB_WIDTH;
    parameter MSTR_RESP_MISC_INFO_PW    = 13,//`MSTR_RESP_MISC_INFO_PW;
    parameter MSTR_ADDR_WD              = 64, //`MASTER_BUS_ADDR_WIDTH;
    parameter MSTR_BURST_LEN_PW         =  8,//`CC_MSTR_BURST_LEN_PW;
    parameter MSTR_MISC_INFO_PW         = 50,//`MSTR_MISC_INFO_PW;
    parameter PF_WD = 3,
    parameter VF_WD = 9,

    // axi string interface configuration
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 185,
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81
)
(
    // common 
    input                                        aclk,
    input                                        aresetn,
    // AXI master write request
    input [MSTR_ID_WD-1:0]                       mstr_awid,
    input                                        mstr_awvalid,
    input [MSTR_ADDR_WD-1:0]                     mstr_awaddr,
    input [MSTR_BURST_LEN_PW-1:0]                mstr_awlen,
    input [2:0]                                  mstr_awsize,
    input [1:0]                                  mstr_awburst,
    input                                        mstr_awlock,
    input [3:0]                                  mstr_awqos,
    input [3:0]                                  mstr_awcache,
    input [2:0]                                  mstr_awprot,
    input [MSTR_MISC_INFO_PW-1:0]                mstr_awmisc_info,
    input [63:0]                                 mstr_awmisc_info_hdr_34dw,
    input [1:0]                                  mstr_awmisc_info_fmt,
    input [9:0]                                  mstr_awmisc_info_dwlen,
    input                                        mstr_awmisc_info_ep,
    input                                        mstr_awmisc_info_last_dcmp_tlp,
    input                                        mstr_awmisc_info_nw,
    input [1:0]                                  mstr_awmisc_info_ats,
    input [PF_WD-1:0]                            mstr_awmisc_info_func_num,
    input [VF_WD-2:0]                            mstr_awmisc_info_vfunc_num,
    input                                        mstr_awmisc_info_vfunc_active,
    input [10:0]                                 mstr_awmisc_info_tph,
    input                                        mstr_awmisc_info_ido,

    output                                       mstr_awready,

    // AXI master write data         
    input                                         mstr_wvalid,
    input                                         mstr_wlast,
    input [MSTR_DATA_WD-1:0]                      mstr_wdata,
    input [MSTR_WSTRB_WD-1:0]                     mstr_wstrb,
    output                                        mstr_wready,

    // AXI master write response         
    output  [MSTR_ID_WD-1:0]                      mstr_bid,
    output                                        mstr_bvalid,
    output  [`CC_AXIJ_DMWR_VALUE +1:0]            mstr_bresp,
    output  [2:0]                                 mstr_bmisc_info_cpl_stat,
    input                                         mstr_bready,

    // AXI master read request
    input [MSTR_ID_WD-1:0]                        mstr_arid,
    input                                         mstr_arvalid,
    input [MSTR_ADDR_WD-1:0]                      mstr_araddr,
    input [MSTR_BURST_LEN_PW-1:0]                 mstr_arlen,
    input [2:0]                                   mstr_arsize,
    input [1:0]                                   mstr_arburst,
    input                                         mstr_arlock,
    input [3:0]                                   mstr_arqos,
    input [3:0]                                   mstr_arcache,
    input [2:0]                                   mstr_arprot,
    input [MSTR_MISC_INFO_PW-1:0]                 mstr_armisc_info,
    input                                         mstr_armisc_info_last_dcmp_tlp,
    input                                         mstr_armisc_info_nw,
    input [1:0]                                   mstr_armisc_info_ats,
    input [PF_WD-1:0]                             mstr_armisc_info_func_num,
    input [VF_WD-2:0]                             mstr_armisc_info_vfunc_num,
    input                                         mstr_armisc_info_vfunc_active,
    input [10:0]                                  mstr_armisc_info_tph,
    input                                         mstr_armisc_info_ido,
    input                                         mstr_armisc_info_zeroread,
    output                                        mstr_arready,

    // AXI master read response & read data
    output  [MSTR_ID_WD-1:0]                      mstr_rid,
    output                                        mstr_rvalid,
    output                                        mstr_rlast,
    output  [MSTR_DATA_WD-1:0]                    mstr_rdata,
    output  [1:0]                                 mstr_rresp,
    output  [MSTR_RESP_MISC_INFO_PW-1:0]          mstr_rmisc_info,
    output  [2:0]                                 mstr_rmisc_info_cpl_stat,
    input                                        mstr_rready,
    
    // cq interface
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]       axis_cq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]       axis_cq_tkeep,
    output wire                                  axis_cq_tlast,
    input  wire                                  axis_cq_tready,
    output wire [AXIS_PCIE_CQ_USER_WIDTH-1:0]    axis_cq_tuser,
    output wire                                  axis_cq_tvalid,

    // cc interface
    input wire [AXIS_PCIE_DATA_WIDTH-1:0]        axis_cc_tdata,
    input wire [AXIS_PCIE_KEEP_WIDTH-1:0]        axis_cc_tkeep,
    input wire                                   axis_cc_tlast,
    output wire                                  axis_cc_tready,
    input wire [AXIS_PCIE_CC_USER_WIDTH-1:0]     axis_cc_tuser,
    input wire                                   axis_cc_tvalid

);

// 256-bit CQ Dword-aligned packets, full-width AXI INCR bursts.
// All counters below count AXI beats or Dwords, never encoded LEN values.
localparam [3:0] ST_IDLE = 0, ST_WRITE = 1, ST_CQ_HEAD = 2,
                 ST_CQ_DATA = 3, ST_CC_HEAD = 4, ST_CC_DATA = 5,
                 ST_CC_DROP = 6, ST_B = 7, ST_R = 8;
// Independent write/read slots; only complete CQ packets share arbitration.
reg [3:0] cq_state, write_state, read_state;
reg prefer_read;
reg request_write;
// request_* stores the write slot; read_* stores the independent read slot.
reg [MSTR_ID_WD-1:0] request_id;
reg [127:0] request_descriptor;
reg [10:0] request_tph;
reg [5:0] request_beats;
reg [8:0] request_dw;
reg [4:0] request_byte_lane;
reg [3:0] request_first_be, request_last_be;
reg [MSTR_ID_WD-1:0] read_id;
reg [127:0] read_descriptor;
reg [10:0] read_tph;
reg [5:0] read_beats;
reg [8:0] read_dw;
reg [4:0] read_byte_lane;
reg [3:0] read_first_be, read_last_be;
reg aw_seen, write_last_seen, write_error;
reg [5:0] write_count;
reg [8:0] send_dw;
reg [4:0] read_index;
reg [255:0] write_buffer [0:31];
reg [31:0] write_strobe [0:31];
reg [31:0] read_buffer [0:255];
reg read_poison [0:255];
reg [8:0] received_dw;
reg [10:0] packet_remaining_dw;
reg [2:0] packet_start_lane;
reg packet_poison;
reg [1:0] read_resp;
reg [2:0] read_status;
reg drop_foreign;

// A W-first transaction reserves only the write slot until its AW arrives.
wire aw_supported = mstr_awlen <= 31 && mstr_awsize == 5 &&
                    mstr_awburst == 2'b01 &&
                    mstr_awmisc_info[23:19] == 0 && !mstr_awmisc_info[9] &&
                    (!mstr_awmisc_info_vfunc_active ||
                     mstr_awmisc_info_vfunc_num <= 247);
wire ar_supported = mstr_arlen <= 31 && mstr_arsize == 5 &&
                    mstr_arburst == 2'b01 &&
                    mstr_armisc_info[23:19] == 0 && !mstr_armisc_info[9] &&
                    !mstr_armisc_info_zeroread &&
                    (!mstr_armisc_info_vfunc_active ||
                     mstr_armisc_info_vfunc_num <= 247);
wire write_pending = write_state == ST_CQ_HEAD;
wire read_pending = read_state == ST_CQ_HEAD;
wire grant_write = cq_state == ST_IDLE && write_pending &&
                   (!read_pending || !prefer_read);
wire grant_read = cq_state == ST_IDLE && read_pending &&
                  (!write_pending || prefer_read);
// Advertise an idle slot before VALID arrives. Otherwise a source that waits
// for READY before presenting its address can stall both address channels.
assign mstr_awready = (write_state == ST_IDLE ||
                      (write_state == ST_WRITE && !aw_seen)) &&
                      (!mstr_awvalid || aw_supported);
assign mstr_wready = (write_state == ST_IDLE || write_state == ST_WRITE) &&
                     !write_last_seen && write_count < 32 &&
                     (!aw_seen || write_count < request_beats);
assign mstr_arready = read_state == ST_IDLE &&
                      (!mstr_arvalid || ar_supported);
wire aw_fire = mstr_awvalid && mstr_awready;
wire w_fire = mstr_wvalid && mstr_wready;
wire ar_fire = mstr_arvalid && mstr_arready;
wire cq_fire = axis_cq_tvalid && axis_cq_tready;
wire cc_fire = axis_cc_tvalid && axis_cc_tready;

wire [7:0] aw_function = mstr_awmisc_info_vfunc_active ?
                        8'd8 + mstr_awmisc_info_vfunc_num :
                        mstr_awmisc_info_func_num;
wire [7:0] ar_function = mstr_armisc_info_vfunc_active ?
                        8'd8 + mstr_armisc_info_vfunc_num :
                        mstr_armisc_info_func_num;

reg [255:0] cq_data;
reg [7:0] cq_keep;
reg [84:0] cq_user;
reg [3:0] cq_payload_dw;
integer keep_lane, source_dw;
always @* begin
    cq_data = 256'b0;
    cq_keep = 8'b0;
    cq_user = 85'b0;
    cq_payload_dw = 0;
    source_dw = 0;
    if (cq_state == ST_CQ_HEAD) begin
        cq_data[127:0] = request_write ? request_descriptor : read_descriptor;
        cq_keep = 8'h0f;
        cq_user[7:0] = request_write ? {request_last_be, request_first_be} :
                                         {read_last_be, read_first_be};
        cq_user[40] = 1'b1;
        cq_user[42] = request_write ? request_tph[0] : read_tph[0];
        cq_user[44:43] = request_write ? request_tph[2:1] : read_tph[2:1];
        cq_user[52:45] = request_write ? request_tph[10:3] : read_tph[10:3];
    end
    if (request_write &&
        (cq_state == ST_CQ_HEAD || cq_state == ST_CQ_DATA)) begin
        // The descriptor occupies lanes 0..3; payload starts in lane 4.
        // Continuation beats carry payload from lane 0 without padding.
        // Read only payload Dwords, skipping the AXI address-alignment padding.
        for (keep_lane = 0; keep_lane < 8; keep_lane = keep_lane + 1) begin
            if ((cq_state == ST_CQ_DATA || keep_lane >= 4) &&
                send_dw + cq_payload_dw < request_dw) begin
                source_dw = {6'b0, request_byte_lane[4:2]} +
                            send_dw + cq_payload_dw;
                cq_data[keep_lane*32 +: 32] =
                    write_buffer[source_dw / 8][(source_dw % 8)*32 +: 32];
                cq_user[8 + keep_lane*4 +: 4] =
                    write_strobe[source_dw / 8][(source_dw % 8)*4 +: 4];
                cq_keep[keep_lane] = 1'b1;
                cq_payload_dw = cq_payload_dw + 1'b1;
            end
        end
    end
end
assign axis_cq_tdata = cq_data;
assign axis_cq_tkeep = cq_keep;
assign axis_cq_tuser = cq_user;
assign axis_cq_tvalid = cq_state == ST_CQ_HEAD || cq_state == ST_CQ_DATA;
assign axis_cq_tlast = (cq_state == ST_CQ_HEAD && !request_write) ||
                       (request_write &&
                        (cq_state == ST_CQ_HEAD || cq_state == ST_CQ_DATA) &&
                        send_dw + cq_payload_dw == request_dw);
assign axis_cc_tready = read_state == ST_CC_HEAD || read_state == ST_CC_DATA ||
                        read_state == ST_CC_DROP;

assign mstr_bid = request_id;
assign mstr_bvalid = write_state == ST_B;
// Assignment zero extends OKAY/SLVERR when the integration enables DMWR.
assign mstr_bresp = write_error ? 2'b10 : 2'b00;
assign mstr_bmisc_info_cpl_stat = write_error ? 3'b100 : 3'b000;
assign mstr_rid = read_id;
assign mstr_rvalid = read_state == ST_R;
assign mstr_rlast = read_state == ST_R &&
                    {1'b0, read_index} == read_beats - 6'd1;
assign mstr_rresp = read_resp;
assign mstr_rmisc_info_cpl_stat = read_status;

reg [255:0] rdata;
reg [MSTR_RESP_MISC_INFO_PW-1:0] rmisc;
integer rlane;
always @* begin
    rdata = 256'b0;
    rmisc = 0;
    if (read_state == ST_R && read_resp == 2'b00) begin
        for (rlane = 0; rlane < 8; rlane = rlane + 1) begin
            if (read_index != 0 || rlane >= read_byte_lane[4:2]) begin
                rdata[rlane*32 +: 32] = read_buffer[{read_index, 3'b0} + rlane];
                rmisc[7] = rmisc[7] |
                            read_poison[{read_index, 3'b0} + rlane];
            end
        end
    end
end
assign mstr_rdata = rdata;
assign mstr_rmisc_info = rmisc;

// Compact each address-aligned Completion payload into a full-request buffer.
// The first payload beat may start at any Dword lane after a split.
reg [3:0] payload_dw;
reg [10:0] remaining_next;
reg payload_bad;
integer clane;
always @* begin
    payload_dw = 0;
    remaining_next = packet_remaining_dw;
    payload_bad = 0;
    for (clane = 0; clane < 8; clane = clane + 1) begin
        if (clane >= packet_start_lane && remaining_next != 0) begin
            if (!axis_cc_tkeep[clane])
                payload_bad = 1;
            payload_dw = payload_dw + 1'b1;
            remaining_next = remaining_next - 1'b1;
        end
    end
end
// CC[30]/[31] carry Tag[8]/[9], matching the saved CQ extension bits.
wire cc_identity_match = {axis_cc_tdata[31:30], axis_cc_tdata[71:64]} ==
                         {read_descriptor[127], read_descriptor[79],
                          read_descriptor[103:96]} &&
                         axis_cc_tdata[63:48] == read_descriptor[95:80];
wire [12:0] expected_byte_count =
            (({4'b0, read_dw} - {4'b0, received_dw}) << 2) -
            (received_dw == 0 ? {11'b0, read_byte_lane[1:0]} : 13'd0);
wire [6:0] expected_lower_address = {read_descriptor[6:2], 2'b00} +
                                    {received_dw[4:0], 2'b00} +
                                    (received_dw == 0 ?
                                     {5'b0, read_byte_lane[1:0]} : 7'd0);
wire cc_header_bad = axis_cc_tkeep[2:0] != 3'b111 ||
                     axis_cc_tdata[28:16] != expected_byte_count ||
                     axis_cc_tdata[6:0] != expected_lower_address ||
                     axis_cc_tdata[42:32] == 0 ||
                     axis_cc_tdata[42:32] > read_dw - received_dw ||
                     axis_cc_tlast;

integer wlane;
integer compact_index;
integer check_beat, check_byte;
reg [4:0] last_write_byte;
reg [31:0] expected_strobe;
reg write_strobes_ok;
wire [4:0] last_beat_index = request_beats[4:0] - 5'd1;
wire [8:0] write_dw_count = (({3'b0, request_beats} - 9'd1) << 3) +
                            {6'b0, last_write_byte[4:2]} + 9'd1 -
                            {6'b0, request_byte_lane[4:2]};
wire [8:0] ar_dw_count = (({1'b0, mstr_arlen} + 9'd1) << 3) -
                         {6'b0, mstr_araddr[4:2]};

// Build CQ descriptors with explicit combinational field assignments.
// Clear reserved bits and the write length, which is filled after W capture.
reg [127:0] aw_descriptor;
reg [127:0] ar_descriptor;
always @* begin
    aw_descriptor = 128'b0;
    aw_descriptor[1:0] = mstr_awmisc_info_ats;
    aw_descriptor[63:2] = mstr_awaddr[63:2];
    aw_descriptor[78:75] = 4'b0001;
    aw_descriptor[79] = mstr_awmisc_info[48]; // Tag[8]
    aw_descriptor[95:80] = mstr_awmisc_info[39:24];
    aw_descriptor[103:96] = mstr_awmisc_info[47:40];
    aw_descriptor[111:104] = aw_function;
    aw_descriptor[114:112] = mstr_awmisc_info[10] ?
                             3'd6 : mstr_awmisc_info[8:6];
    aw_descriptor[123:121] = mstr_awmisc_info[18:16];
    aw_descriptor[126:124] = {mstr_awmisc_info_ido, mstr_awmisc_info[15:14]};
    aw_descriptor[127] = mstr_awmisc_info[49]; // Tag[9]

    ar_descriptor = 128'b0;
    ar_descriptor[1:0] = mstr_armisc_info_ats;
    ar_descriptor[63:2] = mstr_araddr[63:2];
    ar_descriptor[74:64] = {2'b0, ar_dw_count};
    ar_descriptor[78:75] = 4'b0000;
    ar_descriptor[79] = mstr_armisc_info[48]; // Tag[8]
    ar_descriptor[95:80] = mstr_armisc_info[39:24];
    ar_descriptor[103:96] = mstr_armisc_info[47:40];
    ar_descriptor[111:104] = ar_function;
    ar_descriptor[114:112] = mstr_armisc_info[10] ?
                             3'd6 : mstr_armisc_info[8:6];
    ar_descriptor[123:121] = mstr_armisc_info[18:16];
    ar_descriptor[126:124] = {mstr_armisc_info_ido, mstr_armisc_info[15:14]};
    ar_descriptor[127] = mstr_armisc_info[49]; // Tag[9]
end

always @* begin
    last_write_byte = 0;
    expected_strobe = 0;
    write_strobes_ok = 0;
    if (request_beats != 0) begin
        for (check_byte = 0; check_byte < 32; check_byte = check_byte + 1)
            if (write_strobe[last_beat_index][check_byte])
                last_write_byte = check_byte;
        write_strobes_ok = write_strobe[last_beat_index] != 0;
        for (check_beat = 0; check_beat < 32; check_beat = check_beat + 1) begin
            if (check_beat < request_beats) begin
                expected_strobe = 32'hffff_ffff;
                if (check_beat == 0)
                    expected_strobe = expected_strobe << request_byte_lane;
                if (check_beat == {26'b0, request_beats} - 32'd1)
                    expected_strobe = expected_strobe &
                                      (32'hffff_ffff >> (31 - last_write_byte));
                if (write_strobe[check_beat] != expected_strobe)
                        write_strobes_ok = 0;
            end
        end
    end
end
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        cq_state <= ST_IDLE;
        write_state <= ST_IDLE;
        read_state <= ST_IDLE;
        prefer_read <= 0;
        request_write <= 0;
        request_id <= 0;
        request_descriptor <= 0;
        request_tph <= 0;
        request_beats <= 0;
        request_dw <= 0;
        request_byte_lane <= 0;
        request_first_be <= 0;
        request_last_be <= 0;
        read_id <= 0;
        read_descriptor <= 0;
        read_tph <= 0;
        read_beats <= 0;
        read_dw <= 0;
        read_byte_lane <= 0;
        read_first_be <= 0;
        read_last_be <= 0;
        aw_seen <= 0;
        write_last_seen <= 0;
        write_error <= 0;
        write_count <= 0;
        send_dw <= 0;
        read_index <= 0;
        received_dw <= 0;
        packet_remaining_dw <= 0;
        packet_start_lane <= 0;
        packet_poison <= 0;
        read_resp <= 0;
        read_status <= 0;
        drop_foreign <= 0;
    end else begin
        if (aw_fire) begin
            aw_seen <= 1;
            request_id <= mstr_awid;
            request_beats <= {1'b0, mstr_awlen[4:0]} + 6'd1;
            request_byte_lane <= mstr_awaddr[4:0];
            request_descriptor <= aw_descriptor;
            request_tph <= mstr_awmisc_info_tph;
        end
        if (w_fire) begin
            write_buffer[write_count[4:0]] <= mstr_wdata;
            write_strobe[write_count[4:0]] <= mstr_wstrb;
            write_count <= write_count + 1'b1;
            write_last_seen <= mstr_wlast;
        end
        // CQ selection is locked from descriptor through the final payload beat.
        // Releasing CQ never waits for a Completion or an AXI B/R handshake.
        case (cq_state)
            ST_IDLE: begin
                if (grant_write || grant_read) begin
                    request_write <= grant_write;
                    cq_state <= ST_CQ_HEAD;
                end
            end
            ST_CQ_HEAD: begin
                if (cq_fire) begin
                    if (axis_cq_tlast) begin
                        cq_state <= ST_IDLE;
                        prefer_read <= request_write;
                    end else begin
                        cq_state <= ST_CQ_DATA;
                        send_dw <= send_dw + cq_payload_dw;
                    end
                end
            end
            ST_CQ_DATA: begin
                if (cq_fire) begin
                    if (axis_cq_tlast) begin
                        cq_state <= ST_IDLE;
                        prefer_read <= 1;
                    end else
                        send_dw <= send_dw + cq_payload_dw;
                end
            end
            default: cq_state <= ST_IDLE;
        endcase

        case (write_state)
            ST_IDLE: begin
                if (aw_fire || w_fire)
                    write_state <= ST_WRITE;
            end
            ST_WRITE: begin
                if (aw_seen && (write_last_seen || write_count == request_beats)) begin
                    if (write_error || !write_last_seen ||
                        write_count != request_beats || !write_strobes_ok) begin
                        write_error <= 1;
                        write_state <= ST_B;
                    end else begin
                        request_dw <= write_dw_count;
                        request_descriptor[74:64] <= {2'b0, write_dw_count};
                        request_first_be <= write_strobe[0]
                            [{request_byte_lane[4:2], 2'b0} +: 4];
                        request_last_be <= write_dw_count == 9'd1 ?
                            4'h0 : write_strobe[last_beat_index]
                                   [{last_write_byte[4:2], 2'b0} +: 4];
                        send_dw <= 0;
                        write_state <= ST_CQ_HEAD;
                    end
                end
            end
            ST_CQ_HEAD: begin
                if (cq_fire && request_write && cq_state == ST_CQ_HEAD)
                    write_state <= axis_cq_tlast ? ST_B : ST_CQ_DATA;
            end
            ST_CQ_DATA: begin
                if (cq_fire && axis_cq_tlast)
                    write_state <= ST_B;
            end
            ST_B: begin
                if (mstr_bready) begin
                    aw_seen <= 0;
                    write_count <= 0;
                    write_last_seen <= 0;
                    write_error <= 0;
                    write_state <= ST_IDLE;
                end
            end
            default: write_state <= ST_IDLE;
        endcase

        case (read_state)
            ST_IDLE: begin
                if (ar_fire) begin
                    read_id <= mstr_arid;
                    read_beats <= {1'b0, mstr_arlen[4:0]} + 6'd1;
                    read_dw <= ar_dw_count;
                    read_byte_lane <= mstr_araddr[4:0];
                    read_first_be <= 4'hf << mstr_araddr[1:0];
                    read_last_be <= ar_dw_count == 9'd1 ? 4'h0 : 4'hf;
                    read_descriptor <= ar_descriptor;
                    read_tph <= mstr_armisc_info_tph;
                    received_dw <= 0;
                    read_index <= 0;
                    read_resp <= 0;
                    read_status <= 0;
                    read_state <= ST_CQ_HEAD;
                end
            end
            ST_CQ_HEAD: begin
                if (cq_fire && !request_write && cq_state == ST_CQ_HEAD)
                    read_state <= ST_CC_HEAD;
            end
            ST_CC_HEAD: begin
                if (cc_fire) begin
                    if (!cc_identity_match) begin
                        // Foreign Completions cannot satisfy the active request.
                        drop_foreign <= 1;
                        if (!axis_cc_tlast)
                            read_state <= ST_CC_DROP;
                    end else if (axis_cc_tdata[45:43] != 0 || cc_header_bad) begin
                        drop_foreign <= 0;
                        read_resp <= axis_cc_tdata[45:43] == 3'b001 ? 2'b11 : 2'b10;
                        read_status <= axis_cc_tdata[45:43] == 0 ?
                                       3'b100 : axis_cc_tdata[45:43];
                        read_state <= axis_cc_tlast ? ST_R : ST_CC_DROP;
                    end else begin
                        packet_remaining_dw <= axis_cc_tdata[42:32];
                        packet_start_lane <= axis_cc_tdata[4:2];
                        packet_poison <= axis_cc_tdata[46];
                        read_state <= ST_CC_DATA;
                    end
                end
            end
            ST_CC_DATA: begin
                if (cc_fire) begin
                    compact_index = 0;
                    for (wlane = 0; wlane < 8; wlane = wlane + 1) begin
                        if (wlane >= packet_start_lane &&
                            compact_index < packet_remaining_dw) begin
                            read_buffer[read_byte_lane[4:2] + received_dw +
                                        compact_index] <=
                                axis_cc_tdata[wlane*32 +: 32];
                            read_poison[read_byte_lane[4:2] + received_dw +
                                        compact_index] <= packet_poison;
                            compact_index = compact_index + 1;
                        end
                    end
                    received_dw <= received_dw + payload_dw;
                    packet_remaining_dw <= remaining_next;
                    packet_start_lane <= 0;
                    if (payload_bad || (axis_cc_tlast != (remaining_next == 0))) begin
                        read_resp <= 2'b10;
                        read_status <= 3'b100;
                        drop_foreign <= 0;
                        read_state <= axis_cc_tlast ? ST_R : ST_CC_DROP;
                    end else if (axis_cc_tlast) begin
                        read_state <= received_dw + payload_dw == read_dw ?
                                 ST_R : ST_CC_HEAD;
                    end
                end
            end
            ST_CC_DROP: begin
                if (cc_fire && axis_cc_tlast)
                    read_state <= drop_foreign ? ST_CC_HEAD : ST_R;
            end
            ST_R: begin
                if (mstr_rready) begin
                    if (mstr_rlast) begin
                        read_state <= ST_IDLE;
                    end else
                        read_index <= read_index + 1'b1;
                end
            end
            default: read_state <= ST_IDLE;
        endcase
    end
end

endmodule
