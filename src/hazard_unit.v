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
    input  wire        rstn,
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
    input  wire [1:0]  ResultSrcE,  // 2'b01 -> EX instruction is a LOAD
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
    // Forwarding logic
    // Condition checklist:
    //   (a) The producing instruction writes to rd (RegWrite = 1)
    //   (b) rd is not x0 (x0 is hardwired 0, never forwarded)
    //   (c) rd matches the consuming instruction's source register
    //   EX/MEM (MEM stage) has higher priority than MEM/WB (WB stage)
    // -------------------------------------------------------------------------
    assign ForwardAE =
        (!rstn)                                                  ? 2'b00 :
        (RegWriteM && (RdM != 5'b0) && (RdM == Rs1E))  ? 2'b10 : // forward from MEM
        (RegWriteW && (RdW != 5'b0) && (RdW == Rs1E))  ? 2'b01 : // forward from WB
                                                           2'b00;  // no forward

    assign ForwardBE =
        (!rstn)                                                  ? 2'b00 :
        (RegWriteM && (RdM != 5'b0) && (RdM == Rs2E))  ? 2'b10 :
        (RegWriteW && (RdW != 5'b0) && (RdW == Rs2E))  ? 2'b01 :
                                                           2'b00;

    // -------------------------------------------------------------------------
    // Load-use hazard detection
    // The load result is not available until the end of the MEM stage.
    // If the next instruction needs that value at the start of EX, one stall
    // cycle must be inserted and the result is then forwarded from MEM/WB.
    // -------------------------------------------------------------------------
    wire LoadUseHazard;
    assign LoadUseHazard = (ResultSrcE == 2'b01) &&   // EX instruction is LOAD
                           (RdE != 5'b0)          &&   // rd is not x0
                           ((RdE == Rs1D) || (RdE == Rs2D));

    assign StallF = LoadUseHazard;   // freeze PC
    assign StallD = LoadUseHazard;   // freeze IF/ID register

    // -------------------------------------------------------------------------
    // Flush control
    // FlushE covers both: NOP bubble insertion (load-use stall) and
    //                     squashing the wrong instruction (branch/jump).
    // FlushD squashes the instruction that has just been fetched (wrong path).
    // -------------------------------------------------------------------------
    assign FlushD = PCSrcE;                      // squash instruction in ID
    assign FlushE = LoadUseHazard | PCSrcE;      // NOP bubble or squash ID/EX
endmodule
