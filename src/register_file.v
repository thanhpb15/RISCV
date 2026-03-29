// =============================================================================
// Module  : register_file
// Description: RV32I general-purpose register file (32 x 32-bit registers)
//   - Two asynchronous read ports (rs1, rs2)
//   - One synchronous write port (rd, written at WB stage)
//   - x0 is hardwired to 0; any write to x0 is silently discarded
// =============================================================================
module register_file (
    input  wire        clk,
    input  wire        rstn,
    input  wire        WE3,         // write enable (from WB stage)
    input  wire [4:0]  A1,          // rs1 read address
    input  wire [4:0]  A2,          // rs2 read address
    input  wire [4:0]  A3,          // rd  write address (from WB)
    input  wire [31:0] WD3,         // data to write into rd
    output wire [31:0] RD1,         // rs1 read data
    output wire [31:0] RD2          // rs2 read data
);
    reg [31:0] registers [31:0];
    integer i;

    // All registers initialised to 0 at simulation start (models post-reset state)
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'h00000000;
    end

    // Asynchronous read with write-through bypass:
    //   If WB is writing to the same address that ID is reading in the same
    //   clock cycle, return the incoming write data directly.  This models the
    //   "write-first-half / read-second-half" register file assumed by the
    //   Harris & Harris pipeline and avoids a RAW hazard that the forwarding
    //   unit cannot otherwise cover (WB→ID same-cycle conflict).
    assign RD1 = (!rstn)                                    ? 32'h00000000 :
                 (WE3 && A3 != 5'h00 && A3 == A1) ? WD3 :
                 registers[A1];

    assign RD2 = (!rstn)                                    ? 32'h00000000 :
                 (WE3 && A3 != 5'h00 && A3 == A2) ? WD3 :
                 registers[A2];

    // Synchronous write; ignore writes to x0
    always @(posedge clk) begin
        if (WE3 && (A3 != 5'h00)) begin
            registers[A3] <= WD3;
        end
    end
endmodule
