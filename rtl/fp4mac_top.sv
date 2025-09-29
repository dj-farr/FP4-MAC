module fp4mac_top (
    input  logic        i_clk,
    input  logic        i_rst,         // sync active-high
    input  logic        i_data_valid,  // valid for input pair i_a/i_b
    input  logic [3:0]  i_a,
    input  logic [3:0]  i_b,
    output logic [3:0]  o_accum_fp4,   // accumulated FP4 result
    output logic        o_accum_valid
);

    // multiplier -> accumulator wires
    logic [3:0] mul_result;
    logic       mul_valid;

    // instantiate multiplier (registered version)
    fp4_multiplier mul_u (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_data_valid (i_data_valid),
        .i_a          (i_a),
        .i_b          (i_b),
        .o_result     (mul_result),
        .o_valid      (mul_valid)
    );

    // instantiate accumulator (no-func version)
    fp4_accumulator acc_u (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_data_valid (mul_valid),
        .i_fp4        (mul_result),
        .o_accum      (o_accum_fp4),
        .o_valid      (o_accum_valid)
    );

endmodule
