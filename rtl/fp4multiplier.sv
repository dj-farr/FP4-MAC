`timescale 1ns/1ps

module fp4multiplier (
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

    // Simplified E2M1 multiplication using XOR approach with proper zero handling
    always_comb begin
        logic sign_result;
        logic [1:0] exp_a, exp_b, exp_result;
        logic man_a, man_b, man_result;
        logic [3:0] exp_sum;
        logic is_zero_a, is_zero_b;

        // Extract fields
        exp_a = a_r[2:1];
        exp_b = b_r[2:1];
        man_a = a_r[0];
        man_b = b_r[0];
        
        sign_result = a_r[3] ^ b_r[3];
        
        // Check for zeros: both exp=00 and man=0
        is_zero_a = (exp_a == 2'b00) && (man_a == 1'b0);
        is_zero_b = (exp_b == 2'b00) && (man_b == 1'b0);

        if (is_zero_a || is_zero_b) begin
            // Zero multiplication
            result_comb = {sign_result, 2'b00, 1'b0};
        end else begin
            // Use the proven XOR method for mantissa multiplication
            man_result = man_a ^ man_b;
            
            // Add exponents and subtract bias, add carry from mantissa multiplication
            exp_sum = {2'b00, exp_a} + {2'b00, exp_b} + (man_a & man_b) - 4'd1;
            
            // Handle overflow/underflow
            if (exp_sum > 4'd3) begin
                // Clamp to maximum
                exp_result = 2'b11;
                man_result = 1'b1;
            end else if (exp_sum < 4'd0) begin
                // Clamp to minimum (zero or subnormal)
                exp_result = 2'b00;
                man_result = 1'b0;
            end else begin
                exp_result = exp_sum[1:0];
            end
            
            result_comb = {sign_result, exp_result, man_result};
        end
        
        valid_comb = in_valid_r;
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
