// =============================================================================
// Testbench : tb_pipeline_regs
// DUT       : pipeline_IF_ID, pipeline_ID_EX, pipeline_EX_MEM, pipeline_MEM_WB
//             (src/pipeline_regs.v)
// Coverage  :
//   IF_ID  — normal update, stall (en=0 holds), flush (clr=1 → NOP), rstn
//   ID_EX  — normal update, flush (clr=1 → zeros/NOP), rstn
//   EX_MEM — normal update, rstn
//   MEM_WB — normal update, rstn
// =============================================================================
`timescale 1ns/1ps
module tb_pipeline_regs;

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    reg clk;
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

    // =========================================================================
    // pipeline_IF_ID signals
    // =========================================================================
    reg        if_rstn, if_en, if_clr;
    reg [31:0] if_instr_f, if_pc_f, if_pc4_f;
    wire[31:0] if_instr_d, if_pc_d, if_pc4_d;

    pipeline_IF_ID u_ifid (
        .clk     (clk),
        .rstn    (if_rstn),
        .en      (if_en),
        .clr     (if_clr),
        .InstrF  (if_instr_f),
        .PCF     (if_pc_f),
        .PCPlus4F(if_pc4_f),
        .InstrD  (if_instr_d),
        .PCD     (if_pc_d),
        .PCPlus4D(if_pc4_d)
    );

    // =========================================================================
    // pipeline_ID_EX signals
    // =========================================================================
    reg        idex_rstn, idex_clr;
    reg        idex_rw_d, idex_mw_d, idex_as_d, idex_jmp_d, idex_br_d, idex_asel_d;
    reg [1:0]  idex_rs_d;
    reg [3:0]  idex_ac_d;
    reg [2:0]  idex_f3_d;
    reg [31:0] idex_rd1_d, idex_rd2_d, idex_imm_d, idex_pc_d, idex_pc4_d;
    reg [4:0]  idex_rs1_d, idex_rs2_d, idex_rd_d;

    wire       idex_rw_e, idex_mw_e, idex_as_e, idex_jmp_e, idex_br_e, idex_asel_e;
    wire [1:0] idex_rs_e;
    wire [3:0] idex_ac_e;
    wire [2:0] idex_f3_e;
    wire[31:0] idex_rd1_e, idex_rd2_e, idex_imm_e, idex_pc_e, idex_pc4_e;
    wire [4:0] idex_rs1_e, idex_rs2_e, idex_rd_e;

    pipeline_ID_EX u_idex (
        .clk        (clk),
        .rstn       (idex_rstn),
        .clr        (idex_clr),
        .RegWriteD  (idex_rw_d),
        .MemWriteD  (idex_mw_d),
        .ALUSrcD    (idex_as_d),
        .JumpD      (idex_jmp_d),
        .BranchD    (idex_br_d),
        .ASelD      (idex_asel_d),
        .ResultSrcD (idex_rs_d),
        .ALUControlD(idex_ac_d),
        .Funct3D    (idex_f3_d),
        .RD1D       (idex_rd1_d),
        .RD2D       (idex_rd2_d),
        .ImmExtD    (idex_imm_d),
        .PCD        (idex_pc_d),
        .PCPlus4D   (idex_pc4_d),
        .Rs1D       (idex_rs1_d),
        .Rs2D       (idex_rs2_d),
        .RdD        (idex_rd_d),
        .RegWriteE  (idex_rw_e),
        .MemWriteE  (idex_mw_e),
        .ALUSrcE    (idex_as_e),
        .JumpE      (idex_jmp_e),
        .BranchE    (idex_br_e),
        .ASelE      (idex_asel_e),
        .ResultSrcE (idex_rs_e),
        .ALUControlE(idex_ac_e),
        .Funct3E    (idex_f3_e),
        .RD1E       (idex_rd1_e),
        .RD2E       (idex_rd2_e),
        .ImmExtE    (idex_imm_e),
        .PCE        (idex_pc_e),
        .PCPlus4E   (idex_pc4_e),
        .Rs1E       (idex_rs1_e),
        .Rs2E       (idex_rs2_e),
        .RdE        (idex_rd_e)
    );

    // =========================================================================
    // pipeline_EX_MEM signals
    // =========================================================================
    reg        exmem_rstn;
    reg        exmem_rw_e, exmem_mw_e;
    reg [1:0]  exmem_rs_e;
    reg [31:0] exmem_alu_e, exmem_wd_e, exmem_pc4_e;
    reg [4:0]  exmem_rd_e;

    wire       exmem_rw_m, exmem_mw_m;
    wire [1:0] exmem_rs_m;
    wire[31:0] exmem_alu_m, exmem_wd_m, exmem_pc4_m;
    wire [4:0] exmem_rd_m;

    pipeline_EX_MEM u_exmem (
        .clk       (clk),
        .rstn      (exmem_rstn),
        .RegWriteE (exmem_rw_e),
        .MemWriteE (exmem_mw_e),
        .ResultSrcE(exmem_rs_e),
        .ALUResultE(exmem_alu_e),
        .WriteDataE(exmem_wd_e),
        .PCPlus4E  (exmem_pc4_e),
        .RdE       (exmem_rd_e),
        .RegWriteM (exmem_rw_m),
        .MemWriteM (exmem_mw_m),
        .ResultSrcM(exmem_rs_m),
        .ALUResultM(exmem_alu_m),
        .WriteDataM(exmem_wd_m),
        .PCPlus4M  (exmem_pc4_m),
        .RdM       (exmem_rd_m)
    );

    // =========================================================================
    // pipeline_MEM_WB signals
    // =========================================================================
    reg        memwb_rstn;
    reg        memwb_rw_m;
    reg [1:0]  memwb_rs_m;
    reg [31:0] memwb_alu_m, memwb_rd_m, memwb_pc4_m;
    reg [4:0]  memwb_rd_addr_m;

    wire       memwb_rw_w;
    wire [1:0] memwb_rs_w;
    wire[31:0] memwb_alu_w, memwb_rd_w, memwb_pc4_w;
    wire [4:0] memwb_rd_w_addr;

    pipeline_MEM_WB u_memwb (
        .clk       (clk),
        .rstn      (memwb_rstn),
        .RegWriteM (memwb_rw_m),
        .ResultSrcM(memwb_rs_m),
        .ALUResultM(memwb_alu_m),
        .ReadDataM (memwb_rd_m),
        .PCPlus4M  (memwb_pc4_m),
        .RdM       (memwb_rd_addr_m),
        .RegWriteW (memwb_rw_w),
        .ResultSrcW(memwb_rs_w),
        .ALUResultW(memwb_alu_w),
        .ReadDataW (memwb_rd_w),
        .PCPlus4W  (memwb_pc4_w),
        .RdW       (memwb_rd_w_addr)
    );

    // =========================================================================
    // Stimulus — all inside initial block
    // =========================================================================
    initial begin
        $dumpfile("tb_pipeline_regs.vcd");
        $dumpvars(0, tb_pipeline_regs);
        $display("=== tb_pipeline_regs ===");

        // ---------------------------------------------------------------
        // IF_ID: reset → NOP
        // ---------------------------------------------------------------
        $display("\n-- pipeline_IF_ID --");
        if_rstn = 0; if_en = 1; if_clr = 0;
        if_instr_f = 32'hDEADBEEF; if_pc_f = 32'hCAFEBABE; if_pc4_f = 32'h12345678;
        @(posedge clk); #1;
        chk32(if_instr_d, 32'h00000013, "IF_ID rstn=0: instr=NOP");
        chk32(if_pc_d,    32'h00000000, "IF_ID rstn=0: pc=0");

        // Normal update
        if_rstn = 1; if_en = 1; if_clr = 0;
        if_instr_f = 32'hABCD1234; if_pc_f = 32'h00000010; if_pc4_f = 32'h00000014;
        @(posedge clk); #1;
        chk32(if_instr_d, 32'hABCD1234, "IF_ID normal: instr");
        chk32(if_pc_d,    32'h00000010, "IF_ID normal: pc");
        chk32(if_pc4_d,   32'h00000014, "IF_ID normal: pc+4");

        // Stall (en=0): hold previous value
        if_en = 0;
        if_instr_f = 32'h00000000; if_pc_f = 32'h0; if_pc4_f = 32'h0;
        @(posedge clk); #1;
        chk32(if_instr_d, 32'hABCD1234, "IF_ID stall: instr held");
        chk32(if_pc_d,    32'h00000010, "IF_ID stall: pc held");

        // Flush (clr=1): resets to NOP regardless of en
        if_en = 0; if_clr = 1;
        @(posedge clk); #1;
        chk32(if_instr_d, 32'h00000013, "IF_ID flush: instr=NOP");
        chk32(if_pc_d,    32'h00000000, "IF_ID flush: pc=0");

        // ---------------------------------------------------------------
        // ID_EX: reset → all zeros
        // ---------------------------------------------------------------
        $display("\n-- pipeline_ID_EX --");
        idex_rstn = 0; idex_clr = 0;
        idex_rw_d = 1; idex_mw_d = 1; idex_as_d = 1; idex_jmp_d = 1; idex_br_d = 1;
        idex_asel_d = 1; idex_rs_d = 2'b10; idex_ac_d = 4'b1010;
        idex_f3_d = 3'b111;
        idex_rd1_d = 32'hAAAAAAAA; idex_rd2_d = 32'hBBBBBBBB;
        idex_imm_d = 32'hCCCCCCCC; idex_pc_d = 32'h100; idex_pc4_d = 32'h104;
        idex_rs1_d = 5'd1; idex_rs2_d = 5'd2; idex_rd_d = 5'd3;
        @(posedge clk); #1;
        chk1(idex_rw_e,   1'b0,         "ID_EX rstn=0: reg_write=0");
        chk32(idex_rd1_e, 32'h0,        "ID_EX rstn=0: rd1=0");
        chk32(idex_imm_e, 32'h0,        "ID_EX rstn=0: imm=0");

        // Normal update
        idex_rstn = 1; idex_clr = 0;
        @(posedge clk); #1;
        chk1(idex_rw_e,   1'b1,              "ID_EX normal: reg_write");
        chk1(idex_jmp_e,  1'b1,              "ID_EX normal: jump");
        chk32(idex_rd1_e, 32'hAAAAAAAA,      "ID_EX normal: rd1");
        chk32(idex_imm_e, 32'hCCCCCCCC,      "ID_EX normal: imm");
        if (idex_rd_e === 5'd3)
            begin $display("  PASS  ID_EX normal: rd=x3"); pass=pass+1; end
        else
            begin $display("  FAIL  ID_EX normal: rd=%0d exp=3", idex_rd_e); fail=fail+1; end

        // Flush (clr=1): insert NOP bubble
        idex_clr = 1;
        @(posedge clk); #1;
        chk1(idex_rw_e,  1'b0,  "ID_EX flush: reg_write=0");
        chk1(idex_mw_e,  1'b0,  "ID_EX flush: mem_write=0");
        chk1(idex_jmp_e, 1'b0,  "ID_EX flush: jump=0");
        if (idex_rd_e === 5'd0)
            begin $display("  PASS  ID_EX flush: rd=x0"); pass=pass+1; end
        else
            begin $display("  FAIL  ID_EX flush: rd=%0d exp=0", idex_rd_e); fail=fail+1; end

        // ---------------------------------------------------------------
        // EX_MEM: reset → all zeros
        // ---------------------------------------------------------------
        $display("\n-- pipeline_EX_MEM --");
        exmem_rstn = 0;
        exmem_rw_e = 1; exmem_mw_e = 1; exmem_rs_e = 2'b01;
        exmem_alu_e = 32'hABCD0000; exmem_wd_e = 32'h00001234;
        exmem_pc4_e = 32'h00000008; exmem_rd_e = 5'd7;
        @(posedge clk); #1;
        chk1(exmem_rw_m,  1'b0,  "EX_MEM rstn=0: reg_write=0");
        chk32(exmem_alu_m, 32'h0,"EX_MEM rstn=0: alu_result=0");

        exmem_rstn = 1;
        @(posedge clk); #1;
        chk1(exmem_rw_m,  1'b1,              "EX_MEM normal: reg_write");
        chk1(exmem_mw_m,  1'b1,              "EX_MEM normal: mem_write");
        chk32(exmem_alu_m, 32'hABCD0000,     "EX_MEM normal: alu_result");
        chk32(exmem_wd_m,  32'h00001234,     "EX_MEM normal: write_data");
        chk32(exmem_pc4_m, 32'h00000008,     "EX_MEM normal: pc+4");
        if (exmem_rd_m === 5'd7)
            begin $display("  PASS  EX_MEM normal: rd=x7"); pass=pass+1; end
        else
            begin $display("  FAIL  EX_MEM normal: rd=%0d exp=7", exmem_rd_m); fail=fail+1; end

        // ---------------------------------------------------------------
        // MEM_WB: reset → all zeros
        // ---------------------------------------------------------------
        $display("\n-- pipeline_MEM_WB --");
        memwb_rstn = 0;
        memwb_rw_m = 1; memwb_rs_m = 2'b01;
        memwb_alu_m = 32'h11111111; memwb_rd_m = 32'h22222222;
        memwb_pc4_m = 32'h00000010; memwb_rd_addr_m = 5'd5;
        @(posedge clk); #1;
        chk1(memwb_rw_w,  1'b0,  "MEM_WB rstn=0: reg_write=0");
        chk32(memwb_alu_w, 32'h0,"MEM_WB rstn=0: alu_result=0");

        memwb_rstn = 1;
        @(posedge clk); #1;
        chk1(memwb_rw_w,  1'b1,              "MEM_WB normal: reg_write");
        chk32(memwb_alu_w, 32'h11111111,     "MEM_WB normal: alu_result");
        chk32(memwb_rd_w,  32'h22222222,     "MEM_WB normal: read_data");
        chk32(memwb_pc4_w, 32'h00000010,     "MEM_WB normal: pc+4");
        if (memwb_rd_w_addr === 5'd5)
            begin $display("  PASS  MEM_WB normal: rd=x5"); pass=pass+1; end
        else
            begin $display("  FAIL  MEM_WB normal: rd=%0d exp=5", memwb_rd_w_addr); fail=fail+1; end

        $display("\n--- pipeline_regs: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
