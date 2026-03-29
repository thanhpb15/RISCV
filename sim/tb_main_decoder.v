// =============================================================================
// Testbench : tb_main_decoder
// DUT       : main_decoder (src/main_decoder.v)
// Coverage  : all nine supported opcodes; verify every control signal
// =============================================================================
`timescale 1ns/1ps
module tb_main_decoder;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [6:0] op;
    wire [2:0] imm_src;
    wire [1:0] alu_op, result_src;
    wire       mem_write, alu_src, reg_write, jump, branch;

    main_decoder uut (
        .op        (op),
        .ImmSrc    (imm_src),
        .ALUOp     (alu_op),
        .ResultSrc (result_src),
        .MemWrite  (mem_write),
        .ALUSrc    (alu_src),
        .RegWrite  (reg_write),
        .Jump      (jump),
        .Branch    (branch)
    );

    // -------------------------------------------------------------------------
    // Pass / fail — check all outputs at once
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input       got_rw, exp_rw;    // reg_write
        input [1:0] got_rs, exp_rs;    // result_src
        input       got_mw, exp_mw;    // mem_write
        input       got_j,  exp_j;     // jump
        input       got_br, exp_br;    // branch
        input       got_as, exp_as;    // alu_src
        input [2:0] got_is, exp_is;    // imm_src
        input [1:0] got_ao, exp_ao;    // alu_op
        input [79:0] label;
        reg ok;
        begin
            ok = (got_rw===exp_rw) & (got_rs===exp_rs) & (got_mw===exp_mw) &
                 (got_j===exp_j)   & (got_br===exp_br) & (got_as===exp_as)  &
                 (got_is===exp_is) & (got_ao===exp_ao);
            if (ok) begin
                $display("  PASS  %s", label);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %s", label);
                if (got_rw!==exp_rw)   $display("        reg_write=%b exp=%b", got_rw, exp_rw);
                if (got_rs!==exp_rs)   $display("        result_src=%b exp=%b", got_rs, exp_rs);
                if (got_mw!==exp_mw)   $display("        mem_write=%b exp=%b", got_mw, exp_mw);
                if (got_j!==exp_j)     $display("        jump=%b exp=%b", got_j, exp_j);
                if (got_br!==exp_br)   $display("        branch=%b exp=%b", got_br, exp_br);
                if (got_as!==exp_as)   $display("        alu_src=%b exp=%b", got_as, exp_as);
                if (got_is!==exp_is)   $display("        imm_src=%b exp=%b", got_is, exp_is);
                if (got_ao!==exp_ao)   $display("        alu_op=%b exp=%b", got_ao, exp_ao);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_main_decoder.vcd");
        $dumpvars(0, tb_main_decoder);
        $display("=== tb_main_decoder ===");

        // Apply opcode and wait for combinational settle
        // chk(rw,rw_e, rs,rs_e, mw,mw_e, j,j_e, br,br_e, as,as_e, is,is_e, ao,ao_e, label)

        // R-type (0110011): rw=1,rs=00,mw=0,j=0,br=0,as=0,is=000,ao=10
        op = 7'b0110011; #1;
        chk(reg_write,1, result_src,2'b00, mem_write,0, jump,0, branch,0,
            alu_src,0, imm_src,3'b000, alu_op,2'b10, "R-type");

        // I-arith (0010011): rw=1,rs=00,mw=0,j=0,br=0,as=1,is=000,ao=10
        op = 7'b0010011; #1;
        chk(reg_write,1, result_src,2'b00, mem_write,0, jump,0, branch,0,
            alu_src,1, imm_src,3'b000, alu_op,2'b10, "I-arith");

        // Load (0000011): rw=1,rs=01,mw=0,j=0,br=0,as=1,is=000,ao=00
        op = 7'b0000011; #1;
        chk(reg_write,1, result_src,2'b01, mem_write,0, jump,0, branch,0,
            alu_src,1, imm_src,3'b000, alu_op,2'b00, "Load");

        // Store (0100011): rw=0,rs=xx,mw=1,j=0,br=0,as=1,is=001,ao=00
        op = 7'b0100011; #1;
        chk(reg_write,0, result_src,2'b00, mem_write,1, jump,0, branch,0,
            alu_src,1, imm_src,3'b001, alu_op,2'b00, "Store");

        // Branch (1100011): rw=0,rs=xx,mw=0,j=0,br=1,as=0,is=010,ao=01
        op = 7'b1100011; #1;
        chk(reg_write,0, result_src,2'b00, mem_write,0, jump,0, branch,1,
            alu_src,0, imm_src,3'b010, alu_op,2'b01, "Branch");

        // JAL (1101111): rw=1,rs=10,mw=0,j=1,br=0,as=1,is=100,ao=00
        op = 7'b1101111; #1;
        chk(reg_write,1, result_src,2'b10, mem_write,0, jump,1, branch,0,
            alu_src,1, imm_src,3'b100, alu_op,2'b00, "JAL");

        // JALR (1100111): rw=1,rs=10,mw=0,j=1,br=0,as=1,is=000,ao=00
        op = 7'b1100111; #1;
        chk(reg_write,1, result_src,2'b10, mem_write,0, jump,1, branch,0,
            alu_src,1, imm_src,3'b000, alu_op,2'b00, "JALR");

        // LUI (0110111): rw=1,rs=00,mw=0,j=0,br=0,as=1,is=011,ao=00
        op = 7'b0110111; #1;
        chk(reg_write,1, result_src,2'b00, mem_write,0, jump,0, branch,0,
            alu_src,1, imm_src,3'b011, alu_op,2'b00, "LUI");

        // AUIPC (0010111): rw=1,rs=00,mw=0,j=0,br=0,as=1,is=011,ao=00
        op = 7'b0010111; #1;
        chk(reg_write,1, result_src,2'b00, mem_write,0, jump,0, branch,0,
            alu_src,1, imm_src,3'b011, alu_op,2'b00, "AUIPC");

        // Unknown opcode → all defaults (no write, no branch)
        op = 7'b0000000; #1;
        chk(reg_write,0, result_src,2'b00, mem_write,0, jump,0, branch,0,
            alu_src,0, imm_src,3'b000, alu_op,2'b00, "Unknown NOP");

        $display("--- main_decoder: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
