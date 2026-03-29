// =============================================================================
// Testbench : tb_adder
// DUT       : adder (src/adder.v)
// Coverage  : zero, positive, negative wrap-around, large values
// =============================================================================
`timescale 1ns/1ps
module tb_adder;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [31:0] a, b;
    wire [31:0] y;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    adder uut (.a(a), .b(b), .y(y));

    // -------------------------------------------------------------------------
    // Pass / fail tracking
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [63:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-16s  a=%08h b=%08h => y=%08h",
                         label, a, b, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-16s  a=%08h b=%08h => y=%08h  (exp %08h)",
                         label, a, b, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_adder.vcd");
        $dumpvars(0, tb_adder);
        $display("=== tb_adder ===");

        a = 32'h00000000; b = 32'h00000000; #1; chk(y, 32'h00000000, "0+0");
        a = 32'h00000005; b = 32'h00000003; #1; chk(y, 32'h00000008, "5+3");
        a = 32'h00000064; b = 32'h000000C8; #1; chk(y, 32'h0000012C, "100+200");
        a = 32'hFFFFFFFF; b = 32'h00000001; #1; chk(y, 32'h00000000, "wrap");
        a = 32'h7FFFFFFF; b = 32'h00000001; #1; chk(y, 32'h80000000, "maxpos+1");
        a = 32'h80000000; b = 32'h80000000; #1; chk(y, 32'h00000000, "2xminneg");
        a = 32'hDEADBEEF; b = 32'h12345678; #1; chk(y, 32'hF0E21567, "misc");
        a = 32'hABCDEF01; b = 32'h00000000; #1; chk(y, 32'hABCDEF01, "a+0=a");

        $display("--- adder: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
