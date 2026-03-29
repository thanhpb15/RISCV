// =============================================================================
// Testbench : tb_instruction_memory
// DUT       : instruction_memory (src/instruction_memory.v)
// Coverage  : rstn forces zero output; reads from memfile.hex at known byte
//             addresses; word-alignment (bits [1:0] ignored); boundary address
// Notes     : Run from the sim/ directory so $readmemh can find memfile.hex,
//             or ensure the simulator's working directory is set to sim/.
//             memfile.hex word 0 = 32'h00500093  (addi x1, x0, 5)
//             memfile.hex word 1 = 32'h00300113  (addi x2, x0, 3)
//             memfile.hex word 2 = 32'h002081B3  (add  x3, x1, x2)
// =============================================================================
`timescale 1ns/1ps
module tb_instruction_memory;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         rstn;
    reg  [31:0] addr;
    wire [31:0] read_data;

    instruction_memory uut (
        .rstn(rstn),
        .A   (addr),
        .RD  (read_data)
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
        $dumpfile("tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);
        $display("=== tb_instruction_memory ===");

        // Reset active: all reads must return 0
        rstn = 0; addr = 32'h0; #1;
        chk(read_data, 32'h0, "rstn=0: forced 0");

        addr = 32'h4; #1;
        chk(read_data, 32'h0, "rstn=0: addr=4 forced 0");

        // Deassert reset
        rstn = 1;

        // Word 0 (byte addr 0x00) → addi x1, x0, 5
        addr = 32'h00000000; #1;
        chk(read_data, 32'h00500093, "addr=0x00: word0 ADDI x1,5");

        // Word 1 (byte addr 0x04) → addi x2, x0, 3
        addr = 32'h00000004; #1;
        chk(read_data, 32'h00300113, "addr=0x04: word1 ADDI x2,3");

        // Word 2 (byte addr 0x08) → add x3, x1, x2
        addr = 32'h00000008; #1;
        chk(read_data, 32'h002081B3, "addr=0x08: word2 ADD x3");

        // Word 3 (byte addr 0x0C) → sub x4, x1, x2
        addr = 32'h0000000C; #1;
        chk(read_data, 32'h40208233, "addr=0x0C: word3 SUB x4");

        // Byte-alignment ignored: addr=0x01 same as addr=0x00
        addr = 32'h00000001; #1;
        chk(read_data, 32'h00500093, "addr=0x01: byte-align → word0");

        addr = 32'h00000002; #1;
        chk(read_data, 32'h00500093, "addr=0x02: byte-align → word0");

        addr = 32'h00000003; #1;
        chk(read_data, 32'h00500093, "addr=0x03: byte-align → word0");

        addr = 32'h00000005; #1;
        chk(read_data, 32'h00300113, "addr=0x05: byte-align → word1");

        // rstn toggles mid-operation
        rstn = 0; addr = 32'h00000000; #1;
        chk(read_data, 32'h0, "rstn=0 mid-op: forced 0");
        rstn = 1; #1;
        chk(read_data, 32'h00500093, "rstn=1 restored: word0");

        $display("--- instruction_memory: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
