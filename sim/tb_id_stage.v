// =============================================================================
// Testbench : tb_id_stage
// DUT       : id_stage (src/id_stage.v)
// Coverage  : control signal decode for representative instructions;
//             register file read (two ports); immediate extension;
//             write-back path (reg_write_w, rd_w, result_w);
//             x0 read always returns 0
// =============================================================================
`timescale 1ns/1ps
module tb_id_stage;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk;
    reg        reg_write_w;
    reg [4:0]  rd_w;
    reg [31:0] result_w, instr_d;

    wire       reg_write_d, mem_write_d, jump_d, branch_d, alu_src_d, a_sel_d;
    wire [1:0] result_src_d;
    wire [3:0] alu_control_d;
    wire[31:0] read_data_1_d, read_data_2_d, imm_ext_d;
    wire [4:0] rs1_d, rs2_d, rd_d;
    wire [2:0] funct3_d;

    id_stage uut (
        .clk         (clk),
        .RegWriteW   (reg_write_w),
        .RdW         (rd_w),
        .ResultW     (result_w),
        .InstrD      (instr_d),
        .RegWriteD   (reg_write_d),
        .MemWriteD   (mem_write_d),
        .JumpD       (jump_d),
        .BranchD     (branch_d),
        .ALUSrcD     (alu_src_d),
        .ASelD       (a_sel_d),
        .ResultSrcD  (result_src_d),
        .ALUControlD (alu_control_d),
        .RD1D        (read_data_1_d),
        .RD2D        (read_data_2_d),
        .ImmExtD     (imm_ext_d),
        .Rs1D        (rs1_d),
        .Rs2D        (rs2_d),
        .RdD         (rd_d),
        .Funct3D     (funct3_d)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk32;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-40s  val=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  val=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    task automatic chk1;
        input got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-40s  val=%b", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  val=%b  exp=%b", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_id_stage.vcd");
        $dumpvars(0, tb_id_stage);
        $display("=== tb_id_stage ===");

        reg_write_w = 0; rd_w = 5'd0; result_w = 32'h0;
        instr_d = 32'h00000013;   // NOP: addi x0, x0, 0
        #3;

        // ---------------------------------------------------------------
        // Write registers via WB path, then decode instructions that read them
        // ---------------------------------------------------------------
        // Write x1 = 5
        reg_write_w = 1; rd_w = 5'd1; result_w = 32'd5;
        @(posedge clk); #1;
        // Write x2 = 3
        rd_w = 5'd2; result_w = 32'd3;
        @(posedge clk); #1;
        // Write x5 = 0xABCD0000
        rd_w = 5'd5; result_w = 32'hABCD0000;
        @(posedge clk); #1;
        reg_write_w = 0;

        // ---------------------------------------------------------------
        // ADD x3, x1, x2  (R-type)
        // Encoding: op=0110011, rd=x3, funct3=000, rs1=x1, rs2=x2, funct7=0
        // ---------------------------------------------------------------
        $display("\n-- ADD x3,x1,x2 (R-type) --");
        instr_d = 32'b0000000_00010_00001_000_00011_0110011; #1;
        chk1(reg_write_d, 1,        "ADD: reg_write=1");
        chk1(mem_write_d, 0,        "ADD: mem_write=0");
        chk1(alu_src_d,   0,        "ADD: alu_src=0 (rs2)");
        chk1(branch_d,    0,        "ADD: branch=0");
        chk1(jump_d,      0,        "ADD: jump=0");
        chk32(read_data_1_d, 32'd5, "ADD: rs1=x1=5");
        chk32(read_data_2_d, 32'd3, "ADD: rs2=x2=3");
        if (rs1_d===5'd1 && rs2_d===5'd2 && rd_d===5'd3)
            begin $display("  PASS  ADD: rs1/rs2/rd addresses"); pass=pass+1; end
        else
            begin $display("  FAIL  ADD: rs1=%0d rs2=%0d rd=%0d", rs1_d,rs2_d,rd_d); fail=fail+1; end

        // ---------------------------------------------------------------
        // ADDI x4, x1, 100  (I-type)
        // imm=100=0x064, rd=x4, rs1=x1
        // ---------------------------------------------------------------
        $display("\n-- ADDI x4,x1,100 (I-type) --");
        instr_d = 32'b000001100100_00001_000_00100_0010011; #1;
        chk1(reg_write_d, 1,         "ADDI: reg_write=1");
        chk1(alu_src_d,   1,         "ADDI: alu_src=1 (imm)");
        chk32(imm_ext_d,  32'd100,   "ADDI: imm_ext=100");
        chk32(read_data_1_d, 32'd5,  "ADDI: rs1=x1=5");

        // ---------------------------------------------------------------
        // LW x6, 8(x0)  (Load)
        // imm=8, rd=x6, rs1=x0
        // ---------------------------------------------------------------
        $display("\n-- LW x6,8(x0) (Load) --");
        instr_d = 32'b000000001000_00000_010_00110_0000011; #1;
        chk1(reg_write_d,   1,          "LW: reg_write=1");
        chk1(mem_write_d,   0,          "LW: mem_write=0");
        chk1(alu_src_d,     1,          "LW: alu_src=1");
        if (result_src_d===2'b01)
            begin $display("  PASS  LW: result_src=01"); pass=pass+1; end
        else
            begin $display("  FAIL  LW: result_src=%02b exp=01", result_src_d); fail=fail+1; end
        chk32(imm_ext_d, 32'd8,         "LW: imm_ext=8");
        chk32(read_data_1_d, 32'h0,     "LW: rs1=x0=0");

        // ---------------------------------------------------------------
        // SW x2, 4(x5)  (Store)
        // imm=4 → S-type: instr[31:25]=0000000, instr[11:7]=00100
        // rs1=x5, rs2=x2
        // ---------------------------------------------------------------
        $display("\n-- SW x2,4(x5) (Store) --");
        instr_d = 32'b0000000_00010_00101_010_00100_0100011; #1;
        chk1(reg_write_d,   0,             "SW: reg_write=0");
        chk1(mem_write_d,   1,             "SW: mem_write=1");
        chk1(alu_src_d,     1,             "SW: alu_src=1");
        chk32(imm_ext_d,    32'd4,         "SW: imm_ext=4");
        chk32(read_data_1_d, 32'hABCD0000, "SW: rs1=x5=0xABCD0000");
        chk32(read_data_2_d, 32'd3,        "SW: rs2=x2=3");

        // ---------------------------------------------------------------
        // BEQ x1, x2, +8  (Branch)
        // B-type imm=8: instr[31]=0,instr[7]=0,instr[30:25]=000000,instr[11:8]=0100
        // rs1=x1, rs2=x2
        // ---------------------------------------------------------------
        $display("\n-- BEQ x1,x2,+8 (Branch) --");
        instr_d = 32'b0_000000_00010_00001_000_0100_0_1100011; #1;
        chk1(branch_d,      1,          "BEQ: branch=1");
        chk1(mem_write_d,   0,          "BEQ: mem_write=0");
        chk1(reg_write_d,   0,          "BEQ: reg_write=0");
        chk32(imm_ext_d,    32'd8,      "BEQ: imm_ext=8");

        // ---------------------------------------------------------------
        // JAL x11, +8  (Jump)
        // J-type: rd=x11, imm=8
        // imm[3]=1 → imm[10:1]=0000000100 → instr[30:21]=0000000100
        // ---------------------------------------------------------------
        $display("\n-- JAL x11,+8 --");
        instr_d = 32'b0_0000000100_0_00000000_01011_1101111; #1;
        chk1(jump_d,        1,          "JAL: jump=1");
        chk1(reg_write_d,   1,          "JAL: reg_write=1");
        if (result_src_d===2'b10)
            begin $display("  PASS  JAL: result_src=10 (PC+4)"); pass=pass+1; end
        else
            begin $display("  FAIL  JAL: result_src=%02b exp=10", result_src_d); fail=fail+1; end
        chk1(a_sel_d, 1,                "JAL: a_sel=1 (PC)");
        chk32(imm_ext_d, 32'd8,         "JAL: imm_ext=8");

        // ---------------------------------------------------------------
        // x0 read always returns 0 even after write attempts
        // ---------------------------------------------------------------
        $display("\n-- x0 hardwired 0 check --");
        reg_write_w = 1; rd_w = 5'd0; result_w = 32'hFFFFFFFF;
        @(posedge clk); #1;
        reg_write_w = 0;
        // Read x0 via rs1 slot (rs1=x0)
        instr_d = 32'b0000000_00000_00000_000_00001_0110011; #1; // ADD x1,x0,x0
        chk32(read_data_1_d, 32'h0, "x0=0 after write attempt");

        $display("--- id_stage: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
