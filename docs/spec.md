# Control Unit & Instruction Decode Specification

RV32I 5-Stage Pipeline — HUST Computer Architecture Project

---

## 1. RV32I Instruction Formats

All RV32I instructions are 32 bits wide. Six encoding formats are used; the opcode
field `[6:0]` is always in the same position.

```
 31      25 24   20 19   15 14  12 11      7 6       0
┌──────────┬───────┬───────┬──────┬─────────┬─────────┐
│  funct7  │  rs2  │  rs1  │funct3│   rd    │ opcode  │  R-type
└──────────┴───────┴───────┴──────┴─────────┴─────────┘

┌────────────────┬───────┬──────┬─────────┬─────────┐
│   imm[11:0]    │  rs1  │funct3│   rd    │ opcode  │  I-type
└────────────────┴───────┴──────┴─────────┴─────────┘

┌──────────┬───────┬───────┬──────┬─────────┬─────────┐
│ imm[11:5]│  rs2  │  rs1  │funct3│imm[4:0] │ opcode  │  S-type
└──────────┴───────┴───────┴──────┴─────────┴─────────┘

┌─┬──────────┬───────┬───────┬──────┬────────┬─┬─────────┐
│i│imm[10:5] │  rs2  │  rs1  │funct3│imm[4:1]│j│ opcode  │  B-type
└─┴──────────┴───────┴───────┴──────┴────────┴─┴─────────┘
  [31]  [30:25]                       [11:8] [7]
  imm[12]                            imm[4:1] imm[11]

┌─────────────────────────────┬─────────┬─────────┐
│         imm[31:12]          │   rd    │ opcode  │  U-type
└─────────────────────────────┴─────────┴─────────┘

┌─┬──────────┬─┬──────────┬─────────┬─────────┐
│i│imm[10:1] │j│imm[19:12]│   rd    │ opcode  │  J-type
└─┴──────────┴─┴──────────┴─────────┴─────────┘
  [31]  [30:21] [20]  [19:12]
  imm[20]      imm[11] imm[19:12]
```

### Field Summary

| Field | Bits | Description |
|-------|------|-------------|
| `opcode` | `[6:0]` | Instruction class (drives `main_decoder`) |
| `rd` | `[11:7]` | Destination register |
| `funct3` | `[14:12]` | Operation variant within a class |
| `rs1` | `[19:15]` | Source register 1 |
| `rs2` | `[24:20]` | Source register 2 |
| `funct7` | `[31:25]` | Extended opcode (R-type only; bit 5 disambiguates SUB/SRA/SRAI) |

---

## 2. Opcode Map

| Opcode | Binary | Format | Instruction class |
|--------|--------|--------|-------------------|
| R-type | `0110011` | R | `add sub and or xor sll srl sra slt sltu` |
| I-arith | `0010011` | I | `addi andi ori xori slti sltiu slli srli srai` |
| Load | `0000011` | I | `lw` (lb/lh/lbu/lhu — address path identical) |
| Store | `0100011` | S | `sw` (sb/sh — address path identical) |
| Branch | `1100011` | B | `beq bne blt bge bltu bgeu` |
| JAL | `1101111` | J | `jal` |
| JALR | `1100111` | I | `jalr` |
| LUI | `0110111` | U | `lui` |
| AUIPC | `0010111` | U | `auipc` |

---

## 3. Main Decoder (`main_decoder.v`)

The main decoder is a purely combinational block. It receives the 7-bit opcode and
emits the pipeline control signals listed below. All outputs default to 0 / `2'b00`
for unknown opcodes (NOP-like behaviour).

### Control Signal Table

