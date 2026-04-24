# Module Specification: `control_unit`, `main_decoder`, `alu_decoder`

**Files:** `src/control_unit.v`, `src/main_decoder.v`, `src/alu_decoder.v`

**Type:** Instruction decoder / Control path 

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

The control unit is a two-level combinational decoder instantiated in the ID stage. It translates the three instruction-encoding fields — `op[6:0]`, `funct3[2:0]`, `funct7[6:0]` — into all pipeline control signals.


---

## 2. `control_unit`


| Signal       | Direction | Width | Description |
|--------------|-----------|-------|-------------|
| `op`         | Input     | 7     | Opcode field `Instr[6:0]`. |
| `funct3`     | Input     | 3     | `Instr[14:12]`. |
| `funct7`     | Input     | 7     | `Instr[31:25]`. |
| `RegWrite`   | Output    | 1     | `1` = instruction writes to destination register `rd`. |
| `MemWrite`   | Output    | 1     | `1` = instruction writes to data memory (store). |
| `ALUSrc`     | Output    | 1     | `0` = ALU B-input = rs2; `1` = ALU B-input = sign-extended immediate. |
| `Jump`       | Output    | 1     | `1` = unconditional jump (`jal`, `jalr`). |
| `Branch`     | Output    | 1     | `1` = conditional branch. |
| `ResultSrc`  | Output    | 2     | WB mux select (see encoding below). |
| `ImmSrc`     | Output    | 3     | Immediate format select for `imm_extend` (see encoding below). |
| `ALUControl` | Output    | 4     | ALU operation code (see `alu` spec). |

`ImmSrc` is consumed by `imm_extend` within the ID stage and is not propagated through the ID/EX register.

---

## 3. `main_decoder`

### 3.1 Purpose

`main_decoder` maps the 7-bit opcode to high-level control signals plus a 2-bit `ALUOp` intermediate used by `alu_decoder`.

### 3.2 ALUOp Encoding

| `ALUOp` | Meaning | Instructions |
|---------|---------|-------------|
| `2'b00` | Force ADD | `lw`, `sw`, `jal`, `jalr`, `auipc`, `lui` |
| `2'b01` | Force SUB | Branch instructions (for flag comparison) |
| `2'b10` | Decode from Funct3/Funct7 | R-type, I-type arithmetic |

### 3.3 ResultSrc Encoding

| `ResultSrc` | WB Source    | Instructions |
|-------------|--------------|-------------|
| `2'b00`     | ALU result   | R-type, I-type arith, LUI, AUIPC |
| `2'b01`     | Memory data  | `lw` (load) |
| `2'b10`     | PC + 4       | `jal`, `jalr` (return address) |

### 3.4 ImmSrc Encoding

| `ImmSrc` | Format  | Field bits used | Instructions |
|----------|---------|----------------|-------------|
| `3'b000` | I-type  | `Instr[31:20]`                                      | `addi`, `lw`, `jalr`, `slti`, etc. |
| `3'b001` | S-type  | `Instr[31:25]`, `Instr[11:7]`                       | `sw` |
| `3'b010` | B-type  | `Instr[31]`, `Instr[7]`, `Instr[30:25]`, `Instr[11:8]`, `0` | `beq`, `bne`, etc. |
| `3'b011` | U-type  | `Instr[31:12]`, `12'b0`                             | `lui`, `auipc` |
| `3'b100` | J-type  | `Instr[31]`, `Instr[19:12]`, `Instr[20]`, `Instr[30:21]`, `0` | `jal` |

### 3.5 Opcode Decode Table

| Opcode      | Instruction type | RegWrite | MemWrite | ALUSrc | Branch | Jump | ResultSrc | ImmSrc | ALUOp |
|-------------|-----------------|----------|----------|--------|--------|------|-----------|--------|-------|
| `0110011`   | R-type           | 1        | 0        | 0      | 0      | 0    | `00`      | `000`  | `10`  |
| `0010011`   | I-type arith     | 1        | 0        | 1      | 0      | 0    | `00`      | `000`  | `10`  |
| `0000011`   | Load             | 1        | 0        | 1      | 0      | 0    | `01`      | `000`  | `00`  |
| `0100011`   | Store            | 0        | 1        | 1      | 0      | 0    | `--`      | `001`  | `00`  |
| `1100011`   | Branch           | 0        | 0        | 0      | 1      | 0    | `--`      | `010`  | `01`  |
| `1101111`   | JAL              | 1        | 0        | 1      | 0      | 1    | `10`      | `100`  | `00`  |
| `1100111`   | JALR             | 1        | 0        | 1      | 0      | 1    | `10`      | `000`  | `00`  |
| `0110111`   | LUI              | 1        | 0        | 1      | 0      | 0    | `00`      | `011`  | `00`  |
| `0010111`   | AUIPC            | 1        | 0        | 1      | 0      | 0    | `00`      | `011`  | `00`  |
| Others      | (unknown/NOP)    | 0        | 0        | 0      | 0      | 0    | `00`      | `000`  | `00`  |

---

## 4. `alu_decoder`

### 4.1 Purpose

`alu_decoder` takes the `ALUOp` from `main_decoder` plus `funct3`, `funct7`, and `op` to produce the final 4-bit `ALUControl` for the ALU.

### 4.2 Interface

| Signal       | Direction | Width | Description |
|--------------|-----------|-------|-------------|
| `ALUOp`      | Input     | 2     | Intermediate decode from `main_decoder`. |
| `funct3`     | Input     | 3     | Instruction `funct3` field. |
| `funct7`     | Input     | 7     | Instruction `funct7` field. |
| `op`         | Input     | 7     | Opcode (needed for LUI special case and ADD/SUB disambiguation). |
| `ALUControl` | Output    | 4     | ALU operation select. |

### 4.3 Decode Logic

```
Priority 1: LUI (op == 0110111)
  → ALUControl = PASS_B (4'b1010)

Priority 2: ALUOp == 2'b00 (ADD)
  → ALUControl = ADD (4'b0000)

Priority 3: ALUOp == 2'b01 (branch comparison)
  → ALUControl = SUB (4'b0001)

Priority 4: ALUOp == 2'b10 (R/I-type, decode funct3/funct7)
  funct3:
    000: op[5] && funct7[5] → SUB (R-type sub); else ADD (add/addi)
    001: SLL  (4'b0101)
    010: SLT  (4'b1000)
    011: SLTU (4'b1001)
    100: XOR  (4'b0100)
    101: funct7[5] → SRA (4'b0111); else SRL (4'b0110)
    110: OR   (4'b0011)
    111: AND  (4'b0010)
```

### 4.4 ADD vs SUB Disambiguation

For `funct3 = 3'b000`, both `add` and `sub` share the same funct3. They are distinguished by:

| `op[5]` | `funct7[5]` | Operation |
|---------|-------------|-----------|
| `1`     | `1`         | SUB (R-type only) |
| `1`     | `0`         | ADD (`add`) |
| `0`     | `X`         | ADD (`addi` — I-type has no funct7[5] distinction) |

### 4.5 SRL vs SRA Disambiguation

For `funct3 = 3'b101`:

| `funct7[5]` | Operation |
|-------------|-----------|
| `0`         | SRL (logical, zero-fill) |
| `1`         | SRA (arithmetic, sign-fill) |

This applies to both R-type (`srl`/`sra`) and I-type (`srli`/`srai`).

---

## 5. Timing

All three modules are purely combinational. They are instantiated within `id_stage` and their outputs become valid within one combinational delay after the instruction word (`InstrD`) is stable at the IF/ID register output.
