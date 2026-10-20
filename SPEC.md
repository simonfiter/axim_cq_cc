# AXI Manager ↔ PCIe CQ/CC Bridge 开发规格

状态：已实现 CQ/CC 独立传输、Figure 23 的 CQ Dword-Aligned 写布局及 Figure 29 的 Memory Read 单拍 descriptor；仿真检查见 `tb/VERIFICATION_SPEC.md`，后续扩展范围见第 5 节。

## 1. 目标与边界

在 `rtl/axim_cq_cc.v` 的现有 `axim2s` 顶层中，实现从 AXI Manager AW/W/AR 到 CQ 请求包、从 CC 完成包到 AXI B/R 响应的桥接。使用可综合 Verilog。保持用户修正后的顶层模块名、参数列表和端口列表原样；同步维护开发规格及相关验证文件。

本模块的 CQ 是输出，CC 是输入。`aclk` 为全部通道的时钟，`aresetn` 为低有效复位。所有 ready/valid 传输仅在同一时钟沿同时为 1 时发生。

依据：`README.md`、`Agent.md`、`signal_describ/axi_master_signal.md`、`signal_describ/stream_cq_cc.md`、`operation_describ/axis_compelet/axi_stream_complete.md` 及现有顶层。

## 2. 实现架构

### 2.1 请求接收与仲裁

- AW 控制信息、W 数据和 AR 控制信息分别握手。AW 与 W 可在不同周期到达；不能假定 W 连续有效。
- 写通道先保存 AW 及该请求的完整 W 数据，再开始输出 CQ 包。这样在 CQ 包开始后，即使 AXI W 暂停，也能保持 CQ `tvalid` 连续及各拍内容稳定。
- 读通道保存 AR 信息。读写请求在 CQ 出口仲裁；一个 CQ 包从首拍至 `tlast` 握手结束期间不能被另一请求插入。
- 写通道、读通道和 CQ 出口分别使用独立状态机。最多同时保存一笔写请求和一笔读请求，两者的 ID、descriptor、长度、对齐位置、BE、TPH 及数据缓存独立。AW/W 和 AR 可以同时握手；W 先到只占用写槽，不影响读请求。
- CQ 按已就绪的完整请求进行整包轮换仲裁，复位后写优先；写 CQ 包结束后读优先，读 CQ 包结束后写优先。CQ 发送完读 descriptor 后立即释放发送端，不等待 CC 或 AXI R；写包结束后不等待 AXI B 即可发送读请求。CQ 被背压不影响已发送读请求的 CC 接收；等待 CC、CC 包接收及 B/R 背压均不阻塞另一槽的 CQ 发送。
- 写槽在 B 握手后释放，读槽在最后一拍 R 握手后释放；同一方向槽满时施加本方向背压。CC 仍与已发送的读 CQ 请求匹配，无在途读请求或读槽正输出 R 时不接收新的 CC。独立传输不改变读请求与其 Completion 的先后关联，也不允许 CQ 包交错。
- `awready/arready/wready` 只在内部有足够空间且可接受相应事务时拉高。所有已握手数据在复位前或该事务完成前保持有效，不以 `valid` 的后续变化为依据。

### 2.2 CQ 报文生成

