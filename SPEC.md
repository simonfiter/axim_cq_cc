# AXI Manager ↔ PCIe CQ/CC Bridge 开发规格（待确认）

状态：首版实现约定已确认；后续扩展范围见第 5 节。

## 1. 目标与边界

在 `rtl/axim_cq_cc.v` 的现有 `axim2s` 顶层中，实现从 AXI Manager AW/W/AR 到 CQ 请求包、从 CC 完成包到 AXI B/R 响应的桥接。使用可综合 Verilog。保持顶层模块名、参数列表和端口列表原样；只修改实现所需的 RTL，并增加必要的验证文件。

本模块的 CQ 是输出，CC 是输入。`aclk` 为全部通道的时钟，`aresetn` 为低有效复位。所有 ready/valid 传输仅在同一时钟沿同时为 1 时发生。

依据：`README.md`、`Agent.md`、`signal_describ/axi_master_signal.md`、`signal_describ/stream_cq_cc.md`、`operation_describ/axis_compelet/axi_stream_complete.md` 及现有顶层。

## 2. 拟采用的架构

### 2.1 请求接收与仲裁

- AW 控制信息、W 数据和 AR 控制信息分别握手。AW 与 W 可在不同周期到达；不能假定 W 连续有效。
- 写通道先保存 AW 及该请求的完整 W 数据，再开始输出 CQ 包。这样在 CQ 包开始后，即使 AXI W 暂停，也能保持 CQ `tvalid` 连续及各拍内容稳定。
- 读通道保存 AR 信息。读写请求在 CQ 出口仲裁；一个 CQ 包从首拍至 `tlast` 握手结束期间不能被另一请求插入。
- 建议首版采用全局一次只处理一笔 AXI 请求的顺序架构。AW/W 与 AR 同时出现时，采用固定且不会饿死一方的轮换仲裁。此限制降低 ID/Tag 跟踪与拆分完成包的复杂度，但会限制吞吐率，需确认。
- `awready/arready/wready` 只在内部有足够空间且可接受相应事务时拉高。所有已握手数据在复位前或该事务完成前保持有效，不以 `valid` 的后续变化为依据。

### 2.2 CQ 报文生成

- 每个请求以 128-bit descriptor 开始。Memory Read 不带 payload；Memory Write 的 descriptor 后接写数据。按已确认的对齐模式排列 payload，产生连续的 `tkeep`，最后一拍产生 `tlast`。
- descriptor 字段使用 CQ 文档定义的位位置：地址类型 `[1:0]`、地址 `[63:2]`、DW 数 `[74:64]`、请求类型 `[78:75]`、Requester ID `[95:80]`、Tag `[103:96]`、Target Function `[111:104]`、TC `[123:121]`、属性 `[126:124]`。本阶段请求类型只产生 Memory Read (`0000`) 和 Memory Write (`0001`)。未定义或保留字段置零；有明确来源的字段从 AXI sideband 提取。
- CQ Tag `[103:96]` 取 `mstr_*misc_info[47:40]`，直接丢弃 `[49:48]`。接收 CC 时按低 8 bit Tag 校验；在全局单笔在途架构下，高 2 bit 不参与请求匹配。
- 第一拍 `tuser[3:0]` / `[7:4]` 为 first/last byte enable；`tuser[39:8]` 为当前拍 payload 字节有效标志；`tuser[40]` 为 SOP；`tuser[42]`、`[44:43]`、`[52:45]` 为 TPH 信息。首版不启用 parity 校验，CQ parity 和 `discontinue` 置零。
- 首版写请求要求每拍 `mstr_wstrb=32'hffff_ffff`，因此 CQ 首尾 BE 均为 `4'hf`，每个 payload 拍的 32 位 `byte_en` 全为 1。非连续 strobe 和零长度写属于后续扩展。
- CQ `tvalid && !tready` 时，`tdata/tkeep/tlast/tuser/tvalid` 必须保持不变；已经开始的包不能因为输入 AXI 暂停而出现无效拍。

### 2.3 CC 报文接收与 AXI 响应

- 从 CC 前 96 bit 解析 completion descriptor，包括 Lower Address `[6:0]`、Byte Count `[28:16]`、DW Count `[42:32]`、Completion Status `[45:43]`、Requester ID `[63:48]`、Tag `[71:64]`。按 `tkeep/tlast` 确定完整包，去掉 descriptor 与对齐填充后将 payload 转为 AXI R 数据。
- 利用保存的请求上下文关联 Completion 与原始 AXI ID。Memory Read Completion 产生 R；一个读请求的多个 Split Completions 按 Byte Count/DW Count/Lower Address 顺序拼接，直到满足原请求，才产生最后一个 `mstr_rlast`。
- AXI B/R 在 `valid && !ready` 时保持 ID、数据、状态、`last` 和 sideband 稳定。CC 接收侧的缓冲空间不足时拉低 `axis_cc_tready`，不能丢包。
- Memory Write 按 Posted 请求处理；在对应 CQ 包最后一拍握手后产生 AXI B，`bresp=OKAY`、`bmisc_info_cpl_stat=SC`。本阶段不生成 I/O、配置或其他非 Posted 写请求。
- PCIe Completion Status 与 AXI `bresp/rresp`、`*_misc_info_cpl_stat` 的映射单独明确；不能直接把 PCIe 3-bit 状态截成 AXI 2-bit 响应。

