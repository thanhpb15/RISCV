# ALU Decoder

`src/alu_decoder.v` — maps `(ALUOp, funct3, {op5, funct75})` to a 4-bit `ALUControl`.

`x` denotes a don't-care input.

| ALUOp | funct3 | {op₅, funct7₅} | ALUControl   | Instruction                  |
|:-----:|:------:|:--------------:|:------------:|------------------------------|
| 00    | x      | x              | 0000 (add)   | `lw`, `sw`, `jal`, `jalr`, `auipc` |
| 01    | x      | x              | 0001 (subtract) | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| 10    | 000    | 00, 01, 10     | 0000 (add)   | `add`, `addi`                |
| 10    | 000    | 11             | 0001 (subtract) | `sub`                     |
| 10    | 001    | x              | 0101 (sll)   | `sll`, `slli`                |
| 10    | 010    | x              | 1000 (slt)   | `slt`, `slti`                |
| 10    | 011    | x              | 1001 (sltu)  | `sltu`, `sltiu`              |
| 10    | 100    | x              | 0100 (xor)   | `xor`, `xori`                |
| 10    | 101    | x0             | 0110 (srl)   | `srl`, `srli`                |
| 10    | 101    | x1             | 0111 (sra)   | `sra`, `srai`                |
| 10    | 110    | x              | 0011 (or)    | `or`, `ori`                  |
| 10    | 111    | x              | 0010 (and)   | `and`, `andi`                |

**Special case — LUI** (`op = 0110111`): `ALUControl = 1010 (pass_b)` regardless of `ALUOp`.
This rule is checked first (highest priority). The ALU passes the B-input (immediate) directly
to the output: `rd = {imm[31:12], 12'b0}`.

## ALUControl Encoding Summary

| ALUControl | Operation | Expression |
|:----------:|-----------|------------|
| 0000 | ADD    | `A + B` |
| 0001 | SUB    | `A − B` |
| 0010 | AND    | `A & B` |
| 0011 | OR     | `A \| B` |
| 0100 | XOR    | `A ^ B` |
| 0101 | SLL    | `A << B[4:0]` |
| 0110 | SRL    | `A >> B[4:0]` (logical) |
| 0111 | SRA    | `A >>> B[4:0]` (arithmetic) |
| 1000 | SLT    | `(A <ₛ B) ? 1 : 0` |
| 1001 | SLTU   | `(A <ᵤ B) ? 1 : 0` |
| 1010 | PASS_B | `B` |
