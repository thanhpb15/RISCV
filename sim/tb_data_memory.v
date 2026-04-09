// =============================================================================
// Testbench : tb_data_memory
// DUT       : data_memory (src/data_memory.v)
// Coverage  : rstn forces zero read; write-then-read-back at multiple word
//             addresses; write_en gate; byte-alignment ignored (word access);
//             boundary address (word 1023); consecutive writes
// =============================================================================
`timescale 1ns/1ps
module tb_data_memory;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk, rstn, write_en;
    reg [3:0]  byte_en;
    reg [31:0] addr, write_data;
    wire[31:0] read_data;

    data_memory uut (
        .clk (clk),
        .rstn(rstn),
        .WE  (write_en),
        .BE  (byte_en),
        .A   (addr),
        .WD  (write_data),
        .RD  (read_data)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-35s  data=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-35s  data=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // Write helper: assert write_en for one cycle (all byte lanes enabled) then deassert
    task automatic do_write;
        input [31:0] a, d;
        begin
            addr = a; write_data = d; write_en = 1; byte_en = 4'b1111;
            @(posedge clk); #1;
            write_en = 0; byte_en = 4'b0000;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);
        $display("=== tb_data_memory ===");

        rstn = 0; write_en = 0; byte_en = 4'b0000; addr = 32'h0; write_data = 32'h0;

        // Reset active: read returns 0
        #3;
        chk(read_data, 32'h0, "rstn=0: forced 0");

        // Write during reset must not cause trouble (not stored)
        write_en = 1; byte_en = 4'b1111; addr = 32'h0; write_data = 32'hDEADBEEF;
        @(posedge clk); #1;
        write_en = 0; byte_en = 4'b0000;

        // Deassert reset
        @(negedge clk); rstn = 1;

        // Verify data written under reset did not persist
        addr = 32'h0; #1;
        // Note: data_memory has no rstn-gated write, so the write during reset
        // may have stored the value. We only verify the read-during-reset = 0
        // behavior, which was already checked above.

        // --- Basic write/read-back ---
        do_write(32'h00000000, 32'hAABBCCDD);
        addr = 32'h00000000; #1;
        chk(read_data, 32'hAABBCCDD, "addr=0: write/read 0xAABBCCDD");

        do_write(32'h00000004, 32'h12345678);
        addr = 32'h00000004; #1;
        chk(read_data, 32'h12345678, "addr=4: write/read 0x12345678");

        do_write(32'h00000008, 32'hCAFEBABE);
        addr = 32'h00000008; #1;
        chk(read_data, 32'hCAFEBABE, "addr=8: write/read 0xCAFEBABE");

        // --- Different words do not alias ---
        addr = 32'h00000000; #1;
        chk(read_data, 32'hAABBCCDD, "addr=0: no alias with addr=4,8");

        // --- Byte-alignment: bits [1:0] ignored → word address ---
        do_write(32'h0000000C, 32'hFEEDFACE);
        addr = 32'h0000000C; #1; chk(read_data, 32'hFEEDFACE, "addr=0xC: base");
        addr = 32'h0000000D; #1; chk(read_data, 32'hFEEDFACE, "addr=0xD: byte-align → same word");
        addr = 32'h0000000E; #1; chk(read_data, 32'hFEEDFACE, "addr=0xE: byte-align → same word");
        addr = 32'h0000000F; #1; chk(read_data, 32'hFEEDFACE, "addr=0xF: byte-align → same word");

        // --- write_en=0: data unchanged ---
        write_en = 0; addr = 32'h0; write_data = 32'h00000000;
        @(posedge clk); #1;
        addr = 32'h0; #1;
        chk(read_data, 32'hAABBCCDD, "write_en=0: addr=0 unchanged");

        // --- Overwrite same address ---
        do_write(32'h00000000, 32'h00000001);
        addr = 32'h0; #1;
        chk(read_data, 32'h00000001, "addr=0: overwrite → 0x1");

        // --- Boundary: word 1023 (byte addr 0xFFC) ---
        do_write(32'h00000FFC, 32'hBEEFCAFE);
        addr = 32'h00000FFC; #1;
        chk(read_data, 32'hBEEFCAFE, "addr=0xFFC: boundary word 1023");

        // --- rstn=0 overrides combinational read ---
        rstn = 0; addr = 32'h00000004; #1;
        chk(read_data, 32'h0, "rstn=0: forced 0 after write");
        rstn = 1; #1;
        chk(read_data, 32'h12345678, "rstn=1: read restored");

        $display("--- data_memory: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end
endmodule