| Opcode class | `RegWrite` | `ImmSrc` | `ALUSrc` | `MemWrite` | `ResultSrc` | `Branch` | `Jump` | `ALUOp` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| R-type | 1 | — | 0 (rs2) | 0 | `00` (ALU) | 0 | 0 | `10` |
| I-arith | 1 | `000` (I) | 1 (imm) | 0 | `00` (ALU) | 0 | 0 | `10` |
| Load | 1 | `000` (I) | 1 (imm) | 0 | `01` (Mem) | 0 | 0 | `00` |
| Store | 0 | `001` (S) | 1 (imm) | 1 | — | 0 | 0 | `00` |
| Branch | 0 | `010` (B) | 0 (rs2) | 0 | — | 1 | 0 | `01` |
| JAL | 1 | `100` (J) | 1 (imm) | 0 | `10` (PC+4) | 0 | 1 | `00` |
| JALR | 1 | `000` (I) | 1 (imm) | 0 | `10` (PC+4) | 0 | 1 | `00` |
| LUI | 1 | `011` (U) | 1 (imm) | 0 | `00` (ALU) | 0 | 0 | `00` |
| AUIPC | 1 | `011` (U) | 1 (imm) | 0 | `00` (ALU) | 0 | 0 | `00` |

### Signal Definitions

| Signal | Width | Meaning |
|--------|-------|---------|
| `RegWrite` | 1 | Write result to `rd` in the register file |
| `ImmSrc` | 3 | Selects immediate format for `imm_extend` (see Section 5) |
| `ALUSrc` | 1 | ALU B-input: `0` = rs2, `1` = sign-extended immediate |
| `MemWrite` | 1 | Enable data memory write (store instructions) |
| `ResultSrc` | 2 | Write-back source: `00`=ALUResult, `01`=ReadData, `10`=PC+4 |
| `Branch` | 1 | Instruction is a conditional branch |
| `Jump` | 1 | Instruction is an unconditional jump (JAL or JALR) |
| `ALUOp` | 2 | Tells the ALU decoder how to select the ALU operation (see Section 4) |

### Note on `ASelD`

`ASelD` (ALU A-input select: `0`=rs1, `1`=PC) is **not** output by the main decoder.
It is computed combinationally in `id_stage` directly from the opcode:

```verilog
assign ASelD = (InstrD[6:0] == 7'b1101111) ||   // JAL
               (InstrD[6:0] == 7'b0010111);      // AUIPC
```

This matches the block diagram in `images/riscv_pipeline.png`, where the control unit
does not have an `ASel` output. LUI also uses `ALUSrc=1` and the ALU decoder selects
`PASS_B`, so the A-input is irrelevant for LUI.

---

## 4. ALU Decoder (`alu_decoder.v`)

The ALU decoder translates `(ALUOp, funct3, funct7, op)` into a 4-bit `ALUControl`
signal consumed by the ALU.

### ALUOp Encoding

| `ALUOp` | Meaning | Source instructions |
|:-------:|---------|---------------------|
| `2'b00` | Always ADD | load, store, JAL, JALR, AUIPC |
| `2'b01` | Always SUB | branch (subtract rs1−rs2 to generate flags) |
| `2'b10` | Decode from `funct3`/`funct7` | R-type, I-type arithmetic |

**Special case — LUI** (`op = 0110111`): always emits `ALUControl = 4'b1010` (PASS_B)
regardless of `ALUOp`. This is checked first (highest priority).

### ALUControl Decoding for `ALUOp = 2'b10`

| `funct3` | `funct7[5]` / `op[5]` | `ALUControl` | Operation |
|:--------:|:---------------------:|:------------:|-----------|
| `000` | `op[5]=1` **and** `funct7[5]=1` | `0001` | SUB (R-type only) |
| `000` | otherwise | `0000` | ADD / ADDI |
| `001` | — | `0101` | SLL / SLLI |
| `010` | — | `1000` | SLT / SLTI |
| `011` | — | `1001` | SLTU / SLTIU |
| `100` | — | `0100` | XOR / XORI |
| `101` | `0` | `0110` | SRL / SRLI |
| `101` | `1` | `0111` | SRA / SRAI |
| `110` | — | `0011` | OR / ORI |
| `111` | — | `0010` | AND / ANDI |

The condition `op[5]=1 && funct7[5]=1` distinguishes R-type SUB from I-type ADDI
(which shares `funct3=000` but has `op[5]=0`, so `funct7` is an immediate, not an
opcode extension).

