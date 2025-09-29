module fp4_multiplier (
    input  logic        i_clk,
    input  logic        i_rst,         // active-high reset
    input  logic        i_data_valid,
    input  logic [3:0]  i_a,
    input  logic [3:0]  i_b,
    output logic [3:0]  o_result,
    output logic        o_valid
);

    // input registers
    logic        in_valid_r;
    logic [3:0]  a_r, b_r;

    // combinational outputs 
    logic [3:0]  result_comb;
    logic        valid_comb;

    // decode and combinational
    always_comb begin
        logic sign_p;
        logic man_p;
        logic extra;
        logic [3:0] exp_p_raw;
        logic [1:0] exp_p;

        sign_p = a_r[3] ^ b_r[3];
        man_p  = a_r[0] ^ b_r[0];
        extra  = a_r[0] & b_r[0];

        // sum exponents + extra, subtract bias
        exp_p_raw = {1'b0, a_r[2:1]} + {1'b0, b_r[2:1]} + extra - 4'd1;

        // clamp to 0 to 3 range
        if (exp_p_raw > 4'd3)
            exp_p = 2'b11;
        else if (exp_p_raw < 0)
            exp_p = 2'b00;
        else
            exp_p = exp_p_raw[1:0];

        result_comb = {sign_p, exp_p, man_p};
        valid_comb  = in_valid_r;
    end

    // input capture (register inputs when i_data_valid)
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            in_valid_r <= 1'b0;
            a_r        <= 4'd0;
            b_r        <= 4'd0;
            o_result   <= 4'd0;
            o_valid    <= 1'b0;
        end else begin
            // capture new inputs
            if (i_data_valid) begin
                a_r <= i_a;
                b_r <= i_b;
                in_valid_r <= 1'b1;
            end else begin
                in_valid_r <= 1'b0;
            end

            // register combinational result -> outputs
            o_result <= result_comb;
            o_valid  <= valid_comb;
        end
    end
endmodule
