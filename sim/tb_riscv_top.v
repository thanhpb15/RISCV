// =============================================================================
// Testbench : tb_riscv_top
// DUT       : riscv_top (src/riscv_top.v)
// Coverage  : End-to-end pipeline execution of the test program in memfile.hex.
//
// Test program (memfile.hex) — each word at byte address 4*N:
//   0x00: addi x1,  x0,  5     → x1 = 5
//   0x04: addi x2,  x0,  3     → x2 = 3
//   0x08: add  x3,  x1,  x2    → x3 = 8  (MEM/WB→EX and EX/MEM→EX forwarding)
//   0x0C: sub  x4,  x1,  x2    → x4 = 2
//   0x10: and  x5,  x1,  x2    → x5 = 1
//   0x14: or   x6,  x1,  x2    → x6 = 7
//   0x18: xor  x7,  x1,  x2    → x7 = 6
//   0x1C: sw   x3,  0(x0)      → DMEM[0] = 8
//   0x20: lw   x8,  0(x0)      → x8 = 8  (load-use hazard: 1-cycle stall)
//   0x24: beq  x8,  x3, +8     → taken → PC = 0x2C  (2-cycle flush)
//   0x28: addi x9,  x0, 99     → SKIPPED (squashed by branch)
//   0x2C: addi x10, x0, 1      → x10 = 1
//   0x30: jal  x11, +8         → x11 = 0x34, PC = 0x38  (2-cycle flush)
//   0x34: addi x12, x0, 200    → SKIPPED (squashed by JAL)
//   0x38: addi x13, x0, 42     → x13 = 42
//   0x3C: jal  x0,  0          → halt (infinite loop, PC stays 0x3C)
//
// Expected register values after pipeline drains:
//   x1=5  x2=3  x3=8  x4=2  x5=1  x6=7  x7=6  x8=8
//   x9=0  x10=1 x11=0x34  x12=0  x13=42
//
// Notes:
//   Run from the sim/ directory so $readmemh can find memfile.hex.
//   Register file is accessed via hierarchical reference:
//     uut.u_id_stage.rf.registers[n]
// =============================================================================
`timescale 1ns/1ps
module tb_riscv_top;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg clk, rstn;

    riscv_top uut (
        .clk (clk),
        .rstn(rstn)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk_reg;
        input [4:0]  regno;
        input [31:0] exp;
        input [79:0] label;
        reg   [31:0] got;
        begin
            got = uut.u_id_stage.rf.registers[regno];
            if (got === exp) begin
                $display("  PASS  %-25s  x%0d=%08h", label, regno, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-25s  x%0d=%08h  exp=%08h", label, regno, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: run N clock cycles
    // -------------------------------------------------------------------------
    integer i;

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_riscv_top.vcd");
        $dumpvars(0, tb_riscv_top);
        $display("=== tb_riscv_top ===");

        // Assert reset for 3 cycles
        rstn = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rstn = 1;

        // Run enough cycles for the test program to complete and pipeline to drain.
        // 16 instructions + 1 load-use stall + 2*2 flush cycles + 4 drain = ~27 min.
        // Wait 60 cycles to be safe.
        repeat (60) @(posedge clk);
        #1;

        $display("\n-- Register file check --");
        chk_reg(5'd1,  32'd5,      "addi x1,0,5");
        chk_reg(5'd2,  32'd3,      "addi x2,0,3");
        chk_reg(5'd3,  32'd8,      "add x3,x1,x2");
        chk_reg(5'd4,  32'd2,      "sub x4,x1,x2");
        chk_reg(5'd5,  32'd1,      "and x5,x1,x2");
        chk_reg(5'd6,  32'd7,      "or  x6,x1,x2");
        chk_reg(5'd7,  32'd6,      "xor x7,x1,x2");
        chk_reg(5'd8,  32'd8,      "lw x8 (load-use)");
        chk_reg(5'd9,  32'd0,      "x9 skipped (branch)");
        chk_reg(5'd10, 32'd1,      "addi x10,0,1");
        chk_reg(5'd11, 32'h34,     "jal x11 → PC+4=0x34");
        chk_reg(5'd12, 32'd0,      "x12 skipped (JAL)");
        chk_reg(5'd13, 32'd42,     "addi x13,0,42");
        chk_reg(5'd0,  32'd0,      "x0 always 0");

        // -----------------------------------------------------------------------
        // Verify that the pipeline is stuck in the halt loop.
        // jal x0, 0 at 0x3C redirects PC back to 0x3C every 3 cycles.
        // While looping, the 2 instructions after jal (at 0x40 and 0x44) are
        // fetched then flushed, so PC cycles: 0x3C → 0x40 → 0x44 → 0x3C ...
        // We check that PC stays within this 3-state loop for several cycles.
        // -----------------------------------------------------------------------
        $display("\n-- Halt verification --");
        begin : halt_check
            integer hc_ok, hc_cyc;
            hc_ok = 1;
            for (hc_cyc = 0; hc_cyc < 9; hc_cyc = hc_cyc + 1) begin
                @(posedge clk); #1;
                if (uut.u_if_stage.pc_reg.PC < 32'h3C ||
                    uut.u_if_stage.pc_reg.PC > 32'h44) begin
                    hc_ok = 0;
                end
            end
            if (hc_ok) begin
                $display("  PASS  halt: PC stayed in loop [0x3C-0x44] for 9 cycles");
                pass = pass + 1;
            end else begin
                $display("  FAIL  halt: PC left loop range [0x3C-0x44]");
                fail = fail + 1;
            end
        end

        // -----------------------------------------------------------------------
        // Reset mid-run: pipeline should clear completely
        // -----------------------------------------------------------------------
        $display("\n-- Mid-run reset --");
        rstn = 0;
        repeat (3) @(posedge clk); #1;
        // After reset, PC should be 0
        if (uut.u_if_stage.pc_reg.PC === 32'h0) begin
            $display("  PASS  reset: PC=0");
            pass = pass + 1;
        end else begin
            $display("  FAIL  reset: PC=%08h exp=0", uut.u_if_stage.pc_reg.PC);
            fail = fail + 1;
        end

        $display("\n--- riscv_top: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
