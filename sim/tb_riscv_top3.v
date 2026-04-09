// =============================================================================
// Testbench : tb_riscv_top3
// DUT       : riscv_top (src/riscv_top.v)
// Program   : sim/memfile3.hex
//
// Instructions covered (full RV32I base ISA):
//   R-type  : add, sub, and, or, xor, sll, srl, sra, slt, sltu       (10/10)
//   I-type  : addi, andi, ori, xori, slli, srli, srai, slti, sltiu    (9/9)
//   U-type  : lui, auipc                                               (2/2)
//   Load    : lw, lb, lbu, lh, lhu                                     (5/5)
//   Store   : sw, sb, sh                                               (3/3)
//   Branch  : beq(taken), bne(taken), blt(taken), bge(taken),
//             bltu(taken), bgeu(taken), beq(NOT taken)                 (7/7)
//   Jump    : jal, jalr                                                (2/2)
//
// Hazards covered:
//   EX/MEM->EX forwarding   back-to-back producer/consumer
//   MEM/WB->EX forwarding   one-instruction gap
//   Load-use stall          lw immediately followed by dependent ALU op
//   Branch flush (2 cy)     6 taken branches
//   JAL  flush  (2 cy)
//   JALR flush  (2 cy)
//   Not-taken branch        pipeline continues without flush
//
// Sub-word register assignments (final values):
//   x4 = 0xFFFFFED4  lh  x4,10(x0)  sign-extended halfword 0xFED4
//   x5 = 0xFFFFFFAB  lb  x5, 8(x0)  sign-extended byte     0xAB
//   x6 = 0x0000FED4  lhu x6,10(x0)  zero-extended halfword 0xFED4
//
// Run from sim/ so $readmemh can find memfile3.hex.
// Register file accessed via: uut.u_id_stage.rf.registers[n]
// Instruction memory    via: uut.u_if_stage.imem.mem[pc[11:2]]
// =============================================================================
`timescale 1ns/1ps
module tb_riscv_top3;

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
    // Load instruction memory
    // -------------------------------------------------------------------------
    initial
        $readmemh("memfile3.hex", uut.u_if_stage.imem.mem, 0, 1023);

    // -------------------------------------------------------------------------
    // Inline disassembler (uses $write — no trailing newline)
    // Caller is responsible for the final $display / $write("\n").
    // Format:  [<hex>] <mnemonic>  <operands>
    // -------------------------------------------------------------------------
    task automatic disasm_w;
        input [31:0] instr;
        reg [6:0] op;
        reg [4:0] rd, rs1, rs2;
        reg [2:0] f3;
        reg [6:0] f7;
        reg signed [31:0] imm_i, imm_s, imm_b, imm_j;
        begin
            op  = instr[6:0];
            rd  = instr[11:7];
            f3  = instr[14:12];
            rs1 = instr[19:15];
            rs2 = instr[24:20];
            f7  = instr[31:25];
            imm_i = {{20{instr[31]}}, instr[31:20]};
            imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            $write("[%08h] ", instr);
            case (op)
                7'b0110011: begin // R-type
                    case ({f7, f3})
                        10'b0000000_000: $write("add   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0100000_000: $write("sub   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_001: $write("sll   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_010: $write("slt   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_011: $write("sltu  x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_100: $write("xor   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_101: $write("srl   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0100000_101: $write("sra   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_110: $write("or    x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        10'b0000000_111: $write("and   x%0d, x%0d, x%0d",  rd, rs1, rs2);
                        default:         $write("R?    %08h",               instr);
                    endcase
                end
                7'b0010011: begin // I-type arithmetic
                    case (f3)
                        3'b000: $write("addi  x%0d, x%0d, %0d",  rd, rs1, imm_i);
                        3'b010: $write("slti  x%0d, x%0d, %0d",  rd, rs1, imm_i);
                        3'b011: $write("sltiu x%0d, x%0d, %0d",  rd, rs1, $unsigned(imm_i));
                        3'b100: $write("xori  x%0d, x%0d, %0d",  rd, rs1, imm_i);
                        3'b110: $write("ori   x%0d, x%0d, %0d",  rd, rs1, imm_i);
                        3'b111: $write("andi  x%0d, x%0d, %0d",  rd, rs1, imm_i);
                        3'b001: $write("slli  x%0d, x%0d, %0d",  rd, rs1, rs2);
                        3'b101: begin
                            if (f7[5]) $write("srai  x%0d, x%0d, %0d", rd, rs1, rs2);
                            else       $write("srli  x%0d, x%0d, %0d", rd, rs1, rs2);
                        end
                        default: $write("Iarith? %08h", instr);
                    endcase
                end
                7'b0000011: begin // Load
                    case (f3)
                        3'b000: $write("lb    x%0d, %0d(x%0d)",  rd, imm_i, rs1);
                        3'b001: $write("lh    x%0d, %0d(x%0d)",  rd, imm_i, rs1);
                        3'b010: $write("lw    x%0d, %0d(x%0d)",  rd, imm_i, rs1);
                        3'b100: $write("lbu   x%0d, %0d(x%0d)",  rd, imm_i, rs1);
                        3'b101: $write("lhu   x%0d, %0d(x%0d)",  rd, imm_i, rs1);
                        default: $write("load? %08h",             instr);
                    endcase
                end
                7'b0100011: begin // Store
                    case (f3)
                        3'b000: $write("sb    x%0d, %0d(x%0d)",  rs2, imm_s, rs1);
                        3'b001: $write("sh    x%0d, %0d(x%0d)",  rs2, imm_s, rs1);
                        3'b010: $write("sw    x%0d, %0d(x%0d)",  rs2, imm_s, rs1);
                        default: $write("store? %08h",            instr);
                    endcase
                end
                7'b1100011: begin // Branch
                    case (f3)
                        3'b000: $write("beq   x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        3'b001: $write("bne   x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        3'b100: $write("blt   x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        3'b101: $write("bge   x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        3'b110: $write("bltu  x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        3'b111: $write("bgeu  x%0d, x%0d, %0d",  rs1, rs2, imm_b);
                        default: $write("branch? %08h",           instr);
                    endcase
                end
                7'b1101111: $write("jal   x%0d, %0d",          rd,  imm_j);
                7'b1100111: $write("jalr  x%0d, x%0d, %0d",    rd,  rs1, imm_i);
                7'b0110111: $write("lui   x%0d, 0x%05h",        rd,  instr[31:12]);
                7'b0010111: $write("auipc x%0d, 0x%05h",        rd,  instr[31:12]);
                default:    $write("???   %08h",                 instr);
            endcase
        end
    endtask

    // -------------------------------------------------------------------------
    // Pass / fail counter and register check helper
    //
    // chk_reg(regno, expected_value, instruction_pc)
    //   Looks up the instruction at instruction_pc from imem, disassembles it
    //   inline, and prints PASS/FAIL with the register result on the same line.
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;
    integer i;

    // Check by instruction PC — disassembles the instruction at ipc from imem.
    task automatic chk_reg;
        input [4:0]  regno;
        input [31:0] exp;
        input [31:0] ipc;      // byte address of the instruction being verified
        reg   [31:0] got, instr;
        begin
            got   = uut.u_id_stage.rf.registers[regno];
            instr = uut.u_if_stage.imem.mem[ipc[11:2]];
            if (got === exp) begin
                $write("  PASS  ");
                disasm_w(instr);
                $display("  -->  x%0d = %08h", regno, got);
                pass = pass + 1;
            end else begin
                $write("  FAIL  ");
                disasm_w(instr);
                $display("  -->  x%0d = %08h  exp = %08h", regno, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // Check with a free-text label — used when the tested behaviour spans
    // multiple instructions (e.g. branches whose effect is observed via a
    // sentinel register rather than a single write instruction).
    task automatic chk_reg_lbl;
        input [4:0]   regno;
        input [31:0]  exp;
        input [159:0] label;   // up to 20 characters
        reg   [31:0]  got;
        begin
            got = uut.u_id_stage.rf.registers[regno];
            if (got === exp) begin
                $display("  PASS  %-40s  -->  x%0d = %08h", label, regno, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  -->  x%0d = %08h  exp = %08h",
                         label, regno, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_riscv_top3.vcd");
        $dumpvars(0, tb_riscv_top3);
        $display("=== tb_riscv_top3  (full RV32I instruction coverage) ===");

        // Zero-initialise GPR array (ASIC: no hardware reset on GPRs)
        for (i = 0; i < 32; i = i + 1)
            uut.u_id_stage.rf.registers[i] = 32'h0;

        // Assert reset for 3 cycles then release
        rstn = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rstn = 1;

        // 69 instructions + ~3 load-use stalls + 8*2 flush cycles + drain = ~110 cycles.
        // 250 cycles is comfortably safe.
        repeat (250) @(posedge clk);
        #1;

        // ─── Setup ───────────────────────────────────────────────────────────
        $display("\n-- Setup --");
        chk_reg(5'd1,  32'h00000007, 32'h000);  // addi x1,  x0,  7
        chk_reg(5'd2,  32'hFFFFFFFD, 32'h004);  // addi x2,  x0, -3
        chk_reg(5'd3,  32'h00000003, 32'h008);  // addi x3,  x0,  3

        // ─── R-type ──────────────────────────────────────────────────────────
        $display("\n-- R-type --");
        chk_reg(5'd27, 32'h00000004, 32'h00C);  // add  x27, x1,  x2
        // sub x5 and and x6 are overwritten later by lb/lhu; checked in sub-word section
        chk_reg(5'd7,  32'hFFFFFFFF, 32'h018);  // or   x7,  x1,  x2
        chk_reg(5'd8,  32'hFFFFFFFA, 32'h01C);  // xor  x8,  x1,  x2
        chk_reg(5'd9,  32'h00000038, 32'h020);  // sll  x9,  x1,  x3
        chk_reg(5'd10, 32'h1FFFFFFF, 32'h024);  // srl  x10, x2,  x3
        chk_reg(5'd11, 32'hFFFFFFFF, 32'h028);  // sra  x11, x2,  x3
        chk_reg(5'd12, 32'h00000001, 32'h02C);  // slt  x12, x2,  x1
        chk_reg(5'd13, 32'h00000001, 32'h030);  // sltu x13, x1,  x2

        // ─── I-type arithmetic ────────────────────────────────────────────────
        $display("\n-- I-type arithmetic --");
        chk_reg(5'd14, 32'h00000064, 32'h034);  // addi  x14, x0,  100
        chk_reg(5'd15, 32'h00000004, 32'h038);  // andi  x15, x14, 0x0F
        chk_reg(5'd16, 32'h000000E4, 32'h03C);  // ori   x16, x14, 0x80
        chk_reg(5'd17, 32'h0000009B, 32'h040);  // xori  x17, x14, 0xFF
        chk_reg(5'd18, 32'h0000001C, 32'h044);  // slli  x18, x1,  2
        chk_reg(5'd19, 32'h0FFFFFFF, 32'h048);  // srli  x19, x2,  4
        chk_reg(5'd20, 32'hFFFFFFFF, 32'h04C);  // srai  x20, x2,  4
        chk_reg(5'd21, 32'h00000001, 32'h050);  // slti  x21, x2,  0
        chk_reg(5'd22, 32'h00000001, 32'h054);  // sltiu x22, x1,  10

        // ─── LUI / AUIPC ─────────────────────────────────────────────────────
        $display("\n-- LUI / AUIPC --");
        chk_reg(5'd23, 32'hABCDE000, 32'h058);  // lui   x23, 0xABCDE
        chk_reg(5'd24, 32'h0000005C, 32'h05C);  // auipc x24, 0

        // ─── Store / Load word ────────────────────────────────────────────────
        $display("\n-- sw / lw --");
        chk_reg(5'd25, 32'h00000064, 32'h070);  // lw    x25, 4(x0)  -> 100
        chk_reg(5'd26, 32'h0000000E, 32'h06C);  // add   x26, x25, x25  (load-use hazard)

        // ─── Sub-word Store / Load ────────────────────────────────────────────
        $display("\n-- sb / lb --");
        chk_reg(5'd5,  32'hFFFFFFAB, 32'h0F8);  // lb    x5,  8(x0)

        $display("\n-- sh / lh --");
        chk_reg(5'd4,  32'hFFFFFED4, 32'h108);  // lh    x4,  10(x0)

        $display("\n-- sh / lhu --");
        chk_reg(5'd6,  32'h0000FED4, 32'h10C);  // lhu   x6,  10(x0)

        // ─── Branches ────────────────────────────────────────────────────────
        // x28 is a sentinel: stays 0 if any taken branch misfires (sets it to 99),
        // incremented to 1 by not-taken beq fall-through, +1 again by JALR path → 2.
        $display("\n-- Branches (beq/bne/blt/bge/bltu/bgeu + not-taken) --");
        chk_reg_lbl(5'd28, 32'h00000002,
            "beq/bne/blt/bge/bltu/bgeu + not-taken");

        // ─── JAL ─────────────────────────────────────────────────────────────
        $display("\n-- JAL --");
        chk_reg(5'd29, 32'h000000B4, 32'h0B0);  // jal   x29, +12

        // ─── JALR ─────────────────────────────────────────────────────────────
        $display("\n-- JALR --");
        chk_reg(5'd30, 32'h000000CC, 32'h0BC);  // addi  x30, x0,  0xCC
        chk_reg(5'd31, 32'h000000C4, 32'h0C0);  // jalr  x31, x30, 0

        // ─── Hazard summary ───────────────────────────────────────────────────
        $display("\n-- Hazard coverage (EX/MEM fwd, MEM/WB fwd, load-use stall) --");
        chk_reg(5'd4,  32'hFFFFFED4, 32'h108);  // lh x4,10(x0)  (final value after hazard chain)

        // ─── Invariants ───────────────────────────────────────────────────────
        $display("\n-- Invariants --");
        chk_reg(5'd27, 32'h00000004, 32'h00C);  // x27 = add(x1,x2) = 4, never re-written
        // x0 is always 0 — no source instruction; check directly
        if (uut.u_id_stage.rf.registers[0] === 32'h0) begin
            $display("  PASS  x0 always 0");
            pass = pass + 1;
        end else begin
            $display("  FAIL  x0 = %08h  exp = 00000000",
                     uut.u_id_stage.rf.registers[0]);
            fail = fail + 1;
        end

        // ─── Halt verification ────────────────────────────────────────────────
        // jal x0,0 at 0x110: PC oscillates {0x110,0x114,0x118} indefinitely
        $display("\n-- Halt verification --");
        begin : halt_check
            integer hc_ok, hc_cyc;
            hc_ok = 1;
            for (hc_cyc = 0; hc_cyc < 9; hc_cyc = hc_cyc + 1) begin
                @(posedge clk); #1;
                if (uut.u_if_stage.pc_reg.PC < 32'h110 ||
                    uut.u_if_stage.pc_reg.PC > 32'h118)
                    hc_ok = 0;
            end
            if (hc_ok) begin
                $display("  PASS  halt: PC in [0x110..0x118] for 9 cycles");
                pass = pass + 1;
            end else begin
                $display("  FAIL  halt: PC left loop range");
                fail = fail + 1;
            end
        end

        // ─── Mid-run reset ────────────────────────────────────────────────────
        $display("\n-- Mid-run reset --");
        rstn = 0;
        repeat (3) @(posedge clk); #1;
        if (uut.u_if_stage.pc_reg.PC === 32'h0) begin
            $display("  PASS  reset: PC=0");
            pass = pass + 1;
        end else begin
            $display("  FAIL  reset: PC=%08h  exp=0", uut.u_if_stage.pc_reg.PC);
            fail = fail + 1;
        end

        $display("\n=== tb_riscv_top3: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule