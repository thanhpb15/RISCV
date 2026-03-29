# ImmSrc Encoding

`src/imm_extend.v` — sign-extends the immediate field of a 32-bit instruction to 32 bits.


| ImmSrc | ImmExt | Type | Description |
|:------:|--------|:----:|-------------|
| 000 | `{{20{Instr[31]}}, Instr[31:20]}` | I | 12-bit signed immediate |
| 001 | `{{20{Instr[31]}}, Instr[31:25], Instr[11:7]}` | S | 12-bit signed immediate |
| 010 | `{{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0}` | B | 13-bit signed immediate |
| 011 | `{Instr[31:12], 12'h000}` | U | 32-bit (upper 20 bits, lower 12 zeroed) |
| 100 | `{{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0}` | J | 21-bit signed immediate |

## Notes

- Bit 0 of B-type and J-type immediates is hardwired to `0` — branch and jump targets are always 2-byte aligned.
- U-type does not sign-extend; the 20-bit field is placed in bits `[31:12]` and the lower 12 bits are cleared.
- `ImmSrc` is driven by `main_decoder` based solely on the opcode.
