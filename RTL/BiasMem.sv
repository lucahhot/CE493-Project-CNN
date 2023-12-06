`timescale 1ns/1ps

module BiasMem #(
    // MUST be overwritten in CNN
    parameter NUM_FEATURES = 3,
    parameter DATA_WIDTH = 32
)(
    input logic bias_WrEn, // Write enable (active-low)
    input logic clk,
    input logic rst,
    input logic signed [DATA_WIDTH-1:0] bias_weights_input [NUM_FEATURES+1], // Weight input
    output logic signed [DATA_WIDTH-1:0] bias_weights_output [NUM_FEATURES+1] // Weight output
);

logic signed [DATA_WIDTH - 1:0] bias_weights_mem [NUM_FEATURES+1];

assign bias_weights_output = bias_weights_mem;

always_ff @(negedge clk, negedge rst) begin

    if (!rst) 
        bias_weights_mem <= '{default: '0};
    else if (!bias_WrEn) begin
        bias_weights_mem <= bias_weights_input;
    end
end

endmodule