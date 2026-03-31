// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : hazard_unit
// Description: Detects and resolves all three hazard types in the 5-stage
//              RV32I pipeline (forwarding, stall, flush).
//
// 1. DATA FORWARDING  (solves RAW hazards without stalling)
//    EX/MEM -> EX  (1-cycle-ahead):  ForwardAE/ForwardBE = 2'b10
//    MEM/WB -> EX  (2-cycles-ahead): ForwardAE/ForwardBE = 2'b01
//    Priority: EX/MEM takes precedence over MEM/WB (closest producer wins).
//
// 2. STALL  (solves load-use hazard — cannot be resolved by forwarding alone)
//    Condition: instruction in EX is a LOAD (ResultSrcE == 2'b01)
//               AND RdE matches Rs1D or Rs2D of the instruction in ID
//               AND RdE != x0
//    Action:
//      StallF = 1 -> hold PC (PC register enable = 0)
//      StallD = 1 -> hold IF/ID register (enable = 0)
//      FlushE = 1 -> insert NOP bubble into ID/EX register (clear = 1)
//    After 1 stall cycle, the load result can be forwarded from MEM/WB to EX.
//
// 3. FLUSH  (solves control hazards — branch taken or unconditional jump)
//    Condition: PCSrcE = 1 (branch taken or jal/jalr)
//    Action:
//      FlushD = 1 -> flush IF/ID register (wrong instruction already in ID)
//      FlushE = 1 -> flush ID/EX register (wrong instruction already in EX)
//    Penalty: 2 cycles (2 instructions must be squashed).
// =============================================================================
module hazard_unit (
    // Stage pipeline signals
    input  wire        RegWriteM,   // MEM stage: does instruction write rd?
    input  wire        RegWriteW,   // WB  stage: does instruction write rd?
    input  wire        PCSrcE,      // EX  stage: branch taken or jump
    input  wire [4:0]  RdM,         // rd in MEM stage  (EX/MEM register)
    input  wire [4:0]  RdW,         // rd in WB  stage  (MEM/WB register)
    input  wire [4:0]  Rs1E,        // rs1 of instruction in EX
    input  wire [4:0]  Rs2E,        // rs2 of instruction in EX
    input  wire [4:0]  RdE,         // rd  of instruction in EX (load-use check)
    input  wire [4:0]  Rs1D,        // rs1 of instruction in ID (load-use check)
    input  wire [4:0]  Rs2D,        // rs2 of instruction in ID
    input  wire        ResultSrcE,  // 1 = load instruction in EX (ResultSrc[0])
    // Forwarding control
    output wire [1:0]  ForwardAE,   // ALU A-input source select
    output wire [1:0]  ForwardBE,   // ALU B-input source select
    // Stall / Flush control
    output wire        StallF,      // 1 -> hold PC
    output wire        StallD,      // 1 -> hold IF/ID register
    output wire        FlushE,      // 1 -> clear ID/EX register (NOP bubble)
    output wire        FlushD       // 1 -> clear IF/ID register
);
    // -------------------------------------------------------------------------
    // Forwarding logic (per spec: check consumer Rs1E/Rs2E != x0)
    //   (a) rs1E/rs2E != x0  — x0 is hardwired 0, never needs forwarding
    //   (b) rd of producer matches rs1E or rs2E
    //   (c) producer writes to rd (RegWrite = 1)
    //   Priority: EX/MEM (MEM stage) > MEM/WB (WB stage)
    // -------------------------------------------------------------------------
    assign ForwardAE =
        ((Rs1E != 5'b0) && (Rs1E == RdM) && RegWriteM) ? 2'b10 : // EX/MEM → EX
        ((Rs1E != 5'b0) && (Rs1E == RdW) && RegWriteW) ? 2'b01 : // MEM/WB → EX
                                                          2'b00;  // no forward

    assign ForwardBE =
        ((Rs2E != 5'b0) && (Rs2E == RdM) && RegWriteM) ? 2'b10 :
        ((Rs2E != 5'b0) && (Rs2E == RdW) && RegWriteW) ? 2'b01 :
                                                          2'b00;

    // -------------------------------------------------------------------------
    // Load-use hazard (lwStall)
    // A load result is not available until end of MEM; one stall cycle is
    // inserted so the result can be forwarded from MEM/WB to EX next cycle.
    // RdE != x0: a load to x0 is a no-op — no consumer can depend on it.
    // -------------------------------------------------------------------------
    wire lwStall;
    assign lwStall = ResultSrcE && (RdE != 5'b0) &&
                     ((RdE == Rs1D) || (RdE == Rs2D));

    assign StallF = lwStall;
    assign StallD = lwStall;

    // -------------------------------------------------------------------------
    // Flush control
    // FlushE: NOP bubble on load-use stall OR squash wrong-path instruction.
    // FlushD: squash the instruction already fetched into ID on branch/jump.
    // -------------------------------------------------------------------------
    assign FlushD = PCSrcE;
    assign FlushE = lwStall | PCSrcE;
endmodule
