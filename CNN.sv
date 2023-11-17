`timescale 1ns/1ps

module CNN #(
    parameter IMAGE_WIDTH = 12,
    parameter IMAGE_HEIGHT = 12,
    parameter NUM_FEATURES = 2,
    parameter KERNEL_SIZE = 3,
    parameter DATA_WIDTH = 8 // Determines the bit width precision we use in the design throughout
)(
    input logic signed [1:0] image_input [IMAGE_HEIGHT][IMAGE_WIDTH], // 2D image input 
    input logic signed [1:0] weights_input [KERNEL_SIZE*KERNEL_SIZE], // Weights for 1 feature
    input logic [$clog2(NUM_FEATURES):0] feature_writeAddr, // Address or feature number for which feature we want to write to
    input logic feature_WrEn, // Write enable for writing new weights into the feature_memory (active-low)
    input logic clk, // Main clock for the entire chip
    input logic rst_cnn, // Active-low reset signal to reset the convolution process
    input logic rst_weights, // Active-low reset signal to reset all the feature weights to 0
    input logic convolution_enable, // Active-low enable signal to start convolution (DOES NOT RESET CNN)

    // Dummy output for now for synthesis tool to calculate timing
    output logic [DATA_WIDTH-1:0] out [NUM_FEATURES][50]

);

// STRIDE length is assumed to be 1 so that we do not have any division in the RTL
parameter STRIDE = 1;
// POOLING_STRIDE is assumed to be 2 so we can left shift by 1 to represent a division by 2
parameter POOLING_STRIDE = 2;

// Parameters to hold the output dimensions for the convolution_outfmap post convolution
parameter CONVOLUTION_WIDTH = (IMAGE_WIDTH-KERNEL_SIZE)+1;
parameter CONVOLUTION_HEIGHT = (IMAGE_HEIGHT-KERNEL_SIZE)+1;
// Parameters to hold the output dimensions for the pooled_outfmap post pooling
parameter POOLED_WIDTH = CONVOLUTION_WIDTH >> 1;
parameter POOLED_HEIGHT = CONVOLUTION_HEIGHT >> 1;
// parameter to hold the outdimension for the flattened_outfmap post flattening
parameter FLATTENED_LENGTH = POOLED_WIDTH * POOLED_HEIGHT * NUM_FEATURES;

///////////////////////
// FEATURE VARIABLES //
///////////////////////

// Register to hold current weights inside of weights
logic signed [1:0] weights [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// Instatiation of feature weight memory block which will hold all our feature weights and will allow
// for writing new feature weights from outside the chip versus hard coding them all. The PEs will also 
// read the weights from this memory block.
FeatureMem #(KERNEL_SIZE, NUM_FEATURES) weights_mem(.address_w(feature_writeAddr),.feature_WrEn(feature_WrEn), .clk(clk),.rst(rst_weights),.weights_input(weights_input),.weights_output(weights));

///////////////////////////
// CONVOLUTION VARIABLES // 
///////////////////////////

// 3D array output of the first convolution layer (will end up with NUM_FEATURES x 2D arrays)
// (is unsigned since all the negative values should have been converted to 0)
logic [DATA_WIDTH-1:0] convolution_outfmap [NUM_FEATURES][CONVOLUTION_HEIGHT][CONVOLUTION_WIDTH];

// 2D array to hold values of psums from each PE to feed them into the next PEs
logic signed [DATA_WIDTH-1:0] psum_values [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// This KERNEL_SIZE * KERNEL_SIZE array will hold the current infmap tile values to feed into the 
// PE array and will be updated every clock cycle to hold a new tile from the image input
logic signed [1:0] infmap_tile [KERNEL_SIZE*KERNEL_SIZE];

// Variables to loop through the entire input image
int image_row, image_col;

///////////////////////
// POOLING VARIABLES //
///////////////////////

// 3D pooled_outfmap after max pooling (dimensions are changed with pooling)
logic [DATA_WIDTH-1:0] pooled_outfmap [NUM_FEATURES][(POOLED_HEIGHT)][(POOLED_WIDTH)];

// Creating the combinational version of the above register to be updated in the combinational always_comb statement
logic [DATA_WIDTH-1:0] pooled_outfmap_c [NUM_FEATURES][(POOLED_HEIGHT)][(POOLED_WIDTH)];

//////////////////////////
// FLATTENING VARIABLES //
//////////////////////////

// 2D flattened_outfmap after flattening layer 
logic [DATA_WIDTH-1:0] flattened_outfmap [NUM_FEATURES][FLATTENED_LENGTH];

// Combinational version of the above to be updated in the combinational always_comb statement
logic [DATA_WIDTH-1:0] flattened_outfmap_c [NUM_FEATURES][FLATTENED_LENGTH];

assign out = flattened_outfmap;

///////////////////
// FSM VARIABLES // 
///////////////////

// States for the FSM to go through the various stages of the CNN model
parameter IDLE = 0, CONVOLUTION = 1, POOLING = 2, FLATTENING = 3, DENSE = 4, OUTPUT = 5;
logic [2:0] state, next_state;

always_ff @(negedge clk, negedge rst_cnn) begin
    // If rst_cnn is asserted, reset convolution_outfmap and psum_values to all 0.
    // Also reset all the variables used to loop through the input image to create the correct image tiles
    if(!rst_cnn) begin
        convolution_outfmap <= '{default: '0};
        pooled_outfmap <= '{default: '0};
        flattened_outfmap <= '{default: '0};
        image_row <= 0;
        image_col <= 0;
        state <= IDLE;
    end
    // Block to update the clocked state to the next state that is determined combinationally
    else begin
        state <= next_state;
        pooled_outfmap <= pooled_outfmap_c;
        flattened_outfmap <= flattened_outfmap_c;
        // If FSM is in state CONVOLUTION
        if (state == CONVOLUTION) begin
            // Combinational process to update the last psum value in the accumulation back into convolution_outfmap for all features
            for (int feature_index = 0; feature_index < NUM_FEATURES; feature_index = feature_index + STRIDE) begin
                // If the resulting psum value is negative, then enter a 0 into the convolution_outfmap (ReLU or rectified linear unit)
                if (psum_values[feature_index][KERNEL_SIZE*KERNEL_SIZE - 1] < 0)
                    convolution_outfmap[feature_index][image_row][image_col] <= 0;
                else
                    convolution_outfmap[feature_index][image_row][image_col] <= psum_values[feature_index][KERNEL_SIZE*KERNEL_SIZE - 1];
            end
            // Increment image_col by STRIDE till the next tile is out of bounds, then increment image_row by STRIDE and set image_col back to 0
            if ((image_col + STRIDE) == CONVOLUTION_WIDTH) begin
                image_col <= 0;
                image_row <= image_row + STRIDE;
            end
            else
                image_col <= image_col + STRIDE;
            
        end
    end  
end    

always_comb begin

    // Default variable assignments
    next_state = state;
    infmap_tile = '{default: '0};
    pooled_outfmap_c = pooled_outfmap;
    flattened_outfmap_c = flattened_outfmap;

    // Checking through all the states
    case (state) 

        // FSM stays in IDLE state until convolution_enable is asserted (active-low) which moves to the CONVOLUTION state
        IDLE: begin
            if (!convolution_enable)
                next_state = CONVOLUTION;
        end

        // Updates infmap_tile to feed the next tile of image input into the PEs, continues until the tile is 
        // out of bounds and move to the POOLING state
        CONVOLUTION: begin
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
            // If the next image_row and image_col are past the bottom-right corner of our convolution_outfmap, it means that the convolution
            // has finished and the FSM should move to POOLING state
            if ((image_row + STRIDE) == CONVOLUTION_HEIGHT && (image_col + STRIDE) == CONVOLUTION_WIDTH)
                next_state = POOLING;
        end

        // Pooling state performs a max pool with the POOLING_STRIDE stride length 
        POOLING: begin
            int max,row,col;
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
                        pooled_outfmap_c[feature][row][col] = max;
                        col = col + 1;
                    end
                    row = row + 1;
                end
                next_state = FLATTENING;
            end
        end

        // Flattening state flattens all the pooled_outfmaps into a 1 dimensional array
        FLATTENING: begin
            int flattened_index;
            flattened_index = 0;
            // Loop through pooled_outfmap and place the values into flattened_outfmap_c
            for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
                for (int pooled_row = 0; pooled_row < POOLED_HEIGHT; pooled_row = pooled_row + 1) begin
                    for (int pooled_col = 0; pooled_col < POOLED_WIDTH; pooled_col = pooled_col + 1) begin
                        flattened_outfmap_c[feature][flattened_index] = pooled_outfmap[feature][pooled_row][pooled_col];
                        flattened_index = flattened_index + 1;
                    end
                end
            end
            next_state = DENSE;
        end

    endcase
            

end

// Generate PEs in a (KERNEL_SIZE * KERNEL_SIZE) x NUM_FEATURES 2D array
genvar pe_row, pe_col;
// Columns of the PE array are the features and rows are the inputs tile values (infmap values)
for (pe_col = 0; pe_col < NUM_FEATURES; pe_col = pe_col + 1) begin
    for (pe_row = 0; pe_row < (KERNEL_SIZE * KERNEL_SIZE); pe_row = pe_row + 1) begin

        // First row PE takes an inpsum of 0 as accumulation has not started yet
        if (pe_row == 0) 
            ConvolutionPE #(DATA_WIDTH) first_PE(.inpsum('{default: '0}),
                                   .weight(weights[pe_col][pe_row]),
                                   .infmap_value(infmap_tile[pe_row]),
                                   .outpsum(psum_values[pe_col][pe_row]));

        // Other PEs take an inpsum from the previous PE's outpsum
        // The last PE will leave the accumulated psum in the last index of psum_values for the corresponding feature
        else
            ConvolutionPE #(DATA_WIDTH) middle_PE(.inpsum(psum_values[pe_col][pe_row - 1]),
                                    .weight(weights[pe_col][pe_row]),
                                    .infmap_value(infmap_tile[pe_row]),
                                    .outpsum(psum_values[pe_col][pe_row]));
    end
end

endmodule 