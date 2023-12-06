`timescale 1ns/1ps

module FlatteningModule #(
    // These parameters MUST be overwritten in CNN
    parameter NUM_FEATURES = 3,
    parameter POOLED_HEIGHT = 12,
    parameter POOLED_WIDTH = 12,
    parameter FLATTENED_LENGTH = 432,
    parameter DATA_WIDTH = 8
)(
    input logic flatten_start, // Start signal to start flattening
    input logic signed [DATA_WIDTH-1:0] pooled_outfmap [NUM_FEATURES][POOLED_HEIGHT][POOLED_WIDTH],
    output logic signed [DATA_WIDTH-1:0] flattened_outfmap_c [FLATTENED_LENGTH]
);

// Combinational module that flattens the 2D pooled output from the pooling layer and outputs
// a 1D flattened array which will get clocked in CNN
always_comb begin
    if(flatten_start) begin
        int flattened_index;
        flattened_index = 0;
        // Loop through pooled_outfmap and place the values into flattened_outfmap_c
        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            for (int pooled_row = 0; pooled_row < POOLED_HEIGHT; pooled_row = pooled_row + 1) begin
                for (int pooled_col = 0; pooled_col < POOLED_WIDTH; pooled_col = pooled_col + 1) begin
                    flattened_outfmap_c[flattened_index] <= pooled_outfmap[feature][pooled_row][pooled_col];
                    flattened_index = flattened_index + 1;
                end
            end
        end
    end
    else
        flattened_outfmap_c <= '{default: 'X};
end

endmodule
        