`timescale 1ns/1ps

module PoolingModule #(
    // These parameters MUST be overwritten in CNN
    parameter NUM_FEATURES = 10,
    parameter POOLING_STRIDE = 2,
    parameter POOLED_HEIGHT = 10,
    parameter POOLED_WIDTH = 10,
    parameter CONVOLUTION_HEIGHT = 10,
    parameter CONVOLUTION_WIDTH = 10,
    parameter CONVOLUTION_DATA_WIDTH = 8
)(
    input logic pool_start, // Start signal to start pooling
    input logic [CONVOLUTION_DATA_WIDTH-1:0] convolution_outfmap [NUM_FEATURES][CONVOLUTION_HEIGHT][CONVOLUTION_WIDTH],
    output logic [CONVOLUTION_DATA_WIDTH-1:0] pooled_outfmap_c [NUM_FEATURES][(POOLED_HEIGHT)][(POOLED_WIDTH)]
);

// Temp register to hold the current max of pooling tile
logic [CONVOLUTION_DATA_WIDTH-1:0] max;

// Combinational module that applies max pooling to the convolution_outfmap from the convolution layer,
// and outputs to pooled_outfmap_c which will get clocked in CNN
always_comb begin
    if (pool_start) begin
        int row,col;
        // Loop through the all the features in convolution_outfmap in POOLING_STRIDE x POOLING_STRIDE tiles and place the 
        // maximum value into the corresponding position in pooled_outfmap_c
        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            row = 0; 
            for (int convolution_row = 0; convolution_row < CONVOLUTION_HEIGHT; convolution_row = convolution_row + POOLING_STRIDE) begin
                col = 0;
                for (int convolution_col = 0; convolution_col < CONVOLUTION_WIDTH; convolution_col = convolution_col + POOLING_STRIDE) begin
                    max = 0;
                    // Secondary nested for loop for each individual pooling tile
                    for (int pooling_row = 0; pooling_row < POOLING_STRIDE; pooling_row = pooling_row + 1) begin
                        for (int pooling_col = 0; pooling_col < POOLING_STRIDE; pooling_col = pooling_col + 1) begin
                            // Check if current element position is inside of convolution_outfmap bounds
                            if ((pooling_row + convolution_row) < CONVOLUTION_HEIGHT && (pooling_col + convolution_col) < CONVOLUTION_WIDTH) begin
                                // Check if current position value is greater than current max
                                if (convolution_outfmap[feature][pooling_row + convolution_row][pooling_col + convolution_col] > max)
                                    max = convolution_outfmap[feature][pooling_row + convolution_row][pooling_col + convolution_col];
                            end
                        end
                    end
                    // Put our max position into pooled_outfmap
                    pooled_outfmap_c[feature][row][col] <= max;
                    col = col + 1;
                end
                row = row + 1;
            end
        end
    end 
    else
        pooled_outfmap_c <= '{default: 'X};
end

endmodule