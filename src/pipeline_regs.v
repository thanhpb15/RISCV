// =============================================================================
// File    : pipeline_regs.v
// Description: All four pipeline inter-stage registers for the 5-stage
//              RV32I pipeline.
//
//   pipeline_IF_ID   — separates IF  and ID  stages
//   pipeline_ID_EX   — separates ID  and EX  stages
//   pipeline_EX_MEM  — separates EX  and MEM stages
//   pipeline_MEM_WB  — separates MEM and WB  stages
//
// Reset policy : active-low synchronous (rstn=0 resets all registers to 0)
// Stall policy : en=0 holds the register value unchanged (PC / IF-ID only)
// Flush policy : clr=1 resets register to NOP / 0 (overrides en)
// =============================================================================


// =============================================================================
// pipeline_IF_ID
// Stores: instruction word, PC, PC+4
// Control:
//   en  = ~StallF  : hold when load-use stall is asserted
//   clr = FlushD   : squash on branch-taken / jump
// NOP inserted = addi x0, x0, 0  (32'h00000013)
// =============================================================================
module pipeline_IF_ID (
    input  wire        clk,
    input  wire        rstn,
    input  wire        en,           // 1 = update, 0 = hold (stall)
    input  wire        clr,          // 1 = flush to NOP
    input  wire [31:0] InstrF,
    input  wire [31:0] PCF,
    input  wire [31:0] PCPlus4F,
    output reg  [31:0] InstrD,
    output reg  [31:0] PCD,
    output reg  [31:0] PCPlus4D
);
    always @(posedge clk) begin
        if (!rstn || clr) begin
            // NOP: addi x0, x0, 0  (opcode=0010011, rd=0, rs1=0, imm=0)
            InstrD   <= 32'h00000013;
            PCD      <= 32'h00000000;
            PCPlus4D <= 32'h00000000;
        end else if (en) begin
            InstrD   <= InstrF;
            PCD      <= PCF;
            PCPlus4D <= PCPlus4F;
        end
        // else: en=0 -> hold (stall cycle)
    end
endmodule


// =============================================================================
// pipeline_ID_EX
// Stores: all control signals, register-file read data, sign-extended
//         immediate, PC, PC+4, register addresses, Funct3
// Control:
//   clr = FlushE   : insert NOP bubble (load-use) or squash (branch/jump)
// =============================================================================
module pipeline_ID_EX (
    input  wire        clk,
    input  wire        rstn,
    input  wire        clr,              // 1 = insert NOP bubble / flush
    // Control signals from ID stage
    input  wire        RegWriteD,
    input  wire        MemWriteD,
    input  wire        ALUSrcD,
    input  wire        JumpD,
    input  wire        BranchD,
    input  wire        ASelD,            // A-input select: 0=rs1, 1=PC
    input  wire [1:0]  ResultSrcD,
    input  wire [3:0]  ALUControlD,
    input  wire [2:0]  Funct3D,          // passed for branch-condition check
    // Data from register file and immediate extender
    input  wire [31:0] RD1D,
    input  wire [31:0] RD2D,
    input  wire [31:0] ImmExtD,
    input  wire [31:0] PCD,
    input  wire [31:0] PCPlus4D,
    // Register addresses (needed by hazard unit)
    input  wire [4:0]  Rs1D,
    input  wire [4:0]  Rs2D,
    input  wire [4:0]  RdD,
    // EX-stage outputs
    output reg         RegWriteE,
    output reg         MemWriteE,
    output reg         ALUSrcE,
    output reg         JumpE,
    output reg         BranchE,
    output reg         ASelE,
    output reg  [1:0]  ResultSrcE,
    output reg  [3:0]  ALUControlE,
    output reg  [2:0]  Funct3E,
    output reg  [31:0] RD1E,
    output reg  [31:0] RD2E,
    output reg  [31:0] ImmExtE,
    output reg  [31:0] PCE,
    output reg  [31:0] PCPlus4E,
    output reg  [4:0]  Rs1E,
    output reg  [4:0]  Rs2E,
    output reg  [4:0]  RdE
);
    always @(posedge clk) begin
        if (!rstn || clr) begin
            // All control signals = 0 -> effective NOP bubble
            // RdE = x0 prevents the hazard unit from forwarding a bubble
            RegWriteE   <= 1'b0;
            MemWriteE   <= 1'b0;
            ALUSrcE     <= 1'b0;
            JumpE       <= 1'b0;
            BranchE     <= 1'b0;
            ASelE       <= 1'b0;
            ResultSrcE  <= 2'b00;
            ALUControlE <= 4'b0000;
            Funct3E     <= 3'b000;
            RD1E        <= 32'h00000000;
            RD2E        <= 32'h00000000;
            ImmExtE     <= 32'h00000000;
            PCE         <= 32'h00000000;
            PCPlus4E    <= 32'h00000000;
            Rs1E        <= 5'h00;
            Rs2E        <= 5'h00;
            RdE         <= 5'h00;  // x0 ensures no spurious forwarding
        end else begin
            RegWriteE   <= RegWriteD;
            MemWriteE   <= MemWriteD;
            ALUSrcE     <= ALUSrcD;
            JumpE       <= JumpD;
            BranchE     <= BranchD;
            ASelE       <= ASelD;
            ResultSrcE  <= ResultSrcD;
            ALUControlE <= ALUControlD;
            Funct3E     <= Funct3D;
            RD1E        <= RD1D;
            RD2E        <= RD2D;
            ImmExtE     <= ImmExtD;
            PCE         <= PCD;
            PCPlus4E    <= PCPlus4D;
            Rs1E        <= Rs1D;
            Rs2E        <= Rs2D;
            RdE         <= RdD;
        end
    end
