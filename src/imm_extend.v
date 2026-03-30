// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : imm_extend
// Description: Immediate sign-extender. Extracts and sign-extends the immediate
//              field from a 32-bit RISC-V instruction to 32 bits.
//
// ImmSrc encoding (3-bit, driven by main_decoder):
//   3'b000  I-type   sext({Instr[31:20]})
//   3'b001  S-type   sext({Instr[31:25], Instr[11:7]})
//   3'b010  B-type   sext({Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0})
//   3'b011  U-type   {Instr[31:12], 12'b0}   (no sign-extension, already 32-bit)
//   3'b100  J-type   sext({Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0})
//
// Note: bit 0 of B-type and J-type immediates is always 0 (aligned targets).
//       The full 32-bit instruction word is passed as input.
// =============================================================================
module imm_extend (
    input  wire [31:0] Instr,    // full 32-bit instruction
    input  wire [2:0]  ImmSrc,
    output wire [31:0] ImmExt
);
    reg [31:0] ext;

    always @(*) begin
        case (ImmSrc)
            // I-type: addi, lw, jalr, slti, etc.
            3'b000: ext = {{20{Instr[31]}}, Instr[31:20]};

            // S-type: sw, sb, sh
            3'b001: ext = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            // B-type: beq, bne, blt, bge, bltu, bgeu
            // bit 0 is always 0 (2-byte aligned branch target)
            3'b010: ext = {{20{Instr[31]}}, Instr[7], Instr[30:25],
                           Instr[11:8], 1'b0};

            // U-type: lui, auipc
            // 20-bit immediate occupies bits [31:12]; lower 12 bits = 0
            3'b011: ext = {Instr[31:12], 12'h000};

            // J-type: jal
            // bit 0 is always 0 (2-byte aligned jump target)
            3'b100: ext = {{12{Instr[31]}}, Instr[19:12], Instr[20],
                           Instr[30:21], 1'b0};

            default: ext = 32'h00000000;
        endcase
    end

    assign ImmExt = ext;
endmodule
