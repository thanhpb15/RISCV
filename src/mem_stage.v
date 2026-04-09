// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Pham Bao Thanh
// =============================================================================
// Module  : mem_stage  (Memory Access)
// Description: MEM pipeline stage. Performs sub-word-capable data memory
//   reads and writes for the full RV32I load/store subset.
//
// Store path (MemWriteM=1):
//   Funct3M[1:0] selects access width:
//     2'b00  sb  — write 1 byte;  BE = 1-hot at byte_off
//     2'b01  sh  — write 2 bytes; BE = 2-bit mask at halfword_off
//     2'b10  sw  — write 4 bytes; BE = 4'b1111
//   WD is shifted so the relevant byte(s) align with the enabled lane(s).
//
// Load path (MemWriteM=0, ResultSrcM=2'b01):
//   data_memory always returns the full 32-bit word at the word address.
//   mem_stage extracts and sign/zero-extends the requested sub-word:
//     Funct3M = 3'b000  lb   sign-extend byte
//     Funct3M = 3'b001  lh   sign-extend halfword
//     Funct3M = 3'b010  lw   full word (no extension needed)
//     Funct3M = 3'b100  lbu  zero-extend byte
//     Funct3M = 3'b101  lhu  zero-extend halfword
//
// byte_off  = ALUResultM[1:0]  — byte position within the word
// half_off  = ALUResultM[1]    — halfword position within the word
// =============================================================================
module mem_stage (
    input  wire        clk,
    input  wire        rstn,
    input  wire        MemWriteM,
    input  wire [2:0]  Funct3M,       // load/store width and sign selector
    input  wire [31:0] ALUResultM,    // effective byte address (from EX/MEM reg)
    input  wire [31:0] WriteDataM,    // store data — rs2 after forwarding
    output reg  [31:0] ReadDataM      // load data (sign/zero-extended)
);
    // -------------------------------------------------------------------------
    // Byte offset within the word (for sub-word addressing)
    // -------------------------------------------------------------------------
    wire [1:0] byte_off = ALUResultM[1:0];

    // -------------------------------------------------------------------------
    // Store: byte-enable mask and pre-shifted write data
    //   WD is placed into the correct byte lane(s) before writing.
    // -------------------------------------------------------------------------
    reg [3:0]  be;
    reg [31:0] wd_shifted;

    always @(*) begin
        case (Funct3M[1:0])
            // sb: single byte lane
            2'b00: begin
                case (byte_off)
                    2'd0: begin be = 4'b0001; wd_shifted = {24'b0, WriteDataM[7:0]}; end
                    2'd1: begin be = 4'b0010; wd_shifted = {16'b0, WriteDataM[7:0],  8'b0}; end
                    2'd2: begin be = 4'b0100; wd_shifted = { 8'b0, WriteDataM[7:0], 16'b0}; end
                    2'd3: begin be = 4'b1000; wd_shifted = {       WriteDataM[7:0], 24'b0}; end
                endcase
            end
            // sh: two byte lanes (halfword-aligned)
            2'b01: begin
                if (byte_off[1]) begin
                    be        = 4'b1100;
                    wd_shifted = {WriteDataM[15:0], 16'b0};
                end else begin
                    be        = 4'b0011;
                    wd_shifted = {16'b0, WriteDataM[15:0]};
                end
            end
            // sw: all four byte lanes
            default: begin
                be        = 4'b1111;
                wd_shifted = WriteDataM;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Data memory instance
    // -------------------------------------------------------------------------
    wire [31:0] raw_rd;

    data_memory dmem (
        .clk  (clk),
        .rstn (rstn),
        .WE   (MemWriteM),
        .BE   (be),
        .A    (ALUResultM),
        .WD   (wd_shifted),
        .RD   (raw_rd)
    );

    // -------------------------------------------------------------------------
    // Load: extract sub-word from raw_rd and sign/zero-extend
    // -------------------------------------------------------------------------
    always @(*) begin
        case (Funct3M)
            // lb: sign-extend byte
            3'b000: begin
                case (byte_off)
                    2'd0: ReadDataM = {{24{raw_rd[ 7]}}, raw_rd[ 7: 0]};
                    2'd1: ReadDataM = {{24{raw_rd[15]}}, raw_rd[15: 8]};
                    2'd2: ReadDataM = {{24{raw_rd[23]}}, raw_rd[23:16]};
                    2'd3: ReadDataM = {{24{raw_rd[31]}}, raw_rd[31:24]};
                endcase
            end
            // lh: sign-extend halfword
            3'b001: begin
                if (byte_off[1])
                    ReadDataM = {{16{raw_rd[31]}}, raw_rd[31:16]};
                else
                    ReadDataM = {{16{raw_rd[15]}}, raw_rd[15: 0]};
            end
            // lw: full word, pass through
            3'b010: ReadDataM = raw_rd;
            // lbu: zero-extend byte
            3'b100: begin
                case (byte_off)
                    2'd0: ReadDataM = {24'b0, raw_rd[ 7: 0]};
                    2'd1: ReadDataM = {24'b0, raw_rd[15: 8]};
                    2'd2: ReadDataM = {24'b0, raw_rd[23:16]};
                    2'd3: ReadDataM = {24'b0, raw_rd[31:24]};
                endcase
            end
            // lhu: zero-extend halfword
            3'b101: begin
                if (byte_off[1])
                    ReadDataM = {16'b0, raw_rd[31:16]};
                else
                    ReadDataM = {16'b0, raw_rd[15: 0]};
            end
            // default: pass word through (covers sw path; ReadDataM unused for stores)
            default: ReadDataM = raw_rd;
        endcase
    end
endmodule