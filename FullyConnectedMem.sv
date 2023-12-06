`timescale 1ns/1ps

module FullyConnectedMem #(
    // MUST be overwritten in CNN
    parameter FLATTENED_LENGTH = 50,
    parameter FULLYCONNECTED_DATA_WIDTH = 8
)(
    input logic fullyconnected_WrEn, // Write enable (active-low)
    input logic clk,
    input logic rst,
    input logic [FULLYCONNECTED_DATA_WIDTH-1:0] fullyconnected_weights_input [FLATTENED_LENGTH], // Weight input
    output logic [FULLYCONNECTED_DATA_WIDTH-1:0] fullyconnected_weights_output [FLATTENED_LENGTH] // Weight output
);

// Memory for fullyconected weights stored in a 1D array:
logic [FULLYCONNECTED_DATA_WIDTH - 1:0] fullyconnected_weights_mem [FLATTENED_LENGTH];

// Outputs all the feature weights inside fullyconnected_weights_mem
// Has to output all of them at the same time due to the combinational nature of the FULLYCONNECTED layer
assign fullyconnected_weights_output = fullyconnected_weights_mem;

// Writing new weights to the weight memory only when fullyconnected_WrEn is low (active low) or on negedge of clk
always_ff @(negedge clk, negedge rst) begin
    // If reset is asserted, reset all the fullyconnected weights inside the memory to 0
    if (!rst) 
        fullyconnected_weights_mem <= '{default: '0};
    // Else if fullyconnected_WrEn is asserted, write new fullyconnected weights into memory
    else if (!fullyconnected_WrEn) begin
        fullyconnected_weights_mem <= fullyconnected_weights_input;
    end
end

endmodule