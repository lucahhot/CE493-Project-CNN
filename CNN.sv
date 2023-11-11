module CNN #(
    parameter IMAGE_WIDTH = 28,
    parameter IMAGE_HEIGHT = 28,
    parameter NUM_FEATURES = 10,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1
)(
    input logic image_input [IMAGE_WIDTH][IMAGE_HEIGHT], // 2D image input 
    input logic weights_input [KERNEL_SIZE*KERNEL_SIZE], // Weights for 1 feature
    input logic [$clog2(NUM_FEATURES):0] feature_writeAddr, // Address or feature number for which feature we want to write to
    input logic feature_WrEn, // Write enable for writing new weights into the feature_memory (active-low)
    input logic clk, // Main clock for the entire chip
    input logic rst_cnn, // Active-low reset signal to reset the convolution process
    input logic rst_weights // Active-low reset signal to reset all the feature weights to 0

    // NOT SURE WHAT OUTPUT WILL BE
    // Maybe the ReLU, pooling, and connecting of layers can be done internally or 
    // the chip could output all the outfmaps from the first and only convolution
);

// 3D array output of the first convolution layer (will end up with NUM_FEATURES x 2D arrays)
// Using 32 bit precision for each pixel (might have to change)
logic [31:0] outfmap1 [NUM_FEATURES][IMAGE_WIDTH][IMAGE_HEIGHT];

// 2D array to hold values of psums from each PE to feed them into the next PEs
logic [31:0] psum_values [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// This KERNEL_SIZE * KERNEL_SIZE array will hold the current infmap tile values to feed into the 
// PE array and will be updated every clock cycle to hold a new tile from the image input
logic infmap_tile [KERNEL_SIZE*KERNEL_SIZE];

// Register to hold current weights inside of weights
logic weights [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// Instatiation of feature weight memory block which will hold all our feature weights and will allow
// for writing new feature weights from outside the chip versus hard coding them all. The PEs will also 
// read the weights from this memory block.
FeatureMem #(KERNEL_SIZE, NUM_FEATURES) weights_mem(.address_w(feature_writeAddr),.feature_WrEn(feature_WrEn), .clk(clk),.rst(rst_weights),.weights_input(weights_input),.weights_output(weights));


// Variables to loop through the entire input image
int image_row, image_col;

// done signal that is asserted when the entire image has been looped through and stops the convolution
logic done;

always_ff @(negedge clk, negedge rst_cnn) begin
    // If rst_cnn is asserted, reset outfmap1 and psum_values to all 0.
    // Also reset all the variables used to loop through the input image to create the correct image tiles
    if(!rst_cnn) begin
        outfmap1 <= '{default: '0};
        psum_values <= '{default: '0};
        infmap_tile <= '{default: '0};
        image_row <= 0;
        image_col <= 0;
        done <= 0;
    end
    // Everything in this else block is combinational and non-blocking and should all happen in 1 clock cycle
    // This block is only executed if done == 0 as the image has not been looped through completely
    else if (!done) begin
        // Combinational process to update infmap_tile to feed into the PEs
        int tile_index;
        tile_index = 0;
        for (int tile_row = 0; tile_row < KERNEL_SIZE; tile_row = tile_row + 1) begin
            for (int tile_col = 0; tile_col < KERNEL_SIZE; tile_col = tile_col + 1) begin
                infmap_tile[tile_index] = image_input[image_row + tile_row][image_col + tile_col];
                // Increment tile_index for the next tile element (it will naturally stop at KERNEL_SIZE*KERNEL_SIZE
                // as the 2 for loops will only go until that value and stop)
                tile_index = tile_index + 1;
            end
        end
        // Combinational process to update the last psum value in the accumulation back into outfmap1 for all features
        for (int feature_index = 0; feature_index < NUM_FEATURES; feature_index = feature_index + 1) begin
            outfmap1[feature_index][image_row][image_col] = psum_values[feature_index][KERNEL_SIZE*KERNEL_SIZE - 1];
        end
        // Increment image_row and image_col by STRIDE for the next tile in the next cycle
        image_row = image_row + STRIDE;
        image_col = image_col + STRIDE;
        // If the next tile is out of bounds, then assert done and the convolution will stop
        if ((image_row + KERNEL_SIZE == IMAGE_HEIGHT) && (image_col + KERNEL_SIZE == IMAGE_WIDTH))
            done <= 1;
    end  
end    


// Generate PEs in a (KERNEL_SIZE * KERNEL_SIZE) x NUM_FEATURES 2D array
genvar pe_row, pe_col;
// Columns of the PE array are the features and rows are the inputs tile values (infmap values)
for (pe_col = 0; pe_col < NUM_FEATURES; pe_col = pe_col + 1) begin
    for (pe_row = 0; pe_row < (KERNEL_SIZE * KERNEL_SIZE); pe_row = pe_row + 1) begin

        // First row PE takes an inpsum of 0 as accumulation has not started yet
        if (pe_row == 0) 
            ConvolutionPE first_PE(.inpsum(0),
                                   .weight(weights[pe_col][pe_row]),
                                   .infmap_value(infmap_tile[pe_row]),
                                   .outpsum(psum_values[pe_col][pe_row]));

        // Other PEs take an inpsum from the previous PE's outpsum
        // The last PE will leave the accumulated psum in the last index of psum_values for the corresponding feature
        else
            ConvolutionPE middle_PE(.inpsum(psum_values[pe_col][pe_row - 1]),
                                    .weight(weights[pe_col][pe_row]),
                                    .infmap_value(infmap_tile[pe_row]),
                                    .outpsum(psum_values[pe_col][pe_row]));
    end
end

endmodule 






