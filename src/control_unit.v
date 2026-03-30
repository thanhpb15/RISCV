// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : control_unit
// Description: Pipeline control unit — composes main_decoder + alu_decoder.
//   Receives instruction fields (op, funct3, funct7) and emits all
//   control signals needed by the ID / EX / MEM / WB pipeline stages.
// =============================================================================
module control_unit (
    input  wire [6:0] op,
    input  wire [6:0] funct7,
    input  wire [2:0] funct3,
    // Control outputs
    output wire        RegWrite,
    output wire        MemWrite,
    output wire        ALUSrc,
    output wire        Jump,
    output wire        Branch,
    output wire [1:0]  ResultSrc,
    output wire [2:0]  ImmSrc,
    output wire [3:0]  ALUControl  // 4-bit ALU operation code
);
    wire [1:0] ALUOp;

    main_decoder main_dec (
        .op        (op),
        .RegWrite  (RegWrite),
        .ResultSrc (ResultSrc),
        .MemWrite  (MemWrite),
        .Jump      (Jump),
        .Branch    (Branch),
        .ALUSrc    (ALUSrc),
        .ImmSrc    (ImmSrc),
        .ALUOp     (ALUOp)
    );

    alu_decoder alu_dec (
        .ALUOp     (ALUOp),
        .funct3    (funct3),
        .funct7    (funct7),
        .op        (op),
        .ALUControl(ALUControl)
    );
endmodule
