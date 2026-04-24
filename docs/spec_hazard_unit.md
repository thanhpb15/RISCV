# Module Specification: `hazard_unit`

**File:** `src/hazard_unit.v`

**Type:** Control / Hazard Detection Unit

**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`hazard_unit` is a purely combinational module that monitors the pipeline register contents and generates control signals to resolve all three classes of hazards in the 5-stage RV32I pipeline:

| Hazard Class      | Resolution Mechanism | Cost |
|-------------------|---------------------|------|
| RAW data hazard   | Forwarding           | 0 cycles |
| Load-use hazard   | 1-cycle stall + forwarding | 1 cycle |
| Control hazard    | 2-cycle flush        | 2 cycles |

---

## 2. Interface

### 2.1 Inputs

| Signal       | Width | Source               | Description |
|--------------|-------|----------------------|-------------|
| `RegWriteM`  | 1     | EX/MEM pipeline reg  | `1` = instruction in MEM stage writes to a destination register. |
| `RegWriteW`  | 1     | MEM/WB pipeline reg  | `1` = instruction in WB stage writes to a destination register. |
| `PCSrcE`     | 1     | EX stage             | `1` = branch taken or unconditional jump in EX. |
| `RdM`        | 5     | EX/MEM pipeline reg  | Destination register of instruction in MEM stage. |
| `RdW`        | 5     | MEM/WB pipeline reg  | Destination register of instruction in WB stage. |
| `Rs1E`       | 5     | ID/EX pipeline reg   | Source register 1 of instruction in EX stage. |
| `Rs2E`       | 5     | ID/EX pipeline reg   | Source register 2 of instruction in EX stage. |
| `RdE`        | 5     | ID/EX pipeline reg   | Destination register of instruction in EX (used for load-use check). |
| `Rs1D`       | 5     | ID stage             | Source register 1 of instruction in ID stage (load-use check). |
| `Rs2D`       | 5     | ID stage             | Source register 2 of instruction in ID stage (load-use check). |
| `ResultSrcE` | 1     | ID/EX pipeline reg   | `ResultSrcE[0]` — `1` if instruction in EX is a load (`ResultSrc == 2'b01`). |

### 2.2 Outputs

| Signal      | Width | Destination              | Description |
|-------------|-------|--------------------------|-------------|
| `ForwardAE` | 2     | EX stage (ForwardA mux)  | Selects ALU A-input source (rs1 forwarding). |
| `ForwardBE` | 2     | EX stage (ForwardB mux)  | Selects ALU B-input source (rs2 forwarding). |
| `StallF`    | 1     | IF stage (`pc.en`)       | `1` = hold PC register. |
| `StallD`    | 1     | IF/ID register (`en`)    | `1` = hold IF/ID register. |
| `FlushE`    | 1     | ID/EX register (`clr`)   | `1` = clear ID/EX register (insert NOP bubble). |
| `FlushD`    | 1     | IF/ID register (`clr`)   | `1` = clear IF/ID register (squash instruction in ID). |

---

## 3. Forwarding Logic

### 3.1 Forwarding Conditions

Forwarding replaces the stale register-file value with the most recent computed result, sourced from a later pipeline stage. Two forwarding paths are supported:

| Path       | Priority | Source       | ForwardXE |
|------------|----------|--------------|-----------|
| EX/MEM→EX  | High     | `ALUResultM` | `2'b10`   |
| MEM/WB→EX  | Low      | `ResultW`    | `2'b01`   |
| None       | —        | Register file| `2'b00`   |

### 3.2 ForwardAE Logic

```
ForwardAE =
  (Rs1E != x0) && (Rs1E == RdM) && RegWriteM  →  2'b10  // EX/MEM → EX
  (Rs1E != x0) && (Rs1E == RdW) && RegWriteW  →  2'b01  // MEM/WB → EX
  otherwise                                    →  2'b00  // no forward
```

### 3.3 ForwardBE Logic

```
ForwardBE =
  (Rs2E != x0) && (Rs2E == RdM) && RegWriteM  →  2'b10
  (Rs2E != x0) && (Rs2E == RdW) && RegWriteW  →  2'b01
  otherwise                                    →  2'b00
```

### 3.4 Design Rules

