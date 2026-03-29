// =============================================================================
// Testbench : tb_ex_stage
// DUT       : ex_stage (src/ex_stage.v)
// Coverage  : no-forward ALU ops (ADD/SUB/AND/OR); forwarding MUX (A=WB/MEM,
//             B=WB/MEM); a_sel override (PC for JAL/AUIPC); alu_src (imm vs rs2);
//             JALR target (alu_result & ~1); JAL/branch target (PC + imm);
//             branch conditions (BEQ/BNE/BLT/BGE/BLTU/BGEU); pc_src_e logic
// =============================================================================
`timescale 1ns/1ps
module tb_ex_stage;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg [1:0]  forward_a_e, forward_b_e;
    reg        jump_e, branch_e, alu_src_e, a_sel_e;
    reg [3:0]  alu_control_e;
    reg [2:0]  funct3_e;
    reg [31:0] read_data_1_e, read_data_2_e, imm_ext_e, pc_e, pc_plus_4_e;
    reg [31:0] alu_result_m, result_w;

    wire [31:0] pc_target_e, alu_result_e, write_data_e;
    wire        pc_src_e;

    ex_stage uut (
        .ForwardAE   (forward_a_e),
        .ForwardBE   (forward_b_e),
        .JumpE       (jump_e),
        .BranchE     (branch_e),
        .ALUSrcE     (alu_src_e),
        .ASelE       (a_sel_e),
        .ALUControlE (alu_control_e),
        .Funct3E     (funct3_e),
        .RD1E        (read_data_1_e),
        .RD2E        (read_data_2_e),
        .ImmExtE     (imm_ext_e),
        .PCE         (pc_e),
        .PCPlus4E    (pc_plus_4_e),
        .ALUResultM  (alu_result_m),
        .ResultW     (result_w),
        .PCTargetE   (pc_target_e),
        .ALUResultE  (alu_result_e),
        .WriteDataE  (write_data_e),
        .PCSrcE      (pc_src_e)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk32;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-45s  val=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-45s  val=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    task automatic chk1;
        input got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-45s  val=%b", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-45s  val=%b  exp=%b", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // Default: no jump, no branch, no forward, use rs2, rs1 for A
    task automatic set_defaults;
        begin
            forward_a_e = 2'b00; forward_b_e = 2'b00;
            jump_e = 0; branch_e = 0;
            alu_src_e = 0; a_sel_e = 0;
            alu_control_e = 4'b0000; funct3_e = 3'b000;
            read_data_1_e = 32'h0; read_data_2_e = 32'h0;
            imm_ext_e = 32'h0; pc_e = 32'h0; pc_plus_4_e = 32'h4;
            alu_result_m = 32'h0; result_w = 32'h0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_ex_stage.vcd");
        $dumpvars(0, tb_ex_stage);
        $display("=== tb_ex_stage ===");

        // ---------------------------------------------------------------
        // Basic ALU operations (no forwarding, alu_src=0 → use rs2)
        // ---------------------------------------------------------------
        $display("\n-- ALU ops (no forward) --");
        set_defaults();

        // ADD: 5 + 3 = 8
        alu_control_e = 4'b0000;
        read_data_1_e = 32'd5; read_data_2_e = 32'd3; #1;
        chk32(alu_result_e, 32'd8, "ADD 5+3=8");
        chk32(write_data_e, 32'd3, "ADD: write_data=rs2=3");
        chk1(pc_src_e, 0,          "ADD: pc_src=0");

        // SUB: 10 - 4 = 6
        alu_control_e = 4'b0001;
        read_data_1_e = 32'd10; read_data_2_e = 32'd4; #1;
        chk32(alu_result_e, 32'd6, "SUB 10-4=6");

        // AND: 0xFF & 0x0F = 0x0F
        alu_control_e = 4'b0010;
        read_data_1_e = 32'hFF; read_data_2_e = 32'h0F; #1;
        chk32(alu_result_e, 32'h0F, "AND 0xFF&0x0F=0x0F");

        // OR: 0xF0 | 0x0F = 0xFF
        alu_control_e = 4'b0011;
        read_data_1_e = 32'hF0; read_data_2_e = 32'h0F; #1;
        chk32(alu_result_e, 32'hFF, "OR 0xF0|0x0F=0xFF");

        // ---------------------------------------------------------------
        // Immediate source: alu_src=1 uses imm instead of rs2
        // ADDI: rs1=10, imm=20 → result=30
        // ---------------------------------------------------------------
        $display("\n-- alu_src=1 (immediate) --");
        set_defaults();
        alu_control_e = 4'b0000; alu_src_e = 1;
        read_data_1_e = 32'd10; read_data_2_e = 32'd99; imm_ext_e = 32'd20; #1;
        chk32(alu_result_e, 32'd30, "ADDI: rs1+imm=30");
        chk32(write_data_e, 32'd99, "ADDI: write_data=rs2 (not imm)");

        // ---------------------------------------------------------------
        // Forwarding: A-input
        // ---------------------------------------------------------------
        $display("\n-- Forwarding MUX A --");
        set_defaults();
        alu_control_e = 4'b0000;
        read_data_1_e = 32'd1;   // would give 1+0=1 without forward
        result_w      = 32'd100; // WB forward
        alu_result_m  = 32'd200; // MEM forward

        // WB forward (01): 100 + 0 = 100
        forward_a_e = 2'b01; #1;
        chk32(alu_result_e, 32'd100, "fwd_a=01(WB): 100+0=100");

        // MEM forward (10): 200 + 0 = 200
        forward_a_e = 2'b10; #1;
        chk32(alu_result_e, 32'd200, "fwd_a=10(MEM): 200+0=200");

        // No forward (00): 1 + 0 = 1
        forward_a_e = 2'b00; #1;
        chk32(alu_result_e, 32'd1,   "fwd_a=00(none): 1+0=1");

        // ---------------------------------------------------------------
        // Forwarding: B-input
        // ---------------------------------------------------------------
        $display("\n-- Forwarding MUX B --");
        set_defaults();
        alu_control_e = 4'b0000;
        read_data_2_e = 32'd2;
        result_w      = 32'd50;
        alu_result_m  = 32'd75;

        // WB forward (01): 0 + 50 = 50
        forward_b_e = 2'b01; #1;
        chk32(alu_result_e, 32'd50,  "fwd_b=01(WB): 0+50=50");
        chk32(write_data_e, 32'd50,  "fwd_b=01: write_data=forward");

        // MEM forward (10): 0 + 75 = 75
        forward_b_e = 2'b10; #1;
        chk32(alu_result_e, 32'd75,  "fwd_b=10(MEM): 0+75=75");

        // ---------------------------------------------------------------
        // a_sel=1: use PC as A-input (JAL / AUIPC)
        // ---------------------------------------------------------------
        $display("\n-- a_sel=1 (PC as A) --");
        set_defaults();
        alu_control_e = 4'b0000; a_sel_e = 1;
        pc_e = 32'h00000010; imm_ext_e = 32'd8; alu_src_e = 1; #1;
        chk32(alu_result_e, 32'h18, "AUIPC: PC+imm=0x10+8=0x18");

        // ---------------------------------------------------------------
        // JAL target: PC + J-imm (branch adder)
        // jump=1, a_sel=1 → pc_target = branch_target = PC + imm
        // ---------------------------------------------------------------
        $display("\n-- JAL target --");
        set_defaults();
        jump_e = 1; a_sel_e = 1;
        pc_e = 32'h00000020; imm_ext_e = 32'h0000000C; // offset=12
        alu_src_e = 1; alu_control_e = 4'b0000; #1;
        chk32(pc_target_e, 32'h0000002C, "JAL: pc_target=PC+12=0x2C");
        chk1(pc_src_e, 1,                "JAL: pc_src=1");

        // ---------------------------------------------------------------
        // JALR target: (rs1 + imm) & ~1  (jump=1, a_sel=0)
        // ---------------------------------------------------------------
        $display("\n-- JALR target --");
        set_defaults();
        jump_e = 1; a_sel_e = 0; alu_src_e = 1; alu_control_e = 4'b0000;
        read_data_1_e = 32'h00000013; imm_ext_e = 32'd2; // rs1+imm=0x15, &~1=0x14
        #1;
        chk32(pc_target_e, 32'h00000014, "JALR: (rs1+imm)&~1=0x14");
        chk1(pc_src_e, 1,                "JALR: pc_src=1");

        // ---------------------------------------------------------------
        // Branch conditions
        // ---------------------------------------------------------------
        $display("\n-- Branch conditions --");
        set_defaults();
        alu_control_e = 4'b0001; // SUB for comparison
        branch_e = 1;

        // BEQ (f3=000): A==B → taken
        funct3_e = 3'b000;
        read_data_1_e = 32'd7; read_data_2_e = 32'd7; #1;
        chk1(pc_src_e, 1, "BEQ: A==B → taken");
        read_data_1_e = 32'd7; read_data_2_e = 32'd3; #1;
        chk1(pc_src_e, 0, "BEQ: A!=B → not taken");

        // BNE (f3=001): A!=B → taken
        funct3_e = 3'b001;
        read_data_1_e = 32'd7; read_data_2_e = 32'd3; #1;
        chk1(pc_src_e, 1, "BNE: A!=B → taken");
        read_data_1_e = 32'd7; read_data_2_e = 32'd7; #1;
        chk1(pc_src_e, 0, "BNE: A==B → not taken");

        // BLT (f3=100): signed A<B → taken
        funct3_e = 3'b100;
        read_data_1_e = 32'hFFFFFFFF; read_data_2_e = 32'd1; #1; // -1 < 1
        chk1(pc_src_e, 1, "BLT: -1<1 → taken");
        read_data_1_e = 32'd5; read_data_2_e = 32'd3; #1;
        chk1(pc_src_e, 0, "BLT: 5<3 → not taken");

        // BGE (f3=101): signed A>=B → taken
        funct3_e = 3'b101;
        read_data_1_e = 32'd5; read_data_2_e = 32'd3; #1;
        chk1(pc_src_e, 1, "BGE: 5>=3 → taken");
        read_data_1_e = 32'hFFFFFFFF; read_data_2_e = 32'd1; #1;
        chk1(pc_src_e, 0, "BGE: -1>=1 → not taken");

        // BLTU (f3=110): unsigned A<B → taken
        funct3_e = 3'b110;
        read_data_1_e = 32'h00000001; read_data_2_e = 32'hFFFFFFFF; #1;
        chk1(pc_src_e, 1, "BLTU: 1 <u 0xFFFFFFFF → taken");
        read_data_1_e = 32'hFFFFFFFF; read_data_2_e = 32'h00000001; #1;
        chk1(pc_src_e, 0, "BLTU: 0xFFFFFFFF <u 1 → not taken");

        // BGEU (f3=111): unsigned A>=B → taken
        funct3_e = 3'b111;
        read_data_1_e = 32'hFFFFFFFF; read_data_2_e = 32'h00000001; #1;
        chk1(pc_src_e, 1, "BGEU: 0xFFFFFFFF >=u 1 → taken");
        read_data_1_e = 32'h00000001; read_data_2_e = 32'hFFFFFFFF; #1;
        chk1(pc_src_e, 0, "BGEU: 1 >=u 0xFFFFFFFF → not taken");

        // branch_e=0: no branch even if condition met
        branch_e = 0; funct3_e = 3'b000;
        read_data_1_e = 32'd5; read_data_2_e = 32'd5; #1;
        chk1(pc_src_e, 0, "branch_e=0: pc_src=0 even if BEQ");

        $display("--- ex_stage: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