endmodule


// =============================================================================
// pipeline_EX_MEM
// Stores: control signals for MEM/WB stages, ALU result, store data,
//         PC+4 (for JAL/JALR writeback), rd
// No stall / flush needed here (EX/MEM always advances normally)
// =============================================================================
module pipeline_EX_MEM (
    input  wire        clk,
    input  wire        rstn,
    // Control signals
    input  wire        RegWriteE,
    input  wire        MemWriteE,
    input  wire [1:0]  ResultSrcE,
    // Data
    input  wire [31:0] ALUResultE,
    input  wire [31:0] WriteDataE,   // forwarded rs2 value (for store)
    input  wire [31:0] PCPlus4E,
    input  wire [4:0]  RdE,
    // MEM-stage outputs
    output reg         RegWriteM,
    output reg         MemWriteM,
    output reg  [1:0]  ResultSrcM,
    output reg  [31:0] ALUResultM,
    output reg  [31:0] WriteDataM,
    output reg  [31:0] PCPlus4M,
    output reg  [4:0]  RdM
);
    always @(posedge clk) begin
        if (!rstn) begin
            RegWriteM  <= 1'b0;
            MemWriteM  <= 1'b0;
            ResultSrcM <= 2'b00;
            ALUResultM <= 32'h00000000;
            WriteDataM <= 32'h00000000;
            PCPlus4M   <= 32'h00000000;
            RdM        <= 5'h00;
        end else begin
            RegWriteM  <= RegWriteE;
            MemWriteM  <= MemWriteE;
            ResultSrcM <= ResultSrcE;
            ALUResultM <= ALUResultE;
            WriteDataM <= WriteDataE;
            PCPlus4M   <= PCPlus4E;
            RdM        <= RdE;
        end
    end
endmodule


// =============================================================================
// pipeline_MEM_WB
// Stores: control signals for WB stage, ALU result, memory read data,
//         PC+4, rd
// =============================================================================
module pipeline_MEM_WB (
    input  wire        clk,
    input  wire        rstn,
    // Control signals
    input  wire        RegWriteM,
    input  wire [1:0]  ResultSrcM,
    // Data
    input  wire [31:0] ALUResultM,
    input  wire [31:0] ReadDataM,
    input  wire [31:0] PCPlus4M,
    input  wire [4:0]  RdM,
    // WB-stage outputs
    output reg         RegWriteW,
    output reg  [1:0]  ResultSrcW,
    output reg  [31:0] ALUResultW,
    output reg  [31:0] ReadDataW,
    output reg  [31:0] PCPlus4W,
    output reg  [4:0]  RdW
);
    always @(posedge clk) begin
        if (!rstn) begin
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b00;
            ALUResultW <= 32'h00000000;
            ReadDataW  <= 32'h00000000;
            PCPlus4W   <= 32'h00000000;
            RdW        <= 5'h00;
        end else begin
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            ALUResultW <= ALUResultM;
            ReadDataW  <= ReadDataM;
            PCPlus4W   <= PCPlus4M;
            RdW        <= RdM;
        end
    end
endmodule
