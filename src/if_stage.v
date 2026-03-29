// =============================================================================
// Module  : if_stage  (Instruction Fetch)
// Description: IF pipeline stage. Reads the next instruction from IMEM,
//              computes PC+4, and selects the next PC value.
//
// PC selection (combinational mux driven by PCSrcE):
//   PCSrcE = 0  ->  PCNext = PCF + 4       (sequential execution)
//   PCSrcE = 1  ->  PCNext = PCTargetE     (branch taken / JAL / JALR)
//
// Pipeline stall (load-use hazard):
//   en = 0  ->  PC holds its current value (PC register enable = 0)
//
// Outputs feed directly into the pipeline_IF_ID register.
// =============================================================================
module if_stage (
    input  wire        clk,
    input  wire        rstn,
    input  wire        en,           // 1 = advance PC, 0 = stall (hold PC)
    input  wire        PCSrcE,       // 1 = take branch/jump target
    input  wire [31:0] PCTargetE,    // branch / jump destination address
    output wire [31:0] InstrF,       // fetched instruction
    output wire [31:0] PCF,          // current PC
    output wire [31:0] PCPlus4F      // PC + 4 (sequential next PC)
);
    wire [31:0] PCNext;

    // Select next PC: sequential (PC+4) or taken branch/jump target
    mux pc_sel_mux (
        .d0(PCPlus4F),
        .d1(PCTargetE),
        .s (PCSrcE),
        .y (PCNext)
    );

    // Program counter register (synchronous reset, load-use stall enable)
    pc pc_reg (
        .clk   (clk),
        .rstn  (rstn),
        .en    (en),
        .PCNext(PCNext),
        .PC    (PCF)
    );

    // PC + 4 adder
    adder pc_inc (
        .a(PCF),
        .b(32'h00000004),
        .y(PCPlus4F)
    );

    // Instruction memory: combinational read at current PC
    instruction_memory imem (
        .rstn(rstn),
        .A   (PCF),
        .RD  (InstrF)
    );
endmodule
