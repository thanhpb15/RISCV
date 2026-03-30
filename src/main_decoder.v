// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : main_decoder
// Description: Primary instruction decoder. Maps opcode to pipeline control
//              signals for the full RV32I base integer instruction set.
//
// Output signals:
//   RegWrite  : 1 = write result back to rd
//   ImmSrc    : immediate format selector (3-bit, see imm_extend.v)
//                  3'b000=I, 3'b001=S, 3'b010=B, 3'b011=U, 3'b100=J
//   ALUSrc    : ALU B-input selector: 0=rs2, 1=imm
//   MemWrite  : 1 = write to data memory (store instructions)
//   ResultSrc : writeback source: 2'b00=ALU, 2'b01=Mem, 2'b10=PC+4
//   Branch    : 1 = conditional branch (beq/bne/blt/bge/bltu/bgeu)
//   ALUOp     : 2'b00=ADD, 2'b01=SUB/compare, 2'b10=R/I-type decode
//   Jump      : 1 = unconditional jump (jal, jalr)
// =============================================================================
module main_decoder (
    input  wire [6:0] op,
    output wire [2:0] ImmSrc,
    output wire [1:0] ALUOp,
    output wire [1:0] ResultSrc,
    output wire       MemWrite,
    output wire       ALUSrc,
    output wire       RegWrite,
    output wire       Jump,
    output wire       Branch
);
    reg [2:0] ImmSrc_r;
    reg [1:0] ALUOp_r, ResultSrc_r;
    reg       MemWrite_r, ALUSrc_r, RegWrite_r, Jump_r, Branch_r;

    always @(*) begin
        // Defaults: NOP-like (no write, no branch, no jump)
        RegWrite_r  = 1'b0;
        ImmSrc_r    = 3'b000;
        ALUSrc_r    = 1'b0;
        MemWrite_r  = 1'b0;
        ResultSrc_r = 2'b00;
        Branch_r    = 1'b0;
        ALUOp_r     = 2'b00;
        Jump_r      = 1'b0;

        case (op)
            // -----------------------------------------------------------------
            // R-type: add, sub, and, or, xor, sll, srl, sra, slt, sltu
            // -----------------------------------------------------------------
            7'b0110011: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b0;   // B = rs2
                ResultSrc_r = 2'b00;  // WB = ALU result
                ALUOp_r     = 2'b10;  // decode from funct3/funct7
            end

            // -----------------------------------------------------------------
            // I-type arithmetic: addi, andi, ori, xori, slti, sltiu,
            //                    slli, srli, srai
            // -----------------------------------------------------------------
            7'b0010011: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = imm
                ImmSrc_r    = 3'b000; // I-type immediate
                ResultSrc_r = 2'b00;  // WB = ALU result
                ALUOp_r     = 2'b10;
            end

            // -----------------------------------------------------------------
            // Load: lw (and lb/lh/lbu/lhu variants)
            //   Effective address = rs1 + sext(imm)
            // -----------------------------------------------------------------
            7'b0000011: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = imm (address offset)
                ImmSrc_r    = 3'b000; // I-type immediate
                ResultSrc_r = 2'b01;  // WB = data from memory
                ALUOp_r     = 2'b00;  // ADD (address calculation)
            end

            // -----------------------------------------------------------------
            // Store: sw (and sb/sh variants)
            //   Effective address = rs1 + sext(imm)
            // -----------------------------------------------------------------
            7'b0100011: begin
                RegWrite_r  = 1'b0;
                ALUSrc_r    = 1'b1;   // B = imm (address offset)
                ImmSrc_r    = 3'b001; // S-type immediate
                MemWrite_r  = 1'b1;
                ALUOp_r     = 2'b00;  // ADD
            end

            // -----------------------------------------------------------------
            // Branch: beq, bne, blt, bge, bltu, bgeu
            //   ALU computes rs1 - rs2 to generate flags.
            //   Branch adder computes PC + B-offset (branch target).
            // -----------------------------------------------------------------
            7'b1100011: begin
                RegWrite_r  = 1'b0;
                ALUSrc_r    = 1'b0;   // B = rs2 (for comparison)
                ImmSrc_r    = 3'b010; // B-type immediate (branch offset)
                Branch_r    = 1'b1;
                ALUOp_r     = 2'b01;  // SUB (for flags)
            end

            // -----------------------------------------------------------------
            // JAL: jal rd, label
            //   rd = PC + 4;  PC = PC + sext(J-imm)
            //   Branch adder: A=PC, B=J-imm -> branch target
            // -----------------------------------------------------------------
            7'b1101111: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = J-imm
                ImmSrc_r    = 3'b100; // J-type immediate
                ResultSrc_r = 2'b10;  // WB = PC + 4 (return address)
                Jump_r      = 1'b1;
                ALUOp_r     = 2'b00;
            end

            // -----------------------------------------------------------------
            // JALR: jalr rd, rs1, imm
            //   rd = PC + 4;  PC = (rs1 + sext(imm)) & ~1
            //   ALU computes rs1 + imm; execute stage clears bit 0
            // -----------------------------------------------------------------
            7'b1100111: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = I-imm
                ImmSrc_r    = 3'b000; // I-type immediate
                ResultSrc_r = 2'b10;  // WB = PC + 4
                Jump_r      = 1'b1;
                ALUOp_r     = 2'b00;  // ADD
            end

            // -----------------------------------------------------------------
            // LUI: lui rd, imm  ->  rd = {imm[31:12], 12'b0}
            //   alu_decoder sees LUI opcode and selects PASS_B
            // -----------------------------------------------------------------
            7'b0110111: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = U-imm
                ImmSrc_r    = 3'b011; // U-type immediate
                ResultSrc_r = 2'b00;  // WB = ALU result (= imm)
                ALUOp_r     = 2'b00;
            end

            // -----------------------------------------------------------------
            // AUIPC: auipc rd, imm  ->  rd = PC + {imm[31:12], 12'b0}
            // -----------------------------------------------------------------
            7'b0010111: begin
                RegWrite_r  = 1'b1;
                ALUSrc_r    = 1'b1;   // B = U-imm
                ImmSrc_r    = 3'b011; // U-type immediate
                ResultSrc_r = 2'b00;  // WB = ALU result
                ALUOp_r     = 2'b00;  // ADD: PC + (imm << 12)
            end

            default: begin /* unknown opcode treated as NOP */ end
        endcase
    end

    assign ImmSrc    = ImmSrc_r;
    assign ALUOp     = ALUOp_r;
    assign ResultSrc = ResultSrc_r;
    assign MemWrite  = MemWrite_r;
    assign ALUSrc    = ALUSrc_r;
    assign RegWrite  = RegWrite_r;
    assign Jump      = Jump_r;
    assign Branch    = Branch_r;
endmodule
