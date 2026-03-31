// =============================================================================
// Testbench : tb_if_stage
// DUT       : if_stage (src/if_stage.v)
// Coverage  : reset output; sequential fetch (PC+4); stall (en=0 holds PC);
//             branch/jump redirect (pc_src_e=1 → pc_target_e);
//             correct PC+4 computation; re-reset mid-run
// Notes     : Run from the sim/ directory so $readmemh can find memfile.hex.
//             Word 0 (0x00): 0x00500093  addi x1,x0,5
//             Word 1 (0x04): 0x00300113  addi x2,x0,3
//             Word 2 (0x08): 0x002081B3  add  x3,x1,x2
// =============================================================================
`timescale 1ns/1ps
module tb_if_stage;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk, rstn, en, pc_src_e;
    reg [31:0] pc_target_e;
    wire[31:0] instr_f, pc_f, pc_plus_4_f;

    if_stage uut (
        .clk      (clk),
        .rstn     (rstn),
        .en       (en),
        .PCSrcE   (pc_src_e),
        .PCTargetE(pc_target_e),
        .InstrF   (instr_f),
        .PCF      (pc_f),
        .PCPlus4F (pc_plus_4_f)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got_pc, exp_pc, got_instr, exp_instr, got_pc4, exp_pc4;
        input [79:0] label;
        begin
            if (got_pc===exp_pc && got_instr===exp_instr && got_pc4===exp_pc4) begin
                $display("  PASS  %-30s  pc=%08h  instr=%08h  pc4=%08h",
                         label, got_pc, got_instr, got_pc4);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s", label);
                if (got_pc!==exp_pc)
                    $display("        pc=%08h exp=%08h", got_pc, exp_pc);
                if (got_instr!==exp_instr)
                    $display("        instr=%08h exp=%08h", got_instr, exp_instr);
                if (got_pc4!==exp_pc4)
                    $display("        pc4=%08h exp=%08h", got_pc4, exp_pc4);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Load instruction memory
    // -------------------------------------------------------------------------
    initial
        $readmemh("memfile.hex", uut.imem.mem, 0, 1023);

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_if_stage.vcd");
        $dumpvars(0, tb_if_stage);
        $display("=== tb_if_stage ===");

        rstn = 0; en = 1; pc_src_e = 0; pc_target_e = 32'h0;

        // pc uses synchronous reset: must wait for posedge clk before PC is 0.
        // instruction_memory is combinational: already returns 0 while rstn=0.
        @(posedge clk); #1;

        if (pc_f === 32'h0 && instr_f === 32'h0) begin
            $display("  PASS  %-30s  pc=%08h instr=%08h", "rstn=0: pc=0 instr=0",
                     pc_f, instr_f);
            pass = pass + 1;
        end else begin
            $display("  FAIL  rstn=0: pc=%08h(exp 0) instr=%08h(exp 0)", pc_f, instr_f);
            fail = fail + 1;
        end

        // Release reset
        @(negedge clk); rstn = 1;

        // Cycle 0 → Cycle 1: fetch word 0 (PC=0)
        #1;
        chk(pc_f, 32'h0, instr_f, 32'h00500093, pc_plus_4_f, 32'h4,
            "PC=0: fetch word0");

        // Advance: PC → 4
        @(posedge clk); #1;
        chk(pc_f, 32'h4, instr_f, 32'h00300113, pc_plus_4_f, 32'h8,
            "PC=4: fetch word1");

        // Advance: PC → 8
        @(posedge clk); #1;
        chk(pc_f, 32'h8, instr_f, 32'h002081B3, pc_plus_4_f, 32'hC,
            "PC=8: fetch word2");

        // Stall: en=0, PC stays at 8
        en = 0;
        @(posedge clk); #1;
        chk(pc_f, 32'h8, instr_f, 32'h002081B3, pc_plus_4_f, 32'hC,
            "stall: PC=8 held");

        @(posedge clk); #1;
        chk(pc_f, 32'h8, instr_f, 32'h002081B3, pc_plus_4_f, 32'hC,
            "stall 2nd cycle: PC=8 held");

        // Resume and branch: redirect to address 0x00000000
        en = 1; pc_src_e = 1; pc_target_e = 32'h00000000;
        @(posedge clk); #1;
        pc_src_e = 0;
        chk(pc_f, 32'h0, instr_f, 32'h00500093, pc_plus_4_f, 32'h4,
            "branch to 0x0: PC=0 fetch word0");

        // Advance again after redirect
        @(posedge clk); #1;
        chk(pc_f, 32'h4, instr_f, 32'h00300113, pc_plus_4_f, 32'h8,
            "post-branch: PC=4 fetch word1");

        // Jump to word 3 (0x0C)
        pc_src_e = 1; pc_target_e = 32'h0000000C;
        @(posedge clk); #1;
        pc_src_e = 0;
        chk(pc_f, 32'hC, instr_f, 32'h40208233, pc_plus_4_f, 32'h10,
            "jump to 0xC: fetch word3");

        // Re-reset
        rstn = 0;
        @(posedge clk); #1;
        chk(pc_f, 32'h0, instr_f, 32'h0, pc_plus_4_f, 32'h4, "re-reset: pc=0");

        $display("--- if_stage: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
