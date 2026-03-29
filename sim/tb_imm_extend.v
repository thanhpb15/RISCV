// =============================================================================
// Testbench : tb_imm_extend
// DUT       : imm_extend (src/imm_extend.v)
// Coverage  : all five immediate formats (I / S / B / U / J), positive and
//             negative (sign-extension) values
// =============================================================================
`timescale 1ns/1ps
module tb_imm_extend;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [31:0] instr;
    reg  [2:0]  imm_src;
    wire [31:0] imm_ext;

    imm_extend uut (.Instr(instr), .ImmSrc(imm_src), .ImmExt(imm_ext));

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-30s  imm=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  imm=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_imm_extend.vcd");
        $dumpvars(0, tb_imm_extend);
        $display("=== tb_imm_extend ===");

        // ===== I-type (imm_src=3'b000) =====
        // Positive: addi x1, x0, 100  (imm=100=0x064)
        // instr[31:20] = 0x064 → 0000_0110_0100
        imm_src = 3'b000;
        instr = 32'b000001100100_00000_000_00001_0010011; #1;
        chk(imm_ext, 32'd100, "I-type: +100");

        // Negative: addi x1, x0, -5  (imm = 0xFFB)
        // instr[31:20] = 12'hFFB
        instr = 32'b111111111011_00000_000_00001_0010011; #1;
        chk(imm_ext, 32'hFFFFFFFB, "I-type: -5 sext");

        // Negative: imm = -1 (all ones)
        instr = 32'b111111111111_00000_000_00001_0010011; #1;
        chk(imm_ext, 32'hFFFFFFFF, "I-type: -1 sext");

        // ===== S-type (imm_src=3'b001) =====
        // sw x3, 8(x0): imm=8 → imm[11:5]=0000000, imm[4:0]=01000
        // instr[31:25]=0000000, instr[11:7]=01000
        imm_src = 3'b001;
        instr = 32'b0000000_00011_00000_010_01000_0100011; #1;
        chk(imm_ext, 32'd8, "S-type: +8");

        // sw x3, -8(x0): imm=-8=0xFF8 → imm[11:5]=1111111, imm[4:0]=11000
        instr = 32'b1111111_00011_00000_010_11000_0100011; #1;
        chk(imm_ext, 32'hFFFFFFF8, "S-type: -8 sext");

        // ===== B-type (imm_src=3'b010) =====
        // beq with offset=8:
        // imm=8 → imm[12]=0, imm[11]=0, imm[10:5]=000000, imm[4:1]=0100
        // instr[31]=0, instr[7]=0, instr[30:25]=000000, instr[11:8]=0100
        imm_src = 3'b010;
        instr = 32'b0_000000_00000_00000_000_0100_0_1100011; #1;
        chk(imm_ext, 32'd8, "B-type: +8");

        // beq with offset=-8: -8 in 13-bit two's complement = 1_1111_1111_1000
        // imm[12]=1(sign), imm[11]=1, imm[10:5]=111111, imm[4:1]=1100
        // instr[31]=imm[12]=1, instr[30:25]=imm[10:5]=111111,
        // instr[11:8]=imm[4:1]=1100, instr[7]=imm[11]=1
        instr = 32'b1_111111_00000_00000_000_1100_1_1100011; #1;
        chk(imm_ext, 32'hFFFFFFF8, "B-type: -8 sext");

        // ===== U-type (imm_src=3'b011) =====
        // lui x1, 0x12345 → instr[31:12]=0x12345
        imm_src = 3'b011;
        instr = 32'h12345_000 | 7'b0110111; #1;  // lui encoding
        chk(imm_ext, 32'h12345000, "U-type: 0x12345000");

        instr[31:12] = 20'hFFFFF; instr[11:0] = 12'h037; #1;
        chk(imm_ext, 32'hFFFFF000, "U-type: 0xFFFFF000");

        // ===== J-type (imm_src=3'b100) =====
        // jal with offset=8:
        // imm=8 → imm[3]=1, rest 0 → imm[10:1]=0000000100
        // instr[31]=imm[20]=0, instr[30:21]=imm[10:1]=0000000100,
        // instr[20]=imm[11]=0, instr[19:12]=imm[19:12]=00000000
        imm_src = 3'b100;
        instr = 32'b0_0000000100_0_00000000_00000_1101111; #1;
        chk(imm_ext, 32'd8, "J-type: +8");

        // jal with offset=-8: 21-bit two's complement of -8
        // imm[10:1]=1111111100  (imm[3..10]=1, imm[2:1]=0)
        // instr[31]=imm[20]=1, instr[30:21]=imm[10:1]=1111111100,
        // instr[20]=imm[11]=1, instr[19:12]=imm[19:12]=11111111
        instr = 32'b1_1111111100_1_11111111_00000_1101111; #1;
        chk(imm_ext, 32'hFFFFFFF8, "J-type: -8 sext");

        $display("--- imm_extend: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
