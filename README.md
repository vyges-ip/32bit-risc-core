<div align="center">

<a href="https://vyges.com"><img src="https://vyges.com/assets/images/logo.svg" alt="Vyges" height="60" /></a>

# 32-bit RISC Core

### 5-Stage Pipelined Processor with AXI-Lite Interfaces

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![Vyges IP Catalog](https://img.shields.io/badge/Vyges-IP%20Catalog-4C6EF5.svg)](https://catalog.services.vyges.com) [![Vyges Metadata](https://img.shields.io/badge/Vyges-Metadata-00B4D8.svg)](https://vyges.com/products/vycatalog)

</div>

---

## Overview

A 32-bit, 5-stage pipelined RISC processor core designed for embedded and DSP
applications. Features Harvard architecture with dual AXI-Lite master interfaces,
configurable branch prediction, aligned memory enforcement, and an integrated
16x16 complex multiplier with overflow reporting.

## Key Features

- **Pipeline:** 5-stage in-order (IF, ID, EX, MEM, WB) with full data forwarding
- **Bus:** Harvard AXI-Lite — separate instruction fetch and data load/store ports
- **Branch Predictor:** Single-bit history, configurable depth (16-256 entries)
- **Complex Multiplier:** 16x16 with overflow detection (optional, via `HAS_MUL`)
- **Interrupts:** Configurable 1-16 external interrupt lines
- **Memory:** Aligned access enforcement with precise exceptions
- **Reset:** Dual reset (cold + warm) with internal synchronizer
- **Debug:** Commit interface (PC, valid, exception) for trace and verification
- **Tests:** SystemVerilog and cocotb testbenches (passing)

## Architecture

```
+---------------------------------------------------------------+
|                      32-bit RISC Core                         |
+------------+------------+------------+------------+-----------+
| IF Stage   | ID Stage   | EX Stage   | MEM Stage  | WB Stage  |
| - PC Gen   | - Decode   | - ALU      | - LSU      | - RF Write|
| - BP Table | - RegFile  | - Branch   | - AlignChk | - CSR     |
| - Fetch    | - Hazard   | - Cmplx Mul| - Data Bus | - Commit  |
+------------+------------+------------+------------+-----------+
| Control: hazard unit, flush/stall network, CSR/exception unit |
+---------------------------------------------------------------+
         |                                      |
    AXI-Lite (imem)                       AXI-Lite (dmem)
    Instruction Fetch                     Data Load/Store
```

## Performance

| Target | Frequency | Area |
| ------ | --------- | ---- |
| TSMC 22nm | 600 MHz | 0.25 mm2 |
| SkyWater 130nm | 50-80 MHz (est.) | ~2.5 mm2 (est.) |
| Xilinx Artix-7 | 150 MHz | ~8K LUTs |
| Xilinx Ultrascale+ | 250 MHz (est.) | — |

Estimated gate count: ~50K equivalent gates.

## Parameters

| Parameter | Default | Range | Description |
| --------- | ------- | ----- | ----------- |
| `BP_ENTRIES` | 64 | 16-256 | Branch predictor table depth |
| `IRQ_LINES` | 4 | 1-16 | External interrupt lines |
| `RESET_VECTOR` | 0x00010000 | — | Boot address |
| `HAS_MUL` | true | — | Enable complex multiplier |

## Instruction Set

14 opcodes in 32-bit fixed-width format (R-type, I-type, J-type):

`NOP` `ALUR` `ADDI` `ANDI` `ORI` `XORI` `LD` `ST` `BEQ` `BNE` `JAL` `JR` `CSR` `MUL`

ALU operations: ADD, SUB, AND, OR, XOR, SLT, SLL, SRL.

## Repository Structure

```
rtl/
  stanford_risc_pkg.sv       # Package: opcodes, pipeline structs, control types
  stanford_risc_core.sv      # Top-level core (636 lines)
  register_file.sv           # 32x32 dual-read, single-write register file
  branch_predictor.sv        # Configurable single-bit branch predictor
  complex_mul16.sv           # 16x16 complex multiplier with overflow
tb/
  systemverilog/             # SV testbench and system wrapper
  cocotb/                    # Cocotb regression tests
  programs/                  # Test programs
docs/
  32bitrisc_architecture_specification.md
  32bitrisc_design_specification.md
vyges-metadata.json          # Vyges IP metadata ("nutrition label")
```

## Quick Start

```bash
# Simulate with Verilator
verilator --sv --cc rtl/stanford_risc_pkg.sv rtl/*.sv --top-module stanford_risc_core

# Simulate with Icarus Verilog
iverilog -g2012 -o sim rtl/stanford_risc_pkg.sv rtl/*.sv tb/systemverilog/*.sv
./sim

# Run cocotb tests
cd tb/cocotb && make
```

## Documentation

- [Architecture Specification](docs/32bitrisc_architecture_specification.md) — pipeline stages, data paths, control logic, branch prediction
- [Design Specification](docs/32bitrisc_design_specification.md) — requirements, interface definitions, verification plan

## Acknowledgments

This core was designed by **Kumar Hebbalalu** using the Vyges AI platform:

> "I used the Vyges AI platform to generate RTL for a Stanford-based 32-bit RISC
> processor with a 5-stage pipeline, interrupts, branch prediction, and later a
> full 32-bit multiplier with hazard detection. I described the spec entirely in
> plain English, and the platform asked for clarifications only when needed.
>
> Vyges generated the full repository — architecture docs, RTL, testbench, and
> files — cleanly organized and cross-referenced. The RTL quality was excellent:
> modular, readable, and comparable to what an expert team would build. Even the
> gate-count estimate (TSMC 22 nm) matched our prior silicon results.
>
> Overall, Vyges dramatically accelerates chip-design productivity if you know
> what you want."
>
> — Kumar Hebbalalu

---

**Designed with:** [Vyges](https://vyges.com) | **License:** Apache 2.0 | **IP Catalog:** [VyCatalog](https://catalog.services.vyges.com)
