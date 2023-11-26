`timescale 1ns/1ps

module FullyConnectedModule #(
    // These parameters MUST be overwritten in CNN
    parameter FLATTENED_LENGTH = 50,
    parameter CONVOLUTION_DATA_WIDTH = 8,
    parameter FULLYCONNECTED_DATA_WIDTH = 8,
    parameter OUTPUT_DATA_WIDTH = 32
)(
    input logic fullyconnect_start, // Start signal to start fully connecting
    input logic [CONVOLUTION_DATA_WIDTH-1:0] flattened_outfmap [FLATTENED_LENGTH],
    input logic [FULLYCONNECTED_DATA_WIDTH-1:0] fullyconnected_weights [FLATTENED_LENGTH],
    output logic [OUTPUT_DATA_WIDTH-1:0] fullyconnected_output_c
);

// Temp register to hold the current sum of fullyconnected_output_c
logic [OUTPUT_DATA_WIDTH-1:0] sum;

// Combinational module that calculates the final output from the flattened array and the fully
// connected layer weights
always_comb begin
    if (fullyconnect_start) begin
        sum = 0;
        // Loop through flattened_outfmap and multiply the values by the corresponding weight in fullyconnected_weights
        for (int fullyconnect_index = 0; fullyconnect_index < FLATTENED_LENGTH; fullyconnect_index = fullyconnect_index + 1) 
            sum = sum + flattened_outfmap[fullyconnect_index] * fullyconnected_weights[fullyconnect_index];
        fullyconnected_output_c <= sum;
    end
    else begin
        sum = 0;
        fullyconnected_output_c <= '{default: 'X};
    end
end

endmodule