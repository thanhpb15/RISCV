# Module Specification: Pipeline Inter-Stage Registers

**File:** `src/pipeline_regs.v`  
**Type:** Pipeline registers (4 modules)  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

This file defines four **D flip-flop banks** that separate adjacent pipeline stages. Each register bank captures its inputs on the rising clock edge and holds them stable for the downstream stage throughout the following cycle. Together they implement the inter-stage boundaries of the 5-stage RV32I pipeline:

| Module            | Boundary   | Stall | Flush |
|-------------------|-----------|-------|-------|
| `pipeline_IF_ID`  | IF → ID    | Yes (`en`) | Yes (`clr`) |
| `pipeline_ID_EX`  | ID → EX    | No    | Yes (`clr`) |
| `pipeline_EX_MEM` | EX → MEM   | No    | No    |
| `pipeline_MEM_WB` | MEM → WB   | No    | No    |

**Reset policy:** Active-low synchronous (`rstn = 0` forces all registers to 0 / NOP).  
**Stall policy:** `en = 0` holds all register values unchanged (PC and IF/ID only).  
**Flush policy:** `clr = 1` resets the register to NOP values; takes priority over `en`.

---

## 2. `pipeline_IF_ID`

### 2.1 Purpose

Captures the instruction word and PC values produced by `if_stage` and presents them to `id_stage` in the next cycle.

### 2.2 Interface

| Signal     | Dir | Width | Description |
|------------|-----|-------|-------------|
| `clk`      | In  | 1     | Rising-edge clock. |
| `rstn`     | In  | 1     | Active-low synchronous reset. Loads NOP instruction. |
| `en`       | In  | 1     | Register enable. `1` = update; `0` = hold (load-use stall). Connected to `~StallD`. |
| `clr`      | In  | 1     | Flush override. `1` = load NOP regardless of `en`. Connected to `FlushD`. |
| `InstrF`   | In  | 32    | Fetched instruction from IF stage. |
| `PCF`      | In  | 32    | Current PC from IF stage. |
| `PCPlus4F` | In  | 32    | PC+4 from IF stage. |
| `InstrD`   | Out | 32    | Registered instruction presented to ID stage. |
| `PCD`      | Out | 32    | Registered PC presented to ID stage. |
| `PCPlus4D` | Out | 32    | Registered PC+4 presented to ID stage. |

### 2.3 Behavior

```
Priority (clr > en > hold):

On posedge clk:
  if (!rstn || clr):
    InstrD   ← 0x00000013   // NOP: addi x0, x0, 0
    PCD      ← 0x00000000
    PCPlus4D ← 0x00000000
  else if (en):
    InstrD   ← InstrF
    PCD      ← PCF
    PCPlus4D ← PCPlus4F
  // else: en=0, hold all outputs (stall cycle)
```

**NOP Encoding:** `0x00000013` = `addi x0, x0, 0` — decodes to no register write, no memory write; completely inert in all later stages.

### 2.4 Hazard Connections

| Hazard    | Signal     | Source       | Effect |
|-----------|------------|--------------|--------|
| Load-use  | `en = ~StallD` | Hazard unit | Hold IF/ID (same instruction re-decoded) |
| Branch/Jump | `clr = FlushD` | Hazard unit | Squash wrong-path instruction in ID |

---

## 3. `pipeline_ID_EX`

### 3.1 Purpose

Captures all control signals, register-file read data, sign-extended immediate, PC, PC+4, and register addresses from the ID stage and presents them to the EX stage.

### 3.2 Interface

**Inputs (from ID stage / `riscv_top` wiring):**

| Signal       | Width | Description |
|--------------|-------|-------------|
| `clk`        | 1     | Rising-edge clock. |
| `rstn`       | 1     | Active-low synchronous reset. |
| `clr`        | 1     | Flush. `1` = insert NOP bubble (all control signals → 0, `RdE → x0`). Connected to `FlushE`. |
| `RegWriteD`  | 1     | Destination register write enable. |
| `MemWriteD`  | 1     | Data memory write enable. |
| `ALUSrcD`    | 1     | ALU B-input select. |
| `JumpD`      | 1     | Unconditional jump flag. |
| `BranchD`    | 1     | Conditional branch flag. |
| `ASelD`      | 1     | ALU A-input override (PC for JAL/AUIPC). |
| `ResultSrcD` | 2     | Writeback source selector. |
| `ALUControlD`| 4     | ALU operation code. |
| `Funct3D`    | 3     | Branch-condition selector. |
| `RD1D`       | 32    | rs1 register value. |
| `RD2D`       | 32    | rs2 register value. |
| `ImmExtD`    | 32    | Sign-extended immediate. |
| `PCD`        | 32    | PC of this instruction. |
| `PCPlus4D`   | 32    | PC+4 of this instruction. |
| `Rs1D`       | 5     | rs1 address (for hazard unit forwarding check). |
| `Rs2D`       | 5     | rs2 address (for hazard unit forwarding check). |
| `RdD`        | 5     | Destination register address. |

**Outputs (suffix E — to EX stage):**

