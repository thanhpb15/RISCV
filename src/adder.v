// =============================================================================
// Module  : adder
// Description: 32-bit combinational adder
// Used in : PC+4 calculation, branch/JAL target calculation (PC + sign_ext_imm)
// =============================================================================
module adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    assign y = a + b;
endmodule
