`timescale 1ns/1ps

module FeatureMem_tb;
    //Parameters
    parameter KERNEL_SIZE = 3;
    parameter NUM_FEATURES = 10;

    //Signals
    logic [$clog2(NUM_FEATURES):0] address_w;
    logic feature_WrEn;
    logic clk;
    logic rst;
    logic signed [1:0] feature_weights_input [KERNEL_SIZE*KERNEL_SIZE];
    logic signed [1:0] feature_weights_output [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE]; 
    
    FeatureMem #(.KERNEL_SIZE(KERNEL_SIZE))
    FeatureMem_dut (
        .address_w(address_w),
        .feature_WrEn(feature_WrEn),
        .clk(clk),
        .rst(rst),
        .feature_weights_input(feature_weights_input),
        .feature_weights_output(feature_weights_output)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        feature_WrEn = 1;
        clk = 0;
        rst = 1;

        // Generate test data for feature_weights_input
        for (int i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            feature_weights_input[i] = i;
        end

        #10;
        rst = 0;

        #10;
        feature_WrEn = 0;

        #50;

        $finish;
    end

    initial begin
        // Display the output feature weights
        $display("Output Feature Weights:");
        for (int i = 0; i < NUM_FEATURES; i = i + 1) begin
            $display("Feature %0d:", i);
            for (int j = 0; j < KERNEL_SIZE*KERNEL_SIZE; j = j + 1) begin
                $display("feature_weights_output[%0d][%0d] = %0d", i, j, feature_weights_output[i][j]);
            end
        end
    end

endmodule
