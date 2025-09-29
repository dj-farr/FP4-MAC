`timescale 1ns/1ps

module fp4mac_top(
    input  wire        i_clk,
    input  wire        i_rst,         // sync active-high
    input  wire        i_data_valid,  // valid for input pair i_a/i_b
    input  wire [3:0]  i_a,
    input  wire [3:0]  i_b,
    output wire [3:0]  o_accum_fp4,   // accumulated FP4 result
    output wire        o_accum_valid
);

    // multiplier -> accumulator wires
    wire [3:0] mul_result;
    wire       mul_valid;

    // instantiate multiplier
    fp4multiplier mul_u (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_data_valid (i_data_valid),
        .i_a          (i_a),
        .i_b          (i_b),
        .o_result     (mul_result),
        .o_valid      (mul_valid)
    );

    // instantiate accumulator
    fp4accumulator acc_u (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_data_valid (mul_valid),
        .i_fp4        (mul_result),
        .o_accum      (o_accum_fp4),
        .o_valid      (o_accum_valid)
    );

endmodule