`timescale 1ns/1ps

module ConvolutionPE_tb;

    // Parameters
    parameter CONVOLUTION_DATA_WIDTH = 8;
    
    // Signals
    logic signed [CONVOLUTION_DATA_WIDTH-1:0] inpsum;
    logic signed [1:0] weight;
    logic signed [1:0] infmap_value;
    logic signed [CONVOLUTION_DATA_WIDTH-1:0] outpsum;
    
    // Instantiate
    ConvolutionPE #(.CONVOLUTION_DATA_WIDTH(CONVOLUTION_DATA_WIDTH))
    ConvolutionPE_dut (.inpsum(inpsum), .weight(weight), 
    .infmap_value(infmap_value), .outpsum(outpsum));
    
    // Stimulus
    initial begin
        // Initialize test values
        inpsum = 0;
        weight = 3; // Example weight
        infmap_value = 2; // Example infmap_value
        
        #5; 
        $display("Input: inpsum=%d, weight=%d, infmap_value=%d", inpsum, weight, infmap_value);
        $display("Output: outpsum=%d", outpsum);
        
        $finish;
    end

endmodule