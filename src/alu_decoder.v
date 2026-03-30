// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : alu_decoder
// Description: Decodes (ALUOp, Funct3, Funct7, Op) into a 4-bit ALUControl.
//
// ALUOp encoding (driven by main_decoder):
//   2'b00  ADD  — load, store, JAL, JALR, AUIPC
//   2'b01  SUB  — branch (subtraction for flag comparison)
//   2'b10  R/I  — arithmetic/logic, decode further from Funct3/Funct7
//
// Special case: LUI (Op = 0110111) always maps to PASS_B, regardless of ALUOp.
// =============================================================================
module alu_decoder (
    input  wire [1:0]  ALUOp,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [6:0]  op,
    output wire [3:0]  ALUControl
);
    reg [3:0] ctrl;

    always @(*) begin
        if (op == 7'b0110111) begin
            // LUI: pass the immediate (B operand) straight through
            ctrl = 4'b1010; // PASS_B

        end else if (ALUOp == 2'b00) begin
            // Address computation for load / store / JAL / JALR / AUIPC
            ctrl = 4'b0000; // ADD

        end else if (ALUOp == 2'b01) begin
            // Branch comparison via subtraction (flags: Zero, Neg, Overflow, Carry)
            ctrl = 4'b0001; // SUB

        end else begin
            // R-type / I-type arithmetic: decode from funct3 and funct7
            case (funct3)
                // ADD/ADDI or SUB: SUB only for R-type with funct7[5]=1
                3'b000: ctrl = ({op[5], funct7[5]} == 2'b11) ? 4'b0001  // SUB
                                                              : 4'b0000; // ADD / ADDI
                3'b001: ctrl = 4'b0101; // SLL  / SLLI
                3'b010: ctrl = 4'b1000; // SLT  / SLTI  (signed)
                3'b011: ctrl = 4'b1001; // SLTU / SLTIU (unsigned)
                3'b100: ctrl = 4'b0100; // XOR  / XORI
                // SRL/SRLI (funct7[5]=0) or SRA/SRAI (funct7[5]=1)
                3'b101: ctrl = funct7[5] ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b110: ctrl = 4'b0011; // OR   / ORI
                3'b111: ctrl = 4'b0010; // AND  / ANDI
                default: ctrl = 4'b0000;
            endcase
        end
    end

    assign ALUControl = ctrl;
endmodule
