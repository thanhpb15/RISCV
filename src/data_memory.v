// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : data_memory (DMEM)
// Description: Read/write data memory, 1024 x 32-bit words (4 KB).
//   - Asynchronous read (combinational), full 32-bit word
//   - Synchronous byte-lane write on rising clock edge when WE=1
//   - BE[3:0]: byte enable; BE[i]=1 writes byte lane i
//   - WD must already be shifted to the correct byte position by the caller
//   - Word-addressed: byte address bits [1:0] are ignored; index = A[11:2]
// =============================================================================
module data_memory (
    input  wire        clk,
    input  wire        rstn,
    input  wire        WE,          // 1 = write (store instruction)
    input  wire [3:0]  BE,          // byte enable: which lanes to write
    input  wire [31:0] A,           // byte address
    input  wire [31:0] WD,          // write data (pre-shifted to correct lane)
    output wire [31:0] RD           // full 32-bit word read (for load)
);
    reg [31:0] mem [1023:0];

    // Asynchronous word-aligned read; return 0 during reset
    assign RD = (!rstn) ? 32'h00000000 : mem[A[11:2]];

    // Synchronous byte-lane write
    always @(posedge clk) begin
        if (WE) begin
            if (BE[0]) mem[A[11:2]][7:0]   <= WD[7:0];
            if (BE[1]) mem[A[11:2]][15:8]  <= WD[15:8];
            if (BE[2]) mem[A[11:2]][23:16] <= WD[23:16];
            if (BE[3]) mem[A[11:2]][31:24] <= WD[31:24];
        end
    end
endmodule