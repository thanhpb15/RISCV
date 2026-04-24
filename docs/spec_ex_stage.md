# Module Specification: `ex_stage`

**File:** `src/ex_stage.v`

**Type:** Pipeline stage (Execute) 

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`ex_stage` implements the **Execute (EX)** stage of the 5-stage RV32I pipeline. It is the most complex stage, responsible for:

1. **Operand forwarding** — selecting the correct ALU inputs from register file, MEM-stage, or WB-stage data
2. **ALU execution** — computing the arithmetic/logic result or effective address
3. **Branch target computation** — adding PC and immediate for branch/JAL
4. **Branch condition evaluation** — comparing ALU flags against `Funct3` to determine if a branch is taken
5. **Jump target selection** — distinguishing JALR (ALU result & ~1) from JAL (branch adder output)
6. **PC redirect** — asserting `PCSrcE` to redirect the PC when a branch is taken or a jump executes

---

## 2. Interface

### 2.1 Inputs — Forwarding Control

| Signal      | Width | Source        | Description |
|-------------|-------|---------------|-------------|
| `ForwardAE` | 2     | Hazard unit   | Selects rs1 source. `2'b00`=regfile, `2'b01`=WB, `2'b10`=MEM. |
| `ForwardBE` | 2     | Hazard unit   | Selects rs2 source. Same encoding as `ForwardAE`. |

### 2.2 Inputs — Control Signals (from ID/EX register)

| Signal        | Width | Description |
|---------------|-------|-------------|
| `JumpE`       | 1     | `1` = unconditional jump (`jal`/`jalr`). Forces `PCSrcE = 1`. |
| `BranchE`     | 1     | `1` = conditional branch. `PCSrcE` depends on branch condition. |
| `ALUSrcE`     | 1     | ALU B-input select. `0` = forwarded rs2; `1` = `ImmExtE`. |
| `ASelE`       | 1     | ALU A-input override. `0` = forwarded rs1; `1` = `PCE` (JAL/AUIPC). |
| `ALUControlE` | 4     | ALU operation code (see ALU spec). |
| `Funct3E`     | 3     | Instruction `funct3` field used to select branch comparison type. |

### 2.3 Inputs — Data (from ID/EX register)

| Signal     | Width | Description |
|------------|-------|-------------|
| `RD1E`     | 32    | rs1 value from register file (before forwarding). |
| `RD2E`     | 32    | rs2 value from register file (before forwarding). |
| `ImmExtE`  | 32    | Sign-extended immediate. |
| `PCE`      | 32    | PC of this instruction (used for branch/JAL target and AUIPC). |
| `PCPlus4E` | 32    | PC + 4 of this instruction (passed downstream for JAL/JALR return address). |

### 2.4 Inputs — Forwarded Values

| Signal       | Width | Source              | Description |
|--------------|-------|---------------------|-------------|
| `ALUResultM` | 32    | EX/MEM pipeline reg | EX/MEM forwarding path (1-cycle-ahead result). |
| `ResultW`    | 32    | WB stage output     | MEM/WB forwarding path (2-cycles-ahead result). |

### 2.5 Outputs

| Signal       | Width | Destination             | Description |
|--------------|-------|-------------------------|-------------|
| `PCTargetE`  | 32    | IF stage, IF/ID flush   | Branch / jump destination address. |
| `ALUResultE` | 32    | EX/MEM pipeline reg     | ALU computation result (also used for forwarding from EX/MEM → EX). |
| `WriteDataE` | 32    | EX/MEM pipeline reg     | Forwarded rs2 value to be stored in memory (for `sw`). |
| `PCSrcE`     | 1     | IF stage, hazard unit   | `1` = redirect PC to `PCTargetE`. |

---

## 3. Functional Description


### 3.1 Forwarding MUX (A and B)

Both forwarding muxes are 3-to-1 with identical encoding:

| `ForwardXE` | Source     | Condition |
|-------------|------------|-----------|
| `2'b00`     | `RD1E`/`RD2E` (register file) | No producer in MEM or WB |
| `2'b01`     | `ResultW` (WB stage)           | MEM/WB producer matches Rs1E/Rs2E |
| `2'b10`     | `ALUResultM` (EX/MEM register) | EX/MEM producer matches Rs1E/Rs2E |

`WriteDataE` (the B-path after forwarding, before `ALUSrc` selection) is exposed directly as the store data for `sw`.

### 3.2 A-Input Override (ASel)

| `ASelE` | ALU A-input (`SrcA`) |
|---------|----------------------|
| `0`     | Forwarded rs1 (`SrcAE`) |
| `1`     | `PCE` — used by `jal` and `auipc` |

### 3.3 B-Input Selection (ALUSrc)

| `ALUSrcE` | ALU B-input (`SrcB`) |
|-----------|----------------------|
| `0`       | `WriteDataE` (forwarded rs2) — R-type, branch |
| `1`       | `ImmExtE` — I-type, load, store, JAL, JALR, LUI, AUIPC |

### 3.4 Branch Target Computation

A dedicated adder computes `PCBranchE = PCE + ImmExtE`. This covers:
- B-type branches (B-offset immediate)
- JAL (J-offset immediate, with `ASelE = 1`)

### 3.5 PC Target Selection

| Condition               | `PCTargetE` Source |
|-------------------------|--------------------|
| JALR (`JumpE=1, ASelE=0`) | `{ALUResultE[31:1], 1'b0}` — ALU result with bit 0 cleared per spec |
| JAL / Branch taken        | `PCBranchE` = `PCE + ImmExtE` |

### 3.6 Branch Condition Evaluation

The ALU is configured to perform subtraction (`ALUControlE = SUB`) for branch instructions. The result flags are then interpreted per `Funct3E`:

| `Funct3E` | Instruction | Condition                     |
|-----------|-------------|-------------------------------|
| `3'b000`  | `BEQ`       | `Zero`                        |
| `3'b001`  | `BNE`       | `~Zero`                       |
| `3'b100`  | `BLT`       | `Neg ^ Overflow` (signed)     |
| `3'b101`  | `BGE`       | `~(Neg ^ Overflow)` (signed)  |
| `3'b110`  | `BLTU`      | `~Carry` (unsigned borrow)    |
| `3'b111`  | `BGEU`      | `Carry`                       |

### 3.8 PCSrcE Generation

```
PCSrcE = JumpE | (BranchE & BranchTaken)
```

`PCSrcE = 1` redirects the PC and causes `hazard_unit` to flush two pipeline stages (FlushD, FlushE).

---

## 4. Sub-Module Instantiations

| Instance       | Module     | Purpose |
|----------------|------------|---------|
| `fwd_a_mux`    | `mux_3_1`  | Forward mux for rs1 |
| `fwd_b_mux`    | `mux_3_1`  | Forward mux for rs2 (output is also `WriteDataE`) |
| `alu_src_mux`  | `mux`      | Select ALU B-input: forwarded rs2 vs immediate |
| `alu_unit`     | `alu`      | 32-bit ALU — computes result and status flags |
| `branch_adder` | `adder`    | Compute `PCE + ImmExtE` for branch/JAL target |

---

## 5. Timing

All outputs are **purely combinational** relative to the ID/EX register outputs and the forwarded values from later stages. Results are captured by the `pipeline_EX_MEM` register.

`PCSrcE` is also fed back immediately to `if_stage` and `hazard_unit` in the same cycle, making this a same-cycle feedback path (no additional register delay on the control redirect).
