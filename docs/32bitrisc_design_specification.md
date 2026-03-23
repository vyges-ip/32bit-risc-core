# 32-bit 5-Stage Pipeline RISC Design Specification

## Overview

The 32bitRISC IP is a classic 5-stage pipeline processor optimized for embedded control, secure enclaves, and lightweight compute nodes. The core executes a fixed-width 32-bit instruction set, enforces byte-aligned accesses (no misaligned loads/stores), and integrates a single-cycle branch predictor to minimize pipeline bubbles on short control paths. The design targets TSMC 22nm and FPGA prototyping platforms, offering deterministic latencies and straightforward verification.

## IP Information

- **IP Name**: `vyges/32bitRISC`
- **Version**: 0.1.0
- **License**: Apache-2.0
- **Maturity**: Draft
- **Target**: ASIC (TSMC 22nm), FPGA (Xilinx 7-Series)
- **Design Type**: 5-stage pipelined RISC CPU
- **Process Node**: TSMC 22nm reference
- **Target Frequency**: 600 MHz ASIC / 150 MHz FPGA

## Processor Summary

- **Instruction Width**: 32 bits, fixed
- **Pipeline Stages**: IF, ID, EX, MEM, WB
- **Branch Prediction**: Single-bit static predictor (per-PC history bit)
- **ALU**: 32-bit integer operations (ADD/SUB, logical, shift) plus 16×16 complex multiply with overflow flag
- **Register File**: 32 × 32-bit, dual-read single-write
- **Memory Interface**: Harvard (separate instruction/data AXI-lite or SRAM-style bus)
- **Alignment**: Byte-aligned; misaligned accesses raise precise exceptions

## Module Interface

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | input | 1 | Core clock |
| `rst_n_i` | input | 1 | Active-low reset |
| `imem_addr_o` | output | 32 | Instruction fetch address |
| `imem_data_i` | input | 32 | Instruction word |
| `imem_valid_i` | input | 1 | Instruction valid |
| `dmem_addr_o` | output | 32 | Data address |
| `dmem_wdata_o` | output | 32 | Data write bus |
| `dmem_rdata_i` | input | 32 | Data read bus |
| `dmem_we_o` | output | 4 | Byte write enables |
| `dmem_valid_i` | input | 1 | Data beat valid |
| `irq_i` | input | 4 | Interrupt lines |
| `commit_pc_o` | output | 32 | Retired PC (for debug) |
| `commit_valid_o` | output | 1 | Commit strobe |
| `exception_o` | output | 1 | Precise exception flag |

Signal suffix conventions follow Vyges guidelines (`*_i` inputs, `*_o` outputs).

## Pipeline Architecture

1. **IF**: Instruction fetch with branch predictor lookup; sequential PC increment.
2. **ID**: Register read, immediate decode, hazard detection.
3. **EX**: ALU operations, branch resolution, compare and shift units.
4. **MEM**: Load/store interface; byte enables enforce alignment (non-byte-aligned raises exception).
5. **WB**: Register write-back and CSR updates.

Pipeline hazards managed via:
- Forwarding paths from EX/MEM/WB to ID/EX.
- Stall logic on load-use and branch mispredict recovery.
- Flush on exceptions or mispredict.

## Branch Prediction

- **Type**: Single-bit predictor indexed by PC bits [7:2].
- **Table Size**: 64 entries default (configurable).
- **Update Policy**: On branch resolution, update corresponding bit; mispredict triggers flush at IF/ID.
- **Default Behavior**: Initially predicts not-taken until history set.

## Complex Multiply Unit

- Operands interpreted as packed complex values `{real[31:16], imag[15:0]}`, each component signed 16-bit.
- Computes `(a + jb) × (c + jd)` → `{(ac − bd), (ad + bc)}` with results packed back into the same format.
- Overflow is detected if either component exceeds the ±32767 range; overflow status is latched into CSR `mstatus[0]` for firmware consumption.
- Multiply latency matches ALU cycle (single-cycle), so pipeline hazards follow standard ALU forwarding rules.

## Memory and Alignment Rules

- Instruction fetches are naturally aligned 32-bit words; no half-word mode.
- Data accesses must be byte-aligned (address % 1 == 0); hardware enforces byte enables.
- Misaligned load/store triggers exception:
  - MEM stage detects non-zero alignment condition (e.g., address[1:0] ≠ 0 for word).
  - Pipeline flush and trap to exception vector with cause code.

## Exception Model

- Supported exceptions:
  - Instruction misfetch
  - Illegal opcode
  - Misaligned load/store
  - External interrupt
- Trap vector encoded in CSR `mtvec`; single-level machine mode.
- Precise exceptions: pipeline ensures older instructions retire before trap via squash logic.

## Performance Targets

| Metric | Value | Notes |
|--------|-------|-------|
| Frequency | 600 MHz (TSMC 22nm) | With single-cycle BRAMs |
| CPI (avg) | 1.15 | CoreMark-style mix |
| Branch penalty | 2 cycles mispredict | Flush + refetch |
| Load-use penalty | 1 cycle | When forwarding unavailable |

## Design Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `BP_ENTRIES` | int | 64 | 16–256 | Branch predictor table depth |
| `RESET_VECTOR` | int | 0x0001_0000 | — | Boot address |
| `HAS_MUL` | bit | 0 | 0/1 | Optional multiply unit |
| `IRQ_LINES` | int | 4 | 1–16 | External interrupt lines |

## Verification Strategy

- **SystemVerilog TB**: Instruction stream generator covering branches, hazards, exceptions.
- **Cocotb Tests**: ISA compliance, memory access corner cases, predictor coverage.
- **Reference Model**: ISS in Python for scoreboard.
- **Regression Metrics**:
  - 100% ISA opcode coverage
  - All hazard scenarios (load-use, branch sequences)
  - Misalignment exceptions triggered for word/halfword patterns
  - Predictor accuracy stats recorded

## Tool Flow

- **Synthesis**: Yosys → OpenROAD for TSMC 22nm (via scaled liberty).
- **Simulation**: Verilator, Icarus, Xcelium.
- **FPGA**: Vivado (Artix-7) clocking at 150 MHz.

## Future Enhancements

- 2-bit saturating predictor
- Optional instruction cache
- Debug module (JTAG)

