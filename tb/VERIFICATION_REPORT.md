# AXI Manager to CQ/CC Bridge Verification Report

## Result

The CQ Dword-Aligned regression passes with Icarus Verilog in SystemVerilog
2012 mode. All three benches passed:

```text
TEST PASSED
ALIGNMENT TEST PASSED
READY TEST PASSED
```

The regression executed directed single- and multi-beat reads and writes,
W-before-AW timing, random source gaps, CQ/B/R backpressure, a split read
completion, poisoned completion data, UR and CA error completions, simultaneous
AW/AR arbitration checks, reset during an incomplete write, PF/VF sideband
encoding, and six additional fixed-seed randomized transactions.

## CQ layout verified

Memory Write follows Figure 23: the descriptor occupies lanes 0..3 and
DW0..DW3 share the first beat in lanes 4..7. Continuation beats start at lane 0.
Keep and byte enables follow actual payload occupancy. Writes of up to four
Dwords end on the descriptor beat and produce B after its handshake.
Memory Read follows Figure 29: one descriptor beat, keep `0x0f`, TLAST and SOP
asserted, and zero payload byte enables.

Both CQ request types carry the full AXI `misc_info[49:40]` Tag. Descriptor
bits `[103:96]` carry Tag[7:0], bit 79 carries Tag[8], and bit 127 carries
Tag[9]. The main regression checks all four Tag[9:8] combinations for reads
and writes, with CQ stalls and independent concurrent requests. Transaction
logs display full 10-bit CQ and CC Tags. CC bit 30 carries Tag[8] and bit 31
carries Tag[9]; matching compares all ten Tag bits and Requester ID. Directed
tests cover all four Tag[9:8] values, reject twelve packets differing only in
these upper bits (multi-beat SC and single-beat UR), then complete each read
using matching split packets. The new test reproduced false acceptance with
the previous eight-bit matching logic before the RTL correction.

The alignment bench checked 43 writes, including partial byte enables,
1-Dword writes, the 4/5-Dword boundary, 4+8 and 4+8+1 layouts, a 256-Dword
write, and all 32 AXI byte offsets. Every write CQ beat was stalled for two
cycles to check stability and prevent early B responses. The main regression
also checked simultaneous CQ/CC handshakes and stalled read CQ cycles.

## Generated evidence

- `tmp/transactions.log`: decoded effective AXI, CQ, and CC handshakes.
- `tmp/axim2s_tb.vcd`: complete simulation waveform.
- `tmp/axim_alignment_tb.vcd`: alignment regression waveform.
- `tmp/axim_alignment_transactions.log`: alignment handshake log.
- `tmp/cq_dword_main.log`, `tmp/cq_dword_alignment.log`,
  `tmp/cq_dword_ready.log`: simulation results.
- `tmp/cq_dword_synth.log`: Yosys synthesis checks.
- `tmp/tag10_axim2s_tb.log`, `tmp/tag10_axim_alignment_tb.log`,
  `tmp/tag10_axim_ready_tb.log`: passing simulation results after the CQ Tag extension.
- `tmp/cc_tag10_axim2s_tb.log`, `tmp/cc_tag10_axim_alignment_tb.log`,
  `tmp/cc_tag10_axim_ready_tb.log`: simulation results after the CC Tag extension.
- `tmp/cc_tag10_before.log`: failure reproduced with eight-bit CC matching.

These files are temporary evidence and are excluded from Git by `/tmp/`.

## Static checks

Yosys `read_verilog; hierarchy -check; proc; opt; check` completed with exit
code 0 and reported zero problems. Warnings include memory expansion and
procedural loop indices. Icarus compilation warnings include the missing RTL
time scale, array sensitivity, and unused testbench input ports left floating.

## Verified configuration and remaining limits

The run verifies the default 256-bit configuration and the first-version
limits in `SPEC.md`: full-width AXI INCR bursts with arbitrary byte addresses
and contiguous write strobes, CQ Dword-Aligned Memory Read and Memory Write,
one read and one write slot operating independently, and ordered split
completions. It does not claim support for other parameterizations, narrow
transfers, sparse strobes, out-of-order completions, or additional request slots.
