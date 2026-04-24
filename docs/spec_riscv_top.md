# Module Specification: `riscv_top`

**File:** `src/riscv_top.v`  
**Type:** Top-level integration module  
**License:** Apache-2.0 — Copyright 2026 Pham Bao Thanh

---

## 1. Overview

`riscv_top` is the top-level wrapper for a 5-stage, in-order pipelined RISC-V processor implementing the **RV32I** base integer instruction set. It instantiates all pipeline stages, inter-stage registers, and the hazard unit, connecting them via a flat wire network.

### Supported Instructions

| Category      | Instructions |
|---------------|-------------|
| R-type        | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` |
| I-type arith  | `addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`, `slti`, `sltiu` |
| Load          | `lw` |
| Store         | `sw` |
| Branch        | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Jump          | `jal`, `jalr` |
| Upper imm     | `lui`, `auipc` |

---

## 2. Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`  | Input     | 1     | System clock. All registers are clocked on the rising edge. |
| `rstn` | Input     | 1     | Active-low synchronous reset. Asserted low resets the entire pipeline to a known state. |

> **Note:** Instruction and data memories are embedded; there are no external memory ports on this module.

---

### Stage Responsibilities

| Stage | Module | Primary Function |
|-------|--------|-----------------|
| IF    | `if_stage`    | Fetch instruction from IMEM; compute PC+4; select next PC |
| ID    | `id_stage`    | Decode instruction; read register file; sign-extend immediate |
| EX    | `ex_stage`    | Execute ALU operation; resolve forwarding; evaluate branches |
| MEM   | `mem_stage`   | Access data memory (load/store) |
| WB    | `wb_stage`    | Select writeback value; feed back to register file |

---

## 4. Hazard Handling Summary

All hazard detection and resolution is centralised in `hazard_unit`.

### 4.1 Data Forwarding (RAW hazards)

| Forwarding Path | Source Register | ForwardXE |
|-----------------|----------------|-----------|
| EX/MEM → EX     | `ALUResultM`   | `2'b10`   |
| MEM/WB → EX     | `ResultW`      | `2'b01`   |
| No forward      | Register file  | `2'b00`   |

Priority: EX/MEM takes precedence over MEM/WB.

### 4.2 Load-Use Stall

When a `lw` instruction is followed immediately by an instruction that consumes the loaded value, one pipeline bubble is inserted:

| Control | Action |
|---------|--------|
| `StallF = 1` | PC register holds (no fetch advance) |
| `StallD = 1` | IF/ID register holds |
| `FlushE = 1` | NOP bubble inserted into ID/EX register |

After 1 stall cycle, the result can be forwarded via the MEM/WB → EX path.

### 4.3 Branch / Jump Flush

When a branch is taken or a jump is executed (`PCSrcE = 1`), two wrong-path instructions already in the pipeline are squashed:

| Control | Action |
|---------|--------|
| `FlushD = 1` | IF/ID register cleared → instruction in ID becomes NOP |
| `FlushE = 1` | ID/EX register cleared → instruction in EX becomes NOP |

**Branch penalty: 2 cycles.**

---

## 5. Reset Behavior

Reset is **active-low synchronous**. While `rstn = 0`:

- `pc` register resets to `0x00000000`
- `pipeline_IF_ID` inserts NOP (`0x00000013`, `addi x0, x0, 0`)
- `pipeline_ID_EX`, `pipeline_EX_MEM`, `pipeline_MEM_WB` clear all control signals to 0

The processor begins fetching from address `0x00000000` on the first rising edge after `rstn` is de-asserted.

---

## 6. Module Hierarchy

```
riscv_top
   ├── if_stage
   │   ├── mux              (PC select: PC+4 vs branch target)
   │   ├── pc               (program counter register)
   │   ├── adder            (PC + 4)
   │   └── instruction_memory
   ├── pipeline_IF_ID
   ├── id_stage
   │   ├── control_unit
   │   │   ├── main_decoder
   │   │   └── alu_decoder
   │   ├── register_file
   │   └── imm_extend
   ├── pipeline_ID_EX
   ├── ex_stage
   │   ├── mux_3_1          (ForwardA mux)
   │   ├── mux_3_1          (ForwardB mux)
   │   ├── mux              (ALUSrc mux)
   │   ├── alu
   │   └── adder            (branch target: PC + imm)
   ├── pipeline_EX_MEM
   ├── mem_stage
   │   └── data_memory
   ├── pipeline_MEM_WB
   ├── wb_stage
   │   └── mux_3_1          (ResultSrc mux)
   └── hazard_unit
```

---

## 7. Key Internal Wires

| Wire | Width | From → To | Description |
|------|-------|-----------|-------------|
| `PCSrcE`     | 1  | `ex_stage` → `if_stage`, `hazard_unit` | Branch taken or jump |
| `PCTargetE`  | 32 | `ex_stage` → `if_stage` | Branch / jump destination |
| `ResultW`    | 32 | `wb_stage` → `id_stage`, `ex_stage` | Writeback value (forwarding + regfile write) |
| `ALUResultM` | 32 | `pipeline_EX_MEM` → `ex_stage`, `mem_stage` | EX/MEM forwarding value |
| `ForwardAE`  | 2  | `hazard_unit` → `ex_stage` | rs1 forwarding select |
| `ForwardBE`  | 2  | `hazard_unit` → `ex_stage` | rs2 forwarding select |
| `StallF`     | 1  | `hazard_unit` → `if_stage` | Hold PC |
| `StallD`     | 1  | `hazard_unit` → `pipeline_IF_ID` | Hold IF/ID register |
| `FlushE`     | 1  | `hazard_unit` → `pipeline_ID_EX` | Clear ID/EX register |
| `FlushD`     | 1  | `hazard_unit` → `pipeline_IF_ID` | Clear IF/ID register |

---

## 8. Timing and Performance

- **Clock-to-output** latency for a single instruction: 5 cycles (pipeline fill time)
- **Steady-state throughput**: 1 instruction per cycle (IPC ≈ 1.0 for no-hazard programs)
- **Load-use stall penalty**: 1 cycle
- **Branch / jump penalty**: 2 cycles
- Maximum instruction memory: 4 KB (1024 × 32-bit words, byte addresses `0x000`–`0xFFF`)
- Maximum data memory: 4 KB (1024 × 32-bit words, byte addresses `0x000`–`0xFFF`)
