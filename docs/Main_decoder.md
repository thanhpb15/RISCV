# Main Decoder

`src/main_decoder.v` — maps the 7-bit opcode to all pipeline control signals.

`x` / `xx` / `xxx` denote don't-care outputs.

| Instruction | Opcode  | RegWrite | ImmSrc | ALUSrc | MemWrite | ResultSrc | Branch | ALUOp | Jump |
|-------------|---------|:--------:|:------:|:------:|:--------:|:---------:|:------:|:-----:|:----:|
| `lw`        | 0000011 | 1        | 000    | 1      | 0        | 01        | 0      | 00    | 0    |
| `sw`        | 0100011 | 0        | 001    | 1      | 1        | xx        | 0      | 00    | 0    |
| R-type      | 0110011 | 1        | xxx    | 0      | 0        | 00        | 0      | 10    | 0    |
| `beq`–`bgeu`| 1100011 | 0        | 010    | 0      | 0        | xx        | 1      | 01    | 0    |
| I-type ALU  | 0010011 | 1        | 000    | 1      | 0        | 00        | 0      | 10    | 0    |
| `jal`       | 1101111 | 1        | 100    | x      | 0        | 10        | 0      | xx    | 1    |
| `jalr`      | 1100111 | 1        | 000    | 1      | 0        | 10        | 0      | xx    | 1    |
| `lui`       | 0110111 | 1        | 011    | 1      | 0        | 00        | 0      | xx    | 0    |
| `auipc`     | 0010111 | 1        | 011    | 1      | 0        | 00        | 0      | 00    | 0    |

## Signal Definitions

| Signal | Width | Encoding |
|--------|:-----:|----------|
| `RegWrite` | 1 | 1 = write result to `rd` |
| `ImmSrc` | 3 | Immediate format selector — see `ImmSrc_encoding.md` |
| `ALUSrc` | 1 | ALU B-input: 0 = rs2, 1 = ImmExt |
| `MemWrite` | 1 | 1 = write to data memory (store) |
| `ResultSrc` | 2 | Write-back source: `00` = ALUResult, `01` = ReadData, `10` = PC+4 |
| `Branch` | 1 | 1 = conditional branch (evaluate condition in EX) |
| `ALUOp` | 2 | `00` = ADD, `01` = SUB, `10` = decode from funct3/funct7 |
| `Jump` | 1 | 1 = unconditional jump (`jal` / `jalr`) |
