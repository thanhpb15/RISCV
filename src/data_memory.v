// =============================================================================
// Module  : data_memory (DMEM)
// Description: Read/write data memory, 1024 x 32-bit words (4 KB).
//   - Asynchronous read (combinational)
//   - Synchronous write on rising clock edge when WE=1
//   - Word-addressed: byte address bits [1:0] are ignored; index = A[11:2]
//   Note: Only word (32-bit) access is supported. Byte/halfword operations
//         (lb/lh/sb/sh) would require additional byte-enable and masking logic.
// =============================================================================
module data_memory (
    input  wire        clk,
    input  wire        rstn,
    input  wire        WE,          // 1 = write (store instruction)
    input  wire [31:0] A,           // byte address
    input  wire [31:0] WD,          // data to store
    output wire [31:0] RD           // data loaded (for lw)
);
    reg [31:0] mem [1023:0];

    // Asynchronous word-aligned read; return 0 during reset
    assign RD = (!rstn) ? 32'h00000000 : mem[A[11:2]];

    // Synchronous write
    always @(posedge clk) begin
        if (WE) begin
            mem[A[11:2]] <= WD;
        end
    end
endmodule
