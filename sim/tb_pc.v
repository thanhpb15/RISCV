// =============================================================================
// Testbench : tb_pc
// DUT       : pc (src/pc.v)
// Coverage  : reset, hold (en=0), advance (en=1), sequential increments
// =============================================================================
`timescale 1ns/1ps
module tb_pc;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk, rstn, en;
    reg [31:0] pc_next;
    wire[31:0] pc;

    pc uut (.clk(clk), .rstn(rstn), .en(en), .PCNext(pc_next), .PC(pc));

    // -------------------------------------------------------------------------
    // Clock  — 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-30s  pc=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  pc=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_pc.vcd");
        $dumpvars(0, tb_pc);
        $display("=== tb_pc ===");

        // --- reset ---
        rstn = 0; en = 0; pc_next = 32'hDEADBEEF;
        @(posedge clk); #1;
        chk(pc, 32'h00000000, "reset: pc=0");

        rstn = 0; en = 1; pc_next = 32'hCAFEBABE;
        @(posedge clk); #1;
        chk(pc, 32'h00000000, "reset holds even en=1");

        // --- release reset, test hold ---
        rstn = 1; en = 0; pc_next = 32'h00000004;
        @(posedge clk); #1;
        chk(pc, 32'h00000000, "en=0: pc holds at 0");

        pc_next = 32'h00001000;
        @(posedge clk); #1;
        chk(pc, 32'h00000000, "en=0: pc still holds");

        // --- advance ---
        en = 1; pc_next = 32'h00000004;
        @(posedge clk); #1;
        chk(pc, 32'h00000004, "en=1: load 0x4");

        pc_next = 32'h00000008;
        @(posedge clk); #1;
        chk(pc, 32'h00000008, "en=1: load 0x8");

        pc_next = 32'h0000000C;
        @(posedge clk); #1;
        chk(pc, 32'h0000000C, "en=1: load 0xC");

        // --- stall mid-sequence ---
        en = 0;
        @(posedge clk); #1;
        chk(pc, 32'h0000000C, "en=0: stall at 0xC");

        // --- resume ---
        en = 1; pc_next = 32'h00000010;
        @(posedge clk); #1;
        chk(pc, 32'h00000010, "en=1: resume to 0x10");

        // --- branch target ---
        pc_next = 32'h00002000;
        @(posedge clk); #1;
        chk(pc, 32'h00002000, "branch target 0x2000");

        // --- re-reset ---
        rstn = 0;
        @(posedge clk); #1;
        chk(pc, 32'h00000000, "re-reset: back to 0");

        $display("--- pc: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
