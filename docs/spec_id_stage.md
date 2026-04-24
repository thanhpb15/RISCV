# Module Specification: `id_stage`

**File:** `src/id_stage.v`

**Type:** Pipeline stage (Instruction Decode)

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`id_stage` implements the **Instruction Decode (ID)** stage of the 5-stage RV32I pipeline. It decodes the 32-bit instruction word into control signals, reads both source registers from the register file, and sign-extends the embedded immediate operand. All outputs are purely combinational and are registered by the downstream `pipeline_ID_EX` register.

---

## 2. Interface

### 2.1 Inputs

| Signal      | Width | Source           | Description |
|-------------|-------|------------------|-------------|
| `clk`       | 1     | Top-level        | Rising-edge clock (used only by the register file write port). |
| `RegWriteW` | 1     | WB stage         | Write-enable for register file. `1` = write `ResultW` into `RdW`. |
| `RdW`       | 5     | MEM/WB register  | Destination register address being written back. |
| `ResultW`   | 32    | WB stage         | Writeback value (ALU result / memory data / PC+4). |
| `InstrD`    | 32    | IF/ID register   | 32-bit instruction word to decode. |

### 2.2 Outputs — Control Signals

| Signal        | Width | Destination      | Description |
|---------------|-------|------------------|-------------|
| `RegWriteD`   | 1     | ID/EX register   | `1` = this instruction writes to a destination register. |
| `MemWriteD`   | 1     | ID/EX register   | `1` = this instruction writes to data memory (store). |
| `JumpD`       | 1     | ID/EX register   | `1` = unconditional jump (`jal` or `jalr`). |
| `BranchD`     | 1     | ID/EX register   | `1` = conditional branch instruction. |
| `ALUSrcD`     | 1     | ID/EX register   | ALU B-input select. `0` = rs2 register value; `1` = sign-extended immediate. |
| `ASelD`       | 1     | ID/EX register   | ALU A-input override. `0` = rs1; `1` = PC (for `jal` and `auipc`). |
| `ResultSrcD`  | 2     | ID/EX register   | Writeback source select. See encoding table below. |
| `ALUControlD` | 4     | ID/EX register   | ALU operation code. See `alu.v` spec. |

### 2.3 Outputs — Data

| Signal    | Width | Destination     | Description |
|-----------|-------|-----------------|-------------|
| `RD1D`    | 32    | ID/EX register  | Register file read data for rs1. |
| `RD2D`    | 32    | ID/EX register  | Register file read data for rs2. |
| `ImmExtD` | 32    | ID/EX register  | Sign-extended 32-bit immediate. |

### 2.4 Outputs — Register Addresses

| Signal   | Width | Destination                    | Description |
|----------|-------|--------------------------------|-------------|
| `Rs1D`   | 5     | ID/EX register, hazard unit    | Source register 1 address (`Instr[19:15]`). |
| `Rs2D`   | 5     | ID/EX register, hazard unit    | Source register 2 address (`Instr[24:20]`). |
| `RdD`    | 5     | ID/EX register                 | Destination register address (`Instr[11:7]`). |
| `Funct3D`| 3     | ID/EX register                 | `Instr[14:12]` — forwarded to EX for branch condition decode. |

---

## 3. ResultSrcD Encoding

| Value   | Writeback Source | Used By |
|---------|-----------------|---------|
| `2'b00` | ALU result      | R-type, I-type arith, LUI, AUIPC |
| `2'b01` | Data memory     | Load instructions (lw) |
| `2'b10` | PC + 4          | JAL, JALR (return address) |

---

## 4. Functional Description

### 4.1 Instruction Field Extraction

Register addresses and `Funct3` are extracted directly from fixed bit positions defined by the RISC-V ISA:

| Field    | Bits         |
|----------|--------------|
| `Rs1D`   | `Instr[19:15]` |
| `Rs2D`   | `Instr[24:20]` |
| `RdD`    | `Instr[11:7]`  |
| `Funct3D`| `Instr[14:12]` |

### 4.2 ASelD — PC Override for JAL and AUIPC

`ASelD` is derived directly from the opcode rather than the control unit to avoid adding an extra output to `main_decoder`:

```
ASelD = (Instr[6:0] == 7'b1101111)   // JAL
      | (Instr[6:0] == 7'b0010111)   // AUIPC
```

When `ASelD = 1`, the EX stage uses PC instead of rs1 as the ALU A-input.

### 4.3 Control Signal Generation

The `control_unit` sub-module decodes `op` (bits `[6:0]`), `funct3` (bits `[14:12]`), and `funct7` (bits `[31:25]`) into all pipeline control signals. It internally chains `main_decoder` and `alu_decoder`.

### 4.4 Register File Read

Two asynchronous reads are performed simultaneously. A **write-through bypass** is implemented: if the WB stage is writing to the same address as a read port in the same clock cycle, the incoming write data is returned directly (models a write-first register file and resolves the WB→ID same-cycle RAW hazard).

| Condition                         | `RD1D` / `RD2D` returned |
|-----------------------------------|--------------------------|
| `A1/A2 == x0`                     | `0x00000000` (hardwired zero) |
| `WE3 && A3 != x0 && A3 == A1/A2` | `WD3` (write-through bypass) |
| Otherwise                         | `registers[A1]` / `registers[A2]` |

### 4.5 Immediate Extension

The `imm_extend` sub-module reads the full 32-bit instruction and the 3-bit `ImmSrc` control signal from `main_decoder` to select and sign-extend one of five immediate formats (I, S, B, U, J).

---

## 5. Sub-Module Instantiations

| Instance  | Module          | Purpose |
|-----------|-----------------|---------|
| `ctrl`    | `control_unit`  | Decode opcode → control signals + ALU op code |
| `rf`      | `register_file` | Two async reads, one sync write with write-through |
| `imm_ext` | `imm_extend`    | Sign-extend immediate field to 32 bits |

---

<!-- ## 6. Timing

All outputs of `id_stage` are **purely combinational** with respect to `InstrD`. They become valid within one combinational delay after `InstrD` is stable at the output of the IF/ID register. The results are captured by the `pipeline_ID_EX` register on the next rising clock edge.

```
       ┌────┐           ┌────┐
 clk   │    └───────────┘    └──
 InstrD ─────[stable D stage]────
 RD1D   ─────[async, valid after reg+combo]────
 ALUControlD──[decoded, valid after reg+combo]─
``` -->

---

## 6. Hazard Interactions

| Hazard       | Signals Used       | Notes |
|--------------|--------------------|-------|
| Load-use     | `Rs1D`, `Rs2D`     | Hazard unit compares with `RdE` to detect load-use; `StallD` holds IF/ID register |
| WB→ID bypass | `RegWriteW`, `RdW` | Resolved internally in register file (write-through) |
| Branch flush  | —                  | `FlushD` from hazard unit resets the IF/ID register to NOP; ID stage simply sees a NOP instruction |
