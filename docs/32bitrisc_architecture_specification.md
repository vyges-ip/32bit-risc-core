# 32-bit 5-Stage RISC Architecture Specification

## 1. Purpose

This document translates the design requirements into a concrete architecture for the `vyges/32bitRISC` core. It describes the pipeline composition, control logic, data paths, branch prediction mechanism, memory interface rules, CSR/exceptions, and verification hooks needed to implement a 32-bit fixed-width, 5-stage RISC without misaligned accesses and with a single-bit branch predictor.

## 2. Architectural Goals

- Single-issue, in-order pipeline with deterministic IF→WB flow.
- Byte-aligned load/store enforcement with precise exceptions.
- Simple branch predictor (1-bit history per PC bucket) to reduce fetch bubbles.
- Balanced register file access enabling 600 MHz TSMC 22nm and 150 MHz FPGA prototypes.
- Clear separation between core logic and bus adapters (Harvard-style).

## 3. Top-Level Block Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                        32bitRISC Core                          │
├────────────┬────────────┬────────────┬────────────┬───────────┤
│ IF Stage   │ ID Stage   │ EX Stage   │ MEM Stage  │ WB Stage  │
│ - PC Gen   │ - Decode   │ - ALU      │ - LSU      │ - RF Write│
│ - BP Tbl   │ - RegFile  │ - Branch   │ - AlignChk │ - CSR/SR  │
│ - Fetch    │ - Hazard   │ - CSR Calc │ - Data Bus │ - Commit  │
├────────────┴────────────┴────────────┴────────────┴───────────┤
│ Control: hazard unit, flush/stall network, CSR/exception unit │
└───────────────────────────────────────────────────────────────┘
```

## 4. Pipeline Stages & Logic

### 4.1 Instruction Fetch (IF)

- **PC Generation**: `pc_next` computed from predictor decision or sequential `pc+4`.
- **Branch Predictor Table**: 64-entry array, indexed by `PC[7:2]`, storing 1-bit history.
- **Instruction Memory**: Simple SRAM/AXI-lite master; fetch handshake provides `imem_addr_o`, awaits `imem_valid_i`.
- **Outputs**: IF/ID register holds fetched instruction, PC, predictor bit.

### 4.2 Instruction Decode (ID)

- **Decode Unit**: Immediate extraction, opcode classification, control signal generation.
- **Register File**: 32×32 dual-read (rs1, rs2) and single-write (rd). Writes occur in WB stage, bypassed to ID via forwarding.
- **Hazard Detection**:
  - Load-use: compares destination of MEM stage with ID sources; inserts stall bubble when needed.
  - Branch hazard: if predictor says taken but instruction is unresolved, pipeline waits until EX stage resolves.
- **Outputs**: Control bundle, operand data, immediate, PC to EX stage.

### 4.3 Execute (EX)

- **ALU**: Supports arithmetic (ADD/SUB), logic (AND/OR/XOR), shifts (logical/arith), comparisons.
- **Branch Unit**: Evaluates branch conditions (BEQ, BNE, BLT, BGE) and calculates target address.
- **Branch Resolution**: On mismatch with predicted direction, asserts `flush_if_id` and provides new PC.
- **Complex Multiply**: 16×16 complex multiplier consumes packed `{real, imag}` operands, outputs packed product plus overflow bit.
- **CSR Unit (subset)**: handles CSR reads/writes and immediate effects.

### 4.4 Memory (MEM)

- **Load/Store Unit (LSU)**:
  - Aligns addresses to byte boundaries; computes byte-enable mask.
  - Forbids misaligned access: checks `addr[1:0]` for word/halfword operations; raises exception and squashes pipeline if violation occurs.
- **Data Bus Interface**: Exposes `dmem_addr_o`, `dmem_wdata_o`, `dmem_we_o`, with handshake on `dmem_valid_i`.
- **Store Data Forwarding**: Provides `dmem_wdata_o` from EX results; ensures store data is ready while waiting for memory ack.

### 4.5 Write-Back (WB)

- **Register Write**: Writes result from MEM (load) or EX (ALU) to register file.
- **Commit Reporting**: Drives `commit_pc_o`, `commit_valid_o` for trace/debug.
- **CSR Updates**: Applies trap handling side effects (mtvec jump, mepc capture, etc.).

## 5. Branch Prediction Subsystem
- **Overflow Handling**: Multiplier overflow flag propagated through pipeline and stored in CSR `mstatus[0]`.

- **Predictor Table**: `BP_ENTRIES` × 1-bit array.
- **Index**: `PC[log2(BP_ENTRIES)+1:2]`.
- **Predict**: Taken if entry bit = 1, else not taken. IF stage uses prediction to select `pc_next`.
- **Update**: When branch resolves in EX:
  - If branch taken: set entry bit to 1.
  - If not taken: clear entry bit.
- **Mispredict Recovery**: EX stage flushes IF/ID pipeline registers and injects bubble into ID/EX.

## 6. Memory System & Alignment Enforcement

- **Instruction Interface**: Read-only port; no caches in baseline. can be adapted to AXI-lite with ready/valid.
- **Data Interface**: Byte-enable support allows byte/halfword/word operations (aligned only).
- **Misalign Handling**:
  - `addr[1:0] != 0` for word/halfword triggers exception.
  - LSU asserts `exception_o` with cause code; PC redirected to trap vector.
- **Bus Adapter**: Provided elsewhere; core exports simple request/response wires, enabling integration with different fabrics.

## 7. Control, Hazards, and Stalls

- **Forwarding Paths**:
  - EX/MEM → ID/EX for ALU results.
  - MEM/WB → ID/EX for load data (after data returns).
- **Stall Conditions**:
  - Load-use when forwarding not ready.
  - Memory wait-state (dmem_valid_i deasserted).
  - Branch mispredict flush (1-cycle bubble).
- **Pipeline Registers**: Each stage has register slices holding control/data; flush sets them to NOP/zero.

### 7.1 Stall/Hazard Matrix

| Condition | Detection Stage | Affected Stages | Action | Latency |
|-----------|-----------------|-----------------|--------|---------|
| Load-use hazard (EX load feeding ID consumer) | ID compares rs1/rs2 vs. MEM rd | IF/ID, ID/EX | Insert bubble: hold IF, ID; inject NOP into EX | 1 cycle |
| Memory wait-state (`dmem_valid_i = 0`) | MEM | IF through MEM | Freeze pipeline until data ready | variable |
| Branch mispredict | EX compares prediction vs. actual | IF, ID | Flush IF/ID regs, redirect PC | 2 cycles |
| Exception (misalign/illegal) | EX or MEM | All | Flush younger instructions, vector to handler | >=2 cycles |
| CSR busy (writes pending) | WB | ID | Hold decode until CSR write completes | 1 cycle |
| Multiply in progress (`HAS_MUL=1` multi-cycle option) | EX | IF–EX | Stall pipeline until result ready | configurable |

### 7.2 Timing Diagram (Load-Use Stall Example)

```
Cycle:    N     N+1    N+2    N+3
IF    :  LD     STALL  STALL  ADD
ID    :  LD     ADD    STALL  STALL
EX    :  LD     BUBBLE ADD    ADD
MEM   :  LD     LD     MEM    MEM
WB    :        LD      LD     ADD

