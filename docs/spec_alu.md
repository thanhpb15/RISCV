# Module Specification: `alu`

**File:** `src/alu.v`

**Type:** Arithmetic Logic Unit (datapath)

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`alu` is a 32-bit combinational Arithmetic Logic Unit supporting all arithmetic and logic operations required by the RV32I base integer instruction set. It produces a 32-bit result and four status flags derived from a parallel subtraction path. Flags are always valid from the A−B path and are used by the EX stage to evaluate branch conditions.

---

## 2. Interface

| Signal      | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `A`         | Input     | 32    | First operand (rs1 value after forwarding and ASel mux). |
| `B`         | Input     | 32    | Second operand (forwarded rs2 or sign-extended immediate). |
| `ALUControl`| Input     | 4     | Operation select. See encoding table below. |
| `ALUResult` | Output    | 32    | Computed result. |
| `Zero`      | Output    | 1     | `1` when `ALUResult == 0`. Used for BEQ. |
| `Neg`       | Output    | 1     | Sign bit of `A − B`. Used for BLT / BGE. |
| `Overflow`  | Output    | 1     | Signed overflow of `A − B`. Used with `Neg` for BLT / BGE. |
| `Carry`     | Output    | 1     | Carry-out (borrow bit) of `A − B`. `1` means `A ≥ B` (unsigned). Used for BGEU/BLTU. |

---

## 3. ALUControl Encoding

| `ALUControl` | Operation | Expression           | RV32I Instructions |
|-------------|-----------|----------------------|-------------------|
| `4'b0000`   | ADD       | `A + B`              | `add`, `addi`, `lw`, `sw`, `jal`, `jalr`, `auipc` |
| `4'b0001`   | SUB       | `A − B`              | `sub`, branch comparison |
| `4'b0010`   | AND       | `A & B`              | `and`, `andi` |
| `4'b0011`   | OR        | `A \| B`             | `or`, `ori` |
| `4'b0100`   | XOR       | `A ^ B`              | `xor`, `xori` |
| `4'b0101`   | SLL       | `A << B[4:0]`        | `sll`, `slli` |
| `4'b0110`   | SRL       | `A >> B[4:0]` (logical) | `srl`, `srli` |
| `4'b0111`   | SRA       | `A >>> B[4:0]` (arithmetic) | `sra`, `srai` |
| `4'b1000`   | SLT       | `(A <s B) ? 1 : 0`  | `slt`, `slti` |
| `4'b1001`   | SLTU      | `(A <u B) ? 1 : 0`  | `sltu`, `sltiu` |
| `4'b1010`   | PASS_B    | `B`                  | `lui` |
| Others      | (unused)  | `0x00000000`         | — |

---

## 4. Functional Description

### 4.1 Subtraction Path (always active)

A 33-bit two's-complement subtraction is computed in parallel with the main result mux:

```
sub_ext[32:0] = {0, A} + {0, ~B} + 1
sub_result    = sub_ext[31:0]
sub_carry     = sub_ext[32]     // 1 → A ≥ B (unsigned), 0 → A < B (borrow)
sub_overflow  = (A[31] & ~B[31] & ~sub_result[31])   // neg − pos = pos
              | (~A[31] & B[31] & sub_result[31])    // pos − neg = neg
sub_neg       = sub_result[31]
```

These signals feed directly into the four status output ports.

### 4.2 Addition Path

```
add_ext[32:0] = {0, A} + {0, B}
add_result    = add_ext[31:0]
```

Used for ADD operations. Carry-out (`add_ext[32]`) is not exposed.

### 4.3 Status Flags

Flags are **always** derived from the subtraction path, regardless of the ALU operation in progress. They are only meaningful to the branch logic when `ALUControl = SUB` (i.e., branch instructions).

| Flag       | Expression                          | Branch Use |
|------------|-------------------------------------|------------|
| `Zero`     | `ALUResult == 0`                    | BEQ (`Zero=1`), BNE (`Zero=0`) |
| `Neg`      | `sub_result[31]`                    | BLT, BGE (signed) |
| `Overflow` | signed overflow of A−B              | BLT (`Neg^Overflow=1`), BGE |
| `Carry`    | carry-out of A−B (no-borrow = A≥B)  | BGEU (`Carry=1`), BLTU (`Carry=0`) |

> **Note:** `Zero` uses `ALUResult` (i.e., it is `1` when the SUB result is `0x00000000`), not just the sub path. For `BEQ`, `ALUControl = SUB`, so `ALUResult = sub_result` and `Zero = (A == B)` as expected.

### 4.4 Shift Operations

For SLL, SRL, and SRA, only the lower 5 bits of `B` are used as the shift amount (`B[4:0]`), which is consistent with the RISC-V specification (shift amount is always modulo 32).

### 4.5 SLT and SLTU

- **SLT (signed):** `result = (sub_neg ^ sub_overflow) ? 1 : 0`. The XOR of the sign flag and the overflow flag correctly handles signed comparison across all operand combinations.
- **SLTU (unsigned):** `result = (~sub_carry) ? 1 : 0`. When `sub_carry = 0`, borrow occurred, meaning `A <u B`.

### 4.6 PASS_B (LUI)

`ALUControl = 4'b1010` passes `B` through unchanged. For `lui rd, imm`, the immediate extender produces `{imm[31:12], 12'b0}` as the B operand, and the ALU simply forwards it to `ALUResult`.

---

## 5. Timing

All outputs are purely combinational. Typical critical path: the 33-bit addition/subtraction followed by the result mux. Shift operations (especially SRA with `$signed`) may also be on the critical path for longer shift amounts.

---

## 6. Branch Condition Reference

The EX stage's branch evaluator (`ex_stage`) maps `Funct3` to the flag combination:

| `Funct3` | Instruction | ALU Flag Expression |
|----------|-------------|---------------------|
| `3'b000` | BEQ         | `Zero` |
| `3'b001` | BNE         | `~Zero` |
| `3'b100` | BLT         | `Neg ^ Overflow` |
| `3'b101` | BGE         | `~(Neg ^ Overflow)` |
| `3'b110` | BLTU        | `~Carry` |
| `3'b111` | BGEU        | `Carry` |

For all branch instructions, `ALUControlE = 4'b0001` (SUB), so the flags reflect the result of `rs1 − rs2`.