All inputs are registered with the same name and suffix changed from `D` to `E`. See `ex_stage` spec for how each signal is used.

### 3.3 Behavior

```
On posedge clk:
  if (!rstn || clr):
    All control signals ← 0    // effective NOP bubble
    RdE ← x0                   // prevents hazard unit from forwarding bubble
    All data registers ← 0
  else:
    All outputs ← corresponding D-stage inputs
```

Setting `RdE = x0` on flush is critical: the hazard unit checks `RdE != x0` before enabling forwarding, so a flushed bubble cannot cause a spurious forward.

### 3.4 Hazard Connections

| Hazard      | Signal    | Source       | Effect |
|-------------|-----------|--------------|--------|
| Load-use    | `clr = FlushE` | Hazard unit | Insert NOP bubble — stall cycle passes a NOP through EX |
| Branch/Jump | `clr = FlushE` | Hazard unit | Squash wrong-path instruction in EX |

---

## 4. `pipeline_EX_MEM`

### 4.1 Purpose

Captures EX-stage outputs and passes them to the MEM stage. Carries the EX/MEM forwarding value (`ALUResultM`) which feeds back to `ex_stage` via `hazard_unit`.

### 4.2 Interface

**Inputs (from EX stage / `riscv_top`):**

| Signal       | Width | Description |
|--------------|-------|-------------|
| `clk`        | 1     | Rising-edge clock. |
| `rstn`       | 1     | Active-low synchronous reset. |
| `RegWriteE`  | 1     | Register write enable (carried to WB). |
| `MemWriteE`  | 1     | Memory write enable (used in MEM stage). |
| `ResultSrcE` | 2     | Writeback source selector (carried to WB). |
| `ALUResultE` | 32    | ALU result (effective address for load/store; value for ALU ops). |
| `WriteDataE` | 32    | Store data (forwarded rs2). |
| `PCPlus4E`   | 32    | PC+4 (for JAL/JALR return address). |
| `RdE`        | 5     | Destination register address. |

**Outputs (suffix M — to MEM stage / `riscv_top`):**

All inputs registered and presented as `RegWriteM`, `MemWriteM`, `ResultSrcM`, `ALUResultM`, `WriteDataM`, `PCPlus4M`, `RdM`.

### 4.3 Reset Behavior

All registers cleared to 0 on `rstn = 0`. There is no flush or stall control — this register always advances.

---

## 5. `pipeline_MEM_WB`

### 5.1 Purpose

Captures MEM-stage outputs and passes them to the WB stage. Carries the MEM/WB forwarding value (`ALUResultW` and `ReadDataW`) which feeds `ResultW` back to EX.

### 5.2 Interface

**Inputs (from MEM stage / `riscv_top`):**

| Signal       | Width | Description |
|--------------|-------|-------------|
| `clk`        | 1     | Rising-edge clock. |
| `rstn`       | 1     | Active-low synchronous reset. |
| `RegWriteM`  | 1     | Register write enable (forwarded to WB). |
| `ResultSrcM` | 2     | Writeback source selector (forwarded to WB). |
| `ALUResultM` | 32    | ALU result from EX/MEM. |
| `ReadDataM`  | 32    | Data read from DMEM (for load instructions). |
| `PCPlus4M`   | 32    | PC+4 (for JAL/JALR). |
| `RdM`        | 5     | Destination register address. |

**Outputs (suffix W — to WB stage / `riscv_top`):**

All inputs registered and presented as `RegWriteW`, `ResultSrcW`, `ALUResultW`, `ReadDataW`, `PCPlus4W`, `RdW`.

### 5.3 Reset Behavior

All registers cleared to 0 on `rstn = 0`. There is no flush or stall control — this register always advances.

---

## 6. Signal Propagation Summary

The table below shows how each key piece of information travels through all pipeline registers from its origin to its consumer:

| Information    | Origin    | IF/ID | ID/EX | EX/MEM | MEM/WB | Consumer |
|----------------|-----------|-------|-------|--------|--------|----------|
| `Instr`        | IMEM      | ✓     | (decoded) | —  | —      | ID stage |
| `PC`           | PC reg    | ✓     | ✓     | —      | —      | EX (branch addr, AUIPC) |
| `PC+4`         | Adder     | ✓     | ✓     | ✓      | ✓      | WB (JAL/JALR return addr) |
| `RD1`, `RD2`   | Reg file  | —     | ✓     | —      | —      | EX stage |
| `ImmExt`       | Imm ext   | —     | ✓     | —      | —      | EX stage |
| `ALUResult`    | ALU       | —     | —     | ✓      | ✓      | MEM addr, WB result, EX forward |
| `WriteData`    | rs2 (fwd) | —     | —     | ✓      | —      | DMEM write data |
| `ReadData`     | DMEM      | —     | —     | —      | ✓      | WB (load result) |
| `Rd`           | Instr     | —     | ✓     | ✓      | ✓      | Reg file write, hazard check |
| `RegWrite`     | Ctrl unit | —     | ✓     | ✓      | ✓      | Hazard unit, reg file WE |
| `ResultSrc`    | Ctrl unit | —     | ✓     | ✓      | ✓      | WB mux select |
