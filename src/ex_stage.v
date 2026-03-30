// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : ex_stage  (Execute)
// Description: EX pipeline stage. Performs the ALU operation, resolves
//              data-forwarding, computes the branch/jump target address,
//              evaluates the branch condition, and drives PCSrcE.
//
// Data path summary:
//   1. Forward MUX (A) : select rs1 source — RegFile / WB / MEM
//   2. ASel MUX        : override A with PC for JAL / AUIPC
//   3. Forward MUX (B) : select rs2 source — RegFile / WB / MEM
//                        (result is also WriteDataE for store instructions)
//   4. ALUSrc MUX      : select ALU B-input — forwarded rs2 OR immediate
//   5. ALU             : compute result; generate flags for branch
//   6. Branch adder    : compute PC + imm (branch/JAL target)
//   7. PCTargetE mux   : JALR target = ALU result & ~1;
//                        branch/JAL target = branch adder output
//   8. Branch condition: evaluate Funct3 against ALU flags -> PCSrcE
//
// Forwarding encoding (from hazard_unit):
//   2'b00 : no forward  — use value from register file (RD1E / RD2E)
//   2'b01 : WB  forward — use ResultW (output of writeback mux)
//   2'b10 : MEM forward — use ALUResultM (EX/MEM pipeline register)
//
// Branch conditions (Funct3):
//   000 BEQ  : Zero
//   001 BNE  : ~Zero
//   100 BLT  : Neg ^ Overflow           (signed less-than)
//   101 BGE  : ~(Neg ^ Overflow)        (signed greater-or-equal)
//   110 BLTU : ~Carry  (Carry=0 -> borrow -> A <u B)
//   111 BGEU :  Carry
//
// JALR vs JAL target selection:
//   JALR : JumpE=1, ASelE=0  -> PCTargetE = {ALUResultE[31:1], 1'b0}
//   JAL  : JumpE=1, ASelE=1  -> PCTargetE = branch_adder output (PC + J-imm)
// =============================================================================
module ex_stage (
    // Forwarding control from hazard unit
    input  wire [1:0]  ForwardAE,
    input  wire [1:0]  ForwardBE,
    // Control signals from ID/EX pipeline register
    input  wire        JumpE,
    input  wire        BranchE,
    input  wire        ALUSrcE,
    input  wire        ASelE,          // 0=rs1, 1=PC
    input  wire [3:0]  ALUControlE,
    input  wire [2:0]  Funct3E,        // branch-type selector
    // Data from ID/EX pipeline register
    input  wire [31:0] RD1E,
    input  wire [31:0] RD2E,
    input  wire [31:0] ImmExtE,
    input  wire [31:0] PCE,
    input  wire [31:0] PCPlus4E,
    // Forwarded values from later stages
    input  wire [31:0] ALUResultM,     // forward from EX/MEM register (MEM stage)
    input  wire [31:0] ResultW,        // forward from MEM/WB register (WB  stage)
    // Outputs to EX/MEM pipeline register and PC logic
    output wire [31:0] PCTargetE,      // branch / jump destination address
    output wire [31:0] ALUResultE,     // ALU result (also used for forwarding)
    output wire [31:0] WriteDataE,     // forwarded rs2 value (for store data)
    output wire        PCSrcE          // 1 = redirect PC to PCTargetE
);
    // -------------------------------------------------------------------------
    // Forwarding mux for ALU A-input (rs1)
    // -------------------------------------------------------------------------
    wire [31:0] SrcAE;
    mux_3_1 fwd_a_mux (
        .d0(RD1E),       // 2'b00: register file value
        .d1(ResultW),    // 2'b01: forward from WB
        .d2(ALUResultM), // 2'b10: forward from MEM
        .s (ForwardAE),
        .y (SrcAE)
    );

    // -------------------------------------------------------------------------
    // Forwarding mux for ALU B-input (rs2)
    // WriteDataE = forwarded rs2, used as store data for sw/sb/sh
    // -------------------------------------------------------------------------
    mux_3_1 fwd_b_mux (
        .d0(RD2E),
        .d1(ResultW),
        .d2(ALUResultM),
        .s (ForwardBE),
        .y (WriteDataE)    // exposed directly: correct store data
    );

    // -------------------------------------------------------------------------
    // ASel mux: override A with PC for JAL (ASel=1) and AUIPC (ASel=1)
    // Forwarding result is overridden when ASelE=1 (JAL/AUIPC use PC as A)
    // -------------------------------------------------------------------------
    wire [31:0] SrcA;
    assign SrcA = ASelE ? PCE : SrcAE;

    // -------------------------------------------------------------------------
    // ALUSrc mux: select ALU B-input between forwarded rs2 and immediate
    // -------------------------------------------------------------------------
    wire [31:0] SrcB;
    mux alu_src_mux (
        .d0(WriteDataE),  // rs2 (after forwarding)
        .d1(ImmExtE),     // sign-extended immediate
        .s (ALUSrcE),
        .y (SrcB)
    );

    // -------------------------------------------------------------------------
    // ALU: compute result and generate status flags
    // -------------------------------------------------------------------------
    wire ZeroE, NegE, OverflowE, CarryE;
    alu alu_unit (
        .A         (SrcA),
        .B         (SrcB),
        .ALUControl(ALUControlE),
        .ALUResult (ALUResultE),
        .Zero      (ZeroE),
        .Neg       (NegE),
        .Overflow  (OverflowE),
        .Carry     (CarryE)
    );

    // -------------------------------------------------------------------------
    // Branch / JAL target adder: PC + imm
    // Covers: branch (B-offset), JAL (J-offset)
    // -------------------------------------------------------------------------
    wire [31:0] PCBranchE;
    adder branch_adder (
        .a(PCE),
        .b(ImmExtE),
        .y(PCBranchE)
    );

    // -------------------------------------------------------------------------
    // PC target selection
    //   JALR  (JumpE=1, ASelE=0): (rs1 + imm) & ~1  — clear bit 0 per spec
    //   JAL   (JumpE=1, ASelE=1): PC + J-imm via branch adder
    //   Branch (BranchE=1):        PC + B-offset via branch adder
    // -------------------------------------------------------------------------
    assign PCTargetE = (JumpE & ~ASelE) ? {ALUResultE[31:1], 1'b0}
                                        : PCBranchE;

    // -------------------------------------------------------------------------
    // Branch condition evaluation (per Funct3 encoding, spec section 4.5)
    // -------------------------------------------------------------------------
    reg BranchTaken;
    always @(*) begin
        case (Funct3E)
            3'b000: BranchTaken =  ZeroE;                   // BEQ
            3'b001: BranchTaken = ~ZeroE;                   // BNE
            3'b100: BranchTaken =  NegE ^ OverflowE;        // BLT  (signed)
            3'b101: BranchTaken = ~(NegE ^ OverflowE);      // BGE  (signed)
            3'b110: BranchTaken = ~CarryE;                  // BLTU (unsigned)
            3'b111: BranchTaken =  CarryE;                  // BGEU (unsigned)
            default: BranchTaken = 1'b0;
        endcase
    end

    // Redirect PC if unconditional jump or branch condition is satisfied
    assign PCSrcE = JumpE | (BranchE & BranchTaken);
endmodule
