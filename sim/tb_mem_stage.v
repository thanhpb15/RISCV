// =============================================================================
// Testbench : tb_mem_stage
// DUT       : mem_stage (src/mem_stage.v)
// Coverage  : store (mem_write=1) writes to DMEM; load (mem_write=0) reads back;
//             multiple addresses; rstn forces read=0; write_en gate
// =============================================================================
`timescale 1ns/1ps
module tb_mem_stage;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk, rstn, mem_write_m;
    reg [31:0] alu_result_m, write_data_m;
    wire[31:0] read_data_m;

    mem_stage uut (
        .clk       (clk),
        .rstn      (rstn),
        .MemWriteM (mem_write_m),
        .ALUResultM(alu_result_m),
        .WriteDataM(write_data_m),
        .ReadDataM (read_data_m)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk;
        input [31:0] got, exp;
        input [79:0] label;
        begin
            if (got === exp) begin
                $display("  PASS  %-40s  data=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  data=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // Perform a store (one clock cycle)
    task automatic do_store;
        input [31:0] addr, data;
        begin
            alu_result_m = addr;
            write_data_m = data;
            mem_write_m  = 1;
            @(posedge clk); #1;
            mem_write_m = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_mem_stage.vcd");
        $dumpvars(0, tb_mem_stage);
        $display("=== tb_mem_stage ===");

        rstn = 0; mem_write_m = 0;
        alu_result_m = 32'h0; write_data_m = 32'h0;
        #3;

        // Reset: read returns 0
        chk(read_data_m, 32'h0, "rstn=0: read=0");

        @(negedge clk); rstn = 1;

        // --- Store to address 0x00, then load back ---
        do_store(32'h0, 32'hDEADBEEF);
        alu_result_m = 32'h0; mem_write_m = 0; #1;
        chk(read_data_m, 32'hDEADBEEF, "store/load addr=0: 0xDEADBEEF");

        // --- Store to address 0x04, load back ---
        do_store(32'h4, 32'h12345678);
        alu_result_m = 32'h4; #1;
        chk(read_data_m, 32'h12345678, "store/load addr=4: 0x12345678");

        // --- Store to address 0x08 ---
        do_store(32'h8, 32'hCAFEBABE);
        alu_result_m = 32'h8; #1;
        chk(read_data_m, 32'hCAFEBABE, "store/load addr=8: 0xCAFEBABE");

        // --- Addresses do not alias ---
        alu_result_m = 32'h0; #1;
        chk(read_data_m, 32'hDEADBEEF, "no alias: addr=0 still 0xDEADBEEF");

        // --- mem_write=0 does not alter memory ---
        mem_write_m = 0; alu_result_m = 32'h0; write_data_m = 32'h0;
        @(posedge clk); #1;
        alu_result_m = 32'h0; #1;
        chk(read_data_m, 32'hDEADBEEF, "mem_write=0: addr=0 unchanged");

        // --- Store then immediate read at same address ---
        do_store(32'h0C, 32'hFEEDFACE);
        alu_result_m = 32'h0C; #1;
        chk(read_data_m, 32'hFEEDFACE, "store/load addr=0xC: 0xFEEDFACE");

        // --- Overwrite same address ---
        do_store(32'h0, 32'hAABBCCDD);
        alu_result_m = 32'h0; #1;
        chk(read_data_m, 32'hAABBCCDD, "overwrite addr=0: 0xAABBCCDD");

        // --- rstn=0 mid-operation forces read=0 ---
        rstn = 0; alu_result_m = 32'h4; #1;
        chk(read_data_m, 32'h0, "rstn=0 mid-op: read forced 0");
        rstn = 1; #1;
        chk(read_data_m, 32'h12345678, "rstn=1 restored: addr=4 correct");

        $display("--- mem_stage: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
