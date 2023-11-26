`timescale 1ns/1ps

module ConvolutionPE #(
    parameter CONVOLUTION_DATA_WIDTH = 8
)(
    input logic signed [CONVOLUTION_DATA_WIDTH-1:0] inpsum,
    input logic signed [1:0] weight,
    input logic signed [1:0] infmap_value,
    output logic signed [CONVOLUTION_DATA_WIDTH-1:0] outpsum
);

// The PE is a simple MAC operation

always_comb begin
    outpsum = inpsum + (weight * infmap_value);
end

endmodule