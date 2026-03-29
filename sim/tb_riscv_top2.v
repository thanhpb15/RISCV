// =============================================================================
// Testbench : tb_riscv_top2
// DUT       : riscv_top (src/riscv_top.v)
// Program   : sim/memfile2.hex  — comprehensive RV32I coverage
//
// Instructions exercised:
//   R-type  : add, sub, and, or, xor, sll, srl, sra, slt, sltu
//   I-type  : addi, andi, ori, xori, slli, srli, srai, slti, sltiu
//   U-type  : lui, auipc
//   Memory  : sw, lw
//   Branch  : beq(taken), bne(taken), blt(taken), bge(taken),
//             bltu(taken), bgeu(taken), beq(NOT taken)
//   Jump    : jal, jalr
//
// Hazards exercised:
//   EX/MEM→EX forwarding  (0xCC: addi x31,10 → 0xD0: add x31,x31,x31  → x31=20)
//   MEM/WB→EX forwarding  (0xD4: addi x31,5  → nop gap → 0xDC: add x31,x31,x31 → x31=10)
//   Load-use stall         (0xE4: lw x31      → 0xE8: add x31,x31,x31  → x31=20, 1-cycle stall)
//   MEM/WB→EX via lw      (0x6C: beq x24 — x24 loaded 2 cycles ago at 0x64, gap at 0x68)
//   Branch flush (2 cycles) for every taken branch
//   JAL   flush (2 cycles)
//   JALR  flush (2 cycles)
//   Not-taken branch       (no flush, pipeline continues in order)
//
// Run from sim/ so $readmemh("memfile2.hex") resolves correctly.
// =============================================================================
`timescale 1ns/1ps
module tb_riscv_top2;

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

    // Override the instruction memory with the comprehensive test program.
    // The #1 delay (1 ps) ensures this runs after instruction_memory.v's own
    // initial block (which loads the default memfile.hex at time 0).
    initial begin
        #1;
        $readmemh("memfile2.hex", uut.u_if_stage.imem.mem, 0, 1023);
    end

    // -------------------------------------------------------------------------
    // Pass / fail counters
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
                $display("  PASS  %-30s  x%-2d = %08h", label, regno, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  x%-2d = %08h  exp = %08h",
                         label, regno, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_riscv_top2.vcd");
        $dumpvars(0, tb_riscv_top2);
        $display("=== tb_riscv_top2  (comprehensive RV32I) ===");

        // Assert reset for 3 cycles then release
        rstn = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rstn = 1;

        // Wait for program to complete and pipeline to drain.
        // 61 instructions + 1 load-use stall + 6*2 branch flushes
        // + 1 JAL flush(2) + 1 JALR flush(2) + 4 drain = ~84 cycles.
        // 200 cycles is more than enough.
        repeat (200) @(posedge clk);
        #1;

        // ─── Setup / U-type ───────────────────────────────────────────────
        $display("\n-- Setup & U-type --");
        chk_reg(5'd1,  32'h00000001, "addi x1,x0,1");
        chk_reg(5'd2,  32'hFFFFFFFF, "addi x2,x0,-1");
        chk_reg(5'd3,  32'h12345000, "lui  x3,0x12345");
        chk_reg(5'd4,  32'h0000100C, "auipc x4,1 (PC=0x0C+0x1000)");

        // ─── R-type ───────────────────────────────────────────────────────
        $display("\n-- R-type --");
        chk_reg(5'd5,  32'h00000000, "add  x5,x1,x2  (1+(-1)=0)");
        chk_reg(5'd6,  32'hFFFFFFFE, "sub  x6,x2,x1  (-1-1=-2)");
        chk_reg(5'd7,  32'h00000001, "and  x7,x2,x1");
        chk_reg(5'd8,  32'hFFFFFFFF, "or   x8,x2,x1");
        chk_reg(5'd9,  32'hFFFFFFFE, "xor  x9,x2,x1");
        chk_reg(5'd10, 32'h00000002, "sll  x10,x1,x1 (1<<1)");
        chk_reg(5'd11, 32'h7FFFFFFF, "srl  x11,x2,x1 (>>1 logical)");
        chk_reg(5'd12, 32'hFFFFFFFF, "sra  x12,x2,x1 (-1>>1 arith)");
        chk_reg(5'd13, 32'h00000001, "slt  x13,x2,x1 (-1<1 signed)");
        chk_reg(5'd14, 32'h00000001, "sltu x14,x1,x2 (1<0xFFFF..u)");

        // ─── I-type arithmetic ────────────────────────────────────────────
        $display("\n-- I-type arithmetic --");
        chk_reg(5'd15, 32'h00000064, "addi  x15,x0,100");
        chk_reg(5'd16, 32'h00000004, "andi  x16,x15,0x0F");
        chk_reg(5'd17, 32'h000000E4, "ori   x17,x15,0x80");
        chk_reg(5'd18, 32'h0000006B, "xori  x18,x15,0x0F");
        chk_reg(5'd19, 32'h00000010, "slli  x19,x1,4");
        chk_reg(5'd20, 32'h0000000F, "srli  x20,x2,28");
        chk_reg(5'd21, 32'hFFFFFFFF, "srai  x21,x2,4 (-1>>4 arith)");
        chk_reg(5'd22, 32'h00000001, "slti  x22,x2,0 (-1<0 signed)");
        chk_reg(5'd23, 32'h00000001, "sltiu x23,x1,2 (1<2 unsigned)");

        // ─── Load / Store ─────────────────────────────────────────────────
        $display("\n-- Load / Store --");
        chk_reg(5'd24, 32'h12345000, "lw x24,0(x0)");
        chk_reg(5'd25, 32'h00000064, "lw x25,4(x0)");

        // ─── Branches (all taken → x26=99 addi instructions squashed) ────
        $display("\n-- Branches --");
        chk_reg(5'd26, 32'h00000001, "x26=1: 6 branches taken + fall-thru");

        // ─── JAL / JALR ───────────────────────────────────────────────────
        $display("\n-- JAL / JALR --");
        chk_reg(5'd27, 32'h000000A4, "jal x27 → rd=PC+4=0xA4");
        chk_reg(5'd28, 32'h00000037, "x28=55 (JALR target), not 99");
        chk_reg(5'd29, 32'h000000B8, "jalr x29 → rd=PC+4=0xB8");
        chk_reg(5'd30, 32'h000000C0, "addi x30,x0,0xC0 (JALR base)");

        // ─── Explicit Hazard Tests ────────────────────────────────────────
        $display("\n-- Hazard Tests --");
        // EX/MEM→EX: addi x31,10 → add x31,x31,x31  → x31=20
        // MEM/WB→EX: addi x31,5  → nop → add x31,x31,x31  → x31=10
        // Load-use:  sw/lw x31   → add x31,x31,x31  → x31=20 (1-cycle stall)
        chk_reg(5'd31, 32'h00000014, "hazard section: x31=20 (0x14)");

        // ─── x0 always zero ───────────────────────────────────────────────
        $display("\n-- Invariants --");
        chk_reg(5'd0,  32'h00000000, "x0 always 0");

        // ─── Halt verification ────────────────────────────────────────────
        // jal x0,0 at 0xEC loops with period 3: 0xEC → 0xF0 → 0xF4 → 0xEC
        $display("\n-- Halt verification --");
        begin : halt_check
            integer hc_ok, hc_cyc;
            hc_ok = 1;
            for (hc_cyc = 0; hc_cyc < 9; hc_cyc = hc_cyc + 1) begin
                @(posedge clk); #1;
                if (uut.u_if_stage.pc_reg.PC < 32'hEC ||
                    uut.u_if_stage.pc_reg.PC > 32'hF4) begin
                    hc_ok = 0;
                end
            end
            if (hc_ok) begin
                $display("  PASS  halt: PC stayed in loop [0xEC-0xF4] for 9 cycles");
                pass = pass + 1;
            end else begin
                $display("  FAIL  halt: PC left loop range [0xEC-0xF4]");
                fail = fail + 1;
            end
        end

        // ─── Mid-run reset ────────────────────────────────────────────────
        $display("\n-- Mid-run reset --");
        rstn = 0;
        repeat (3) @(posedge clk); #1;
        if (uut.u_if_stage.pc_reg.PC === 32'h0) begin
            $display("  PASS  reset: PC=0");
            pass = pass + 1;
        end else begin
            $display("  FAIL  reset: PC=%08h  exp=0",
                     uut.u_if_stage.pc_reg.PC);
            fail = fail + 1;
        end

        $display("\n--- riscv_top2: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
