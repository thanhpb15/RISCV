// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : register_file
// Description: RV32I general-purpose register file (32 x 32-bit registers)
//   - Two asynchronous read ports (rs1, rs2)
//   - One synchronous write port (rd, written at WB stage)
//   - No hardware reset on register contents (software initialises before use)
//   - x0 is hardwired to 0 via read logic; writes to x0 are silently discarded
// =============================================================================
module register_file (
    input  wire        clk,
    input  wire        WE3,         // write enable (from WB stage)
    input  wire [4:0]  A1,          // rs1 read address
    input  wire [4:0]  A2,          // rs2 read address
    input  wire [4:0]  A3,          // rd  write address (from WB)
    input  wire [31:0] WD3,         // data to write into rd
    output wire [31:0] RD1,         // rs1 read data
    output wire [31:0] RD2          // rs2 read data
);
    reg [31:0] registers [31:0];

    // Asynchronous read with write-through bypass:
    //   If WB is writing to the same address that ID is reading in the same
    //   clock cycle, return the incoming write data directly.  This models the
    //   "write-first-half / read-second-half" register file assumed by the
    //   Harris & Harris pipeline and avoids a RAW hazard that the forwarding
    //   unit cannot otherwise cover (WB→ID same-cycle conflict).
    //   x0 is always 0 — enforced here, no reset needed.
    assign RD1 = (A1 == 5'h00)                        ? 32'h00000000 :
                 (WE3 && A3 != 5'h00 && A3 == A1)     ? WD3          :
                 registers[A1];

    assign RD2 = (A2 == 5'h00)                        ? 32'h00000000 :
                 (WE3 && A3 != 5'h00 && A3 == A2)     ? WD3          :
                 registers[A2];

    // Synchronous write; ignore writes to x0
    always @(posedge clk) begin
        if (WE3 && (A3 != 5'h00))
            registers[A3] <= WD3;
    end
endmodule