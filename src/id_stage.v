// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : id_stage  (Instruction Decode)
// Description: ID pipeline stage. Decodes the instruction, reads source
//              registers, and sign-extends the immediate operand.
//
// Sub-units instantiated:
//   control_unit   — decodes Op/Funct3/Funct7 into all control signals
//   register_file  — reads rs1, rs2; receives write-back from WB stage
//   imm_extend     — produces sign-extended 32-bit immediate
//
// Register addresses (Rs1, Rs2, Rd) and Funct3 are extracted directly from
// the instruction word and passed to the ID/EX pipeline register and to the
// hazard unit.
//
// Note: PCD and PCPlus4D travel from the IF/ID register directly to the
//       ID/EX register via wires in riscv_top — they do not pass through
//       this module.
// =============================================================================
module id_stage (
    input  wire        clk,
    // Write-back interface (from WB stage, fed back into register file)
    input  wire        RegWriteW,
    input  wire [4:0]  RdW,
    input  wire [31:0] ResultW,
    // Instruction from IF/ID pipeline register
    input  wire [31:0] InstrD,
    // Control signal outputs (combinational, to ID/EX register)
    output wire        RegWriteD,
    output wire        MemWriteD,
    output wire        JumpD,
    output wire        BranchD,
    output wire        ALUSrcD,
    output wire        ASelD,        // 0=rs1, 1=PC  (JAL/AUIPC)
    output wire [1:0]  ResultSrcD,
    output wire [3:0]  ALUControlD,
    // Data outputs (to ID/EX register)
    output wire [31:0] RD1D,         // rs1 value from register file
    output wire [31:0] RD2D,         // rs2 value from register file
    output wire [31:0] ImmExtD,      // sign-extended immediate
    // Register addresses (to ID/EX register and hazard unit)
    output wire [4:0]  Rs1D,
    output wire [4:0]  Rs2D,
    output wire [4:0]  RdD,
    output wire [2:0]  Funct3D       // forwarded to EX for branch-type decode
);
    wire [2:0] ImmSrcD;

    // Extract register addresses and Funct3 from instruction encoding
    assign Rs1D    = InstrD[19:15];
    assign Rs2D    = InstrD[24:20];
    assign RdD     = InstrD[11:7];
    assign Funct3D = InstrD[14:12];

    // ASelD: route PC to ALU A-input for JAL (7'b1101111) and AUIPC (7'b0010111).
    // Derived directly from the opcode rather than emitted by the control unit.
    assign ASelD = (InstrD[6:0] == 7'b1101111) || (InstrD[6:0] == 7'b0010111);

    // Control unit: decode op/funct3/funct7 -> control signals
    control_unit ctrl (
        .op        (InstrD[6:0]),
        .funct3    (InstrD[14:12]),
        .funct7    (InstrD[31:25]),
        .RegWrite  (RegWriteD),
        .ResultSrc (ResultSrcD),
        .MemWrite  (MemWriteD),
        .Jump      (JumpD),
        .Branch    (BranchD),
        .ALUSrc    (ALUSrcD),
        .ImmSrc    (ImmSrcD),
        .ALUControl(ALUControlD)
    );

    // Register file: two asynchronous read ports, one synchronous write port
    register_file rf (
        .clk (clk),
        .WE3 (RegWriteW),
        .A1  (InstrD[19:15]),
        .A2  (InstrD[24:20]),
        .A3  (RdW),
        .WD3 (ResultW),
        .RD1 (RD1D),
        .RD2 (RD2D)
    );

    // Immediate extender: sign-extends the embedded immediate to 32 bits
    imm_extend imm_ext (
        .Instr  (InstrD),
        .ImmSrc (ImmSrcD),
        .ImmExt (ImmExtD)
    );
endmodule
