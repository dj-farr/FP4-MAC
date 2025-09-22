module fp4accumulator (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_clear,        // clear to +0
    input  logic        i_acc_valid,    // consume current product
    input  logic        i_flush,        // request packed output

    // Wide product input
    input  logic        i_p_sign,
    input  logic [2:0]  i_p_exp_u,      // unbiased
    input  logic [4:0]  i_p_sig_grs,    // {I,F,G,R,S}

    // Telemetry
    output logic        o_acc_sign,
    output logic [2:0]  o_acc_exp_u,
    output logic [5:0]  o_acc_sig6,     // {I1,I0,F,G,R,S}

    // Packed fp4 {s,e[1:0],m}
    output logic        o_fp4_valid,
    output logic [3:0]  o_fp4
);
    localparam int BIAS = 1;

    // -------- state --------
    logic               acc_sign;
    logic signed [2:0]  acc_exp_u;
    logic        [5:0]  acc_sig6;       // {I1,I0,F,G,R,S}
    logic               acc_zero;

    assign acc_zero    = (acc_sig6 == 6'b0);
    assign o_acc_sign  = acc_sign;
    assign o_acc_exp_u = acc_exp_u;
    assign o_acc_sig6  = acc_sig6;

    // -------- helpers --------

    // Right shift with sticky: y = x >> sh; sticky = OR(shifted-out) OR old S
    task automatic rshift_sticky6(
        input  logic [5:0] x,
        input  integer     sh,
        output logic [5:0] y,
        output logic       sticky
    );
        integer k;
        logic dropped;
        begin
            if (sh <= 0) begin
                y      = x;
                sticky = x[0];
            end else if (sh >= 6) begin
                // everything shifts out
                dropped = (|x);
                y       = 6'b0;
                sticky  = dropped;
            end else begin
                dropped = 1'b0;
                for (k = 0; k < sh; k = k + 1) begin
                    dropped = dropped | x[k];
                end
                y      = x >> sh;
                sticky = dropped | x[0];
            end
        end
    endtask

    // Leading-one index; returns -1 if zero
    function automatic integer lead1_idx6(input logic [5:0] x);
        integer i;
        integer found;
        begin
            found = -1;
            for (i = 5; i >= 0; i--) begin
                if ((found == -1) && x[i]) found = i;
            end
            lead1_idx6 = found;
        end
    endfunction

    // Pack normalized wide -> 4-bit fp4 with RNE
    function automatic logic [3:0] pack_fp4(
        input  logic        sgn,
        input  logic signed [2:0] exp_u_nrm,
        input  logic [5:0]  sig6_nrm
    );
        logic [1:0] keep;  // {I0,F}
        logic       G, Rb, S;
        logic       round_up;
        logic [1:0] rounded;
        logic       carry_up;
        logic signed [2:0] exp_u_rnd;
        logic [1:0] keep_final;
        logic signed [3:0] e_bi;
        begin
            if (sig6_nrm == 6'b0) begin
                pack_fp4 = 4'b0_00_0;
            end else begin
                keep = {sig6_nrm[4], sig6_nrm[3]};
                G    = sig6_nrm[2];
                Rb   = sig6_nrm[1];
                S    = sig6_nrm[0];

                // RNE: round up if G && (R|S|LSB(keep))
                round_up = (G & (Rb | S | keep[0]));
                rounded  = keep + (round_up ? 2'd1 : 2'd0);
                // detect 1.1 -> +1 -> 10.0 (becomes 00 with carry)
                carry_up = (round_up && (rounded == 2'b00));

                exp_u_rnd  = exp_u_nrm + (carry_up ? 3'sd1 : 3'sd0);
                keep_final = carry_up ? 2'b10 : rounded;

                // re-bias and saturate
                e_bi = exp_u_rnd + BIAS; // signed add
                if (e_bi < 0)      pack_fp4 = 4'b0_00_0;             // underflow -> 0
                else if (e_bi > 3) pack_fp4 = {sgn, 2'b11, 1'b1};    // ±6.0
                else               pack_fp4 = {sgn, e_bi[1:0], keep_final[0]};
            end
        end
    endfunction

    // -------- accumulate one product (comb) --------
    logic               sum_sign;
    logic signed [2:0]  sum_exp_u;
    logic        [6:0]  sum_sig7;
    logic        [5:0]  norm_sig;
    logic signed [2:0]  norm_exp;

    // temps
    integer             shift, li, need_left;
    logic       [5:0]   A_sig, B_sig, tmp, t2;
    logic               sticky_tmp, st2;

    always_comb begin
        // Default: keep current
        sum_sign  = acc_sign;
        sum_exp_u = acc_exp_u;
        sum_sig7  = {1'b0, acc_sig6};

        if (acc_zero) begin
            // Load input directly (prepend carry bit=0 and I1=0)
            sum_sign  = i_p_sign;
            sum_exp_u = i_p_exp_u;
            sum_sig7  = {1'b0, 1'b0, i_p_sig_grs}; // {carry, I1=0, I,F,G,R,S}
        end else begin
            if (acc_exp_u >= i_p_exp_u) begin
                sum_exp_u = acc_exp_u;
                shift     = acc_exp_u - i_p_exp_u;

                // Align product
                rshift_sticky6({1'b0, i_p_sig_grs}, shift, tmp, sticky_tmp);
                B_sig     = tmp;
                B_sig[0]  = sticky_tmp; // force sticky into S
                A_sig     = acc_sig6;
            end else begin
                sum_exp_u = i_p_exp_u;
                shift     = i_p_exp_u - acc_exp_u;

                // Align accumulator
                rshift_sticky6(acc_sig6, shift, tmp, sticky_tmp);
                A_sig     = tmp;
                A_sig[0]  = sticky_tmp;
                B_sig     = {1'b0, i_p_sig_grs};
            end

            if (acc_sign == i_p_sign) begin
                sum_sign = acc_sign;
                sum_sig7 = {1'b0, A_sig} + {1'b0, B_sig};
            end else begin
                if (A_sig >= B_sig) begin
                    sum_sign = acc_sign;
                    sum_sig7 = {1'b0, A_sig} - {1'b0, B_sig};
                end else begin
                    sum_sign = i_p_sign;
                    sum_sig7 = {1'b0, B_sig} - {1'b0, A_sig};
                end
            end
        end

        // Normalize
        norm_sig = sum_sig7[5:0];
        norm_exp = sum_exp_u;

        if (sum_sig7[6]) begin
            // Carry beyond I1 -> >>1, exp+1
            norm_sig = sum_sig7[6:1];
            norm_exp = sum_exp_u + 3'sd1;
        end else if (sum_sig7[5]) begin
            // I1==1 -> >>1 with sticky, exp+1
            rshift_sticky6(sum_sig7[5:0], 1, t2, st2);
            norm_sig     = t2;
            norm_sig[0]  = st2;
            norm_exp     = sum_exp_u + 3'sd1;
        end else if (sum_sig7[5:0] != 6'b0) begin
            // Left normalize to place 1 at I0 (bit4)
            li = lead1_idx6(sum_sig7[5:0]);
            need_left = 4 - li; // target I0 at bit 4
            if (need_left > 0) begin
                norm_sig = sum_sig7[5:0] << need_left;
                norm_exp = sum_exp_u - need_left;
            end
        end else begin
            norm_sig = 6'b0;
            norm_exp = 3'sd0;
        end

        if (norm_sig == 6'b0) begin
            sum_sign = 1'b0; // zero is +0
        end
    end

    // -------- registers --------
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            acc_sign    <= 1'b0;
            acc_exp_u   <= 3'sd0;
            acc_sig6    <= 6'd0;
            o_fp4_valid <= 1'b0;
            o_fp4       <= 4'd0;
        end else begin
            if (i_clear) begin
                acc_sign  <= 1'b0;
                acc_exp_u <= 3'sd0;
                acc_sig6  <= 6'd0;
            end else if (i_acc_valid) begin
                acc_sign  <= (acc_zero ? i_p_sign : sum_sign);
                acc_exp_u <= norm_exp;
                acc_sig6  <= norm_sig;
            end

            if (i_flush) begin
                o_fp4_valid <= 1'b1;
                o_fp4       <= pack_fp4((acc_zero ? i_p_sign : sum_sign), norm_exp, norm_sig);
            end else begin
                o_fp4_valid <= 1'b0;
            end
        end
    end
endmodule
