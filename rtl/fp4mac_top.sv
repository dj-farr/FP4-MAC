module fp4mac_top (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_clear,
    input  logic        i_in_valid,
    input  logic        i_flush,

    input  logic [3:0]  i_a,
    input  logic [3:0]  i_b,

    output logic        o_fp4_valid,
    output logic [3:0]  o_fp4,

    output logic        o_acc_sign,
    output logic [2:0]  o_acc_exp_u,
    output logic [5:0]  o_acc_sig6
);
    logic        m_valid;
    logic        m_sign;
    logic [2:0]  m_exp_u;
    logic [4:0]  m_sig_grs;

    // Multiplier
    fp4multiplier u_mul (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_data_valid (i_in_valid),
        .a            (i_a),
        .b            (i_b),
        .o_valid      (m_valid),    // NOTE: o_valid
        .o_sign       (m_sign),
        .o_exp_u      (m_exp_u),
        .o_sig_grs    (m_sig_grs)
    );

    // Accumulator
    fp4accumulator u_acc (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_clear     (i_clear),
        .i_acc_valid (m_valid),
        .i_flush     (i_flush),
        .i_p_sign    (m_sign),
        .i_p_exp_u   (m_exp_u),
        .i_p_sig_grs (m_sig_grs),
        .o_acc_sign  (o_acc_sign),
        .o_acc_exp_u (o_acc_exp_u),
        .o_acc_sig6  (o_acc_sig6),
        .o_fp4_valid (o_fp4_valid),
        .o_fp4       (o_fp4)
    );
endmodule
