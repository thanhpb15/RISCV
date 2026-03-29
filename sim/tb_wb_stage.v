// =============================================================================
// Testbench : tb_wb_stage
// DUT       : wb_stage (src/wb_stage.v)
// Coverage  : all three result_src_w encodings (ALU / Mem / PC+4)
// =============================================================================
`timescale 1ns/1ps
module tb_wb_stage;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg [1:0]  result_src_w;
    reg [31:0] alu_result_w, read_data_w, pc_plus_4_w;
    wire[31:0] result_w;

    wb_stage uut (
        .ResultSrcW(result_src_w),
        .ALUResultW(alu_result_w),
        .ReadDataW (read_data_w),
        .PCPlus4W  (pc_plus_4_w),
        .ResultW   (result_w)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-30s  result=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-30s  result=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_wb_stage.vcd");
        $dumpvars(0, tb_wb_stage);
        $display("=== tb_wb_stage ===");

        alu_result_w = 32'hABCD_1234;
        read_data_w  = 32'h5678_EF01;
        pc_plus_4_w  = 32'h0000_0034;

        // result_src=00 → ALU result
        result_src_w = 2'b00; #1;
        chk(result_w, 32'hABCD_1234, "2'b00: ALU result");

        // result_src=01 → memory read
        result_src_w = 2'b01; #1;
        chk(result_w, 32'h5678_EF01, "2'b01: mem read");

        // result_src=10 → PC+4 (return address)
        result_src_w = 2'b10; #1;
        chk(result_w, 32'h0000_0034, "2'b10: PC+4");

        // Change values and re-check
        alu_result_w = 32'h0000_0007;
        read_data_w  = 32'hDEAD_BEEF;
        pc_plus_4_w  = 32'h0000_0008;

        result_src_w = 2'b00; #1; chk(result_w, 32'h0000_0007, "2'b00: ALU=7");
        result_src_w = 2'b01; #1; chk(result_w, 32'hDEAD_BEEF, "2'b01: mem");
        result_src_w = 2'b10; #1; chk(result_w, 32'h0000_0008, "2'b10: PC+4=8");

        $display("--- wb_stage: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
