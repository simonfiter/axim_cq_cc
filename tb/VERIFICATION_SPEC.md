# AXI Manager to CQ/CC Bridge Verification Specification

## 1. Verification scope

The environment verifies the default 256-bit configuration described by
`SPEC.md`.  It treats the bridge as a single-request design and checks memory
read and memory write traffic only.  Addresses are 32-byte aligned, AXI size
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
| TP13 | Simultaneous AW and AR | Alternating arbitration prevents fixed-priority starvation |
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
