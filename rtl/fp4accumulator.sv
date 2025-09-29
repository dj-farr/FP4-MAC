`timescale 1ns/1ps

module fp4accumulator (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic        i_data_valid,
    input  logic [3:0]  i_fp4,      // E2M1
    output logic [3:0]  o_accum, 
    output logic        o_valid
);

    logic [3:0] acc_reg;
    logic [3:0] sum_result;
    logic i_data_valid_r; 

    // combinational logic - addition
    always_comb begin
        sum_result = fp4_add(acc_reg, i_fp4);
    end

    // sequential logic - regs
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            acc_reg  <= 4'b0000; 
            o_accum  <= 4'b0000;
            o_valid  <= 1'b0;
            i_data_valid_r <= 1'b0;
        end else begin
            i_data_valid_r <= i_data_valid;
            if (i_data_valid && !i_data_valid_r) begin
                acc_reg <= sum_result;
                o_accum <= sum_result;
                o_valid <= 1'b1;
            end else begin
                o_valid <= 1'b0;
            end
        end
    end

    // fp4 addition
    function [3:0] fp4_add(input [3:0] a, input [3:0] b);
        reg sign_a, sign_b, sign_result;
        reg [1:0] exp_a, exp_b, exp_result;
        reg man_a, man_b, man_result;
        reg [1:0] mant_a_full, mant_b_full;
        reg [2:0] sum, diff;
        reg [1:0] exp_diff;
        begin
            // get fields
            sign_a = a[3];
            exp_a = a[2:1];
            man_a = a[0];
            sign_b = b[3];
            exp_b = b[2:1];
            man_b = b[0];
            
            // zero cases
            if (a[2:0] == 3'b000) begin
                fp4_add = b;
            end else if (b[2:0] == 3'b000) begin
                fp4_add = a;
            end else begin
                mant_a_full = {1'b1, man_a};
                mant_b_full = {1'b1, man_b}; 
                
                // align exps - shift smaller mantissa right
                if (exp_a > exp_b) begin
                    exp_diff = exp_a - exp_b;
                    if (exp_diff >= 1) mant_b_full = mant_b_full >> 1; 
                    exp_result = exp_a;
                end else if (exp_b > exp_a) begin
                    exp_diff = exp_b - exp_a;
                    if (exp_diff >= 1) mant_a_full = mant_a_full >> 1;
                    exp_result = exp_b;
                end else begin
                    exp_result = exp_a;
                end
                
                // add/sub based on sign
                if (sign_a == sign_b) begin
                    sum = mant_a_full + mant_b_full;
                    sign_result = sign_a;
                    
                    // normalize if overflow
                    if (sum >= 3'b100) begin
                        sum = sum >> 1;
                        if (exp_result < 2'd3) exp_result = exp_result + 1;
                        else begin // overflow to max
                            fp4_add = {sign_result, 2'b11, 1'b1};
                        end
                    end
                    man_result = sum[0];
                    fp4_add = {sign_result, exp_result, man_result};
                    
                end else begin
                    if (mant_a_full >= mant_b_full) begin
                        diff = mant_a_full - mant_b_full;
                        sign_result = sign_a;
                    end else begin
                        diff = mant_b_full - mant_a_full;
                        sign_result = sign_b;
                    end
                    
                    // zero case
                    if (diff == 0) begin
                        fp4_add = 4'b0000;
                    end else begin
                        // normalize, shift left if needed
                        if (diff[1] == 0 && exp_result > 0) begin
                            diff = diff << 1;
                            exp_result = exp_result - 1;
                        end
                        
                        // underflow check
                        if (exp_result == 0 && diff[1] == 0) begin
                            fp4_add = 4'b0000;
                        end else begin
                            man_result = diff[0];
                            fp4_add = {sign_result, exp_result, man_result};
                        end
                    end
                end
            end
        end
    endfunction

endmodule