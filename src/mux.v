// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : mux (2-to-1) and mux_3_1 (3-to-1)
// Description: 32-bit combinational multiplexers
// =============================================================================

// 2-to-1 MUX: S=0 -> D0, S=1 -> D1
module mux (
    input  wire [31:0] d0,
    input  wire [31:0] d1,
    input  wire        s,
    output wire [31:0] y
);
    assign y = s ? d1 : d0;
endmodule

// 3-to-1 MUX: S=2'b00->D0, S=2'b01->D1, S=2'b10->D2
// Used for: writeback source select (ALU / MEM / PC+4),
//           forwarding source select (RegFile / WB / MEM)
module mux_3_1 (
    input  wire [31:0] d0,
    input  wire [31:0] d1,
    input  wire [31:0] d2,
    input  wire [1:0]  s,
    output wire [31:0] y
);
    assign y = (s == 2'b00) ? d0 :
               (s == 2'b01) ? d1 :
               (s == 2'b10) ? d2 : 32'h00000000;
endmodule
