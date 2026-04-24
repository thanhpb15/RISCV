# RV32I Pipeline — Module Specification Index

**Project:** HUST Computer Architecture — RV32I 5-Stage Pipelined Processor  
**Author:** Pham Bao Thanh  
**License:** Apache-2.0

---

## Architecture Overview

5-stage in-order pipeline implementing the RV32I base integer instruction set:

```
IF → ID → EX → MEM → WB
```

Hazard resolution: data forwarding (EX/MEM→EX, MEM/WB→EX), 1-cycle load-use stall, 2-cycle branch/jump flush.

---

## Specification Files

### Top-Level

| File | Module(s) | Description |
|------|-----------|-------------|
| [spec_riscv_top.md](spec_riscv_top.md) | `riscv_top` | Top-level integration, hierarchy, wire map, hazard summary |

### Pipeline Stages

| File | Module(s) | Stage |
|------|-----------|-------|
| [spec_if_stage.md](spec_if_stage.md) | `if_stage` | Instruction Fetch — PC, IMEM read, PC selection |
| [spec_id_stage.md](spec_id_stage.md) | `id_stage` | Instruction Decode — control signals, register read, immediate extend |
| [spec_ex_stage.md](spec_ex_stage.md) | `ex_stage` | Execute — forwarding, ALU, branch eval, PC redirect |
| [spec_mem_wb_stages.md](spec_mem_wb_stages.md) | `mem_stage`, `wb_stage` | Memory access (DMEM) and writeback mux |

### Pipeline Registers

| File | Module(s) | Description |
|------|-----------|-------------|
| [spec_pipeline_regs.md](spec_pipeline_regs.md) | `pipeline_IF_ID`, `pipeline_ID_EX`, `pipeline_EX_MEM`, `pipeline_MEM_WB` | All four inter-stage registers; stall/flush control |

### Control Path

| File | Module(s) | Description |
|------|-----------|-------------|
| [spec_control_unit.md](spec_control_unit.md) | `control_unit`, `main_decoder`, `alu_decoder` | Opcode decode → control signals + ALU operation |
| [spec_hazard_unit.md](spec_hazard_unit.md) | `hazard_unit` | Forwarding, load-use stall, branch/jump flush |

### Datapath Components

| File | Module(s) | Description |
|------|-----------|-------------|
| [spec_alu.md](spec_alu.md) | `alu` | 32-bit ALU, 11 operations, 4 status flags |
| [spec_register_file.md](spec_register_file.md) | `register_file` | 32×32 register file, async read, sync write, write-through bypass |
| [spec_imm_extend.md](spec_imm_extend.md) | `imm_extend` | 5-format immediate sign-extender (I/S/B/U/J) |
| [spec_memories.md](spec_memories.md) | `instruction_memory`, `data_memory` | 4 KB IMEM (async RO) and 4 KB DMEM (async R / sync W) |
| [spec_primitives.md](spec_primitives.md) | `mux`, `mux_3_1`, `adder`, `pc` | 2:1 mux, 3:1 mux, 32-bit adder, PC register |

---

## Quick Reference: Control Signal Encodings

### ResultSrc (WB mux)
| Value | Source | Used by |
|-------|--------|---------|
| `00` | ALU result | R/I-type, LUI, AUIPC |
| `01` | Memory read | `lw` |
| `10` | PC + 4 | `jal`, `jalr` |

### ForwardXE (hazard unit → ex_stage)
| Value | Source | Condition |
|-------|--------|-----------|
| `00` | Register file | No producer in MEM/WB |
| `01` | `ResultW` (WB) | MEM/WB matches RsE |
| `10` | `ALUResultM` (MEM) | EX/MEM matches RsE |

### ALUControl (alu_decoder → alu)
| Value | Operation |
|-------|-----------|
| `0000` | ADD |
| `0001` | SUB |
| `0010` | AND |
| `0011` | OR |
| `0100` | XOR |
| `0101` | SLL |
| `0110` | SRL |
| `0111` | SRA |
| `1000` | SLT (signed) |
| `1001` | SLTU (unsigned) |
| `1010` | PASS_B (LUI) |

### ImmSrc (main_decoder → imm_extend)
| Value | Format | Instructions |
|-------|--------|-------------|
| `000` | I-type | `addi`, `lw`, `jalr`, shift imm, compare imm |
| `001` | S-type | `sw` |
| `010` | B-type | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| `011` | U-type | `lui`, `auipc` |
| `100` | J-type | `jal` |
