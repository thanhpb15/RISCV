// =============================================================================
// Module  : wb_stage  (Write Back)
// Description: WB pipeline stage. Selects the value to write back into the
//              destination register rd.
//
// ResultSrcW encoding:
//   2'b00  ALU result   — R-type, I-type arithmetic, LUI, AUIPC
//   2'b01  Memory data  — load instructions (lw, lb, lh, ...)
//   2'b10  PC + 4       — return address for JAL / JALR
//
// ResultW is also fed back to the ID stage (register file write port) and
// to the EX stage (MEM/WB forwarding path).
// =============================================================================
module wb_stage (
    input  wire [1:0]  ResultSrcW,
    input  wire [31:0] ALUResultW,
    input  wire [31:0] ReadDataW,
    input  wire [31:0] PCPlus4W,
    output wire [31:0] ResultW        // writeback value (combinational)
);
    mux_3_1 wb_mux (
        .d0(ALUResultW),
        .d1(ReadDataW),
        .d2(PCPlus4W),
        .s (ResultSrcW),
        .y (ResultW)
    );
endmodule
