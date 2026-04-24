# Module Specification: `instruction_memory` and `data_memory`

**Files:** `src/instruction_memory.v`, `src/data_memory.v`  
**Type:** Memory subsystem  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Common Properties

Both memories share the same address space parameters:

| Property       | Value |
|----------------|-------|
| Word width     | 32 bits |
| Depth          | 1024 words |
| Total size     | 4 KB (4096 bytes) |
| Addressing     | Word-addressed: index = `A[11:2]` (byte address bits [1:0] ignored) |
| Alignment      | Word-aligned only (no sub-word access) |

Address bits `[1:0]` are **ignored** — all accesses must be 4-byte aligned. Bits `[11:2]` provide a 10-bit index into the 1024-word array.

---

## Part 1 — `instruction_memory` (IMEM)

### 1. Overview

`instruction_memory` is a read-only, 4 KB instruction memory. It is read **combinationally** (asynchronously) — a new instruction is presented every cycle without a read-enable signal. The memory is loaded by the testbench via `$readmemh` before simulation begins.

### 2. Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `rstn` | Input     | 1     | Active-low synchronous reset. When `0`, `RD` is forced to `0x00000000`. |
| `A`    | Input     | 32    | Byte address. Only bits `[11:2]` are used (10-bit word index). |
| `RD`   | Output    | 32    | Instruction word at address `A`. Combinational / asynchronous. |

### 3. Functional Description

```
RD = (!rstn) ? 32'h00000000 : mem[A[11:2]]
```

During reset (`rstn = 0`), the output is forced to `0x00000000`, preventing the pipeline from executing instructions. On de-assertion of reset, the memory immediately presents the instruction at `PC = 0x00000000`.

### 4. Memory Loading

The memory array `mem[1023:0]` is **not** initialized in the RTL. The testbench must populate it before simulation using hierarchical reference:

```verilog
$readmemh("program.hex", tb.u_top.u_if_stage.imem.mem);
```

Each line in the `.hex` file corresponds to one 32-bit instruction word (little-endian, one word per line in hexadecimal).



`RD` is valid within one combinational delay after `A` is stable. The result is captured by the IF/ID pipeline register on the next rising clock edge.

### 6. Address Mapping

| Byte Address Range | Word Index | Notes |
|--------------------|-----------|-------|
| `0x000`–`0x003`    | 0         | First instruction (reset vector) |
| `0x004`–`0x007`    | 1         | — |
| …                  | …         | — |
| `0xFFC`–`0xFFF`    | 1023      | Last instruction |
| `≥ 0x1000`         | wraps (A[11:2]) | Out-of-range; behavior is implementation-defined |

---

## Part 2 — `data_memory` (DMEM)

### 1. Overview

`data_memory` is a read/write, 4 KB data memory. Reads are **asynchronous** (combinational); writes are **synchronous** (registered on the rising clock edge when `WE = 1`). It is used exclusively by the MEM stage for `lw` and `sw` instructions.

### 2. Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`  | Input     | 1     | Rising-edge clock (for synchronous write). |
| `rstn` | Input     | 1     | Active-low synchronous reset. When `0`, `RD` is forced to `0x00000000`. |
| `WE`   | Input     | 1     | Write enable. `1` = write `WD` to address `A` on the next rising edge. `0` = no write. |
| `A`    | Input     | 32    | Byte address. Only bits `[11:2]` are used. |
| `WD`   | Input     | 32    | Write data (for store instructions — forwarded rs2 value). |
| `RD`   | Output    | 32    | Read data (for load instructions). Combinational. |

### 3. Functional Description

#### 3.1 Read (asynchronous)

```
RD = (!rstn) ? 32'h00000000 : mem[A[11:2]]
```

`RD` is valid combinationally. The result is captured by the MEM/WB pipeline register on the next rising clock edge. It is then selected by the WB stage if `ResultSrc = 2'b01`.

#### 3.2 Write (synchronous)

```
On posedge clk:
  if (WE):
    mem[A[11:2]] ← WD
```

`WD` is the store data from the EX/MEM pipeline register (`WriteDataM`), which already contains the correctly forwarded rs2 value from the EX stage.

### 4. Read-After-Write Behavior

Because writes are synchronous and reads are asynchronous, a store followed immediately by a load to the same address requires **one cycle** between the write and the subsequent read to see the updated value. In this pipeline:
- The store executes in MEM at cycle N (data written at rising edge of cycle N)
- A subsequent load to the same address executes in MEM at cycle N+1 or later
- The forwarding unit provides the correct data via register forwarding if needed

### 5. Initialization

The memory array `mem[1023:0]` has no hardware reset. Initial contents are undefined in RTL. Testbenches may pre-load DMEM using:

```verilog
$readmemh("data.hex", tb.u_top.u_mem_stage.dmem.mem);
```

### 6. Address Mapping

| Byte Address Range | Word Index | Notes |
|--------------------|-----------|-------|
| `0x000`–`0x003`    | 0         | First data word |
| `0x004`–`0x007`    | 1         | — |
| …                  | …         | — |
| `0xFFC`–`0xFFF`    | 1023      | Last data word |

---

## 3. Memory Map Summary

The processor uses a **Harvard architecture** with separate instruction and data memories. They are independent 4 KB spaces each starting at byte address `0x000`:

| Memory | Base Address | Size | Access |
|--------|-------------|------|--------|
| IMEM   | `0x000`     | 4 KB | Read-only, asynchronous |
| DMEM   | `0x000`     | 4 KB | Read (async) / Write (sync) |

Since the two address spaces are separate, there is no aliasing between instruction and data accesses.
