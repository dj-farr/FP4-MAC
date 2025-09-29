`timescale 1ns/1ps

module tb_fp4mac_top;

    logic        clk;
    logic        rst;
    logic        data_v;
    logic [3:0]  a, b;
    logic [3:0]  o_accum;
    logic        o_valid;

    // DUT
    fp4mac_top dut (
        .i_clk        (clk),
        .i_rst        (rst),
        .i_data_valid (data_v),
        .i_a          (a),
        .i_b          (b),
        .o_accum_fp4  (o_accum),
        .o_accum_valid(o_valid)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz-ish

    // waveform
    initial begin
        $dumpfile("tb_fp4mac_top.vcd");
        $dumpvars(0, tb_fp4mac_top);
    end

    // ------- reference helpers (behavioral FP4 ops) --------
    // FP4 format: {sign, exp[1:0], man}
    // implicit significand = 1 + man/2
    function automatic logic [3:0] ref_fp4_mul(input logic [3:0] A, input logic [3:0] B);
        logic sign_a, sign_b;
        logic [1:0] ea, eb;
        logic ma, mb;
        logic extra;
        logic [3:0] sum_raw;
        logic signed [3:0] exp_biased;
        logic [1:0] exp_out;
        logic man_out;
        logic sign_out;
        sign_a = A[3]; sign_b = B[3];
        ea = A[2:1]; eb = B[2:1];
        ma = A[0]; mb = B[0];
        extra = ma & mb; // increment when 1.5*1.5 >= 2
        // sum = ea + eb + extra - bias(1)
        sum_raw = ({1'b0, ea} + {1'b0, eb} + extra);
        exp_biased = $signed({1'b0, sum_raw}) - 4'sd1;
        if (exp_biased < 0) exp_out = 2'b00;
        else if (exp_biased > 3) exp_out = 2'b11;
        else exp_out = exp_biased[1:0];
        man_out = ma ^ mb; // truncation rule used in DUT
        sign_out = sign_a ^ sign_b;
        ref_fp4_mul = {sign_out, exp_out, man_out};
    endfunction

    // fp4_add_ref: add two FP4 numbers (same algorithm as accumulator)
    function automatic logic [3:0] ref_fp4_add(input logic [3:0] A, input logic [3:0] B);
        // decode
        logic sa, sb;
        logic [1:0] ea, eb;
        logic ma, mb;
        sa = A[3]; ea = A[2:1]; ma = A[0];
        sb = B[3]; eb = B[2:1]; mb = B[0];

        // make 6-bit mantissas with implicit 1 at bit5 and frac at bit4
        logic [5:0] ma_ext, mb_ext;
        ma_ext = 6'd0; mb_ext = 6'd0;
        ma_ext[5] = 1'b1; ma_ext[4] = ma;
        mb_ext[5] = 1'b1; mb_ext[4] = mb;

        // align
        logic [2:0] exp_res;
        if (ea > eb) begin
            case (ea - eb)
                2'd0: mb_ext = mb_ext;
                2'd1: mb_ext = {1'b0, mb_ext[5:1]};
                2'd2: mb_ext = {2'b00, mb_ext[5:2]};
                default: mb_ext = {3'b000, mb_ext[5:3]};
            endcase
            exp_res = {1'b0, ea};
        end else begin
            case (eb - ea)
                2'd0: ma_ext = ma_ext;
                2'd1: ma_ext = {1'b0, ma_ext[5:1]};
                2'd2: ma_ext = {2'b00, ma_ext[5:2]};
                default: ma_ext = {3'b000, ma_ext[5:3]};
            endcase
            exp_res = {1'b0, eb};
        end

        // add/sub
        logic [6:0] mant_sum;
        logic sign_res;
        if (sa == sb) begin
            mant_sum = {1'b0, ma_ext} + {1'b0, mb_ext};
            sign_res = sa;
        end else begin
            if (ma_ext >= mb_ext) begin
                mant_sum = {1'b0, ma_ext} - {1'b0, mb_ext};
                sign_res = sa;
            end else begin
                mant_sum = {1'b0, mb_ext} - {1'b0, ma_ext};
                sign_res = sb;
            end
        end

        // zero check
        if (mant_sum == 7'd0) begin
            ref_fp4_add = 4'b0000;
            return;
        end

        // normalize
        logic [5:0] mant_norm;
        if (mant_sum[6]) begin
            mant_norm = mant_sum[6:1];
            exp_res = exp_res + 3'd1;
        end else if (mant_sum[5]) begin
            mant_norm = mant_sum[5:0];
        end else begin
            // shift left once if possible, else underflow to zero
            if (exp_res != 3'd0) begin
                mant_norm = {mant_sum[5:0],1'b0}[5:0];
                exp_res = exp_res - 3'd1;
            end else begin
                ref_fp4_add = 4'b0000;
                return;
            end
        end

        // clamp high
        logic [1:0] out_exp;
        logic out_man;
        if (exp_res > 3) begin
            out_exp = 2'b11;
            out_man = 1'b1;
        end else begin
            out_exp = exp_res[1:0];
            out_man = mant_norm[4];
        end

        ref_fp4_add = {sign_res, out_exp, out_man};
    endfunction

    // small FIFO for products (since pipeline = 2 cycles total)
    logic [3:0] prod_q [0:15];
    int q_head, q_tail, q_count;

    task push_prod(input logic [3:0] v);
        prod_q[q_tail] = v;
        q_tail = (q_tail + 1) % 16;
        q_count++;
    endtask

    function logic [3:0] pop_prod();
        logic [3:0] tmp;
        tmp = prod_q[q_head];
        q_head = (q_head + 1) % 16;
        q_count--;
        pop_prod = tmp;
    endfunction

    // reference accumulator state
    logic [3:0] ref_acc;

    // stimulus
    initial begin
        // init
        rst = 1; data_v = 0; a = 0; b = 0;
        q_head = 0; q_tail = 0; q_count = 0;
        ref_acc = 4'd0;

        #20;
        rst = 0;
        #20;

        // test vectors: a few hand-picked and some random
        // format helper: {s,e1,e0,m}
        logic [3:0] tv_a[0:15];
        logic [3:0] tv_b[0:15];

        // hand-picked
        tv_a[0] = 4'b0000; // +0
        tv_b[0] = 4'b0000;
        tv_a[1] = 4'b0001; // +1 (exp0 man1? interpret as +1.5*2^-1? still use encoding)
        tv_b[1] = 4'b0011; // +3
        tv_a[2] = 4'b1001; // -1  (sign bit 1)
        tv_b[2] = 4'b0111; // +7 basically high exp/mant
        // some useful edges
        tv_a[3] = 4'b0111; // +exp=3,man=1 -> large positive
        tv_b[3] = 4'b0111;
        tv_a[4] = 4'b1111; // -exp=3,man=1 -> large negative
        tv_b[4] = 4'b1111;

        // fill rest with random combinations
        int i;
        for (i = 5; i <= 15; i++) begin
            tv_a[i] = $urandom_range(0,15);
            tv_b[i] = $urandom_range(0,15);
        end

        // apply sequence
        for (i = 0; i <= 15; i++) begin
            a = tv_a[i];
            b = tv_b[i];
            data_v = 1;
            // compute product reference and push (we don't update ref_acc until product actually consumed)
            push_prod(ref_fp4_mul(a,b));
            @(posedge clk);
            data_v = 0;
            a = 4'dx; b = 4'dx;
            // allow a few cycles between inputs
            @(posedge clk);
        end

        // wait until all queued products are consumed
        // there should be one product in queue per input; accumulator asserts o_valid when consuming
        int timeout = 200;
        while (q_count > 0 && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end

        if (q_count != 0) begin
            $display("ERROR: queue not drained (q_count=%0d)", q_count);
        end else begin
            $display("All inputs driven and products consumed.");
        end

        #50;
        $display("TEST FINISHED");
        $finish;
    end

    // check on each o_valid: pop expected product, update ref_acc via ref_add and compare
    always_ff @(posedge clk) begin
        if (rst) begin
            ref_acc <= 4'd0;
        end else begin
            if (o_valid) begin
                if (q_count == 0) begin
                    $display("ERROR @%0t: o_valid asserted but no queued product", $time);
                end else begin
                    logic [3:0] prod_expected;
                    prod_expected = pop_prod();
                    // update reference accumulator and clamp via ref_fp4_add
                    ref_acc <= ref_fp4_add(ref_acc, prod_expected);

                    // small delay to allow ref_acc to settle (comparison uses new ref_acc)
                    #1;
                    if (o_accum !== ref_acc) begin
                        $display("MISMATCH @%0t: DUT=%b expected=%b (prod=%b)", $time, o_accum, ref_acc, prod_expected);
                    end else begin
                        $display("OK      @%0t: DUT=%b expected=%b (prod=%b)", $time, o_accum, ref_acc, prod_expected);
                    end
                end
            end
        end
    end

endmodule
