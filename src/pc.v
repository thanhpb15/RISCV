// =============================================================================
// Module  : pc (Program Counter Register)
// Description: 32-bit synchronous register holding the current PC value.
//   - Reset  : active-low synchronous (rstn=0 forces PC to 0x00000000)
//   - Enable : en=1 updates PC on rising clock edge; en=0 holds PC (stall)
// =============================================================================
module pc (
    input  wire        clk,
    input  wire        rstn,      // active-low synchronous reset
    input  wire        en,        // 1 = update, 0 = hold (pipeline stall)
    input  wire [31:0] PCNext,
    output reg  [31:0] PC
);
    always @(posedge clk) begin
        if (!rstn) begin
            PC <= 32'h00000000;
        end else if (en) begin
            PC <= PCNext;
        end
        // else: en=0, hold current PC (stall)
    end
endmodule
