# AXI Manager to CQ/CC Bridge Verification Report

## Result

The self-checking regression passes with Icarus Verilog in SystemVerilog 2012
mode.  The final simulation banner is:

```text
TEST PASSED
```

The regression executed directed single- and multi-beat reads and writes,
W-before-AW timing, random source gaps, CQ/B/R backpressure, a split read
completion, poisoned completion data, UR and CA error completions, simultaneous
AW/AR arbitration checks, reset during an incomplete write, PF/VF sideband
encoding, and six additional fixed-seed randomized transactions.

## RTL issue found and corrected

The first regression detected that a Memory Write CQ descriptor used
`tkeep=8'hff`.  In the selected 256-bit address-aligned mode the descriptor
occupies four low DW lanes and the upper four lanes are padding, so both Memory
Read and Memory Write descriptor beats require `tkeep=8'h0f`.  The RTL was
corrected and the full regression was rerun successfully.

## Generated evidence

- `tmp/transactions.log`: decoded effective AXI, CQ, and CC handshakes.
- `tmp/axim2s_tb.vcd`: complete simulation waveform.

Both files are temporary evidence and are excluded from Git by `/tmp/`.

## Static checks

Verilator lint completed with exit code 0.  It reports no fatal errors.  The
remaining warnings are chiefly the existing top-module/file-name mismatch,
the missing RTL time scale, intentionally unsupported/unused top-level inputs,
and explicit-width warnings in counters and testbench integer expressions.

## Verified configuration and remaining limits

The run verifies the default 256-bit configuration and the first-version
limits in `SPEC.md`: aligned 32-byte AXI beats, full write strobes, Memory Read
and Memory Write only, no more than one request in flight, and ordered split
completions.  It does not claim support for other parameterizations, narrow or
unaligned transfers, sparse strobes, out-of-order completions, or multiple
requests in flight.
