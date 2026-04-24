# Module Specification: `if_stage`

**File:** `src/if_stage.v`

**Type:** Pipeline stage (Instruction Fetch) 

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`if_stage` implements the **Instruction Fetch (IF)** stage of the 5-stage RV32I pipeline. Each cycle it reads one 32-bit instruction from the instruction memory at the address held in the PC register and computes the sequential next address (`PC + 4`). A 2-to-1 multiplexer selects between sequential execution and a branch/jump target.

---

## 2. Interface

| Signal      | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `clk`       | Input     | 1     | Rising-edge clock. |
| `rstn`      | Input     | 1     | Active-low synchronous reset. Resets PC to `0x00000000`. |
| `en`        | Input     | 1     | PC enable. `1` = advance PC on next clock. `0` = hold current PC (load-use stall). Connected to `~StallF` from hazard unit. |
| `PCSrcE`    | Input     | 1     | PC source select from EX stage. `0` = sequential (`PC+4`); `1` = branch/jump target (`PCTargetE`). |
| `PCTargetE` | Input     | 32    | Branch or jump destination address computed in EX stage. |
| `InstrF`    | Output    | 32    | 32-bit instruction word fetched from IMEM at address `PCF`. |
| `PCF`       | Output    | 32    | Current value of the program counter (byte address). |
| `PCPlus4F`  | Output    | 32    | `PCF + 4` — sequential next PC / return address seed. |

---

## 3. Functional Description

### 3.1 PC Selection


| `PCSrcE` | `PCNext`     | Effect               |
|----------|--------------|----------------------|
| `0`      | `PCF + 4`    | Sequential execution |
| `1`      | `PCTargetE`  | Branch taken / JAL / JALR |

`PCSrcE` is driven by the EX stage and is asserted for:
- Any conditional branch whose condition evaluates to true
- `JAL` (unconditional)
- `JALR` (unconditional)

### 3.2 Instruction Fetch

The instruction memory (`instruction_memory`) is read **combinationally** every cycle at address `PCF`. There is no read-enable; the memory always presents an instruction. During reset (`rstn = 0`) the memory returns `0x00000000`.

### 3.3 PC Register

The PC is a 32-bit synchronous register with:
- **Synchronous reset** to `0x00000000` when `rstn = 0`
- **Enable** input — when `en = 0` (stall), the PC holds its current value and the same instruction is re-presented to the IF/ID register next cycle

### 3.4 PC + 4 Adder

A dedicated 32-bit combinational adder computes `PCPlus4F = PCF + 4`. This value is:
- Fed back as the default `PCNext` (sequential path)
- Passed downstream through pipeline registers for use as the JAL/JALR return address

---

## 4. Sub-Module Instantiations

| Instance      | Module               | Purpose |
|---------------|----------------------|---------|
| `pc_sel_mux`  | `mux`                | Select between `PCPlus4F` and `PCTargetE` |
| `pc_reg`      | `pc`                 | 32-bit PC register with synchronous reset and enable |
| `pc_inc`      | `adder`              | Compute `PCF + 4` |
| `imem`        | `instruction_memory` | 4 KB read-only instruction memory |

---



## 5. Reset Behavior

| Signal    | Value after reset (`rstn = 0`) |
|-----------|-------------------------------|
| `PCF`     | `0x00000000`                   |
| `PCPlus4F`| `0x00000004`                   |
| `InstrF`  | `0x00000000` (IMEM returns 0)  |

---

## 6. Hazard Interactions

| Hazard Type   | Signal      | Effect on IF stage |
|---------------|-------------|-------------------|
| Load-use stall| `en = 0`    | PC holds; same instruction fetched again next cycle |
| Branch/Jump   | `PCSrcE = 1`| PCNext redirected to `PCTargetE` on the **next** cycle |

 **Branch latency note:** Because `PCSrcE` is resolved in EX (cycle N+2 relative to the branch fetch), two wrong-path instructions already in the pipeline (in IF and ID) must be flushed by `FlushD` and `FlushE`.