- CQ 使用 Figure 23 的 256-bit Dword-Aligned 排列：首拍 `tdata[127:0]` 为 descriptor，`tdata[255:128]` 从低到高放 DW0..DW3；后续拍从 `tdata[31:0]` 起连续发送 DW4 及之后的数据。CC 读 Completion payload 仍从 descriptor 后一拍开始，按该包的 Lower Address 定位，前面的空位按对齐填充处理。AXI 地址通道的输入限制另见第 3、6 节。
- 每个请求以 128-bit descriptor 开始。Memory Read 不带 payload；Memory Write 的 descriptor 后接写数据。按已确认的对齐模式排列 payload，产生连续的 `tkeep`，最后一拍产生 `tlast`。
- descriptor 字段使用 CQ 文档定义的位位置：地址类型 `[1:0]`、地址 `[63:2]`、DW 数 `[74:64]`、请求类型 `[78:75]`、Requester ID `[95:80]`、Tag `[103:96]`、Target Function `[111:104]`、TC `[123:121]`、属性 `[126:124]`。本阶段请求类型只产生 Memory Read (`0000`) 和 Memory Write (`0001`)。未定义或保留字段置零；有明确来源的字段从 AXI sideband 提取。
- CQ 使用完整 10-bit Tag：`[103:96]` 取 `mstr_*misc_info[47:40]`（Tag[7:0]），原保留位 `[79]` 取 `mstr_*misc_info[48]`（Tag[8]），原保留位 `[127]` 取 `mstr_*misc_info[49]`（Tag[9]），读写请求均采用此映射。接收 CC 时按独立读槽的 Requester ID 和完整 10-bit Tag 校验；CC `[71:64]` 为 Tag[7:0]，bit30 为 Tag[8]，bit31 为 Tag[9]。
- 第一拍 `tuser[3:0]` / `[7:4]` 为 first/last byte enable；`tuser[39:8]` 为当前拍 payload 字节有效标志；`tuser[40]` 为 SOP；`tuser[42]`、`[44:43]`、`[52:45]` 为 TPH 信息。首版不启用 parity 校验，CQ parity 和 `discontinue` 置零。
- CQ 写请求跳过 AXI 首拍地址之前的填充 DW，将有效 payload 重新拼接：descriptor 所在首拍最多发送 4 DW，后续拍最多发送 8 DW；首个 DW 内保留原字节位置。`tuser.byte_en` 随对应数据同步搬移，首拍 descriptor 对应的 `tuser[23:8]` 为零，payload 对应的 `tuser[39:24]` 为有效字节使能。`tkeep` 连续覆盖 descriptor 及有效 payload DW；满首拍为 `8'hff`，不足 4 DW 时按实际长度生成。仅最后一拍拉高 `tlast`，不超过 4 DW 的写请求在首拍结束并在握手后产生 B。例如 13 DW 分为 4+8+1 DW，尾拍 `tkeep=8'h01`；21 DW 分为 4+8+8+1 DW；256 DW 共 33 拍（含 descriptor 首拍）。读请求按 Figure 29 只有 descriptor，`tkeep=8'h0f`、`tlast=1`、payload byte enable 为零。首尾 BE、SOP 及 TPH 仅首拍有效，其余拍置零。
- Requester ID、Tag、BAR ID、TC、NS/RO 分别来自 `misc_info[39:24]`、`[49:40]`、`[8:6]`、`[18:16]`、`[14]`/`[15]`；ROM 标志 `[10]` 为 1 时 BAR ID 为 6。AT 来自 `*_ats`，IDO 来自 `*_ido`。BAR Aperture 无输入来源，置零。
- 写请求允许首拍地址之前的无效字节和末拍末尾的无效字节，通过 `WSTRB` 表示；中间字节必须连续有效，不能有空洞。CQ First/Last BE 由首末有效 DW 的 `WSTRB` 生成；仅 1 DW 时 Last BE 为零。当前一个 PCIe Memory Write 包不能表示中间 DW 的稀疏 `WSTRB`，此类写请求返回 SLVERR/CA，不发送 CQ。零长度写属于后续扩展。
- CQ `tvalid && !tready` 时，`tdata/tkeep/tlast/tuser/tvalid` 必须保持不变；已经开始的包不能因为输入 AXI 暂停而出现无效拍。

### 2.3 CC 报文接收与 AXI 响应

