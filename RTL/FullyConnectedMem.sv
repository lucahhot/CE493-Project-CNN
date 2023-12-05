`timescale 1ns/1ps

module FullyConnectedMem #(
    // MUST be overwritten in CNN
    parameter FLATTENED_LENGTH = 432,
    parameter DATA_WIDTH = 8
)(
    input logic fullyconnected_WrEn, // Write enable (active-low)
    input logic clk,
    input logic rst,
    input logic [4:0] address_w, // Write address
    input logic signed [DATA_WIDTH-1:0] fullyconnected_weights_input [16], // Weight input
    output logic signed [DATA_WIDTH-1:0] fullyconnected_weights_output [FLATTENED_LENGTH] // Weight output
);

// Memory for fullyconected weights stored in a 1D array:
logic signed [DATA_WIDTH - 1:0] fullyconnected_weights_mem [FLATTENED_LENGTH];

// Outputs all the feature weights inside fullyconnected_weights_mem
// Has to output all of them at the same time due to the combinational nature of the FULLYCONNECTED layer
assign fullyconnected_weights_output = fullyconnected_weights_mem;

int start_index;

// Writing new weights to the weight memory only when fullyconnected_WrEn is low (active low) or on negedge of clk
always_ff @(negedge clk, negedge rst) begin
    // If reset is asserted, reset all the fullyconnected weights inside the memory to 0
    if (!rst) 
        fullyconnected_weights_mem <= '{default: '0};
    // Else if fullyconnected_WrEn is asserted, write new fullyconnected weights into memory
    else if (!fullyconnected_WrEn) begin
        // Check that address_w is valid or else don't write to memory
        if (address_w >= 0 && address_w < 27) begin // 27*16 = 432, highest address should be 26
            start_index = 16 * address_w;
            // Manual assignment since we can't synthesize a variable loop constant
            fullyconnected_weights_mem[start_index] <= fullyconnected_weights_input[0];
            fullyconnected_weights_mem[start_index+1] <= fullyconnected_weights_input[1];
            fullyconnected_weights_mem[start_index+2] <= fullyconnected_weights_input[2];
            fullyconnected_weights_mem[start_index+3] <= fullyconnected_weights_input[3];
            fullyconnected_weights_mem[start_index+4] <= fullyconnected_weights_input[4];
            fullyconnected_weights_mem[start_index+5] <= fullyconnected_weights_input[5];
            fullyconnected_weights_mem[start_index+6] <= fullyconnected_weights_input[6];
            fullyconnected_weights_mem[start_index+7] <= fullyconnected_weights_input[7];
            fullyconnected_weights_mem[start_index+8] <= fullyconnected_weights_input[8];
            fullyconnected_weights_mem[start_index+9] <= fullyconnected_weights_input[9];
            fullyconnected_weights_mem[start_index+10] <= fullyconnected_weights_input[10];
            fullyconnected_weights_mem[start_index+11] <= fullyconnected_weights_input[11];
            fullyconnected_weights_mem[start_index+12] <= fullyconnected_weights_input[12];
            fullyconnected_weights_mem[start_index+13] <= fullyconnected_weights_input[13];
            fullyconnected_weights_mem[start_index+14] <= fullyconnected_weights_input[14];
            fullyconnected_weights_mem[start_index+15] <= fullyconnected_weights_input[15];
        end
    end
end

endmodule