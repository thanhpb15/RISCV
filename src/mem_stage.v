// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : mem_stage  (Memory Access)
// Description: MEM pipeline stage. Performs data memory reads and writes.
//   - Store (MemWriteM=1): writes WriteDataM to address ALUResultM
//   - Load  (MemWriteM=0): reads from address ALUResultM -> ReadDataM
//   - ALUResultM is passed through to the MEM/WB register for R/I-type
//     instructions that do not access memory (ResultSrc != Mem).
// =============================================================================
module mem_stage (
    input  wire        clk,
    input  wire        rstn,
    input  wire        MemWriteM,
    input  wire [31:0] ALUResultM,   // effective address (from EX/MEM register)
    input  wire [31:0] WriteDataM,   // store data — rs2 value after forwarding
    output wire [31:0] ReadDataM     // load data (valid when ResultSrc=Mem)
);
    data_memory dmem (
        .clk (clk),
        .rstn(rstn),
        .WE  (MemWriteM),
        .A   (ALUResultM),
        .WD  (WriteDataM),
        .RD  (ReadDataM)
    );
endmodule