Legend:
- LD = load instruction producing register x1
- ADD = instruction consuming x1 (dependent)
- STALL/BUBBLE indicate inserted pipeline hold to wait for load data.
```

## 8. Exception & CSR Architecture

- **CSR Set**: `mstatus`, `mtvec`, `mepc`, `mcause`, `mscratch`, minimal machine mode.
- **Trap Flow**:
  1. MEM detects misaligned access or EX detects illegal instruction.
  2. WB stage writes `mepc`, `mcause`.
  3. PC set to `mtvec`.
  4. Pipeline flushed; next fetch from handler.
- **Return from Trap**: `mret` instruction restores `pc` from `mepc`.
- **Multiply Overflow Flag**: `mstatus[0]` reflects latest multiply overflow; firmware can poll/clear via CSR writes.

## 9. Clock & Reset Domains

- **Clock**: Single synchronous clock `clk_i`.
- **Cold Reset** (`rst_cold_n_i`, external): Forces full state clear (register file, CSRs, pipeline regs, predictor table). Used on power-on; requires re-fetch from `RESET_VECTOR`.
- **Warm Reset** (`rst_warm_n_i` or CSR-triggered): Flushes pipeline and reloads PC from `RESET_VECTOR` but preserves register file and CSRs except status bits. Used for software-initiated restart or watchdog recovery.
- Both reset inputs are asynchronous and synchronized internally via two-flop sync before deassertion.
- Optional clock gating handled outside the core; gating enable must respect warm-reset release ordering.

## 10. Configuration Parameters

- `BP_ENTRIES`: 16–256; defaults 64.
- `HAS_MUL`: includes multiply hardware when 1.
- `IRQ_LINES`: width of `irq_i`.
- `RESET_VECTOR`: start PC; parameter ensures ROM boot flexibility.

## 11. Verification Hooks

- **Commit Interface**: `commit_pc_o`, `commit_valid_o` feed scoreboard.
- **Exception Signals**: `exception_o` with encoded reason for TB checks.
- **Branch Monitor**: Provide optional debug port: `bp_index`, `bp_prediction`, `bp_actual` (guarded by `ifdef DEBUG`).
- **Performance Counters**: Basic event counters (cycles, instructions, mispredicts) accessible via CSR for profiling tests.

## 12. Integration Guidelines

- **Bus Wrappers**: Provide simple adapter modules to map core’s imem/dmem signals onto AXI-lite or SRAM macros.
- **Interrupt Controller**: External aggregator should align `irq_i` width; level-sensitive by default.
- **Clock Gating**: If used, insert gating cell ahead of core; ensure gating release respects pipeline flush to avoid partial transactions.
- **FPGA Notes**: Use dual-port BRAMs for instruction/data memories; keep register file implemented via LUT RAM or distributed RAM for timing.

## 13. Open Items

- Evaluate dual-issue variant (future).
- Expand CSR set for machine timer.
- Investigate optional I-cache and simple BTB for branch targets.