- 从 CC 前 96 bit 解析 completion descriptor，包括 Lower Address `[6:0]`、Byte Count `[28:16]`、DW Count `[42:32]`、Completion Status `[45:43]`、Requester ID `[63:48]`、10-bit Tag `{[31], [30], [71:64]}`。按 `tkeep/tlast` 确定完整包，去掉 descriptor 与对齐填充后将 payload 转为 AXI R 数据。
- 利用保存的请求上下文关联 Completion 与原始 AXI ID。Memory Read Completion 产生 R；一个读请求的多个 Split Completions 按 Byte Count/DW Count/Lower Address 顺序拼接，直到满足原请求，才产生最后一个 `mstr_rlast`。
- AXI B/R 在 `valid && !ready` 时保持 ID、数据、状态、`last` 和 sideband 稳定。CC 接收侧的缓冲空间不足时拉低 `axis_cc_tready`，不能丢包。
- 读路径使用 256 DW 的整请求缓存，全部 Split Completion 接收完毕后才输出 R。每个 CC 包从 descriptor 后一拍开始接收 payload，第一 payload 拍跳过 `Lower Address[4:2]` 指定的填充 DW；各包数据按 AR 地址对应的 AXI byte lane 写入缓存，首拍地址之前的 lane 不作为有效数据。每个 DW 保存该包的 EP，输出 AXI 拍内任一有效 DW 带 EP 时令 `rmisc_info[7]=1`，其余位为零。缓存无需复位，只有完整写入后才向 AXI 输出。
- Memory Write 按 Posted 请求处理；在对应 CQ 包最后一拍握手后产生 AXI B，`bresp=OKAY`、`bmisc_info_cpl_stat=SC`。本阶段不生成 I/O、配置或其他非 Posted 写请求。
- PCIe Completion Status 与 AXI `bresp/rresp`、`*_misc_info_cpl_stat` 的映射单独明确；不能直接把 PCIe 3-bit 状态截成 AXI 2-bit 响应。
- SC (`000`) → OKAY (`00`)，UR (`001`) → DECERR (`11`)，CA (`100`) → SLVERR (`10`)；响应 sideband 保留 Completion Status。UR/CA 包剩余内容（包括请求日志字段）丢弃到 `tlast`，随后返回原请求 LEN+1 拍零数据，最后一拍 RLAST。若后续 split 报错，也对整笔读请求返回该错误，不暴露此前缓存的数据。

## 3. 支持范围与参数

| 项目 | 建议首版规格 | 确认状态 |
| --- | --- | --- |
| AXI 请求类型 | 仅 Memory Read、Memory Write | 已确认 |
| AXI/CQ/CC 宽度 | 默认 256/256 bit，`WSTRB=32`、`TKEEP=8` | 已确认首版范围 |
| AXI-Stream 报文对齐模式 | CQ 为 Dword-Aligned：首个 payload DW 在 descriptor 同拍的 lane 4，后续拍从 lane 0 连续发送；CC 仍按 Completion Lower Address 对齐 | 本次更新 |
| 并发数 | 最多一笔写和一笔读同时在途，CQ 发送与 CC 接收可以同周期握手 | 本次更新 |
| AXI burst | `mstr_awlen/mstr_arlen` 均为“传输拍数减一”，实际拍数为 LEN+1 | 已确认；与信号说明中的“实际拍数”表述不一致，以本项目约定为准 |
| 事务长度 | 单笔请求不超过 256 DW；大于 256 DW 的请求由上游拆分后再送入本模块 | 已确认；单笔上限是输入契约 |
| CQ Tag | `mstr_*misc_info[49:40]`；Tag[7:0] → descriptor[103:96]，Tag[8] → descriptor[79]，Tag[9] → descriptor[127] | 已确认 |
| AXI 数据传输 | 允许任意字节地址；`awsize/arsize=5`，首拍从地址对应的 byte lane 开始，末拍可由 `WSTRB` 指定较短的有效数据 | 本次更新 |
| 奇偶校验 | 首版无需 parity 检查；CQ parity 置零 | 已确认 |
| PF | 最多 8 个 PF，索引 0..7；Target Function = `func_num`，编码 0..7 | 已确认首版范围 |
| VF | 最多 248 个 VF，索引 0..247；Target Function = `8 + vfunc_num`，编码 8..255 | 已确认首版范围 |

顶层参数和端口即使首版仅验证默认宽度，也保持原样。首版数据通路按 256-bit 实现；其他参数组合不属于已承诺功能。单请求 256 DW 上限对应最多 32 个 256-bit AXI 拍，即 LEN 不超过 31。

## 4. 开发要求

1. 按已确认的首版范围实现；没有依据的边带行为须在实现说明中列为限制。
2. RTL 使用可综合 Verilog；不增加仿真专用逻辑到数据通路；不修改顶层参数或端口。
3. 仅改任务需要的文件，不重排或重写无关内容。复杂状态机按请求接收、CQ 发送、CC 接收、AXI 响应分开，状态和计数器注明单位（字节、DW 或 AXI 拍）。
4. 设计所有 ready/valid 通道的背压行为；reset 清除有效位及事务上下文；不能凭等待固定周期判断事务结束。
5. 对 descriptor 字段、LEN+1、10-bit Tag 扩展映射、BE/keep、首尾拍、零长度请求、错误状态和 Split Completion 编写有针对性的仿真。至少覆盖 AW/W 不同到达顺序、CQ/CC 背压、B/R 背压和复位中断。
6. 验证通过后报告实际支持范围、运行的检查命令及尚存限制。

