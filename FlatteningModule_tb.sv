`timescale 1ns/1ps

module FlatteningModule_tb;

    // Parameters
    parameter NUM_FEATURES = 10;
    parameter POOLED_HEIGHT = 10;
    parameter POOLED_WIDTH = 10;
    parameter FLATTENED_LENGTH = NUM_FEATURES * POOLED_HEIGHT * POOLED_WIDTH;
    parameter CONVOLUTION_DATA_WIDTH = 8;

    // Signals
    logic flatten_start;
    logic [CONVOLUTION_DATA_WIDTH-1:0] pooled_outfmap [NUM_FEATURES][POOLED_HEIGHT][POOLED_WIDTH];
    logic [CONVOLUTION_DATA_WIDTH-1:0] flattened_outfmap_c [FLATTENED_LENGTH];

    // Instantiate
    FlatteningModule #(
        .NUM_FEATURES(NUM_FEATURES),
        .POOLED_HEIGHT(POOLED_HEIGHT),
        .POOLED_WIDTH(POOLED_WIDTH),
        .FLATTENED_LENGTH(FLATTENED_LENGTH),
        .CONVOLUTION_DATA_WIDTH(CONVOLUTION_DATA_WIDTH)
    ) 
    FlatteningModule_dut (
        .flatten_start(flatten_start),
        .pooled_outfmap(pooled_outfmap),
        .flattened_outfmap_c(flattened_outfmap_c)
    );

    initial begin
        flatten_start = 1;

        // Generate test data for pooled_outfmap
        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            for (int row = 0; row < POOLED_HEIGHT; row = row + 1) begin
                for (int col = 0; col < POOLED_WIDTH; col = col + 1) begin
                    pooled_outfmap[feature][row][col] = feature * POOLED_HEIGHT * POOLED_WIDTH + row * POOLED_WIDTH + col;
                end
            end
        end

        #10 flatten_start = 0;

        #50;
        $finish;
    end


    initial begin
        // Display the output flattened_outfmap_c
        $display("Flattened Output:");
        for (int i = 0; i < FLATTENED_LENGTH; i = i + 1) begin
            $display("flattened_outfmap_c[%0d] = %0d", i, flattened_outfmap_c[i]);
        end
    end

endmodule
