`timescale 1ns/1ps

module tb_fp4mac;

    // Clock and reset
    logic clk;
    logic rst;
    
    // DUT interface
    logic        data_valid;
    logic [3:0]  a, b;
    logic [3:0]  accum_out;
    logic        accum_valid;

    // DUT instantiation
    fp4mac_top dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_data_valid(data_valid),
        .i_a(a),
        .i_b(b),
        .o_accum_fp4(accum_out),
        .o_accum_valid(accum_valid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_fp4mac.vcd");
        $dumpvars(0, tb_fp4mac);
    end

    // FP4 Format: {sign, exp[1:0], mantissa} - E2M1 with bias=1
    // Value = (-1)^sign * (1 + mantissa) * 2^(exp-1)
    // Range: -6 to +6
    // 
    // FP4 E2M1 values:
    // 4'b0000 = +0     4'b1000 = -0
    // 4'b0001 = +1.5   4'b1001 = -1.5  
    // 4'b0010 = +1     4'b1010 = -1
    // 4'b0011 = +2     4'b1011 = -2
    // 4'b0100 = +0.5   4'b1100 = -0.5
    // 4'b0101 = +0.75  4'b1101 = -0.75
    // 4'b0110 = +3     4'b1110 = -3
    // 4'b0111 = +6     4'b1111 = -6

    // Test stimulus
    initial begin
        // Initialize signals
        rst = 1;
        data_valid = 0;
        a = 4'h0;
        b = 4'h0;

        // Reset sequence
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("Starting FP4 MAC test...");
        $display("FP4 Format: {sign, exp[1:0], mantissa}");
        $display("Value = (-1)^sign * (1 + mantissa) * 2^(exp-1)");

        // Test 1: Basic multiplication 1 * 1 = 1  
        $display("\nTest 1: 1 * 1 = 1");
        send_inputs(4'b0010, 4'b0010);  // +1 * +1 = +1
        wait_and_check();

        // Test 2: Zero multiplication
        $display("\nTest 2: 0 * 1 = 0");
        send_inputs(4'b0000, 4'b0010);  // +0 * +1 = +0
        wait_and_check();

        // Test 3: Fraction multiplication
        $display("\nTest 3: 0.5 * 2 = 1");
        send_inputs(4'b0001, 4'b0100);  // +0.5 * +2 = +1
        wait_and_check();

        // Test 4: Negative multiplication
        $display("\nTest 4: -1 * 1 = -1");
        send_inputs(4'b1010, 4'b0010);  // -1 * +1 = -1
        wait_and_check();

        // Test 5: Larger values
        $display("\nTest 5: 1.5 * 2 = 3");
        send_inputs(4'b0011, 4'b0100);  // +1.5 * +2 = +3
        wait_and_check();

        // Test 6: Accumulation test - build up sum
        $display("\nTest 6: Accumulation: 1 + 1 + 1 = 3");
        send_inputs(4'b0010, 4'b0010);  // +1 * +1 = +1 (acc = 1)
        wait_cycles(3);
        send_inputs(4'b0010, 4'b0010);  // +1 * +1 = +1 (acc = 1+1 = 2)
        wait_cycles(3);
        send_inputs(4'b0010, 4'b0010);  // +1 * +1 = +1 (acc = 2+1 = 3)
        wait_cycles(5);

        // Test 7: Mixed signs
        $display("\nTest 7: 2 * -0.5 = -1");
        send_inputs(4'b0100, 4'b1001);  // +2 * -0.5 = -1
        wait_cycles(5);

        // === EXTENDED TEST SUITE ===
        
        // Test 8: Maximum positive values
        $display("\nTest 8: Max values: 6 * 1 = 6");
        send_inputs(4'b0111, 4'b0010);  // +6 * +1 = +6
        wait_and_check();

        // Test 9: Maximum negative values
        $display("\nTest 9: Max negative: -6 * 1 = -6");
        send_inputs(4'b1111, 4'b0010);  // -6 * +1 = -6
        wait_and_check();

        // Test 10: Subnormal operations
        $display("\nTest 10: Subnormals: 0.5 * 0.5 = 0.25→0");
        send_inputs(4'b0001, 4'b0001);  // +0.5 * +0.5 = +0.25 (underflow)
        wait_and_check();

        // Test 11: Mixed subnormal and normal
        $display("\nTest 11: 0.5 * 3 = 1.5");
        send_inputs(4'b0001, 4'b0101);  // +0.5 * +3 = +1.5
        wait_and_check();

        // Test 12: Zero times anything
        $display("\nTest 12: 0 * 6 = 0");
        send_inputs(4'b0000, 4'b0111);  // +0 * +6 = +0
        wait_and_check();

        // Test 13: Negative zero
        $display("\nTest 13: -0 * 1 = -0");
        send_inputs(4'b1000, 4'b0010);  // -0 * +1 = -0
        wait_and_check();

        // Test 14: Large multiplication (potential overflow)
        $display("\nTest 14: 6 * 6 = 36→max");
        send_inputs(4'b0111, 4'b0111);  // +6 * +6 = overflow to max
        wait_and_check();

        // Test 15: Negative large multiplication
        $display("\nTest 15: -6 * 6 = -36→min");
        send_inputs(4'b1111, 4'b0111);  // -6 * +6 = overflow to min
        wait_and_check();

        // Test 16: Fractional precision test
        $display("\nTest 16: 1.5 * 1.5 = 2.25→2");
        send_inputs(4'b0011, 4'b0011);  // +1.5 * +1.5 = +2.25 → rounded
        wait_and_check();

        // Test 17: Sign combinations - both negative
        $display("\nTest 17: -2 * -3 = 6");
        send_inputs(4'b1100, 4'b1101);  // -2 * -3 = +6
        wait_and_check();

        // Test 18: Accumulation with mixed signs
        $display("\nTest 18: Accumulation: Add +2, then subtract 1");
        send_inputs(4'b0100, 4'b0010);  // +2 * +1 = +2
        wait_and_check();
        send_inputs(4'b1010, 4'b0010);  // -1 * +1 = -1 (acc: 2-1=1)
        wait_and_check();

        // Test 19: Accumulation cancellation
        $display("\nTest 19: Accumulation cancellation: +3 - 3 = 0");
        send_inputs(4'b0101, 4'b0010);  // +3 * +1 = +3
        wait_and_check();
        send_inputs(4'b1101, 4'b0010);  // -3 * +1 = -3 (acc: 3-3=0)
        wait_and_check();

        // Test 20: Reset accumulator and test edge case
        $display("\nTest 20: Reset and edge case: 4 * 1.5 = 6");
        // Reset by adding zero
        send_inputs(4'b0000, 4'b0010);  // +0 * +1 = +0 (clears accumulator)
        wait_and_check();
        send_inputs(4'b0110, 4'b0011);  // +4 * +1.5 = +6
        wait_and_check();

        // Test 21: Systematic sign testing
        $display("\nTest 21: Sign matrix: + * +, + * -, - * +, - * -");
        send_inputs(4'b0010, 4'b0010);  // +1 * +1 = +1
        wait_and_check();
        send_inputs(4'b0010, 4'b1010);  // +1 * -1 = -1 (acc: 1-1=0)
        wait_and_check();
        send_inputs(4'b1010, 4'b0010);  // -1 * +1 = -1 (acc: 0-1=-1)
        wait_and_check();
        send_inputs(4'b1010, 4'b1010);  // -1 * -1 = +1 (acc: -1+1=0)
        wait_and_check();

        // Test 22: Boundary accumulation
        $display("\nTest 22: Build up to near max: 2+2+2=6");
        send_inputs(4'b0000, 4'b0010);  // Clear accumulator: 0*1=0
        wait_and_check();
        send_inputs(4'b0100, 4'b0010);  // +2 * +1 = +2
        wait_and_check();
        send_inputs(4'b0100, 4'b0010);  // +2 * +1 = +2 (acc: 2+2=4)
        wait_and_check();
        send_inputs(4'b0100, 4'b0010);  // +2 * +1 = +2 (acc: 4+2=6)
        wait_and_check();

        // Test 23: Overflow accumulation test
        $display("\nTest 23: Overflow test: 6 + 3 → max");
        send_inputs(4'b0101, 4'b0010);  // +3 * +1 = +3 (acc: 6+3→max)
        wait_and_check();

        // Test 24: Underflow test with subnormals
        $display("\nTest 24: Subnormal precision: 0.5 * 1 = 0.5");
        send_inputs(4'b0000, 4'b0010);  // Clear: 0*1=0
        wait_and_check();
        send_inputs(4'b0001, 4'b0010);  // +0.5 * +1 = +0.5
        wait_and_check();

        // Test 25: Complex accumulation sequence
        $display("\nTest 25: Complex sequence: Build 1.5, subtract 0.5, add 2");
        send_inputs(4'b0000, 4'b0010);  // Clear: 0*1=0
        wait_and_check();
        send_inputs(4'b0011, 4'b0010);  // +1.5 * +1 = +1.5
        wait_and_check();
        send_inputs(4'b1001, 4'b0010);  // -0.5 * +1 = -0.5 (acc: 1.5-0.5=1)
        wait_and_check();
        send_inputs(4'b0100, 4'b0010);  // +2 * +1 = +2 (acc: 1+2=3)
        wait_and_check();

        $display("\n=== ALL TESTS COMPLETED ===");
        $display("Total tests run: 25");
        $finish;
    end

    // Task to send inputs
    task send_inputs(input [3:0] val_a, input [3:0] val_b);
        begin
            @(posedge clk);
            a = val_a;
            b = val_b;
            data_valid = 1;
            $display("@%0t: Sending inputs a=%b (%s) * b=%b (%s)", 
                    $time, val_a, fp4_to_string(val_a), val_b, fp4_to_string(val_b));
            
            @(posedge clk);
            data_valid = 0;
            a = 4'hx;
            b = 4'hx;
        end
    endtask

    // Task to wait and check results
    task wait_and_check();
        integer timeout;
        begin
            timeout = 0;
            // Wait for output valid or timeout
            while (!accum_valid && timeout < 20) begin
                @(posedge clk);
                timeout++;
            end
            
            if (accum_valid) begin
                $display("@%0t: Result valid! accum_out=%b (%s)", $time, accum_out, fp4_to_string(accum_out));
            end else begin
                $display("@%0t: ERROR - No valid output received (timeout)", $time);
            end
        end
    endtask

    // Task to wait specific cycles
    task wait_cycles(input integer cycles);
        integer i;
        begin
            for (i = 0; i < cycles; i++) begin
                @(posedge clk);
            end
        end
    endtask

    // Function to convert FP4 to readable string
    function string fp4_to_string(input [3:0] fp4_val);
        logic sign;
        logic [1:0] exp;
        logic mantissa;
        real value;
        
        sign = fp4_val[3];
        exp = fp4_val[2:1];
        mantissa = fp4_val[0];
        
        if (fp4_val[2:0] == 3'b000) begin
            fp4_to_string = sign ? "-0" : "+0";
        end else begin
            // Value = (-1)^sign * (1 + mantissa) * 2^(exp-1)
            value = (1.0 + mantissa) * (2.0 ** (exp - 1));
            if (sign) value = -value;
            
            case (fp4_val)
                4'b0000: fp4_to_string = "+0";     // Zero
                4'b0001: fp4_to_string = "+0.5";   // Subnormal: 2^0 * 0.5 = 0.5
                4'b0010: fp4_to_string = "+1";     // Normal: 2^0 * 1.0 = 1.0  
                4'b0011: fp4_to_string = "+1.5";   // Normal: 2^0 * 1.5 = 1.5
                4'b0100: fp4_to_string = "+2";     // Normal: 2^1 * 1.0 = 2.0
                4'b0101: fp4_to_string = "+3";     // Normal: 2^1 * 1.5 = 3.0
                4'b0110: fp4_to_string = "+4";     // Normal: 2^2 * 1.0 = 4.0
                4'b0111: fp4_to_string = "+6";     // Normal: 2^2 * 1.5 = 6.0 (max)
                4'b1000: fp4_to_string = "-0";     // Negative zero
                4'b1001: fp4_to_string = "-0.5";   // Negative subnormal
                4'b1010: fp4_to_string = "-1";     // Normal: -2^0 * 1.0 = -1.0
                4'b1011: fp4_to_string = "-1.5";   // Normal: -2^0 * 1.5 = -1.5
                4'b1100: fp4_to_string = "-2";     // Normal: -2^1 * 1.0 = -2.0
                4'b1101: fp4_to_string = "-3";     // Normal: -2^1 * 1.5 = -3.0
                4'b1110: fp4_to_string = "-4";     // Normal: -2^2 * 1.0 = -4.0
                4'b1111: fp4_to_string = "-6";     // Normal: -2^2 * 1.5 = -6.0 (min)
                default: fp4_to_string = "???";
            endcase
        end
    endfunction

    // Monitor all signals continuously
    always @(posedge clk) begin
        if (!rst) begin
            $display("@%0t: clk | data_v=%b a=%b b=%b | mul_v=%b mul_res=%b | acc_v=%b acc_out=%b (%s)", 
                    $time, data_valid, a, b, dut.mul_valid, dut.mul_result, accum_valid, accum_out, fp4_to_string(accum_out));
        end
    end

endmodule