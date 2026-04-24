# Module Specification: `register_file`

**File:** `src/register_file.v`  
**Type:** Register File (datapath storage)  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`register_file` implements the **RV32I general-purpose register file** — 32 registers of 32 bits each (`x0`–`x31`). It provides two independent asynchronous read ports and one synchronous write port. Register `x0` is hardwired to zero by the read logic; writes to `x0` are silently discarded.

A **write-through bypass** (same-cycle forwarding) is implemented: if the WB stage writes to the same address that the ID stage reads in the same clock cycle, the incoming write data is returned directly from the read port. This eliminates the WB→ID same-cycle RAW hazard that the forwarding unit cannot otherwise resolve.

---

## 2. Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`  | Input     | 1     | Rising-edge clock. The write port is synchronous. |
| `WE3`  | Input     | 1     | Write enable for port 3 (from WB stage). `1` = write `WD3` into `registers[A3]`. |
| `A1`   | Input     | 5     | Read address for port 1 (`rs1`). Selects which register to read. |
| `A2`   | Input     | 5     | Read address for port 2 (`rs2`). |
| `A3`   | Input     | 5     | Write address (`rd` from WB stage). |
| `WD3`  | Input     | 32    | Write data (from WB stage `ResultW`). |
| `RD1`  | Output    | 32    | Read data for port 1 (`rs1` value). Asynchronous, combinational. |
| `RD2`  | Output    | 32    | Read data for port 2 (`rs2` value). Asynchronous, combinational. |

---

## 3. Functional Description

### 3.1 Read Logic (Asynchronous)

Both read ports evaluate combinationally each cycle according to the following priority:

```
RD1 =
  (A1 == x0)                        → 0x00000000      // x0 hardwired zero
  (WE3 && A3 != x0 && A3 == A1)     → WD3             // write-through bypass
  otherwise                          → registers[A1]   // normal read

RD2 =
  (A2 == x0)                        → 0x00000000
  (WE3 && A3 != x0 && A3 == A2)     → WD3
  otherwise                          → registers[A2]
```

The write-through bypass models a **write-first** (or "internal forwarding") register file: when WB writes to the same address that ID reads in the same clock cycle, the new value is immediately visible on the read port.

### 3.2 Write Logic (Synchronous)

```
On posedge clk:
  if (WE3 && A3 != x0):
    registers[A3] ← WD3
```

Writes are guarded by `WE3` and the `A3 != x0` constraint. The register array itself has **no hardware reset** — software must initialise registers before use (or avoid reading uninitialised registers). The hazard unit and write-through bypass ensure correct operation during pipeline operation regardless of initial register state.

### 3.3 x0 Handling

`x0` is enforced to zero at the read ports, not in the storage array. This avoids the need for a hardware reset on the entire register array and is consistent with the RISC-V specification that defines x0 as always-zero.

---

## 4. Write-Through Bypass Detail

The bypass is necessary to cover the **WB→ID same-cycle RAW hazard**, which the pipeline's main forwarding unit (in `hazard_unit`) does not handle directly:

```
Cycle N:   WB writes rd = x5 (RegWriteW=1, RdW=5, ResultW=value)
Cycle N:   ID reads rs1 = x5 (A1=5)
```

In this case, the register array still holds the old value from before cycle N. Without the bypass, ID would read a stale value. With the bypass, `WD3` is returned directly.

This is the **only** RAW case that the forwarding unit does not cover, because forwarding only operates on the EX stage operands (not ID reads).

---

## 5. Port Summary

| Port | Type   | Width | Clock   | Notes |
|------|--------|-------|---------|-------|
| Read port 1 (`A1`/`RD1`) | Read  | 5/32 | Async   | rs1 |
| Read port 2 (`A2`/`RD2`) | Read  | 5/32 | Async   | rs2 |
| Write port 3 (`A3`/`WD3`/`WE3`) | Write | 5/32/1 | posedge clk | rd from WB |

---

## 6. Reset / Initialization

There is **no hardware reset** on the register storage array. In simulation, registers may hold unknown (`X`) values before the first write. The testbench or startup code is responsible for ensuring registers are written before being read as meaningful values.

The x0 bypass in the read logic guarantees that x0 always reads as zero regardless of the storage contents.

---