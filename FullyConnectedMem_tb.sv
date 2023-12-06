`timescale 1ns/1ps

module FullyConnectedMem_tb;

    // Parameters
    parameter FLATTENED_LENGTH = 50;
    parameter FULLYCONNECTED_DATA_WIDTH = 8;

    // Signals
    logic fullyconnected_WrEn;
    logic clk;
    logic rst;
    logic [FULLYCONNECTED_DATA_WIDTH-1:0] fullyconnected_weights_input [FLATTENED_LENGTH];
    logic [FULLYCONNECTED_DATA_WIDTH-1:0] fullyconnected_weights_output [FLATTENED_LENGTH];

    // Instantiate
    FullyConnectedMem #(
        .FLATTENED_LENGTH(FLATTENED_LENGTH),
        .FULLYCONNECTED_DATA_WIDTH(FULLYCONNECTED_DATA_WIDTH)
    ) 
    FullyConnectedMem_dut (
        .fullyconnected_WrEn(fullyconnected_WrEn),
        .clk(clk),
        .rst(rst),
        .fullyconnected_weights_input(fullyconnected_weights_input),
        .fullyconnected_weights_output(fullyconnected_weights_output)
    );
    always
        #10 clk = ~clk;

    initial begin
        fullyconnected_WrEn = 1;
        clk = 0;
        rst = 1;
        for (int i = 0; i < FLATTENED_LENGTH; i = i + 1) begin
            fullyconnected_weights_input[i] = i;
        end

        #10 rst = 0;

        #10 fullyconnected_WrEn = 0; 
        
        #50;
        $finish;
    end

    // Monitor or display outputs
    initial begin
        // Display the output weights
        $display("Output Weights:");
        for (int i = 0; i < FLATTENED_LENGTH; i = i + 1) begin
            $display("fullyconnected_weights_output[%0d] = %0d", i, fullyconnected_weights_output[i]);
        end
    end

endmodule
