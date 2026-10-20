# AXI Manager to CQ/CC Bridge Verification Specification

## 1. Verification scope

The environment verifies the default 256-bit configuration described by
`SPEC.md`.  It checks independent single-read and single-write slots, with
memory read and memory write traffic only. Main-regression addresses are 32-byte aligned, AXI size
is 5, write strobes are all ones, and bursts contain 1 to 32 AXI beats.

The testbench is self-checking.  A mismatch terminates the simulation with
`$fatal`; a successful run prints `TEST PASSED`.

## 2. Testbench architecture

- AXI requester driver: drives AW, W, and AR independently and applies B/R
  backpressure.
- CQ monitor/scoreboard: checks descriptor fields, packet boundaries, keep,
  user sideband, and write payload data.
- CC completion driver: creates successful, split, UR, and CA completions and
  applies gaps while respecting ready/valid.
- AXI response scoreboard: checks ID, response status, completion status,
  read data, and `rlast`.
- Protocol assertions: check that CQ, B, and R outputs remain stable while
  valid is asserted and ready is deasserted.
- Transaction logger: records every effective AXI and AXI-Stream handshake in
  `tmp/transactions.log`.  Descriptor log records identify the PCIe request or
  completion type and decode address, length, Requester ID, Tag, function,
  status, and byte count as applicable.

The simulation dumps `tmp/axim2s_tb.vcd`.

## 3. Test points

| ID | Test point | Expected result |
| --- | --- | --- |
| TP01 | Reset defaults | No output valid; request ready is available after reset |
| TP02 | Single-beat memory write | Correct CQ Memory Write descriptor and payload; OKAY B |
| TP03 | Multi-beat memory write | All payload beats ordered; `tlast` only on final beat |
| TP04 | W valid before AW and W gaps | W is retained by requester until accepted; no CQ bubbles |
| TP05 | CQ backpressure | CQ data/user/keep/last stay stable |
| TP06 | B backpressure | B ID/response/status stay stable |
| TP07 | Single-completion memory read | Correct CQ Memory Read descriptor and AXI R data |
| TP08 | Split read completions | Payload is concatenated in order and `rlast` is correct |
| TP09 | CC gaps/backpressure | No payload loss or duplication |
| TP10 | R backpressure | R ID/data/response/status/last stay stable |
| TP11 | UR completion | AXI response is DECERR and completion status is UR |
| TP12 | CA completion | AXI response is SLVERR and completion status is CA |
| TP13 | Simultaneous AW and AR | Both free slots accept independently; CQ arbitrates complete packets |
| TP14 | PF/VF and sideband fields | Target function, Tag, Requester ID, TC, attributes, ATS and TPH decode correctly |
| TP15 | Reset during an incomplete request | Partial context is discarded and a later request succeeds |
| TP16 | Random regression | Random address, ID, sideband, length, data, gaps and backpressure across multiple transactions |

## 4. Pass criteria

All directed and randomized test points must finish without `$fatal`, the
scoreboard error count must remain zero, and the final banner must be
`TEST PASSED`.  Compilation warnings are reviewed separately.  Generated
waveforms and logs must remain below `tmp/` and are not committed.

## 5. Run commands

From the repository root in PowerShell:

```powershell
New-Item -ItemType Directory -Force tmp | Out-Null
. .\oss-cad-suite\environment.ps1
iverilog -g2012 -Wall -s axim2s_tb -o tmp\axim2s_tb.vvp rtl\axim_cq_cc.v tb\axim2s_tb.sv
vvp tmp\axim2s_tb.vvp
```

## 6. CQ payload lane-1 regression

The CQ Memory Write payload starts at `tdata[63:32]` in the beat after
the descriptor, independently of AXI address alignment. Later beats start
at lane 0. The descriptor uses keep `0xff`, SOP=1 and zero payload byte
enables; the first payload beat has zero byte enables in lane 0.

`axim2s_tb` checks repacked data, byte enables, keep and last under random CQ
backpressure, including output stability. `axim_alignment_tb` checks 39 writes
with randomized data: partial first/last Dwords, one-Dword writes, the 7/8-Dword
boundary, Figure 26's 7+8+6 layout (last keep `0x3f`), a 256-Dword write requiring
33 payload beats, and all 32 AXI byte offsets with varying burst lengths and
randomized addresses. Existing aligned, unaligned and split read checks remain.

Compile each bench with `-g2012 -DCC_AXIJ_DMWR_VALUE=0 -s <bench>` using
`rtl/axim_cq_cc.v` and `tb/<bench>.sv`, then run the resulting file with `vvp`.
Use `axim2s_tb`, `axim_alignment_tb`, and `axim_ready_tb` as the bench names.
Keep the compiled files, VCDs and transaction logs under `tmp/`.

## 7. Memory Read CQ layout (Figure 29)

The Memory Read request consists of a single 128-bit descriptor in
`tdata[127:0]`, with no payload beat. Its keep is `0x0f`, TLAST and SOP are
asserted, payload byte enables (`tuser[39:8]`) and discontinue (`tuser[41]`)
are zero. First/Last BE remain valid on the descriptor. Upper data lanes
are unused and driven to zero by this implementation.

`axim2s_tb` checks these fields and descriptor contents at each request
handshake. Its stability monitor checks all CQ outputs while stalled and
requires at least one stalled Memory Read CQ cycle in the regression.

## 8. Independent CQ transmission and CC reception

The read slot and write slot hold separate IDs, descriptors, lengths, alignment
and response state. CQ packet ownership stays fixed until TLAST; CC parsing and
AXI responses run independently. A read Completion still requires its read CQ
descriptor to have been transmitted. Each slot backpressures only its own
direction until the final B/R handshake releases it.

`axim2s_tb.check_cq_cc_independence` checks:

- A CQ write descriptor is held under forced backpressure while an earlier
  read's CC packet and all AXI R beats complete.
- A stalled B response permits a new read CQ packet, split CC packets and R.
- Stalled R data remains stable while a write CQ packet and B complete.
- W arriving before AW does not block a complete read transaction.
- Three pairs with randomized addresses perform simultaneous CQ/CC handshakes,
  with full payload scoreboards and stability assertions.
- AW and AR handshake on the same cycle; different IDs, PF/VF/TPH fields and
  split/poisoned read data remain isolated during concurrent write transmission.
- An error Completion returns DECERR without aborting the concurrent CQ write.
- Reset discards both a read awaiting CC and a write stalled on CQ; fresh write
  and read transactions then complete successfully.

The regression requires nonzero simultaneous CQ/CC and AW/AR handshake coverage.
Waveforms and decoded handshake logs remain in `tmp/axim2s_tb.vcd` and
`tmp/transactions.log`; the console result is captured in `tmp/decouple_check.log`.
