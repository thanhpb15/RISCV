// =============================================================================
// Testbench : tb_control_unit
// DUT       : control_unit (src/control_unit.v)
// Coverage  : end-to-end decode for representative instructions from each
//             opcode class; verifies alu_control is correctly composed
// =============================================================================
`timescale 1ns/1ps
module tb_control_unit;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [6:0] op, funct7;
    reg  [2:0] funct3;
    wire       reg_write, mem_write, alu_src, jump, branch;
    wire [1:0] result_src;
    wire [2:0] imm_src;
    wire [3:0] alu_control;

    control_unit uut (
        .op        (op),
        .funct7    (funct7),
        .funct3    (funct3),
        .RegWrite  (reg_write),
        .MemWrite  (mem_write),
        .ALUSrc    (alu_src),
        .Jump      (jump),
        .Branch    (branch),
        .ResultSrc (result_src),
        .ImmSrc    (imm_src),
        .ALUControl(alu_control)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [3:0] got_ac, exp_ac;
        input       got_rw, exp_rw;
        input [79:0] label;
        begin
            if (got_ac===exp_ac && got_rw===exp_rw) begin
                $display("  PASS  %-30s  alu_ctrl=%04b  reg_write=%b",
                         label, got_ac, got_rw);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  alu_ctrl=%04b(exp %04b) rw=%b(exp %b)",
                         label, got_ac, exp_ac, got_rw, exp_rw);
                fail = fail + 1;
            end
        end
    endtask

    task automatic chk_ctrl;
        input got_j, exp_j, got_br, exp_br, got_mw, exp_mw;
        input [1:0] got_rs, exp_rs;
        input [79:0] label;
        begin
            if (got_j===exp_j && got_br===exp_br && got_mw===exp_mw && got_rs===exp_rs) begin
                $display("  PASS  %-30s  j=%b br=%b mw=%b rs=%b",
                         label, got_j, got_br, got_mw, got_rs);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  j=%b(e%b) br=%b(e%b) mw=%b(e%b) rs=%b(e%b)",
                         label, got_j,exp_j, got_br,exp_br, got_mw,exp_mw, got_rs,exp_rs);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);
        $display("=== tb_control_unit ===");

        // --- ADD: R-type, f3=000, f7=0 ---
        op=7'b0110011; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "ADD  (R-type)");
        chk_ctrl(jump,0, branch,0, mem_write,0, result_src,2'b00, "ADD ctrl");

        // --- SUB: R-type, f3=000, f7=0100000 ---
        funct7=7'b0100000; #1;
        chk(alu_control,4'b0001, reg_write,1, "SUB  (R-type)");

        // --- OR: R-type, f3=110 ---
        funct3=3'b110; funct7=7'b0000000; #1;
        chk(alu_control,4'b0011, reg_write,1, "OR   (R-type)");

        // --- AND: R-type, f3=111 ---
        funct3=3'b111; #1;
        chk(alu_control,4'b0010, reg_write,1, "AND  (R-type)");

        // --- XOR: R-type, f3=100 ---
        funct3=3'b100; #1;
        chk(alu_control,4'b0100, reg_write,1, "XOR  (R-type)");

        // --- SLT: R-type, f3=010 ---
        funct3=3'b010; #1;
        chk(alu_control,4'b1000, reg_write,1, "SLT  (R-type)");

        // --- SLTU: R-type, f3=011 ---
        funct3=3'b011; #1;
        chk(alu_control,4'b1001, reg_write,1, "SLTU (R-type)");

        // --- SLL: R-type, f3=001 ---
        funct3=3'b001; #1;
        chk(alu_control,4'b0101, reg_write,1, "SLL  (R-type)");

        // --- SRL/SRA: R-type, f3=101 ---
        funct3=3'b101; funct7=7'b0000000; #1;
        chk(alu_control,4'b0110, reg_write,1, "SRL  (R-type)");
        funct7=7'b0100000; #1;
        chk(alu_control,4'b0111, reg_write,1, "SRA  (R-type)");

        // --- ADDI: I-arith, f3=000 ---
        op=7'b0010011; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "ADDI (I-type)");

        // --- LW: Load ---
        op=7'b0000011; funct3=3'b010; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "LW   (load)");
        chk_ctrl(jump,0, branch,0, mem_write,0, result_src,2'b01, "LW ctrl");

        // --- SW: Store ---
        op=7'b0100011; funct3=3'b010; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,0, "SW   (store)");
        chk_ctrl(jump,0, branch,0, mem_write,1, result_src,2'b00, "SW ctrl");

        // --- BEQ: Branch ---
        op=7'b1100011; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0001, reg_write,0, "BEQ  (branch)");
        chk_ctrl(jump,0, branch,1, mem_write,0, result_src,2'b00, "BEQ ctrl");

        // --- JAL ---
        op=7'b1101111; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "JAL");
        chk_ctrl(jump,1, branch,0, mem_write,0, result_src,2'b10, "JAL ctrl");

        // --- JALR ---
        op=7'b1100111; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "JALR");
        chk_ctrl(jump,1, branch,0, mem_write,0, result_src,2'b10, "JALR ctrl");

        // --- LUI ---
        op=7'b0110111; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b1010, reg_write,1, "LUI  (PASS_B)");
        chk_ctrl(jump,0, branch,0, mem_write,0, result_src,2'b00, "LUI ctrl");

        // --- AUIPC ---
        op=7'b0010111; funct3=3'b000; funct7=7'b0000000; #1;
        chk(alu_control,4'b0000, reg_write,1, "AUIPC");

        $display("--- control_unit: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
