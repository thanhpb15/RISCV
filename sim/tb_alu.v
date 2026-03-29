// =============================================================================
// Testbench : tb_alu
// DUT       : alu (src/alu.v)
// Coverage  : all 11 ALU operations; zero/neg/overflow/carry flags
// =============================================================================
`timescale 1ns/1ps
module tb_alu;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [31:0] a, b;
    reg  [3:0]  alu_control;
    wire [31:0] result;
    wire        zero, neg, overflow, carry;

    alu uut (
        .A         (a),
        .B         (b),
        .ALUControl(alu_control),
        .ALUResult (result),
        .Zero      (zero),
        .Neg       (neg),
        .Overflow  (overflow),
        .Carry     (carry)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got_r, exp_r;
        input        got_z, exp_z;
        input [79:0] label;
        begin
            if (got_r === exp_r && got_z === exp_z) begin
                $display("  PASS  %-25s  result=%08h  zero=%b", label, got_r, got_z);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-25s  result=%08h(exp %08h)  zero=%b(exp %b)",
                         label, got_r, exp_r, got_z, exp_z);
                fail = fail + 1;
            end
        end
    endtask

    task automatic chk_flags;
        input got_z, exp_z, got_n, exp_n, got_ov, exp_ov, got_c, exp_c;
        input [79:0] label;
        begin
            if (got_z===exp_z && got_n===exp_n && got_ov===exp_ov && got_c===exp_c) begin
                $display("  PASS  %-25s  z=%b n=%b ov=%b c=%b", label, got_z,got_n,got_ov,got_c);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-25s  z=%b(exp%b) n=%b(exp%b) ov=%b(exp%b) c=%b(exp%b)",
                         label, got_z,exp_z, got_n,exp_n, got_ov,exp_ov, got_c,exp_c);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        $display("=== tb_alu ===");

        // --- ADD (4'b0000) ---
        alu_control = 4'b0000;
        a=32'd5;  b=32'd3;  #1; chk(result, 32'd8,          zero, 0, "ADD 5+3=8");
        a=32'd0;  b=32'd0;  #1; chk(result, 32'h0,          zero, 1, "ADD 0+0=0 (zero)");
        a=32'hFFFFFFFF; b=32'd1; #1; chk(result, 32'h0,     zero, 1, "ADD wrap");

        // --- SUB (4'b0001) ---
        alu_control = 4'b0001;
        a=32'd5;  b=32'd3;  #1; chk(result, 32'd2,          zero, 0, "SUB 5-3=2");
        a=32'd3;  b=32'd3;  #1; chk(result, 32'h0,          zero, 1, "SUB 3-3=0 (zero)");
        a=32'd3;  b=32'd5;  #1; chk(result, 32'hFFFFFFFE,   zero, 0, "SUB 3-5=-2");

        // --- AND (4'b0010) ---
        alu_control = 4'b0010;
        a=32'hFF00FF00; b=32'hF0F0F0F0; #1;
        chk(result, 32'hF000F000, zero, 0, "AND misc");
        a=32'hAAAAAAAA; b=32'h55555555; #1;
        chk(result, 32'h00000000, zero, 1, "AND->0 (zero)");

        // --- OR (4'b0011) ---
        alu_control = 4'b0011;
        a=32'hF0F0F0F0; b=32'h0F0F0F0F; #1;
        chk(result, 32'hFFFFFFFF, zero, 0, "OR misc");
        a=32'h00000000; b=32'h00000000; #1;
        chk(result, 32'h00000000, zero, 1, "OR 0|0=0");

        // --- XOR (4'b0100) ---
        alu_control = 4'b0100;
        a=32'hFFFFFFFF; b=32'hFFFFFFFF; #1;
        chk(result, 32'h00000000, zero, 1, "XOR same->0");
        a=32'hF0F0F0F0; b=32'h0F0F0F0F; #1;
        chk(result, 32'hFFFFFFFF, zero, 0, "XOR diff");

        // --- SLL (4'b0101) ---
        alu_control = 4'b0101;
        a=32'h00000001; b=32'd4; #1; chk(result, 32'h00000010, zero, 0, "SLL 1<<4=16");
        a=32'h00000001; b=32'd31;#1; chk(result, 32'h80000000, zero, 0, "SLL 1<<31");
        a=32'h00000001; b=32'd0; #1; chk(result, 32'h00000001, zero, 0, "SLL 1<<0=1");

        // --- SRL (4'b0110) ---
        alu_control = 4'b0110;
        a=32'h80000000; b=32'd1; #1; chk(result, 32'h40000000, zero, 0, "SRL logical");
        a=32'hFFFFFFFF; b=32'd4; #1; chk(result, 32'h0FFFFFFF, zero, 0, "SRL zero-fill");

        // --- SRA (4'b0111) ---
        alu_control = 4'b0111;
        a=32'h80000000; b=32'd1; #1; chk(result, 32'hC0000000, zero, 0, "SRA sign-fill");
        a=32'h40000000; b=32'd1; #1; chk(result, 32'h20000000, zero, 0, "SRA positive");

        // --- SLT (4'b1000) — signed less-than ---
        alu_control = 4'b1000;
        a=32'd3;        b=32'd5; #1; chk(result, 32'h1, zero, 0, "SLT 3<5=1");
        a=32'd5;        b=32'd3; #1; chk(result, 32'h0, zero, 1, "SLT 5<3=0");
        a=32'hFFFFFFFF; b=32'd1; #1; chk(result, 32'h1, zero, 0, "SLT -1<1=1");
        a=32'd1; b=32'hFFFFFFFF; #1; chk(result, 32'h0, zero, 1, "SLT 1<-1=0");

        // --- SLTU (4'b1001) — unsigned less-than ---
        alu_control = 4'b1001;
        a=32'd3;        b=32'd5;         #1; chk(result, 32'h1, zero, 0, "SLTU 3<5=1");
        a=32'd5;        b=32'd3;         #1; chk(result, 32'h0, zero, 1, "SLTU 5<3=0");
        a=32'h00000001; b=32'hFFFFFFFF;  #1; chk(result, 32'h1, zero, 0, "SLTU 1<max=1");
        a=32'hFFFFFFFF; b=32'h00000001;  #1; chk(result, 32'h0, zero, 1, "SLTU max<1=0");

        // --- PASS_B (4'b1010) — used for LUI ---
        alu_control = 4'b1010;
        a=32'hDEADBEEF; b=32'h12345000; #1; chk(result, 32'h12345000, zero, 0, "PASS_B");
        a=32'hFFFFFFFF; b=32'h00000000; #1; chk(result, 32'h00000000, zero, 1, "PASS_B 0");

        // --- Flag checks (SUB path) ---
        alu_control = 4'b0001;
        $display("  [flags: SUB A-B]");
        // A==B: zero=1, neg=0, overflow=0, carry=1
        a=32'd7; b=32'd7; #1;
        chk_flags(zero,1, neg,0, overflow,0, carry,1, "7-7: z=1,n=0,ov=0,c=1");
        // A>B (unsigned): carry=1 (no borrow)
        a=32'd5; b=32'd3; #1;
        chk_flags(zero,0, neg,0, overflow,0, carry,1, "5-3: c=1(A>=B)");
        // A<B (unsigned): carry=0 (borrow)
        a=32'd3; b=32'd5; #1;
        chk_flags(zero,0, neg,1, overflow,0, carry,0, "3-5: c=0(A<B),n=1");
        // Signed overflow: 0x7FFFFFFF - 0xFFFFFFFF = large positive (should be neg)
        a=32'h7FFFFFFF; b=32'hFFFFFFFF; #1;
        chk_flags(zero,0, neg,1, overflow,1, carry,0, "maxpos-(-1): ov=1");

        $display("--- alu: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
