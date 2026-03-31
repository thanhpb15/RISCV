// =============================================================================
// Testbench : tb_hazard_unit
// DUT       : hazard_unit (src/hazard_unit.v)
// Coverage  : no-hazard baseline; EX/MEM→EX forwarding (forward_a/b=10);
//             MEM/WB→EX forwarding (forward_a/b=01); EX/MEM priority over MEM/WB;
//             x0 never forwarded; load-use stall (lwStall); control flush; stall+flush combo
// =============================================================================
`timescale 1ns/1ps
module tb_hazard_unit;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        reg_write_m, reg_write_w, pc_src_e, result_src_e;
    reg  [4:0] rd_m, rd_w, rs1_e, rs2_e, rd_e, rs1_d, rs2_d;

    wire [1:0] forward_a_e, forward_b_e;
    wire       stall_f, stall_d, flush_e, flush_d;

    hazard_unit uut (
        .RegWriteM  (reg_write_m),
        .RegWriteW  (reg_write_w),
        .PCSrcE     (pc_src_e),
        .RdM        (rd_m),
        .RdW        (rd_w),
        .Rs1E       (rs1_e),
        .Rs2E       (rs2_e),
        .RdE        (rd_e),
        .Rs1D       (rs1_d),
        .Rs2D       (rs2_d),
        .ResultSrcE (result_src_e),
        .ForwardAE  (forward_a_e),
        .ForwardBE  (forward_b_e),
        .StallF     (stall_f),
        .StallD     (stall_d),
        .FlushE     (flush_e),
        .FlushD     (flush_d)
    );

    // -------------------------------------------------------------------------
    // Pass / fail
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task automatic chk_fwd;
        input [1:0] got_a, exp_a, got_b, exp_b;
        input [79:0] label;
        begin
            if (got_a===exp_a && got_b===exp_b) begin
                $display("  PASS  %-40s  fwd_a=%02b fwd_b=%02b", label, got_a, got_b);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  fwd_a=%02b(e%02b) fwd_b=%02b(e%02b)",
                         label, got_a, exp_a, got_b, exp_b);
                fail = fail + 1;
            end
        end
    endtask

    task automatic chk_ctrl;
        input got_sf, exp_sf, got_sd, exp_sd, got_fe, exp_fe, got_fd, exp_fd;
        input [79:0] label;
        begin
            if (got_sf===exp_sf && got_sd===exp_sd && got_fe===exp_fe && got_fd===exp_fd) begin
                $display("  PASS  %-40s  sf=%b sd=%b fe=%b fd=%b",
                         label, got_sf, got_sd, got_fe, got_fd);
                pass = pass + 1;
            end else begin
                $display("  FAIL  %-40s  sf=%b(e%b) sd=%b(e%b) fe=%b(e%b) fd=%b(e%b)",
                         label, got_sf,exp_sf, got_sd,exp_sd, got_fe,exp_fe, got_fd,exp_fd);
                fail = fail + 1;
            end
        end
    endtask

    // Default: no hazards
    task automatic set_defaults;
        begin
            reg_write_m = 0; reg_write_w = 0; pc_src_e = 0; result_src_e = 0;
            rd_m = 5'd0; rd_w = 5'd0;
            rs1_e = 5'd0; rs2_e = 5'd0;
            rd_e = 5'd0; rs1_d = 5'd0; rs2_d = 5'd0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_hazard_unit.vcd");
        $dumpvars(0, tb_hazard_unit);
        $display("=== tb_hazard_unit ===");

        // --- No hazard baseline ---
        set_defaults(); #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b00, "no hazard: fwd=00");
        chk_ctrl(stall_f,0, stall_d,0, flush_e,0, flush_d,0, "no hazard: all 0");

        // --- EX/MEM → EX forwarding: forward_a = 10 ---
        // rd_m=x1 matches rs1_e=x1, reg_write_m=1
        set_defaults();
        reg_write_m = 1; rd_m = 5'd1; rs1_e = 5'd1; #1;
        chk_fwd(forward_a_e,2'b10, forward_b_e,2'b00, "EX/MEM fwd_a=10");
        chk_ctrl(stall_f,0, stall_d,0, flush_e,0, flush_d,0, "EX/MEM: no stall");

        // --- EX/MEM → EX forwarding: forward_b = 10 ---
        set_defaults();
        reg_write_m = 1; rd_m = 5'd5; rs2_e = 5'd5; #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b10, "EX/MEM fwd_b=10");

        // --- EX/MEM forward both A and B ---
        set_defaults();
        reg_write_m = 1; rd_m = 5'd3;
        rs1_e = 5'd3; rs2_e = 5'd3; #1;
        chk_fwd(forward_a_e,2'b10, forward_b_e,2'b10, "EX/MEM fwd_a=10 fwd_b=10");

        // --- MEM/WB → EX forwarding: forward_a = 01 ---
        set_defaults();
        reg_write_w = 1; rd_w = 5'd2; rs1_e = 5'd2; #1;
        chk_fwd(forward_a_e,2'b01, forward_b_e,2'b00, "MEM/WB fwd_a=01");

        // --- MEM/WB → EX forwarding: forward_b = 01 ---
        set_defaults();
        reg_write_w = 1; rd_w = 5'd4; rs2_e = 5'd4; #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b01, "MEM/WB fwd_b=01");

        // --- EX/MEM takes priority over MEM/WB (same reg) ---
        // Both rd_m and rd_w match rs1_e; EX/MEM wins → 2'b10
        set_defaults();
        reg_write_m = 1; rd_m = 5'd7;
        reg_write_w = 1; rd_w = 5'd7;
        rs1_e = 5'd7; #1;
        chk_fwd(forward_a_e,2'b10, forward_b_e,2'b00, "priority: EX/MEM over MEM/WB");

        // --- x0 is never forwarded (Rs1E=0 / Rs2E=0 fails the != 0 check) ---
        set_defaults();
        reg_write_m = 1; rd_m = 5'd0; rs1_e = 5'd0;
        reg_write_w = 1; rd_w = 5'd0; rs2_e = 5'd0; #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b00, "x0: no forward");

        // --- reg_write=0 blocks forwarding ---
        set_defaults();
        reg_write_m = 0; rd_m = 5'd1; rs1_e = 5'd1; #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b00, "reg_write_m=0: no fwd");

        set_defaults();
        reg_write_w = 0; rd_w = 5'd1; rs1_e = 5'd1; #1;
        chk_fwd(forward_a_e,2'b00, forward_b_e,2'b00, "reg_write_w=0: no fwd");

        // --- Load-use hazard (lwStall): stall + flush_e ---
        // result_src_e=1 (load in EX), rd_e=x1 matches rs1_d=x1
        set_defaults();
        result_src_e = 1; rd_e = 5'd1; rs1_d = 5'd1; #1;
        chk_ctrl(stall_f,1, stall_d,1, flush_e,1, flush_d,0, "load-use rs1: stall+flush_e");

        // rd_e matches rs2_d
        set_defaults();
        result_src_e = 1; rd_e = 5'd2; rs2_d = 5'd2; #1;
        chk_ctrl(stall_f,1, stall_d,1, flush_e,1, flush_d,0, "load-use rs2: stall+flush_e");

        // rd_e=x0 → no stall (load to x0 has no consumer)
        set_defaults();
        result_src_e = 1; rd_e = 5'd0; rs1_d = 5'd0; #1;
        chk_ctrl(stall_f,0, stall_d,0, flush_e,0, flush_d,0, "load-use x0: no stall");

        // result_src_e=0 → not a load, no stall
        set_defaults();
        result_src_e = 0; rd_e = 5'd1; rs1_d = 5'd1; #1;
        chk_ctrl(stall_f,0, stall_d,0, flush_e,0, flush_d,0, "non-load: no stall");

        // --- Control flush: flush_d + flush_e ---
        set_defaults();
        pc_src_e = 1; #1;
        chk_ctrl(stall_f,0, stall_d,0, flush_e,1, flush_d,1, "branch taken: flush_d+flush_e");

        // --- Simultaneous load-use stall AND control flush ---
        // (edge case: load followed immediately by a branch that is taken)
        set_defaults();
        result_src_e = 1; rd_e = 5'd3; rs1_d = 5'd3;
        pc_src_e = 1; #1;
        chk_ctrl(stall_f,1, stall_d,1, flush_e,1, flush_d,1,
                 "load-use + branch: all asserted");

        $display("--- hazard_unit: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end

endmodule
