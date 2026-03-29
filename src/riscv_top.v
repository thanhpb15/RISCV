// =============================================================================
// Module  : riscv_top  (Top-level)
// Description: RV32I 5-stage pipelined processor with full hazard handling.
//
// Architecture:  IF -> ID -> EX -> MEM -> WB
//
// Supported instructions (RV32I base integer ISA):
//   R-type  : add, sub, and, or, xor, sll, srl, sra, slt, sltu
//   I-arith : addi, andi, ori, xori, xori, slli, srli, srai, slti, sltiu
//   Load    : lw  (word only; byte/halfword requires dmem byte-enable extension)
//   Store   : sw
//   Branch  : beq, bne, blt, bge, bltu, bgeu
//   Jump    : jal, jalr
//   Upper   : lui, auipc
//
// Hazard resolution:
//   Forwarding : EX/MEM -> EX  and  MEM/WB -> EX  (resolves RAW hazards)
//   Stall      : 1-cycle stall for load-use hazard, then MEM/WB forward
//   Flush      : 2-cycle penalty for branch-taken and JAL/JALR
//
// Module hierarchy:
//   riscv_top
//   ├── if_stage          (instruction fetch)
//   ├── pipeline_IF_ID    (IF/ID register)
//   ├── id_stage          (instruction decode, register read)
//   ├── pipeline_ID_EX    (ID/EX register)
//   ├── ex_stage          (ALU, forwarding, branch eval)
//   ├── pipeline_EX_MEM   (EX/MEM register)
//   ├── mem_stage         (data memory access)
//   ├── pipeline_MEM_WB   (MEM/WB register)
//   ├── wb_stage          (writeback mux)
//   └── hazard_unit       (forwarding + stall + flush control)
//
// Reset: active-low synchronous (rstn=0 resets entire pipeline to known state)
// =============================================================================
module riscv_top (
    input wire clk,
    input wire rstn   // active-low synchronous reset
);

    // =========================================================================
    // Wire declarations, grouped by pipeline stage boundary
    // =========================================================================

    // IF stage outputs
    wire [31:0] InstrF, PCF, PCPlus4F;

    // IF/ID register outputs (suffix D = Decode stage)
    wire [31:0] InstrD, PCD, PCPlus4D;

    // ID stage outputs (combinational, suffix D)
    wire        RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD, ASelD;
    wire [1:0]  ResultSrcD;
    wire [3:0]  ALUControlD;
    wire [2:0]  Funct3D;
    wire [31:0] RD1D, RD2D, ImmExtD;
    wire [4:0]  Rs1D, Rs2D, RdD;

    // ID/EX register outputs (suffix E = Execute stage)
    wire        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE, ASelE;
    wire [1:0]  ResultSrcE;
    wire [3:0]  ALUControlE;
    wire [2:0]  Funct3E;
    wire [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E;
    wire [4:0]  Rs1E, Rs2E, RdE;

    // EX stage outputs
    wire [31:0] PCTargetE, ALUResultE, WriteDataE;
    wire        PCSrcE;

    // EX/MEM register outputs (suffix M = Memory stage)
    wire        RegWriteM, MemWriteM;
    wire [1:0]  ResultSrcM;
    wire [31:0] ALUResultM, WriteDataM, PCPlus4M;
    wire [4:0]  RdM;

    // MEM stage outputs
    wire [31:0] ReadDataM;

    // MEM/WB register outputs (suffix W = Writeback stage)
    wire        RegWriteW;
    wire [1:0]  ResultSrcW;
    wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
    wire [4:0]  RdW;

    // WB stage output (fed back to ID and EX for forwarding)
    wire [31:0] ResultW;

    // Hazard unit outputs
    wire [1:0]  ForwardAE, ForwardBE;
    wire        StallF, StallD, FlushE, FlushD;

    // =========================================================================
    // IF Stage — Instruction Fetch
    // =========================================================================
    if_stage u_if_stage (
        .clk       (clk),
        .rstn      (rstn),
        .en        (~StallF),
        .PCSrcE    (PCSrcE),
        .PCTargetE (PCTargetE),
        .InstrF    (InstrF),
        .PCF       (PCF),
        .PCPlus4F  (PCPlus4F)
    );

    // =========================================================================
    // IF/ID Pipeline Register
    // en=~StallD: hold on load-use stall
    // clr=FlushD: squash on branch-taken / jump
    // =========================================================================
    pipeline_IF_ID u_if_id (
        .clk       (clk),
        .rstn      (rstn),
        .en        (~StallD),
        .clr       (FlushD),
        .InstrF    (InstrF),
        .PCF       (PCF),
        .PCPlus4F  (PCPlus4F),
        .InstrD    (InstrD),
        .PCD       (PCD),
        .PCPlus4D  (PCPlus4D)
    );

    // =========================================================================
    // ID Stage — Instruction Decode
    // Writeback path: RdW, RegWriteW, ResultW loop back here
    // =========================================================================
    id_stage u_id_stage (
        .clk          (clk),
        .rstn         (rstn),
        .RegWriteW    (RegWriteW),
        .RdW          (RdW),
        .ResultW      (ResultW),
        .InstrD       (InstrD),
        .RegWriteD    (RegWriteD),
        .MemWriteD    (MemWriteD),
        .JumpD        (JumpD),
        .BranchD      (BranchD),
        .ALUSrcD      (ALUSrcD),
        .ASelD        (ASelD),
        .ResultSrcD   (ResultSrcD),
        .ALUControlD  (ALUControlD),
        .RD1D         (RD1D),
        .RD2D         (RD2D),
        .ImmExtD      (ImmExtD),
        .Rs1D         (Rs1D),
        .Rs2D         (Rs2D),
        .RdD          (RdD),
        .Funct3D      (Funct3D)
    );

    // =========================================================================
    // ID/EX Pipeline Register
    // clr=FlushE: insert NOP bubble (load-use) or squash (branch/jump)
    // =========================================================================
    pipeline_ID_EX u_id_ex (
        .clk          (clk),
        .rstn         (rstn),
        .clr          (FlushE),
        .RegWriteD    (RegWriteD),
        .MemWriteD    (MemWriteD),
        .ALUSrcD      (ALUSrcD),
        .JumpD        (JumpD),
        .BranchD      (BranchD),
        .ASelD        (ASelD),
        .ResultSrcD   (ResultSrcD),
        .ALUControlD  (ALUControlD),
        .Funct3D      (Funct3D),
        .RD1D         (RD1D),
        .RD2D         (RD2D),
        .ImmExtD      (ImmExtD),
        .PCD          (PCD),
        .PCPlus4D     (PCPlus4D),
        .Rs1D         (Rs1D),
        .Rs2D         (Rs2D),
        .RdD          (RdD),
        .RegWriteE    (RegWriteE),
        .MemWriteE    (MemWriteE),
        .ALUSrcE      (ALUSrcE),
        .JumpE        (JumpE),
        .BranchE      (BranchE),
        .ASelE        (ASelE),
        .ResultSrcE   (ResultSrcE),
        .ALUControlE  (ALUControlE),
        .Funct3E      (Funct3E),
        .RD1E         (RD1E),
        .RD2E         (RD2E),
        .ImmExtE      (ImmExtE),
        .PCE          (PCE),
        .PCPlus4E     (PCPlus4E),
        .Rs1E         (Rs1E),
        .Rs2E         (Rs2E),
        .RdE          (RdE)
    );

    // =========================================================================
    // EX Stage — Execute
    // =========================================================================
    ex_stage u_ex_stage (
        .ForwardAE    (ForwardAE),
        .ForwardBE    (ForwardBE),
        .JumpE        (JumpE),
        .BranchE      (BranchE),
        .ALUSrcE      (ALUSrcE),
        .ASelE        (ASelE),
        .ALUControlE  (ALUControlE),
        .Funct3E      (Funct3E),
        .RD1E         (RD1E),
        .RD2E         (RD2E),
        .ImmExtE      (ImmExtE),
        .PCE          (PCE),
        .PCPlus4E     (PCPlus4E),
        .ALUResultM   (ALUResultM),
        .ResultW      (ResultW),
        .PCTargetE    (PCTargetE),
        .ALUResultE   (ALUResultE),
        .WriteDataE   (WriteDataE),
        .PCSrcE       (PCSrcE)
    );

    // =========================================================================
    // EX/MEM Pipeline Register
    // =========================================================================
    pipeline_EX_MEM u_ex_mem (
        .clk          (clk),
        .rstn         (rstn),
        .RegWriteE    (RegWriteE),
        .MemWriteE    (MemWriteE),
        .ResultSrcE   (ResultSrcE),
        .ALUResultE   (ALUResultE),
        .WriteDataE   (WriteDataE),
        .PCPlus4E     (PCPlus4E),
        .RdE          (RdE),
        .RegWriteM    (RegWriteM),
        .MemWriteM    (MemWriteM),
        .ResultSrcM   (ResultSrcM),
        .ALUResultM   (ALUResultM),
        .WriteDataM   (WriteDataM),
        .PCPlus4M     (PCPlus4M),
        .RdM          (RdM)
    );

    // =========================================================================
    // MEM Stage — Data Memory Access
    // =========================================================================
    mem_stage u_mem_stage (
        .clk          (clk),
        .rstn         (rstn),
        .MemWriteM    (MemWriteM),
        .ALUResultM   (ALUResultM),
        .WriteDataM   (WriteDataM),
        .ReadDataM    (ReadDataM)
    );

    // =========================================================================
    // MEM/WB Pipeline Register
    // =========================================================================
    pipeline_MEM_WB u_mem_wb (
        .clk          (clk),
        .rstn         (rstn),
        .RegWriteM    (RegWriteM),
        .ResultSrcM   (ResultSrcM),
        .ALUResultM   (ALUResultM),
        .ReadDataM    (ReadDataM),
        .PCPlus4M     (PCPlus4M),
        .RdM          (RdM),
        .RegWriteW    (RegWriteW),
        .ResultSrcW   (ResultSrcW),
        .ALUResultW   (ALUResultW),
        .ReadDataW    (ReadDataW),
        .PCPlus4W     (PCPlus4W),
        .RdW          (RdW)
    );

    // =========================================================================
    // WB Stage — Write Back (combinational)
    // ResultW is fed back to: id_stage (register file write)
    //                         ex_stage (MEM/WB forwarding path)
    // =========================================================================
    wb_stage u_wb_stage (
        .ResultSrcW   (ResultSrcW),
        .ALUResultW   (ALUResultW),
        .ReadDataW    (ReadDataW),
        .PCPlus4W     (PCPlus4W),
        .ResultW      (ResultW)
    );

    // =========================================================================
    // Hazard Unit — Forwarding / Stall / Flush control
    // =========================================================================
    hazard_unit u_hazard (
        .rstn         (rstn),
        .RegWriteM    (RegWriteM),
        .RegWriteW    (RegWriteW),
        .PCSrcE       (PCSrcE),
        .RdM          (RdM),
        .RdW          (RdW),
        .Rs1E         (Rs1E),
        .Rs2E         (Rs2E),
        .RdE          (RdE),
        .Rs1D         (Rs1D),
        .Rs2D         (Rs2D),
        .ResultSrcE   (ResultSrcE),
        .ForwardAE    (ForwardAE),
        .ForwardBE    (ForwardBE),
        .StallF       (StallF),
        .StallD       (StallD),
        .FlushE       (FlushE),
        .FlushD       (FlushD)
    );

endmodule
