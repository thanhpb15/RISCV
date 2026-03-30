// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : alu (Arithmetic Logic Unit)
// Description: 32-bit ALU supporting all RV32I arithmetic and logic operations.
//
// ALU control encoding (4-bit), per spec section 10.2:
//   4'b0000  ADD    A + B
//   4'b0001  SUB    A - B          (also used to generate flags for branches)
//   4'b0010  AND    A & B
//   4'b0011  OR     A | B
//   4'b0100  XOR    A ^ B
//   4'b0101  SLL    A << B[4:0]    logical shift left
//   4'b0110  SRL    A >> B[4:0]    logical shift right (zero-fill)
//   4'b0111  SRA    A >>> B[4:0]   arithmetic shift right (sign-fill)
//   4'b1000  SLT    (A <s B) ? 1 : 0   signed less-than
//   4'b1001  SLTU   (A <u B) ? 1 : 0   unsigned less-than
//   4'b1010  PASS_B  ALUResult = B      used for LUI (rd = imm)
//
// Status flags (computed from A - B subtraction, valid for branch conditions):
//   Zero     : ALUResult == 0  (used for BEQ)
//   Neg      : sign bit of (A - B)          (used for BLT / BGE)
//   Overflow : signed overflow of (A - B)   (used for BLT / BGE)
//   Carry    : carry-out of (A - B);
//              Carry=1 means A >= B unsigned (used for BLTU / BGEU)
// =============================================================================
module alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUControl,
    output wire        Overflow,
    output wire        Carry,
    output wire        Neg,
    output wire        Zero,
    output wire [31:0] ALUResult
);
    // -------------------------------------------------------------------------
    // 33-bit subtraction: A - B = A + ~B + 1 (two's complement)
    // Used for: SUB result, SLT/SLTU comparison, branch flag generation
    // -------------------------------------------------------------------------
    wire [32:0] sub_ext;
    assign sub_ext = {1'b0, A} + {1'b0, ~B} + 33'd1;
    wire [31:0] sub_result   = sub_ext[31:0];
    wire        sub_carry    = sub_ext[32];   // 1 = no borrow = A >= B (unsigned)
    // Signed overflow: occurs when signs of operands differ and
    // sign of result differs from sign of A
    wire        sub_overflow = ( A[31] & ~B[31] & ~sub_result[31]) |  // pos - neg = neg
                               (~A[31] &  B[31] &  sub_result[31]);   // neg - pos = pos
    wire        sub_neg      = sub_result[31];

    // -------------------------------------------------------------------------
    // 33-bit addition: A + B (carry-out stored in bit 32)
    // -------------------------------------------------------------------------
    wire [32:0] add_ext;
    assign add_ext = {1'b0, A} + {1'b0, B};

    // -------------------------------------------------------------------------
    // Result mux
    // -------------------------------------------------------------------------
    reg [31:0] result_r;
    always @(*) begin
        case (ALUControl)
            4'b0000: result_r = add_ext[31:0];                      // ADD
            4'b0001: result_r = sub_result;                          // SUB
            4'b0010: result_r = A & B;                               // AND
            4'b0011: result_r = A | B;                               // OR
            4'b0100: result_r = A ^ B;                               // XOR
            4'b0101: result_r = A << B[4:0];                         // SLL
            4'b0110: result_r = A >> B[4:0];                         // SRL (logical)
            4'b0111: result_r = $signed(A) >>> B[4:0];               // SRA (arithmetic)
            4'b1000: result_r = {31'b0, sub_neg ^ sub_overflow};     // SLT  (signed)
            4'b1001: result_r = {31'b0, ~sub_carry};                 // SLTU (unsigned)
            4'b1010: result_r = B;                                   // PASS_B (LUI)
            default: result_r = 32'h00000000;
        endcase
    end

    // Flags are always derived from the A - B subtraction path.
    // They are only meaningful when the ALU performs SUB or branch comparison.
    assign ALUResult = result_r;
    assign Zero      = (result_r == 32'h00000000);
    assign Neg       = sub_neg;
    assign Overflow  = sub_overflow;
    assign Carry     = sub_carry;

endmodule