## 5. 需要确认的协议问题

以下问题会改变 RTL 行为，文档或当前端口尚不足以安全决定：

1. **扩展范围**：其他参数组合、窄传输、写数据有效区间内有空洞的 `WSTRB`、零长度读写、I/O/Message/ATS 和多笔在途不属于首版；后续需要时单独定义。
2. **Target Function 分配**：CQ 文档的示例只列出 4 个 PF 和 4 个 VF。本项目首版按顶层实际配置划分 8-bit 空间：PF0..PF7 使用 0..7；VF0..VF247 使用 8..255。`vfunc_active=1` 时将 `8 + vfunc_num` 写入 CQ `[111:104]`，否则使用 `func_num`。`vfunc_num>247` 时 AW/AR 暂不握手。其他没有可用映射的字段置零。CQ Tag 使用第 2.2 节定义的 10-bit 扩展映射。
3. **错误与异常**：首版按 CC descriptor 中 SC/UR/CA 状态输出 AXI OKAY/DECERR/SLVERR，RRS、discontinue 和 parity 错误的系统级恢复策略未定义；需要扩展时另行确认。
4. **Split Completion**：同一读请求可由多个按顺序到达的 CC 包完成；用 Byte Count 判断剩余数据。首版要求这些包的有效数据合计等于原 AR 请求字节数。

## 6. 实现约束与交付状态

- 输入为 Memory 类型（`misc_info[23:19]=0`、I/O 标志 `[9]=0`）的 INCR burst，LEN≤31、SIZE=5，允许地址低 5 bit 为任意值。读请求覆盖从 AR 地址到 LEN 指定的末拍末尾；写请求以末拍 `WSTRB` 的最高有效字节确定末尾。地址通道仅对这些请求及有效 VF 编号握手；零长度读不握手。单笔请求不得跨越 AXI 规定的 4 KiB 边界，上游负责拆分。其它输入不属于首版契约。
- W 可先于 AW 接收，最多缓存 32 拍。一旦接收 WLAST，不再接收本事务的 W；AW 到达并收齐数据后检查拍数、WLAST 和 `WSTRB`。首拍地址之前及末拍末尾允许无效 strobe，中间字节连续有效；其它 `WSTRB` 形态、提前 WLAST、到达期望拍数仍无 WLAST，返回 SLVERR/CA，不发送 CQ；缺失 AW 或缺失预期 W 数据时继续等待，不提供超时机制。
- CC 按 Requester ID 和完整 10-bit Tag 匹配。无关完成包（包括仅 Tag[8] 或 Tag[9] 不同的包）丢弃到 TLAST，然后继续等待当前请求，不产生 AXI 响应。
- SC 包检查 descriptor keep、Byte Count、Lower Address、DW Count、payload keep 和 TLAST 边界。格式不一致时排空该包，整笔读返回 SLVERR/CA 和零数据。其它未定义 Completion Status 保留状态 sideband 并映射为 SLVERR；不承诺系统级错误恢复。
- 首版 Split Completion 的起始地址及长度必须按 DW 对齐；Byte Count 等于当前请求剩余字节数，Lower Address 等于下一有效数据地址的低 7 bit。允许 split 边界位于 AXI 拍内部。
- `*_hdr_34dw`、`*_fmt`、`*_dwlen`、`*_last_dcmp_tlp`、`*_nw`、写 EP、AXI lock/qos/cache/prot 不参与首版报文转换。请求大小由 LEN+1 与 SIZE 契约确定，不能利用这些字段扩展为其它报文类型。
- CC parity 不检查；discontinue 不参与首版恢复处理，要求输入不发生 discontinue。CQ parity 固定为零。外部需关闭 parity 检查。
- 顶层 `mstr_bresp` 原样保留，集成环境必须提供 `CC_AXIJ_DMWR_VALUE` 宏定义；标准两位响应在开启额外 DMWR 位时零扩展。
- 已执行主回归、地址对齐回归及 READY 回归。主回归覆盖 CQ/CC 同周期握手、CQ 背压下 CC/R 推进、B 背压下读 CQ/CC 推进、R 背压下写 CQ 推进、W 先到不阻塞读、AW/AR 同时接收、split/poison/error 上下文隔离，以及双槽在途复位恢复。波形和有效握手 transaction 日志保存在 `tmp/`。
