`timescale 1ns/1ps

module tb_fp4mac_top;

  // Clock / reset
  logic clk = 0;
  logic rst = 1;

  // DUT IO
  logic        i_clear;
  logic        i_in_valid;
  logic        i_flush;
  logic [3:0]  i_a, i_b;
  logic        o_fp4_valid;
  logic [3:0]  o_fp4;           // <<< 4 bits: {s,e[1:0],m}

  // Debug
  logic        o_acc_sign;
  logic [2:0]  o_acc_exp_u;
  logic [5:0]  o_acc_sig6;

  // Locals that were previously declared mid-initial (move them up)
  logic [3:0] z1, z2, z3;

  // Clock
  always #5 clk = ~clk;   // 100 MHz

  // DUT
  fp4mac_top dut (
    .i_clk       (clk),
    .i_rst       (rst),

    .i_clear     (i_clear),
    .i_in_valid  (i_in_valid),
    .i_flush     (i_flush),

    .i_a         (i_a),
    .i_b         (i_b),

    .o_fp4_valid (o_fp4_valid),
    .o_fp4       (o_fp4),

    .o_acc_sign  (o_acc_sign),
    .o_acc_exp_u (o_acc_exp_u),
    .o_acc_sig6  (o_acc_sig6)
  );

  // ----------------------------------------------------------------------------
  // Helpers for fp4 packing/unpacking (packed: {sign, e[1:0], m})
  // Bias = 1, significand = 1.0 or 1.5 depending on m bit.
  // value = (-1)^sign * (1.0 + 0.5*m) * 2^(e - 1)
  // ----------------------------------------------------------------------------
  function automatic logic [3:0] fp4_pack(input integer sign, input integer e_unbiased, input integer frac_bit);
    integer e_bi;
    begin
      e_bi = e_unbiased + 1;
      if (e_bi < 0) e_bi = 0;
      if (e_bi > 3) e_bi = 3;
      fp4_pack = {sign[0], e_bi[1:0], frac_bit[0]};
    end
  endfunction

  function automatic real fp4_to_real(input logic [3:0] x);
    integer s, eb, m, eu;
    real sig;
    begin
      s  = x[3];
      eb = x[2:1];
      m  = x[0];
      eu = eb - 1;
      sig = 1.0 + 0.5 * m;
      fp4_to_real = (s ? -1.0 : 1.0) * sig * (1<<eu);
    end
  endfunction

  // Convenience constants
  localparam logic [3:0] FP4_P1_0 = fp4_pack(0, 0, 0); // +1.0
  localparam logic [3:0] FP4_P1_5 = fp4_pack(0, 0, 1); // +1.5
  localparam logic [3:0] FP4_N1_5 = fp4_pack(1, 0, 1); // -1.5

  // Drive a single (a,b) pair for one cycle
  task automatic drive_pair(input logic [3:0] a, input logic [3:0] b);
    @(negedge clk);
    i_a <= a;
    i_b <= b;
    i_in_valid <= 1'b1;
    @(negedge clk);
    i_in_valid <= 1'b0;
  endtask

  // Pulse clear or flush
  task automatic pulse_clear;
    @(negedge clk);
    i_clear <= 1'b1;
    @(negedge clk);
    i_clear <= 1'b0;
  endtask

  task automatic pulse_flush;
    @(negedge clk);
    i_flush <= 1'b1;
    @(negedge clk);
    i_flush <= 1'b0;
  endtask

  // Wait for flush result
  task automatic wait_fp4_result(output logic [3:0] outw);
    begin
      do @(posedge clk); while (!o_fp4_valid);
      outw = o_fp4;
    end
  endtask

  // Pretty print
  function automatic string fp4_str(input logic [3:0] z);
    fp4_str = $sformatf("{s=%0d, e=%0d, m=%0d}", z[3], z[2:1], z[0]);
  endfunction

  // ----------------------------------------------------------------------------
  // Test sequence
  // ----------------------------------------------------------------------------
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_fp4mac_top);

    // Init
    i_clear     = 0;
    i_in_valid  = 0;
    i_flush     = 0;
    i_a         = '0;
    i_b         = '0;

    // Reset
    repeat (3) @(negedge clk);
    rst = 0;

    // ========== TEST 1 ==========
    // Accumulate: (1.5*1.5) + (1.5*1.0) = 3.75
    // With 1-bit frac, RNE → 4.0 → packed {0, 11, 0}
    $display("\nTEST1: (1.5*1.5) + (1.5*1.0) -> expect ~ +4.0 (packed {0,11,0})");
    pulse_clear();

    drive_pair(FP4_P1_5, FP4_P1_5); // 2.25
    drive_pair(FP4_P1_5, FP4_P1_0); // 1.5

    // Allow for pipeline latency (bump if your mul has more)
    repeat (6) @(negedge clk);

    pulse_flush();
    wait_fp4_result(z1);
    $display("TEST1 result packed = %b %s", z1, fp4_str(z1));
    if (z1 !== {1'b0, 2'b11, 1'b0})
      $error("TEST1 FAIL: expected {0,11,0} (approx +4.0)");

    // ========== TEST 2 ==========
    // Saturation: sum of eight (1.0*1.0) = 8.0 → saturate to +6.0 (packed {0,11,1})
    $display("\nTEST2: eight (1.0*1.0) -> expect saturate to +6.0 (packed {0,11,1})");
    pulse_clear();
    for (int i = 0; i < 8; i++) begin
      drive_pair(FP4_P1_0, FP4_P1_0);
    end
    repeat (12) @(negedge clk);
    pulse_flush();
    wait_fp4_result(z2);
    $display("TEST2 result packed = %b %s", z2, fp4_str(z2));
    if (z2 !== {1'b0, 2'b11, 1'b1})
      $error("TEST2 FAIL: expected {0,11,1} (+6.0)");

    // ========== TEST 3 ==========
    // Mixed signs: (-1.5*1.0) + (1.0*1.0) = -0.5 → {1,00,0}
    $display("\nTEST3: (-1.5*1.0) + (1.0*1.0) -> expect -0.5 (packed {1,00,0})");
    pulse_clear();

    drive_pair(FP4_N1_5, FP4_P1_0); // -1.5
    drive_pair(FP4_P1_0, FP4_P1_0); // +1.0

    repeat (6) @(negedge clk);
    pulse_flush();
    wait_fp4_result(z3);
    $display("TEST3 result packed = %b %s", z3, fp4_str(z3));
    if (z3 !== {1'b1, 2'b00, 1'b0})
      $error("TEST3 FAIL: expected {1,00,0} (-0.5)");

    $display("\nAll tests completed. Inspect errors above (if any).");
    #20;
    $finish;
  end

endmodule
