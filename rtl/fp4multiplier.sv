// Wide-output fp4 multiplier (bias=1).
// Packed inputs {s,e[1:0],m} with m = 0(->1.0) or 1(->1.5)
// Outputs: o_sign, o_exp_u(unbiased 3b), o_sig_grs={I,F,G,R,S}
module fp4multiplier (
    input  logic       i_clk,
    input  logic       i_rst,
    input  logic       i_data_valid,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic       o_valid, 
    output logic       o_sign,
    output logic [2:0] o_exp_u,
    output logic [4:0] o_sig_grs
);
    localparam int BIAS = 1;

    // Stage 0: capture/decode
    logic s0_v;
    logic s_a, s_b;
    logic [1:0] e_a_b, e_b_b;
    logic       m_a, m_b;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            s0_v <= 1'b0;
        end else begin
            s0_v   <= i_data_valid;
            s_a    <= a[3];  e_a_b <= a[2:1];  m_a <= a[0];
            s_b    <= b[3];  e_b_b <= b[2:1];  m_b <= b[0];
        end
    end

    // Stage 1: sign, unbiased exponent sum, product class
    logic        s1_v;
    logic        sign_p;
    logic signed [2:0] exp_u_sum;
    typedef enum logic [1:0] {P_1_00, P_1_50, P_2_25} prod_t;
    prod_t prod_kind;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            s1_v <= 1'b0;
        end else begin
            s1_v     <= s0_v;
            sign_p   <= s_a ^ s_b;
            exp_u_sum <= $signed({1'b0,e_a_b}) - BIAS
                       +  $signed({1'b0,e_b_b}) - BIAS;

            unique case ({m_a,m_b})
                2'b00: prod_kind <= P_1_00; // 1.0
                2'b01,
                2'b10: prod_kind <= P_1_50; // 1.5
                default: prod_kind <= P_2_25; // 2.25
            endcase
        end
    end

    // Stage 2: normalize (2.25 -> 1.125, bump exp) and form {I,F,G,R,S}
    logic s2_v;
    logic [2:0] exp_u_out;
    logic [4:0] sig_grs_out;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            s2_v        <= 1'b0;
            exp_u_out   <= 3'd0;
            sig_grs_out <= 5'd0;
        end else begin
            s2_v <= s1_v;
            unique case (prod_kind)
                P_1_00: begin // 1.0
                    exp_u_out   <= exp_u_sum;
                    sig_grs_out <= 5'b1_0_0_0_0; // 1.0 with GRS=000
                end
                P_1_50: begin // 1.5
                    exp_u_out   <= exp_u_sum;
                    sig_grs_out <= 5'b1_1_0_0_0; // 1.1 with GRS=000
                end
                default: begin // 2.25 -> >>1 => 1.125; exp+1
                    exp_u_out   <= exp_u_sum + 3'd1;
                    sig_grs_out <= 5'b1_0_0_1_0; // 1.0 with GRS=010
                end

            endcase
        end
    end

    // Outputs
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            o_valid  <= 1'b0;
            o_sign   <= 1'b0;
            o_exp_u  <= 3'd0;
            o_sig_grs<= 5'd0;
        end else begin
            o_valid   <= s2_v;
            o_sign    <= sign_p;
            o_exp_u   <= exp_u_out;
            o_sig_grs <= sig_grs_out;
        end
    end
endmodule
