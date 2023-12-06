`timescale 1ns/1ps

module ConvolutionPE #(
    parameter DATA_WIDTH = 8,
    parameter PSUM_DATA_WIDTH = 12,
    parameter BIAS_DATA_WIDTH = 32
)(
    input logic signed [PSUM_DATA_WIDTH-1:0] inpsum,
    input logic signed [DATA_WIDTH-1:0] weight,
    input logic signed [BIAS_DATA_WIDTH-1:0] bias,
    input logic infmap_value,
    output logic signed [PSUM_DATA_WIDTH-1:0] outpsum
);

// The PE is a simple MAC operation

// To hold multiply operand as we'll check if infmap_value == 0 or not
logic signed [1:0] multiply_operand;

always_comb begin
    if (infmap_value)
        multiply_operand = 1;
    else
        multiply_operand = -1;
    outpsum = inpsum + (weight * multiply_operand + bias);
end

endmodule