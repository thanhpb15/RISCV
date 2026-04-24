# Module Specification: Primitive Modules

**File:** `src/mux.v`, `src/adder.v`, `src/pc.v`  
**Type:** Primitive datapath / control components  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. `mux` — 2-to-1 Multiplexer

**File:** `src/mux.v`

### 1.1 Overview

32-bit 2-to-1 combinational multiplexer. Selects between two 32-bit inputs based on a 1-bit select signal.

### 1.2 Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `d0`   | Input     | 32    | Input selected when `s = 0`. |
| `d1`   | Input     | 32    | Input selected when `s = 1`. |
| `s`    | Input     | 1     | Select signal. |
| `y`    | Output    | 32    | Selected output: `s ? d1 : d0`. |

### 1.3 Logic

```verilog
assign y = s ? d1 : d0;
```

### 1.4 Instantiation Sites

| Instance name  | Module       | Location     | `d0`        | `d1`         | `s`        |
|----------------|--------------|-------------|-------------|--------------|------------|
| `pc_sel_mux`   | `if_stage`   | IF stage    | `PCPlus4F`  | `PCTargetE`  | `PCSrcE`   |
| `alu_src_mux`  | `ex_stage`   | EX stage    | `WriteDataE`| `ImmExtE`    | `ALUSrcE`  |

---

## 2. `mux_3_1` — 3-to-1 Multiplexer

**File:** `src/mux.v`

### 2.1 Overview

32-bit 3-to-1 combinational multiplexer. Selects among three 32-bit inputs based on a 2-bit select signal. Used for writeback source selection and data forwarding.

### 2.2 Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `d0`   | Input     | 32    | Input selected when `s = 2'b00`. |
| `d1`   | Input     | 32    | Input selected when `s = 2'b01`. |
| `d2`   | Input     | 32    | Input selected when `s = 2'b10`. |
| `s`    | Input     | 2     | Select signal. |
| `y`    | Output    | 32    | Selected output. `2'b11` → `0x00000000` (default / unused). |

### 2.3 Logic

```verilog
assign y = (s == 2'b00) ? d0 :
           (s == 2'b01) ? d1 :
           (s == 2'b10) ? d2 : 32'h00000000;
```

### 2.4 Instantiation Sites

| Instance name | Module      | Location  | `d0`         | `d1`        | `d2`         | `s`           |
|---------------|-------------|----------|--------------|-------------|--------------|---------------|
| `fwd_a_mux`   | `ex_stage`  | EX stage | `RD1E` (regfile) | `ResultW` (WB) | `ALUResultM` (MEM) | `ForwardAE` |
| `fwd_b_mux`   | `ex_stage`  | EX stage | `RD2E`       | `ResultW`   | `ALUResultM` | `ForwardBE`   |
| `wb_mux`      | `wb_stage`  | WB stage | `ALUResultW` | `ReadDataW` | `PCPlus4W`   | `ResultSrcW`  |

---

## 3. `adder` — 32-bit Combinational Adder

**File:** `src/adder.v`

### 3.1 Overview

Simple 32-bit unsigned adder. Used for PC+4 computation and branch/JAL target calculation.

### 3.2 Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `a`    | Input     | 32    | First addend. |
| `b`    | Input     | 32    | Second addend. |
| `y`    | Output    | 32    | Sum `a + b`. No carry-out exposed. |

### 3.3 Logic

```verilog
assign y = a + b;
```

Overflow is silently discarded (wraps at 2³²). This is correct for PC arithmetic in a 32-bit address space.

### 3.4 Instantiation Sites

| Instance name   | Module      | `a`      | `b`              | `y`           | Purpose |
|-----------------|-------------|---------|------------------|---------------|---------|
| `pc_inc`        | `if_stage`  | `PCF`   | `32'h00000004`   | `PCPlus4F`    | Sequential next PC |
| `branch_adder`  | `ex_stage`  | `PCE`   | `ImmExtE`        | `PCBranchE`   | Branch / JAL target |

---

## 4. `pc` — Program Counter Register

**File:** `src/pc.v`

### 4.1 Overview

32-bit synchronous register with active-low reset and a load-enable input for pipeline stall support. Holds the byte address of the instruction currently being fetched.

### 4.2 Interface

| Signal   | Direction | Width | Description |
|----------|-----------|-------|-------------|
| `clk`    | Input     | 1     | Rising-edge clock. |
| `rstn`   | Input     | 1     | Active-low synchronous reset. When `0`, `PC` is forced to `0x00000000` on the next rising edge. |
| `en`     | Input     | 1     | Enable. `1` = load `PCNext` on rising edge. `0` = hold current value (stall). |
| `PCNext` | Input     | 32    | Next PC value (from `pc_sel_mux` in `if_stage`). |
| `PC`     | Output    | 32    | Current program counter (registered). |

### 4.3 Behavior

```
On posedge clk:
  if (!rstn):
    PC ← 0x00000000
  else if (en):
    PC ← PCNext
  // else (en=0): hold PC (stall cycle)
```

Reset takes priority over enable. Enable takes priority over hold.

### 4.4 Reset Behavior

On the first rising edge with `rstn = 1` and `en = 1`, the PC advances from `0x00000000` to `PCNext`. Since `PCNext = PCPlus4F = 0x00000004` in steady state (sequential), the pipeline begins executing instructions from address `0x00000000` after reset.

### 4.5 Stall Behavior

When the hazard unit asserts `StallF = 1`, `if_stage` drives `en = 0`. The PC holds, the instruction memory re-presents the same instruction, and the IF/ID register (also stalled) captures the same instruction again — effectively freezing the front of the pipeline for one cycle.
