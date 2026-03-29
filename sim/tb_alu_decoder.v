// =============================================================================
// Testbench : tb_alu_decoder
// DUT       : alu_decoder (src/alu_decoder.v)
// Coverage  : LUI special case; alu_op=00/01/10 with all funct3/funct7 combos
// =============================================================================
`timescale 1ns/1ps
module tb_alu_decoder;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg [1:0] alu_op;
    reg [2:0] funct3;
    reg [6:0] funct7, op;
    wire[3:0] alu_control;

    alu_decoder uut (
        .ALUOp     (alu_op),
        .funct3    (funct3),
        .funct7    (funct7),
        .op        (op),
        .ALUControl(alu_control)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [3:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-35s  ctrl=%04b", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-35s  ctrl=%04b  exp=%04b", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_alu_decoder.vcd");
        $dumpvars(0, tb_alu_decoder);
        $display("=== tb_alu_decoder ===");

        // --- LUI override (op=0110111) always → PASS_B regardless of alu_op ---
        op = 7'b0110111;
        alu_op = 2'b00; funct3 = 3'b000; funct7 = 7'b0000000; #1;
        chk(alu_control, 4'b1010, "LUI: PASS_B (alu_op=00)");
        alu_op = 2'b10; funct3 = 3'b000; funct7 = 7'b0000000; #1;
        chk(alu_control, 4'b1010, "LUI: PASS_B (alu_op=10)");

        // --- alu_op=2'b00 → ADD (load/store/JAL/JALR/AUIPC) ---
        op = 7'b0000011; // load
        alu_op = 2'b00; funct3 = 3'bxxx; funct7 = 7'bxxxxxxx; #1;
        chk(alu_control, 4'b0000, "alu_op=00: ADD (load)");
        op = 7'b0100011; // store
        alu_op = 2'b00; #1;
        chk(alu_control, 4'b0000, "alu_op=00: ADD (store)");

        // --- alu_op=2'b01 → SUB (branch comparison) ---
        op = 7'b1100011; // branch
        alu_op = 2'b01; #1;
        chk(alu_control, 4'b0001, "alu_op=01: SUB (branch)");

        // --- alu_op=2'b10 — R-type and I-type arithmetic ---
        op = 7'b0110011; // R-type for SUB disambiguation
        alu_op = 2'b10;

        // funct3=000: ADD if not R-SUB
        funct3 = 3'b000; funct7 = 7'b0000000; #1;
        chk(alu_control, 4'b0000, "R-type ADD  (f7=0)");

        // funct3=000: SUB  (R-type, funct7[5]=1, op[5]=1)
        funct3 = 3'b000; funct7 = 7'b0100000; #1;
        chk(alu_control, 4'b0001, "R-type SUB  (f7[5]=1)");

        // I-type: op[5]=0 → always ADD for funct3=000
        op = 7'b0010011;
        funct3 = 3'b000; funct7 = 7'b0100000; #1;
        chk(alu_control, 4'b0000, "I-type ADDI (op[5]=0)");

        op = 7'b0110011; // back to R-type for remaining
        funct3 = 3'b001; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0101, "SLL  f3=001");
        funct3 = 3'b010; funct7 = 7'b0000000; #1; chk(alu_control, 4'b1000, "SLT  f3=010");
        funct3 = 3'b011; funct7 = 7'b0000000; #1; chk(alu_control, 4'b1001, "SLTU f3=011");
        funct3 = 3'b100; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0100, "XOR  f3=100");
        funct3 = 3'b101; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0110, "SRL  f3=101 f7=0");
        funct3 = 3'b101; funct7 = 7'b0100000; #1; chk(alu_control, 4'b0111, "SRA  f3=101 f7[5]=1");
        funct3 = 3'b110; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0011, "OR   f3=110");
        funct3 = 3'b111; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0010, "AND  f3=111");

        // I-type shifts share the same funct7 disambiguation
        op = 7'b0010011;
        funct3 = 3'b101; funct7 = 7'b0000000; #1; chk(alu_control, 4'b0110, "SRLI f3=101 f7=0");
        funct3 = 3'b101; funct7 = 7'b0100000; #1; chk(alu_control, 4'b0111, "SRAI f3=101 f7[5]=1");

        $display("--- alu_decoder: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