---

## 5. Immediate Extension (`imm_extend.v`)

The `ImmSrc` signal selects how bits from the 32-bit instruction word are assembled
and sign-extended into a 32-bit value.

| `ImmSrc` | Format | Bit assembly | Used by |
|:--------:|--------|--------------|---------|
| `000` | I-type | `{Instr[31]{20}, Instr[31:20]}` | load, JALR, I-arith |
| `001` | S-type | `{Instr[31]{20}, Instr[31:25], Instr[11:7]}` | store |
| `010` | B-type | `{Instr[31]{20}, Instr[7], Instr[30:25], Instr[11:8], 1'b0}` | branch |
| `011` | U-type | `{Instr[31:12], 12'h000}` | LUI, AUIPC |
| `100` | J-type | `{Instr[31]{12}, Instr[19:12], Instr[20], Instr[30:21], 1'b0}` | JAL |

B-type and J-type immediates have bit 0 forced to `0` because branch and jump targets
must be 2-byte aligned (RISC-V compressed extension) or 4-byte aligned (RV32I only).

---

## 6. ALU Operations (`alu.v`)

### ALUControl Encoding

| `ALUControl` | Mnemonic | Operation | Notes |
|:------------:|----------|-----------|-------|
| `0000` | ADD | `A + B` | |
| `0001` | SUB | `A − B` | Also drives flag outputs |
| `0010` | AND | `A & B` | |
| `0011` | OR | `A \| B` | |
| `0100` | XOR | `A ^ B` | |
| `0101` | SLL | `A << B[4:0]` | Logical shift left |
| `0110` | SRL | `A >> B[4:0]` | Logical shift right (zero-fill) |
| `0111` | SRA | `A >>> B[4:0]` | Arithmetic shift right (sign-fill) |
| `1000` | SLT | `(A <ₛ B) ? 1 : 0` | Signed comparison |
| `1001` | SLTU | `(A <ᵤ B) ? 1 : 0` | Unsigned comparison |
| `1010` | PASS_B | `B` | LUI: `rd = imm` |

### Status Flags

Flags are always derived from the `A − B` subtraction path. They are only
architecturally meaningful when `ALUControl = SUB` (branch comparison).

| Flag | Definition | Used by |
|------|------------|---------|
| `Zero` | `ALUResult == 0` | BEQ, BNE |
| `Neg` | `(A−B)[31]` (sign bit) | BLT, BGE |
| `Overflow` | Signed overflow of `A−B` | BLT, BGE |
| `Carry` | Carry-out of `A−B`; `1` means `A ≥ B` unsigned | BLTU, BGEU |

Overflow detection: `(A[31] & ~B[31] & ~result[31]) | (~A[31] & B[31] & result[31])`

---

## 7. Branch Condition Evaluation (`ex_stage.v`)

The branch condition is evaluated in the EX stage using the ALU flags produced by
subtracting `rs1 − rs2` (`ALUOp = 2'b01`).

| `funct3` | Mnemonic | Condition | ALU flags used |
|:--------:|----------|-----------|----------------|
| `000` | BEQ | `rs1 == rs2` | `Zero` |
| `001` | BNE | `rs1 != rs2` | `~Zero` |
| `100` | BLT | `rs1 <ₛ rs2` | `Neg ^ Overflow` |
| `101` | BGE | `rs1 ≥ₛ rs2` | `~(Neg ^ Overflow)` |
| `110` | BLTU | `rs1 <ᵤ rs2` | `~Carry` |
| `111` | BGEU | `rs1 ≥ᵤ rs2` | `Carry` |

`PCSrcE = JumpE | (BranchE & BranchTaken)` — redirects the PC to `PCTargetE` when
set, and triggers a 2-cycle flush in the hazard unit.

---

## 8. PC Target Computation (`ex_stage.v`)

Two addresses are computed in the EX stage:

| Source | Formula | Used by |
|--------|---------|---------|
| Branch adder | `PCE + ImmExtE` | Branches (B-imm), JAL (J-imm) |
| ALU result | `rs1 + imm` | JALR (rs1+I-imm, then bit 0 cleared) |

Final `PCTargetE` selection:

```
PCTargetE = (JumpE & ~ASelE) ? {ALUResultE[31:1], 1'b0}   // JALR
                              : PCBranchE                   // branch / JAL
```

- **JALR**: `JumpE=1`, `ASelE=0` → ALU computes `rs1+imm`; bit 0 is cleared per the
  RISC-V specification.
- **JAL**: `JumpE=1`, `ASelE=1` → branch adder computes `PC + J-imm` directly.
- **Branch taken**: `BranchE=1`, `BranchTaken=1` → branch adder computes `PC + B-imm`.

---

## 9. Data Path Control Summary (per instruction)

The table below maps every supported instruction to its full set of control signals
as they appear in the EX stage (after passing through the ID/EX pipeline register).

| Instruction | `RegWrite` | `ALUSrc` | `ASel` | `MemWrite` | `ResultSrc` | `Branch` | `Jump` | `ALUControl` | `ImmSrc` |
|-------------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `add/sub/and/or/xor/sll/srl/sra/slt/sltu` | 1 | 0 | 0 | 0 | `00` | 0 | 0 | per funct3/7 | — |
| `addi/andi/ori/xori/slti/sltiu/slli/srli/srai` | 1 | 1 | 0 | 0 | `00` | 0 | 0 | per funct3 | `000` |
| `lw` | 1 | 1 | 0 | 0 | `01` | 0 | 0 | ADD | `000` |
| `sw` | 0 | 1 | 0 | 1 | — | 0 | 0 | ADD | `001` |
| `beq/bne/blt/bge/bltu/bgeu` | 0 | 0 | 0 | 0 | — | 1 | 0 | SUB | `010` |
| `jal` | 1 | 1 | **1** | 0 | `10` | 0 | 1 | ADD | `100` |
| `jalr` | 1 | 1 | 0 | 0 | `10` | 0 | 1 | ADD | `000` |
| `lui` | 1 | 1 | 0 | 0 | `00` | 0 | 0 | PASS_B | `011` |
| `auipc` | 1 | 1 | **1** | 0 | `00` | 0 | 0 | ADD | `011` |

`ASel=1` means the ALU A-input is driven by `PCE` instead of `rs1`. This is set
for JAL (target = PC+J-imm, but see note) and AUIPC (result = PC+U-imm). For JAL,
the ALU computes `PC+J-imm` as the branch target; for AUIPC, the ALU computes
`PC + {imm, 12'b0}` as the writeback result.

---

## 10. Hazard Unit Summary (`hazard_unit.v`)

### Forwarding

| Condition | `ForwardAE` | `ForwardBE` |
|-----------|:-----------:|:-----------:|
| `RegWriteM && RdM≠0 && RdM==Rs1E` | `2'b10` | — |
| `RegWriteM && RdM≠0 && RdM==Rs2E` | — | `2'b10` |
| `RegWriteW && RdW≠0 && RdW==Rs1E` (no EX/MEM match) | `2'b01` | — |
| `RegWriteW && RdW≠0 && RdW==Rs2E` (no EX/MEM match) | — | `2'b01` |
| No match | `2'b00` | `2'b00` |

Forwarding mux in `ex_stage`: `00`=register file, `01`=ResultW (WB), `10`=ALUResultM (MEM).

### Load-Use Stall

**Detection:** `ResultSrcE == 2'b01` (load in EX) **AND** `RdE ≠ 0` **AND** (`RdE == Rs1D` OR `RdE == Rs2D`)

**Action:** `StallF=1`, `StallD=1`, `FlushE=1` — freezes IF and ID, injects NOP into EX.

### Control Hazard Flush

**Detection:** `PCSrcE == 1`

**Action:** `FlushD=1`, `FlushE=1` — squashes the two instructions already in IF/ID and ID/EX.
