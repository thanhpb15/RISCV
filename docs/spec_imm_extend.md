# Module Specification: `imm_extend`

**File:** `src/imm_extend.v`

**Type:** Immediate sign-extender (datapath)
 
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`imm_extend` is a purely combinational module that extracts and sign-extends the immediate field embedded in a 32-bit RISC-V instruction to produce a 32-bit signed immediate operand. The RISC-V ISA defines five immediate encoding formats (I, S, B, U, J), each with different bit layouts.

---

## 2. Interface

| Signal   | Direction | Width | Description |
|----------|-----------|-------|-------------|
| `Instr`  | Input     | 32    | Full 32-bit instruction word. |
| `ImmSrc` | Input     | 3     | Immediate format selector (from `main_decoder`). |
| `ImmExt` | Output    | 32    | Sign-extended 32-bit immediate. |

---

## 3. ImmSrc Encoding

| `ImmSrc` | Format | Instructions | Output Expression |
|----------|--------|-------------|-------------------|
| `3'b000` | I-type | `addi`, `lw`, `jalr`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai` | `sext(Instr[31:20])` |
| `3'b001` | S-type | `sw`        | `sext({Instr[31:25], Instr[11:7]})` |
| `3'b010` | B-type | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` | `sext({Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0})` |
| `3'b011` | U-type | `lui`, `auipc` | `{Instr[31:12], 12'b0}` |
| `3'b100` | J-type | `jal`       | `sext({Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0})` |
| Others   | —      | (undefined) | `32'h00000000` |

Sign extension (`sext`) replicates `Instr[31]` (the MSB of the instruction, always the immediate sign bit in RISC-V) into all upper bits.

---

## 4. Immediate Bit Layouts

The RISC-V ISA scrambles the immediate bits to keep `rd`, `rs1`, and `rs2` at fixed positions across all formats. The layouts below show how bits from the 32-bit instruction are assembled:

### 4.1 I-type (12-bit signed immediate)

```
Instr: [31:20] → ImmExt[11:0], sign-extended to [31:12]

ImmExt[31:12] = {20{Instr[31]}}
ImmExt[11:0]  = Instr[31:20]
```

Range: −2048 to +2047.

### 4.2 S-type (12-bit signed immediate)

```
Instr[31:25] → ImmExt[11:5]
Instr[11:7]  → ImmExt[4:0]
Sign-extended from bit 11

ImmExt[31:12] = {20{Instr[31]}}
ImmExt[11:5]  = Instr[31:25]
ImmExt[4:0]   = Instr[11:7]
```

Range: −2048 to +2047.

### 4.3 B-type (13-bit signed immediate, bit 0 = 0)

```
Instr[31]    → ImmExt[12]
Instr[7]     → ImmExt[11]
Instr[30:25] → ImmExt[10:5]
Instr[11:8]  → ImmExt[4:1]
1'b0         → ImmExt[0]    (always 0: 2-byte alignment)

ImmExt[31:13] = {19{Instr[31]}}
ImmExt[12]    = Instr[31]
ImmExt[11]    = Instr[7]
ImmExt[10:5]  = Instr[30:25]
ImmExt[4:1]   = Instr[11:8]
ImmExt[0]     = 1'b0
```

Range: −4096 to +4094 (multiples of 2).

### 4.4 U-type (20-bit upper immediate)

```
Instr[31:12] → ImmExt[31:12]
12'b0        → ImmExt[11:0]

(No sign extension needed — the full 32-bit value is formed directly.)
```

Used for `lui` (rd = imm) and `auipc` (rd = PC + imm).

### 4.5 J-type (21-bit signed immediate, bit 0 = 0)

```
Instr[31]    → ImmExt[20]
Instr[19:12] → ImmExt[19:12]
Instr[20]    → ImmExt[11]
Instr[30:21] → ImmExt[10:1]
1'b0         → ImmExt[0]    (always 0: 2-byte alignment)

ImmExt[31:21] = {11{Instr[31]}}
ImmExt[20]    = Instr[31]
ImmExt[19:12] = Instr[19:12]
ImmExt[11]    = Instr[20]
ImmExt[10:1]  = Instr[30:21]
ImmExt[0]     = 1'b0
```

Range: −1 MiB to +1 MiB − 2 (multiples of 2).

---

## 5. Design Notes

- **Sign bit is always `Instr[31]`:** Regardless of the immediate format, the most significant bit of the instruction word is always the sign bit of the immediate. This is a deliberate RISC-V design choice to simplify hardware.
- **B and J immediates have bit 0 forced to 0:** Branch and jump targets are always at least 2-byte aligned (supporting RV32C compressed instructions). Even without compressed support, this alignment is enforced in the encoding.
- **U-type is not sign-extended:** The 20-bit field occupies the upper bits of the 32-bit word; the lower 12 bits are zero-filled. This is not sign extension.

---

## 6. Timing

Purely combinational. Output `ImmExt` is valid within one mux propagation delay after `Instr` and `ImmSrc` are stable. The result is captured by the `pipeline_ID_EX` register.
