// =============================================================================
// Testbench : tb_mux
// DUT       : mux (2-to-1) and mux_3_1 (3-to-1)  — src/mux.v
// =============================================================================
`timescale 1ns/1ps
module tb_mux;

    // -------------------------------------------------------------------------
    // 2-to-1 MUX signals
    // -------------------------------------------------------------------------
    reg  [31:0] a2, b2;
    reg         s2;
    wire [31:0] c2;

    mux uut_mux2 (.d0(a2), .d1(b2), .s(s2), .y(c2));

    // -------------------------------------------------------------------------
    // 3-to-1 MUX signals
    // -------------------------------------------------------------------------
    reg  [31:0] a3, b3, c3;
    reg  [1:0]  s3;
    wire [31:0] d3;

    mux_3_1 uut_mux3 (.d0(a3), .d1(b3), .d2(c3), .s(s3), .y(d3));

    // -------------------------------------------------------------------------
    // Pass / fail tracking
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk32;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-20s  got=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-20s  got=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_mux.vcd");
        $dumpvars(0, tb_mux);
        $display("=== tb_mux (2-to-1) ===");

        a2 = 32'hAAAA0000; b2 = 32'h0000BBBB;
        s2 = 0; #1; chk32(c2, 32'hAAAA0000, "mux2: s=0 -> a");
        s2 = 1; #1; chk32(c2, 32'h0000BBBB, "mux2: s=1 -> b");

        a2 = 32'h12345678; b2 = 32'h87654321;
        s2 = 0; #1; chk32(c2, 32'h12345678, "mux2: s=0 misc");
        s2 = 1; #1; chk32(c2, 32'h87654321, "mux2: s=1 misc");

        $display("=== tb_mux (3-to-1) ===");

        a3 = 32'hAAA00000; b3 = 32'hBBB00000; c3 = 32'hCCC00000;
        s3 = 2'b00; #1; chk32(d3, 32'hAAA00000, "mux3: 00 -> a");
        s3 = 2'b01; #1; chk32(d3, 32'hBBB00000, "mux3: 01 -> b");
        s3 = 2'b10; #1; chk32(d3, 32'hCCC00000, "mux3: 10 -> c");
        s3 = 2'b11; #1; chk32(d3, 32'h00000000, "mux3: 11 -> 0");

        a3 = 32'hDEADBEEF; b3 = 32'hCAFEBABE; c3 = 32'h0BADF00D;
        s3 = 2'b00; #1; chk32(d3, 32'hDEADBEEF, "mux3: 00 misc");
        s3 = 2'b01; #1; chk32(d3, 32'hCAFEBABE, "mux3: 01 misc");
        s3 = 2'b10; #1; chk32(d3, 32'h0BADF00D, "mux3: 10 misc");

        $display("--- mux: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
