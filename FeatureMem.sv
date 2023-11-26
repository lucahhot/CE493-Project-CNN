`timescale 1ns/1ps

module FeatureMem #(
    parameter KERNEL_SIZE = 3,
    parameter NUM_FEATURES = 10
)(
    input logic [$clog2(NUM_FEATURES):0] address_w, // Write address
    input logic feature_WrEn, // Write enable for the weights memory
    input logic clk, // Writes new data synchronized with the main chip clock
    input logic rst, // Active-low reset to reset all weights inside the memory
    input logic signed [1:0] feature_weights_input [KERNEL_SIZE*KERNEL_SIZE], // Weight input
    output logic signed [1:0] feature_weights_output [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE] // Weights output
);

// Memory for feature weights stored in a 2D array:
// Each feature will have it's own KERNEL_SIZE * KERNELS_SIZE array of weight value
// For example, if the feature has a 3x3 feature map, the array will be a 1 dimensional
// 9 element flattened array of the feature weights. 
logic signed [1:0] feature_weights_mem [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// Outputs all the feature weights inside feature_weights_mem. 
// It has to output all the feature weights at the same because of the way the MAC calculations are done:
// All the feature weights are used simultaneously by the PEs on the same part of the image input so 
// all the feature weights have to be accessed at the same time. 
assign feature_weights_output = feature_weights_mem;

// Writing new weights to the weight memory only when feature_WrEn is low (active low) or on negedge of clk
always_ff @(negedge clk, negedge rst) begin
    // If reset is asserted, reset all the feature weights inside the memory to 0
    if (!rst) 
        feature_weights_mem <= '{default: '0};
    // Else if feature_WrEn is asserted, write new feature weights into corresponding address location
    else if (!feature_WrEn) begin
            // Check that address_w is valid or else don't write to memory
            if (address_w >= 0 && address_w < NUM_FEATURES)
                feature_weights_mem[address_w] <= feature_weights_input;
    end
end


endmodule