## 3. 拟支持范围与参数

| 项目 | 建议首版规格 | 确认状态 |
| --- | --- | --- |
| AXI 请求类型 | 仅 Memory Read、Memory Write | 已确认 |
| AXI/CQ/CC 宽度 | 默认 256/256 bit，`WSTRB=32`、`TKEEP=8` | 已确认首版范围 |
| 对齐模式 | CQ/CC 均采用 address-aligned | 已确认 |
| 并发数 | 全局最多一笔尚未完成的 AXI 请求 | 待确认性能要求 |
| AXI burst | `mstr_awlen/mstr_arlen` 均为“传输拍数减一”，实际拍数为 LEN+1 | 已确认；与信号说明中的“实际拍数”表述不一致，以本项目约定为准 |
| 事务长度 | 单笔请求不超过 256 DW；大于 256 DW 的请求由上游拆分后再送入本模块 | 已确认；单笔上限是输入契约 |
| CQ Tag | `mstr_*misc_info[47:40]`；`[49:48]` 截断 | 已确认 |
| AXI 数据传输 | 32-byte 对齐、每拍 32-byte 的整拍传输；`awsize/arsize=5`，写拍 `wstrb` 全 1 | 已确认首版范围 |
| 奇偶校验 | 首版无需 parity 检查；CQ parity 置零 | 已确认 |
| PF | 最多 8 个 PF，索引 0..7；Target Function = `func_num`，编码 0..7 | 已确认首版范围 |
| VF | 最多 248 个 VF，索引 0..247；Target Function = `8 + vfunc_num`，编码 8..255 | 已确认首版范围 |

顶层参数和端口即使首版仅验证默认宽度，也保持原样。首版数据通路按 256-bit 实现；其他参数组合不属于已承诺功能。单请求 256 DW 上限对应最多 32 个 256-bit AXI 拍，即 LEN 不超过 31。

## 4. 开发要求

1. 按已确认的首版范围实现；没有依据的边带行为须在实现说明中列为限制。
2. RTL 使用可综合 Verilog；不增加仿真专用逻辑到数据通路；不修改顶层参数或端口。
3. 仅改任务需要的文件，不重排或重写无关内容。复杂状态机按请求接收、CQ 发送、CC 接收、AXI 响应分开，状态和计数器注明单位（字节、DW 或 AXI 拍）。
4. 设计所有 ready/valid 通道的背压行为；reset 清除有效位及事务上下文；不能凭等待固定周期判断事务结束。
5. 对 descriptor 字段、LEN+1、Tag 高位截断、BE/keep、首尾拍、零长度请求、错误状态和 Split Completion 编写有针对性的仿真。至少覆盖 AW/W 不同到达顺序、CQ/CC 背压、B/R 背压和复位中断。
6. 验证通过后报告实际支持范围、运行的检查命令及尚存限制。

## 5. 需要确认的协议问题

以下问题会改变 RTL 行为，文档或当前端口尚不足以安全决定：

1. **扩展范围**：其他参数组合、窄传输、非对齐地址、任意 `WSTRB`、零长度读写、I/O/Message/ATS 和多笔在途不属于首版；后续需要时单独定义。
2. **Target Function 分配**：CQ 文档的示例只列出 4 个 PF 和 4 个 VF。本项目首版按顶层实际配置划分 8-bit 空间：PF0..PF7 使用 0..7；VF0..VF247 使用 8..255。`vfunc_active=1` 时将 `8 + vfunc_num` 写入 CQ `[111:104]`，否则使用 `func_num`。`vfunc_num>247` 时 AW/AR 暂不握手。其他没有可用映射的字段置零。Tag 只取低 8 bit。
3. **错误与异常**：首版按 CC descriptor 中 SC/UR/CA 状态输出 AXI OKAY/DECERR/SLVERR，RRS、discontinue 和 parity 错误的系统级恢复策略未定义；需要扩展时另行确认。
4. **Split Completion**：同一读请求可由多个按顺序到达的 CC 包完成；用 Byte Count 判断剩余数据。首版要求这些包的有效数据合计等于原 AR 请求字节数。