- **x0 is never forwarded:** The `RsXE != x0` guard prevents forwarding to x0 reads, since x0 is hardwired zero and the register file already handles it correctly.
- **EX/MEM takes priority:** When two producers both match the consumer (rare but possible in back-to-back producers), the closer producer (EX/MEM) takes precedence.
- **RegWrite guard:** Even if register addresses match, forwarding only occurs when the producer instruction actually writes to a register (`RegWrite = 1`). This prevents spurious forwarding from instructions like branches or stores.

---

## 4. Load-Use Stall Logic

### 4.1 Detection Condition

A load-use hazard occurs when:
1. The instruction currently in EX is a **load** (`ResultSrcE = 1`)
2. The load's destination register (`RdE`) matches one of the source registers of the instruction in ID (`Rs1D` or `Rs2D`)
3. The destination is not x0 (`RdE != x0`)

```
lwStall = ResultSrcE
        && (RdE != x0)
        && ((RdE == Rs1D) || (RdE == Rs2D))
```

### 4.2 Resolution Actions

| Signal   | Value | Effect |
|----------|-------|--------|
| `StallF` | `1`   | PC register holds — same instruction re-fetched next cycle |
| `StallD` | `1`   | IF/ID register holds — same instruction re-decoded next cycle |
| `FlushE` | `1`   | ID/EX register cleared — NOP bubble inserted into EX |

After the stall cycle, the load result is available in the MEM/WB register and the hazard unit forwards it via `MEM/WB → EX` (`ForwardXE = 2'b01`).

<!-- ### 4.3 Stall Timing Example

```
Cycle    : 1      2      3      4      5      6
Stage    :
  IF     : lw     ADD    ADD    ...    ...    ...
  ID     :        lw     lw*    ADD    ...    ...
  EX     :               NOP    lw     ADD    ...
  MEM    :                      NOP    lw     ADD
  WB     :                             NOP    lw   → ResultW forwarded to ADD in EX
```
`*` = stalled (held by StallD); NOP = bubble inserted by FlushE. -->

---

## 5. Flush Logic (Control Hazards)

### 5.1 Detection Condition

A control hazard occurs whenever `PCSrcE = 1`:
- A conditional branch is taken
- `JAL` or `JALR` executes

At this point, two instructions already in the pipeline (in IF and ID) are on the wrong path and must be squashed.

### 5.2 Resolution Actions

| Signal   | Value | Effect |
|----------|-------|--------|
| `FlushD` | `1`   | IF/ID register cleared → instruction in ID replaced by NOP |
| `FlushE` | `1`   | ID/EX register cleared → instruction in EX replaced by NOP |

`FlushE` is asserted for **both** the load-use stall case and the branch/jump case:
```
FlushE = lwStall | PCSrcE
FlushD = PCSrcE
```
<!-- 
### 5.3 Flush Timing Example

```
Cycle    : 1      2      3      4      5
IF       : beq    X      Y      Z      ...
ID       :        beq    X      Y      ...
EX       :               beq    NOP    NOP   ← FlushE, FlushD at cycle 3
MEM      :                      beq    ...
```
Instructions X and Y are squashed; Z (the correct branch target) is fetched in cycle 4. -->

---

## 6. Interaction Between Stall and Flush

`FlushE` is the OR of both stall and flush conditions. This is correct because:
- During a load-use stall, the instruction that was in EX (the consumer) moves to a bubble, and a new copy of the consumer remains in ID (held by StallD).
- During a branch/jump, the wrong-path instructions in EX and ID must both be squashed.

There is no scenario where `StallF`/`StallD` and `PCSrcE` are simultaneously asserted in a correct program execution, because:
- The branch resolves in EX (cycle N+2 after fetch), while the load-use stall affects IF/ID (cycles N and N+1 before the consumer reaches EX).
- The hazard unit still handles this case correctly via `FlushE = lwStall | PCSrcE`.

---

## 7. Summary Truth Table

| Condition           | `StallF` | `StallD` | `FlushE` | `FlushD` | `ForwardXE` |
|---------------------|----------|----------|----------|----------|-------------|
| No hazard           | 0        | 0        | 0        | 0        | `00`        |
| Load-use stall      | 1        | 1        | 1        | 0        | `00` (next cycle: `01`) |
| Branch/Jump taken   | 0        | 0        | 1        | 1        | (per RAW logic) |
| RAW, EX/MEM→EX      | 0        | 0        | 0        | 0        | `10`        |
| RAW, MEM/WB→EX      | 0        | 0        | 0        | 0        | `01`        |
