# Module Specification: `mem_stage` and `wb_stage`

**Files:** `src/mem_stage.v`, `src/wb_stage.v`  
**Type:** Pipeline stages (Memory Access and Write Back)  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## Part 1 — `mem_stage` (Memory Access)

### 1. Overview

`mem_stage` implements the **Memory Access (MEM)** stage of the 5-stage RV32I pipeline. It acts as a thin wrapper around the `data_memory` module, routing control and data signals. For non-memory instructions, the module is transparent — `ALUResultM` passes through the EX/MEM register to MEM/WB without modification.

### 2. Interface

| Signal       | Direction | Width | Description |
|--------------|-----------|-------|-------------|
| `clk`        | Input     | 1     | Rising-edge clock (forwarded to `data_memory`). |
| `rstn`       | Input     | 1     | Active-low synchronous reset (forwarded to `data_memory`). |
| `MemWriteM`  | Input     | 1     | `1` = store operation (write to DMEM); `0` = load or non-memory op. |
| `ALUResultM` | Input     | 32    | Effective byte address computed by the ALU in EX. |
| `WriteDataM` | Input     | 32    | Store data — forwarded rs2 value after any EX-stage forwarding. |
| `ReadDataM`  | Output    | 32    | Data read from DMEM at `ALUResultM` (valid when `ResultSrc = Mem`). |

### 3. Functional Description

#### 3.1 Store Operation (`MemWriteM = 1`)

On the rising clock edge, `WriteDataM` is written to DMEM at word address `ALUResultM[11:2]`. Byte address bits `[1:0]` are ignored (word-aligned only).

#### 3.2 Load Operation (`MemWriteM = 0`)

`ReadDataM` is produced combinationally from DMEM at address `ALUResultM[11:2]`. The result is registered by the downstream `pipeline_MEM_WB` register and becomes `ReadDataW`.

#### 3.3 Non-Memory Instructions

When `MemWriteM = 0` and `ResultSrcM != 2'b01`, the `ReadDataM` output is irrelevant — the WB stage selects `ALUResultW` or `PCPlus4W` instead. No special action is required in this stage.

### 4. Sub-Module Instantiations

| Instance | Module        | Purpose |
|----------|---------------|---------|
| `dmem`   | `data_memory` | 4 KB word-addressed data memory |


---

## Part 2 — `wb_stage` (Write Back)

### 1. Overview

`wb_stage` implements the **Write Back (WB)** stage of the 5-stage RV32I pipeline. It is a purely combinational 3-to-1 multiplexer that selects the value to write into the destination register. The output `ResultW` is fed back to two places:
- `id_stage` (register file write port)
- `ex_stage` (MEM/WB forwarding path)

### 2. Interface

| Signal       | Direction | Width | Description |
|--------------|-----------|-------|-------------|
| `ResultSrcW` | Input     | 2     | Writeback source selector. See encoding below. |
| `ALUResultW` | Input     | 32    | ALU result propagated from EX/MEM → MEM/WB. |
| `ReadDataW`  | Input     | 32    | Data read from DMEM, propagated from MEM/WB. |
| `PCPlus4W`   | Input     | 32    | PC+4, propagated from MEM/WB. Used as return address for JAL/JALR. |
| `ResultW`    | Output    | 32    | Selected writeback value — written to `rd` and forwarded to EX. |

### 3. ResultSrcW Encoding

| `ResultSrcW` | Source      | Used By |
|--------------|-------------|---------|
| `2'b00`      | `ALUResultW` | R-type, I-type arith, LUI, AUIPC |
| `2'b01`      | `ReadDataW`  | Load instructions (`lw`) |
| `2'b10`      | `PCPlus4W`   | `jal`, `jalr` (return address = PC+4) |
| `2'b11`      | `0x00000000` | Undefined (default case in mux) |

### 4. Functional Description

`wb_stage` is a single 3-to-1 32-bit multiplexer. There is no combinational logic other than the selection.

`ResultW` is valid combinationally and:
1. Fed to `register_file.WD3` — written on the next rising edge when `RegWriteW = 1`
2. Fed to `ex_stage` forwarding path (MEM/WB → EX) — used immediately in the same cycle

### 5. Sub-Module Instantiations

| Instance  | Module    | Purpose |
|-----------|-----------|---------|
| `wb_mux`  | `mux_3_1` | 3-to-1 result source multiplexer |

### 6. Timing

`wb_stage` is purely combinational. It has no clock input. The result is available within one mux propagation delay after the MEM/WB register outputs are stable.

### 7. Feedback Paths from WB

| Destination         | Signal       | Purpose |
|---------------------|--------------|---------|
| `register_file.WD3` | `ResultW`    | Synchronous write at WB stage |
| `ex_stage` fwd MUX  | `ResultW`    | MEM/WB → EX forwarding (2-cycle-ahead result) |
| `id_stage` RF bypass| `ResultW`    | Write-through bypass in register file (same-cycle write) |
