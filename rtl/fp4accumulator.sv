module fp4_accumulator (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic        i_data_valid,
    input  logic [3:0]  i_fp4,      // E2M1
    output logic [3:0]  o_accum, 
    output logic        o_valid
);

    logic [3:0] acc_r;
    logic       valid_r;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            acc_r   <= 4'd0;
            valid_r <= 1'b0;
        end else begin
            valid_r <= i_data_valid;

            if (i_data_valid) begin
                acc_r <= fp4_add(acc_r, i_fp4);
            end
        end
    end

    assign o_accum = acc_r;
    assign o_valid = valid_r;

    // -------------------------------------------------
    // Combinational FP4 adder
    function automatic [3:0] fp4_add(input [3:0] a, input [3:0] b);
        logic sign_a, sign_b;
        logic [1:0] exp_a, exp_b;
        logic man_a, man_b;
        logic [2:0] mant_a, mant_b;
        logic [2:0] mant_res;
        logic [1:0] exp_res;
        logic sign_res;
        logic extra;

        sign_a = a[3]; exp_a = a[2:1]; man_a = a[0];
        sign_b = b[3]; exp_b = b[2:1]; man_b = b[0];

        // add implicit leading 1
        mant_a = {1'b1, man_a};
        mant_b = {1'b1, man_b};

        // align exponents
        if (exp_a > exp_b) begin
            mant_b = mant_b >> (exp_a - exp_b);
            exp_res = exp_a;
        end else begin
            mant_a = mant_a >> (exp_b - exp_a);
            exp_res = exp_b;
        end

        // add/subtract mantissas
        if (sign_a == sign_b)
            mant_res = mant_a + mant_b;
        else if (mant_a >= mant_b)
            mant_res = mant_a - mant_b;
        else begin
            mant_res = mant_b - mant_a;
            sign_res = sign_b;
        end
        sign_res = (mant_res == 0) ? 1'b0 : (sign_a); // zero is always positive

        // normalize
        if (mant_res[2]) begin
            mant_res = mant_res >> 1;
            exp_res  = exp_res + 1;
        end

        // clamp exponent
        if (exp_res > 2'b11) exp_res = 2'b11;

        // pack result
        fp4_add = {sign_res, exp_res, mant_res[0]};
    endfunction
endmodule
