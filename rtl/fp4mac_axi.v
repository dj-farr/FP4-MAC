`timescale 1ns/1ps

// AXI-Lite wrapper for FP4 MAC unit
module fp4mac_axi (
    // AXI-Lite Clock and Reset
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    
    // AXI-Lite Write Address Channel
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    
    // AXI-Lite Write Data Channel  
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    
    // AXI-Lite Write Response Channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    
    // AXI-Lite Read Address Channel
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    
    // AXI-Lite Read Data Channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

    // Register map
    // 0x00: Control register [0]=start, [1]=reset_acc
    // 0x04: Input A (FP4 in bits [3:0])
    // 0x08: Input B (FP4 in bits [3:0]) 
    // 0x0C: Result (FP4 in bits [3:0]), [31]=valid
    // 0x10: Status register [0]=busy, [1]=done

    // Internal registers
    reg [31:0] control_reg;
    reg [31:0] input_a_reg;
    reg [31:0] input_b_reg;
    wire [31:0] result_reg;
    wire [31:0] status_reg;
    
    // MAC interface signals
    wire        mac_start;
    wire        mac_reset_acc;
    wire [3:0]  mac_input_a;
    wire [3:0]  mac_input_b;
    wire [3:0]  mac_result;
    wire        mac_valid;
    wire        mac_busy;
    
    // Extract signals from registers
    assign mac_start = control_reg[0];
    assign mac_reset_acc = control_reg[1];
    assign mac_input_a = input_a_reg[3:0];
    assign mac_input_b = input_b_reg[3:0];
    assign result_reg = {mac_valid, 27'h0, mac_result};
    assign status_reg = {30'h0, mac_valid, mac_busy};
    
    // AXI-Lite logic (simplified - you'd need full implementation)
    reg [31:0] axi_awaddr;
    reg        axi_awready;
    reg        axi_wready;
    reg [1:0]  axi_bresp;
    reg        axi_bvalid;
    reg [31:0] axi_araddr;
    reg        axi_arready;
    reg [31:0] axi_rdata;
    reg [1:0]  axi_rresp;
    reg        axi_rvalid;
    
    // Assign AXI outputs
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = axi_rdata;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;
    
    // Simplified write logic
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            control_reg <= 32'h0;
            input_a_reg <= 32'h0;
            input_b_reg <= 32'h0;
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            axi_bvalid <= 1'b0;
        end else begin
            // AXI write handling (simplified)
            if (s_axi_awvalid && s_axi_wvalid && axi_awready && axi_wready) begin
                case (axi_awaddr[7:0])
                    8'h00: control_reg <= s_axi_wdata;
                    8'h04: input_a_reg <= s_axi_wdata;  
                    8'h08: input_b_reg <= s_axi_wdata;
                endcase
            end
        end
    end
    
    // Simplified read logic
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_rdata <= 32'h0;
            axi_rvalid <= 1'b0;
            axi_arready <= 1'b0;
        end else begin
            if (s_axi_arvalid && axi_arready) begin
                case (axi_araddr[7:0])
                    8'h00: axi_rdata <= control_reg;
                    8'h04: axi_rdata <= input_a_reg;
                    8'h08: axi_rdata <= input_b_reg;
                    8'h0C: axi_rdata <= result_reg;
                    8'h10: axi_rdata <= status_reg;
                    default: axi_rdata <= 32'h0;
                endcase
                axi_rvalid <= 1'b1;
            end
        end
    end

    // Instantiate your FP4 MAC
    fp4mac_top mac_inst (
        .i_clk(s_axi_aclk),
        .i_rst(~s_axi_aresetn | mac_reset_acc),
        .i_data_valid(mac_start),
        .i_a(mac_input_a),
        .i_b(mac_input_b),
        .o_accum_fp4(mac_result),
        .o_accum_valid(mac_valid)
    );
    
    // Control logic for busy signal
    reg mac_busy_reg;
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            mac_busy_reg <= 1'b0;
        end else begin
            if (mac_start) mac_busy_reg <= 1'b1;
            if (mac_valid) mac_busy_reg <= 1'b0;
        end
    end
    assign mac_busy = mac_busy_reg;

endmodule