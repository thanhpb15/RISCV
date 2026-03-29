// =============================================================================
// Testbench : tb_register_file
// DUT       : register_file (src/register_file.v)
// Coverage  : rstn forces zero reads, x0 hardwired to 0, basic write-then-read,
//             two independent read ports, write-enable gate
// =============================================================================
`timescale 1ns/1ps
module tb_register_file;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk, rstn, write_en_3;
    reg  [4:0] addr_1, addr_2, addr_3;
    reg [31:0] write_data_3;
    wire[31:0] read_data_1, read_data_2;

    register_file uut (
        .clk (clk),
        .rstn(rstn),
        .WE3 (write_en_3),
        .A1  (addr_1),
        .A2  (addr_2),
        .A3  (addr_3),
        .WD3 (write_data_3),
        .RD1 (read_data_1),
        .RD2 (read_data_2)
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
                $display("  PASS  %-35s  data=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-35s  data=%08h  exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_register_file.vcd");
        $dumpvars(0, tb_register_file);
        $display("=== tb_register_file ===");

        // Reset active: all reads must return 0
        rstn = 0; write_en_3 = 0;
        addr_1 = 5'd1; addr_2 = 5'd2;
        addr_3 = 5'd0; write_data_3 = 32'hDEADBEEF;
        #3;
        chk(read_data_1, 32'h0, "rstn=0: rd1 forced 0");
        chk(read_data_2, 32'h0, "rstn=0: rd2 forced 0");

        // Deassert reset
        @(negedge clk); rstn = 1;

        // --- x0 hardwired to 0 ---
        addr_1 = 5'd0; addr_2 = 5'd0;
        write_en_3 = 1; addr_3 = 5'd0; write_data_3 = 32'hFFFFFFFF;
        @(posedge clk); #1;   // clock edge: attempt write to x0
        write_en_3 = 0;
        #1;
        chk(read_data_1, 32'h0, "x0 hardwired 0 (rd1)");
        chk(read_data_2, 32'h0, "x0 hardwired 0 (rd2)");

        // --- Write x1=0xABCD1234, then read back ---
        write_en_3 = 1; addr_3 = 5'd1; write_data_3 = 32'hABCD1234;
        @(posedge clk); #1;
        write_en_3 = 0;
        addr_1 = 5'd1; #1;
        chk(read_data_1, 32'hABCD1234, "write/read x1=0xABCD1234");

        // --- Write x2=0x00000042, x3=0xDEADBEEF ---
        write_en_3 = 1; addr_3 = 5'd2; write_data_3 = 32'h00000042;
        @(posedge clk); #1;
        addr_3 = 5'd3; write_data_3 = 32'hDEADBEEF;
        @(posedge clk); #1;
        write_en_3 = 0;

        addr_1 = 5'd2; addr_2 = 5'd3; #1;
        chk(read_data_1, 32'h00000042, "x2=0x42 (rd1)");
        chk(read_data_2, 32'hDEADBEEF, "x3=0xDEADBEEF (rd2)");

        // --- Two independent read ports simultaneously ---
        addr_1 = 5'd1; addr_2 = 5'd2; #1;
        chk(read_data_1, 32'hABCD1234, "dual port: rd1=x1");
        chk(read_data_2, 32'h00000042, "dual port: rd2=x2");

        // --- write_en=0 does not change register ---
        write_en_3 = 0; addr_3 = 5'd1; write_data_3 = 32'h00000000;
        @(posedge clk); #1;
        addr_1 = 5'd1; #1;
        chk(read_data_1, 32'hABCD1234, "write_en=0: x1 unchanged");

        // --- Write x31 (boundary register) ---
        write_en_3 = 1; addr_3 = 5'd31; write_data_3 = 32'hCAFEBABE;
        @(posedge clk); #1;
        write_en_3 = 0;
        addr_2 = 5'd31; #1;
        chk(read_data_2, 32'hCAFEBABE, "x31=0xCAFEBABE (boundary)");

        // --- rstn=0 again overrides combinational read ---
        rstn = 0; #1;
        chk(read_data_2, 32'h0, "rstn=0: rd2 forced 0 (after write)");
        rstn = 1;

        $display("--- register_file: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
