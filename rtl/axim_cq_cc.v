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
    input                               aclk,
    input                               aresetn,

    // AXI master write request
    input [MSTR_ID_WD-1:0]              mstr_awid,
    input [MSTR_ADDR_WD-1:0]            mstr_awaddr,
    input [MSTR_BURST_LEN_PW-1:0]       mstr_awlen,
    input [2:0]                         mstr_awsize,
    input [1:0]                         mstr_awburst,
    input [3:0]                         mstr_awlock,
    input [3:0]                         mstr_awcache,
    input [2:0]                         mstr_awprot,
    input [3:0]                         mstr_awqos,
    input [MSTR_MISC_INFO_PW-1:0]       mstr_awmisc_info,
    input [63:0]                        mstr_awmisc_info_hdr_34dw,
    input [1:0]                         mstr_awmisc_info_fmt,
    input [9:0]                         mstr_awmisc_info_dwlen,
    input                               mstr_awmisc_info_ep,
    input                               mstr_awmisc_info_last_dcmp_tlp,
    input [1:0]                         mstr_awmisc_info_ats,
    input                               mstr_awmisc_info_nw,
    input [PF_WD-1:0]                   mstr_awmisc_info_func_num,
    input [VF_WD-2:0]                   mstr_awmisc_info_vfunc_num,
    input                               mstr_awmisc_info_vfunc_active,
    input [10:0]                        mstr_awmisc_info_tph,
    input                               mstr_awmisc_info_ido,
    output                              mstr_awready,
    input                               mstr_awvalid,

    // AXI master write data
    input                               mstr_wvalid,
    input                               mstr_wlast,
    input [MSTR_DATA_WD-1:0]            mstr_wdata,
    input [MSTR_WSTRB_WD-1:0]           mstr_wstrb,
    output                              mstr_wready,

    // AXI master write response
    output [MSTR_ID_WD-1:0]             mstr_bid,
    output                              mstr_bvalid,
    output [0 + 1:0]                    mstr_bresp,
    output [2:0]                        mstr_bmisc_info_cpl_stat,
    input                               mstr_bready,

    // AXI master read request
    input [MSTR_ID_WD-1:0]              mstr_arid,
    input                               mstr_arvalid,
    input [MSTR_ADDR_WD-1:0]            mstr_araddr,
    input [MSTR_BURST_LEN_PW-1:0]       mstr_arlen,
    input [2:0]                         mstr_arsize,
    input [1:0]                         mstr_arburst,
    input [3:0]                         mstr_arlock,
    input [3:0]                         mstr_arqos,
    input [3:0]                         mstr_arcache,
    input [2:0]                         mstr_arprot,
    input [MSTR_MISC_INFO_PW-1:0]       mstr_armisc_info,
    input                               mstr_armisc_info_last_dcmp_tlp,
    input                               mstr_armisc_info_nw,
    input [1:0]                         mstr_armisc_info_ats,
    input [PF_WD-1:0]                   mstr_armisc_info_func_num,
    input [VF_WD-2:0]                   mstr_armisc_info_vfunc_num,
    input                               mstr_armisc_info_vfunc_active,
    input [10:0]                        mstr_armisc_info_tph,
    input                               mstr_armisc_info_ido,
    input                               mstr_armisc_info_zeroread,
    output                              mstr_arready,

    // AXI master read response & read data
    output [MSTR_ID_WD-1:0]              mstr_rid,
    output                               mstr_rvalid,
    output                               mstr_rlast,
    output [MSTR_DATA_WD-1:0]            mstr_rdata,
    output [1:0]                         mstr_rresp,
    output [MSTR_RESP_MISC_INFO_PW-1:0]  mstr_rmisc_info,
    output [2:0]                         mstr_rmisc_info_cpl_stat,
    input                                mstr_rready,

    
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

    // First implementation: one 256-bit, naturally aligned memory request at
    // a time.  The source supplies at most 256 DW per request.
    localparam ST_IDLE       = 3'd0;
    localparam ST_WRITE_DATA = 3'd1;
    localparam ST_CQ_HEADER  = 3'd2;
    localparam ST_CQ_DATA    = 3'd3;
    localparam ST_B_RESPONSE = 3'd4;
    localparam ST_CC_HEADER  = 3'd5;
    localparam ST_CC_DATA    = 3'd6;
    localparam ST_R_RESPONSE = 3'd7;

    reg [2:0] state;
    reg prefer_read;
    reg req_write;
    reg [MSTR_ID_WD-1:0] req_id;
    reg [MSTR_ADDR_WD-1:0] req_addr;
    reg [MSTR_BURST_LEN_PW-1:0] req_len;
    reg [MSTR_MISC_INFO_PW-1:0] req_misc;
    reg [1:0] req_ats;
    reg [PF_WD-1:0] req_func_num;
    reg [VF_WD-2:0] req_vfunc_num;
    reg req_vfunc_active;
    reg [10:0] req_tph;
    reg req_ido;
    reg [5:0] write_count;
    reg [5:0] send_count;
    reg [8:0] read_dw_count;
    reg [5:0] read_word_count;
    reg [10:0] packet_dw_count;
    reg [10:0] packet_dw_received;
    reg [1:0] read_resp;
    reg [2:0] read_cpl_stat;
    reg read_poison;

    // A complete write packet is collected before starting CQ: CQ must not
    // insert an invalid cycle once a packet has started.
    reg [MSTR_DATA_WD-1:0] write_data [0:31];
    reg [31:0] read_data_dw [0:255];

    // PF indices 0..7 use Target Function 0..7; VF indices 0..247 use
    // Target Function 8..255.  VF indices above
    // the configured range are not accepted.
    wire write_candidate = mstr_awvalid &&
        (!mstr_awmisc_info_vfunc_active || mstr_awmisc_info_vfunc_num <= 8'd247);
    wire read_candidate = mstr_arvalid &&
        (!mstr_armisc_info_vfunc_active || mstr_armisc_info_vfunc_num <= 8'd247);
    wire grant_write = write_candidate && (!read_candidate || !prefer_read);
    wire grant_read = read_candidate && (!write_candidate || prefer_read);

    assign mstr_awready = (state == ST_IDLE) && grant_write;
    assign mstr_arready = (state == ST_IDLE) && grant_read;
    assign mstr_wready = (state == ST_WRITE_DATA);

    assign mstr_bid = req_id;
    assign mstr_bvalid = (state == ST_B_RESPONSE);
    assign mstr_bresp = 2'b00;
    assign mstr_bmisc_info_cpl_stat = 3'b000;

    assign mstr_rid = req_id;
    assign mstr_rvalid = (state == ST_R_RESPONSE);
    assign mstr_rlast = (read_word_count == req_len[5:0]);
    assign mstr_rresp = read_resp;
    assign mstr_rmisc_info = {{(MSTR_RESP_MISC_INFO_PW-8){1'b0}}, read_poison, 7'b0};
    assign mstr_rmisc_info_cpl_stat = read_cpl_stat;

    genvar word_lane;
    generate
        for (word_lane = 0; word_lane < 8; word_lane = word_lane + 1) begin : g_read_data
            assign mstr_rdata[word_lane*32 +: 32] =
                (read_resp == 2'b00) ?
                read_data_dw[{read_word_count, 3'b000} + word_lane] : 32'b0;
        end
    endgenerate

    // CQ uses one 16-byte descriptor followed by a new payload beat in
    // address-aligned mode.  The first beat's upper half is padding.
    reg [127:0] cq_descriptor;
    always @* begin
        cq_descriptor = 128'b0;
        cq_descriptor[1:0] = req_ats;
        cq_descriptor[63:2] = req_addr[63:2];
        cq_descriptor[74:64] = ({3'b0, req_len} + 11'd1) << 3;
        cq_descriptor[78:75] = req_write ? 4'b0001 : 4'b0000;
        cq_descriptor[95:80] = req_misc[39:24];
        cq_descriptor[103:96] = req_misc[47:40];
        cq_descriptor[111:104] = req_vfunc_active ?
            (8'd8 + req_vfunc_num) : {{(8-PF_WD){1'b0}}, req_func_num};
        cq_descriptor[114:112] = req_misc[8:6];
        cq_descriptor[123:121] = req_misc[18:16];
        cq_descriptor[124] = req_misc[14];
        cq_descriptor[125] = req_misc[15];
        cq_descriptor[126] = req_ido;
    end

    reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] cq_user;
    always @* begin
        cq_user = {AXIS_PCIE_CQ_USER_WIDTH{1'b0}};
        if (state == ST_CQ_HEADER) begin
            cq_user[3:0] = 4'hf;
            cq_user[7:4] = 4'hf;
            cq_user[40] = 1'b1;
            cq_user[42] = req_tph[0];
            cq_user[44:43] = req_tph[2:1];
            cq_user[52:45] = req_tph[10:3];
        end else if (state == ST_CQ_DATA) begin
            cq_user[39:8] = 32'hffff_ffff;
        end
    end

    assign axis_cq_tvalid = (state == ST_CQ_HEADER) || (state == ST_CQ_DATA);
    assign axis_cq_tdata = (state == ST_CQ_HEADER) ?
        {{(AXIS_PCIE_DATA_WIDTH-128){1'b0}}, cq_descriptor} :
        (state == ST_CQ_DATA) ? write_data[send_count[4:0]] :
        {AXIS_PCIE_DATA_WIDTH{1'b0}};
    // In address-aligned mode the descriptor owns only the low four DW lanes;
    // the high four lanes are padding for both reads and writes.
    assign axis_cq_tkeep = (state == ST_CQ_HEADER) ? 8'h0f : 8'hff;
    assign axis_cq_tlast = (state == ST_CQ_HEADER && !req_write) ||
        (state == ST_CQ_DATA && send_count == req_len[5:0]);
    assign axis_cq_tuser = cq_user;

    // For 256-bit address-aligned CC, the descriptor occupies the first beat
    // and payload starts at DW lane zero of the next beat.
    assign axis_cc_tready = (state == ST_CC_HEADER) || (state == ST_CC_DATA);

    function [3:0] count_keep;
        input [7:0] keep;
        integer bit_index;
        begin
            count_keep = 4'd0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                count_keep = count_keep + keep[bit_index];
        end
    endfunction

    wire [3:0] accepted_dw = count_keep(axis_cc_tkeep[7:0]);
    wire [8:0] next_read_dw_count = read_dw_count + accepted_dw;
    wire [12:0] remaining_read_bytes =
        (({5'b0, req_len} + 13'd1) << 5) - ({4'b0, read_dw_count} << 2);

    integer dw_lane;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= ST_IDLE;
            prefer_read <= 1'b0;
            req_write <= 1'b0;
            req_id <= {MSTR_ID_WD{1'b0}};
            req_addr <= {MSTR_ADDR_WD{1'b0}};
            req_len <= {MSTR_BURST_LEN_PW{1'b0}};
            req_misc <= {MSTR_MISC_INFO_PW{1'b0}};
            req_ats <= 2'b0;
            req_func_num <= {PF_WD{1'b0}};
            req_vfunc_num <= {(VF_WD-1){1'b0}};
            req_vfunc_active <= 1'b0;
            req_tph <= 11'b0;
            req_ido <= 1'b0;
            write_count <= 6'b0;
            send_count <= 6'b0;
            read_dw_count <= 9'b0;
            read_word_count <= 6'b0;
            packet_dw_count <= 11'b0;
            packet_dw_received <= 11'b0;
            read_resp <= 2'b00;
            read_cpl_stat <= 3'b0;
            read_poison <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (mstr_awvalid && mstr_awready) begin
                        req_write <= 1'b1;
                        req_id <= mstr_awid;
                        req_addr <= mstr_awaddr;
                        req_len <= mstr_awlen;
                        req_misc <= mstr_awmisc_info;
                        req_ats <= mstr_awmisc_info_ats;
                        req_func_num <= mstr_awmisc_info_func_num;
                        req_vfunc_num <= mstr_awmisc_info_vfunc_num;
                        req_vfunc_active <= mstr_awmisc_info_vfunc_active;
                        req_tph <= mstr_awmisc_info_tph;
                        req_ido <= mstr_awmisc_info_ido;
                        write_count <= 6'b0;
                        prefer_read <= 1'b1;
                        state <= ST_WRITE_DATA;
                    end else if (mstr_arvalid && mstr_arready) begin
                        req_write <= 1'b0;
                        req_id <= mstr_arid;
                        req_addr <= mstr_araddr;
                        req_len <= mstr_arlen;
                        req_misc <= mstr_armisc_info;
                        req_ats <= mstr_armisc_info_ats;
                        req_func_num <= mstr_armisc_info_func_num;
                        req_vfunc_num <= mstr_armisc_info_vfunc_num;
                        req_vfunc_active <= mstr_armisc_info_vfunc_active;
                        req_tph <= mstr_armisc_info_tph;
                        req_ido <= mstr_armisc_info_ido;
                        read_dw_count <= 9'b0;
                        read_word_count <= 6'b0;
                        read_resp <= 2'b00;
                        read_cpl_stat <= 3'b0;
                        read_poison <= 1'b0;
                        prefer_read <= 1'b0;
                        state <= ST_CQ_HEADER;
                    end
                end
                ST_WRITE_DATA: begin
                    if (mstr_wvalid && mstr_wready) begin
                        write_data[write_count[4:0]] <= mstr_wdata;
                        if (write_count == req_len[5:0])
                            state <= ST_CQ_HEADER;
                        else
                            write_count <= write_count + 6'd1;
                    end
                end
                ST_CQ_HEADER: begin
                    if (axis_cq_tvalid && axis_cq_tready) begin
                        if (req_write) begin
                            send_count <= 6'b0;
                            state <= ST_CQ_DATA;
                        end else begin
                            state <= ST_CC_HEADER;
                        end
                    end
                end
                ST_CQ_DATA: begin
                    if (axis_cq_tvalid && axis_cq_tready) begin
                        if (send_count == req_len[5:0])
                            state <= ST_B_RESPONSE;
                        else
                            send_count <= send_count + 6'd1;
                    end
                end
                ST_B_RESPONSE: begin
                    if (mstr_bready)
                        state <= ST_IDLE;
                end
                ST_CC_HEADER: begin
                    if (axis_cc_tvalid && axis_cc_tready) begin
                        packet_dw_count <= axis_cc_tdata[42:32];
                        packet_dw_received <= 11'b0;
                        read_poison <= read_poison | axis_cc_tdata[46];
                        if (axis_cc_tdata[71:64] != req_misc[47:40] ||
                            axis_cc_tdata[63:48] != req_misc[39:24]) begin
                            read_resp <= 2'b10;
                            read_cpl_stat <= 3'b100;
                        end else if (axis_cc_tdata[45:43] != 3'b000) begin
                            read_resp <= (axis_cc_tdata[45:43] == 3'b001) ?
                                2'b11 : 2'b10;
                            read_cpl_stat <= axis_cc_tdata[45:43];
                        end else if (axis_cc_tdata[28:16] != remaining_read_bytes) begin
                            read_resp <= 2'b10;
                            read_cpl_stat <= 3'b100;
                        end
                        if (axis_cc_tlast) begin
                            if (axis_cc_tdata[45:43] == 3'b000) begin
                                read_resp <= 2'b10;
                                read_cpl_stat <= 3'b100;
                            end
                            state <= ST_R_RESPONSE;
                        end else begin
                            state <= ST_CC_DATA;
                        end
                    end
                end
                ST_CC_DATA: begin
                    if (axis_cc_tvalid && axis_cc_tready) begin
                        if (read_resp != 2'b00) begin
                            if (axis_cc_tlast)
                                state <= ST_R_RESPONSE;
                        end else begin
                            for (dw_lane = 0; dw_lane < 8; dw_lane = dw_lane + 1)
                                if (axis_cc_tkeep[dw_lane] &&
                                    (read_dw_count + dw_lane < 9'd256))
                                    read_data_dw[read_dw_count + dw_lane] <=
                                        axis_cc_tdata[dw_lane*32 +: 32];
                            read_dw_count <= next_read_dw_count;
                            packet_dw_received <= packet_dw_received + accepted_dw;
                            if (axis_cc_tlast) begin
                                if (packet_dw_received + accepted_dw != packet_dw_count ||
                                    next_read_dw_count > ({3'b0, req_len} + 9'd1) * 9'd8) begin
                                    read_resp <= 2'b10;
                                    read_cpl_stat <= 3'b100;
                                    state <= ST_R_RESPONSE;
                                end else if (next_read_dw_count ==
                                             ({3'b0, req_len} + 9'd1) * 9'd8) begin
                                    state <= ST_R_RESPONSE;
                                end else begin
                                    state <= ST_CC_HEADER;
                                end
                            end
                        end
                    end
                end
                ST_R_RESPONSE: begin
                    if (mstr_rready) begin
                        if (read_word_count == req_len[5:0])
                            state <= ST_IDLE;
                        else
                            read_word_count <= read_word_count + 6'd1;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
