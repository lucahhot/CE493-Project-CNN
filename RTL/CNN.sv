`timescale 1ns/1ps

module CNN #(
    parameter IMAGE_WIDTH = 28,
    parameter IMAGE_HEIGHT = 28,
    parameter NUM_FEATURES = 3,
    parameter KERNEL_SIZE = 4,
    parameter CONVOLUTION_WIDTH =25, // = (IMAGE_WIDTH-KERNEL_SIZE)/STRIDE+1
    parameter CONVOLUTION_HEIGHT = 25, // = (IMAGE_HEIGHT-KERNEL_SIZE)/STRIDE+1
    parameter POOLED_WIDTH = 12, // = CONVOLUTION_WIDTH >> 1
    parameter POOLED_HEIGHT = 12, // = CONVOLUTION_HEIGHT >> 1
    parameter FLATTENED_LENGTH = 432, // = POOLED_WIDTH * POOLED_HEIGHT * NUM_FEATURES;
    parameter DATA_WIDTH = 8, // Everything inside the CNN should be 8 bits wide
    parameter PSUM_DATA_WIDTH = 12, // Need extra bits to add all the psums
    parameter FULLYCONNECTED_DATA_WIDTH = 32 // Bit width for the fully connected layer in case but final output will be 8 bits

)(
    input logic image_input [IMAGE_HEIGHT][IMAGE_WIDTH], // 2D image input (binary)

    input logic signed [DATA_WIDTH-1:0] feature_weights_input [KERNEL_SIZE*KERNEL_SIZE], // Weights for 1 feature
    input logic [1:0] feature_writeAddr, // Address or feature number for which feature we want to write to
    input logic feature_WrEn, // Write enable for writing new weights into the feature memory (active-low)
    input logic rst_feature_weights, // Active-low reset signal to reset all the feature weights to 0

    // Weights for the fully connected layer (load in sets of 16 to prevent having too many input pins)
    // This will lead to 432/16 = 27 cycles to load in all the fully connected weights
    input logic signed [DATA_WIDTH-1:0] fullyconnected_weights_input [16], 
    input logic [4:0] fullyconnected_writeAddr, // Address to load fully connected bits in chunks of 16 weights 
    input logic fullyconnected_WrEn, // Write enable for writing new weights into the fullyconnected memory (active-low)
    input logic rst_fullyconnected_weights, // Active-low reset signal to reset all the fullyconnected weights to 0

    input logic clk, // Main clock for the entire chip
    input logic rst_cnn, // Active-low reset signal to reset the convolution process
    input logic convolution_enable, // Active-low enable signal to start convolution (DOES NOT RESET CNN)

    input logic signed [DATA_WIDTH-1:0] bias_weights_input [NUM_FEATURES+1], // NUM_FEATURES + 1 biases to include 1 per feature and 1 for the fully connected weights
    input logic bias_WrEn,
    input logic rst_bias_weights,

    // Dummy output for now for synthesis tool to calculate timing (the first value of the first feature's flattened output)
    output logic [DATA_WIDTH-1:0] cnn_output

);

// STRIDE length is assumed to be 1 so that we do not have any division in the RTL
parameter STRIDE = 1;
// POOLING_STRIDE is assumed to be 2 so we can left shift by 1 to represent a division by 2
parameter POOLING_STRIDE = 2;

///////////////////////
// FEATURE VARIABLES //
///////////////////////

// Register to hold current feature weights inside 
logic signed [DATA_WIDTH-1:0] feature_weights [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// Instatiation of feature weight memory block which will hold all our feature weights and will allow
// for writing new feature weights from outside the chip versus hard coding them all. The PEs will also 
// read the weights from this memory block.
FeatureMem #(KERNEL_SIZE, NUM_FEATURES, DATA_WIDTH) feature_weights_mem(.address_w(feature_writeAddr),.feature_WrEn(feature_WrEn), 
.clk(clk),.rst(rst_feature_weights),.feature_weights_input(feature_weights_input),.feature_weights_output(feature_weights));

// Register to hold current biases inside
logic signed [DATA_WIDTH-1:0] bias_weights [NUM_FEATURES+1];

// Instantiation of bias weight memory block which will hold all the biases to be used in the convolution and fully connected layer
BiasMem #(NUM_FEATURES, DATA_WIDTH) bias_weights_mem(.bias_WrEn(bias_WrEn),.clk(clk),.rst(rst_bias_weights),.bias_weights_input(bias_weights_input),
.bias_weights_output(bias_weights));

///////////////////////////
// CONVOLUTION VARIABLES // 
///////////////////////////

// 3D array output of the first convolution layer (will end up with NUM_FEATURES x 2D arrays)
// (is unsigned since all the negative values should have been converted to 0)
logic [DATA_WIDTH-1:0] convolution_outfmap [NUM_FEATURES][CONVOLUTION_HEIGHT][CONVOLUTION_WIDTH];

// 2D array to hold values of psums from each PE to feed them into the next PEs
logic signed [PSUM_DATA_WIDTH-1:0] psum_values [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// This KERNEL_SIZE * KERNEL_SIZE array will hold the current infmap tile values to feed into the 
// PE array and will be updated every clock cycle to hold a new tile from the image input
logic infmap_tile [KERNEL_SIZE*KERNEL_SIZE];

// Variables to loop through the entire input image
int image_row, image_col;

///////////////////////
// POOLING VARIABLES //
///////////////////////

// 3D pooled_outfmap after max pooling (dimensions are changed with pooling)
logic [DATA_WIDTH-1:0] pooled_outfmap [NUM_FEATURES][(POOLED_HEIGHT)][(POOLED_WIDTH)];

// Creating the combinational version of the above register to be updated in the combinational always_comb statement
logic [DATA_WIDTH-1:0] pooled_outfmap_c [NUM_FEATURES][(POOLED_HEIGHT)][(POOLED_WIDTH)];

// Start signal to start pooling during stage POOLING
logic pool_start;

// Instantiation of PoolingModule block which performs pooling when start signal pool_start is asserted high
PoolingModule #(NUM_FEATURES,POOLING_STRIDE,POOLED_HEIGHT,POOLED_WIDTH,CONVOLUTION_HEIGHT,CONVOLUTION_WIDTH,DATA_WIDTH) 
pooling_block(.pool_start(pool_start),.convolution_outfmap(convolution_outfmap),.pooled_outfmap_c(pooled_outfmap_c));

//////////////////////////
// FLATTENING VARIABLES //
//////////////////////////

// 1D flattened_outfmap after flattening layer 
logic [DATA_WIDTH-1:0] flattened_outfmap [FLATTENED_LENGTH];

// Combinational version of the above to be updated in the combinational always_comb statement
logic [DATA_WIDTH-1:0] flattened_outfmap_c [FLATTENED_LENGTH];

// Start signal to start flattening during stage FLATTENING
logic flatten_start;

// Instantiation of FlatteningModule block which performs flattening when start signal flatten_start is asserted high
FlatteningModule #(NUM_FEATURES,POOLED_HEIGHT,POOLED_WIDTH,FLATTENED_LENGTH,DATA_WIDTH)
flattening_block(.flatten_start(flatten_start),.pooled_outfmap(pooled_outfmap),.flattened_outfmap_c(flattened_outfmap_c));

//////////////////////////////
// FULLYCONNECTED VARIABLES //
//////////////////////////////

// Register to hold current fullyconnected weights 
logic signed [DATA_WIDTH - 1:0] fullyconnected_weights [FLATTENED_LENGTH];

// Instatiation of fullyconnected weights memory block to hold fullyconnected weights for the FULLYCONNECTED layer 
// to use when determining a final output
FullyConnectedMem #(FLATTENED_LENGTH,DATA_WIDTH) fullyconnected_weights_mem(.fullyconnected_WrEn(fullyconnected_WrEn),.clk(clk),
.rst(rst_fullyconnected_weights),.address_w(fullyconnected_writeAddr),.fullyconnected_weights_input(fullyconnected_weights_input),.fullyconnected_weights_output(fullyconnected_weights));

// Scalar value after fullyconnected layer that's clocked and is the CNN output
logic [DATA_WIDTH-1:0] fullyconected_output;

// Combinational value of fullyconnected output
logic [DATA_WIDTH-1:0] fullyconnected_output_c;

// Start signal to start fullyconnected layer during stage FULLYCONNECTED
logic fullyconnect_start;

// Instantiation of FullyConnectedModule block which performs the fullyconnected layer when start signal fullyconnect_start is asserted high
FullyConnectedModule #(FLATTENED_LENGTH,DATA_WIDTH,FULLYCONNECTED_DATA_WIDTH)
fullyconnected_block(.fullyconnect_start(fullyconnect_start),.flattened_outfmap(flattened_outfmap),.fullyconnected_weights(fullyconnected_weights),.bias(bias_weights[NUM_FEATURES]),.fullyconnected_output_c(fullyconnected_output_c));

///////////////////
// FSM VARIABLES // 
///////////////////

// States for the FSM to go through the various stages of the CNN model
parameter IDLE = 0, CONVOLUTION = 1, POOLING = 2, FLATTENING = 3, FULLYCONNECTED = 4, OUTPUT = 5;
logic [2:0] state, next_state;

always_ff @(negedge clk, negedge rst_cnn) begin
    // If rst_cnn is asserted, reset convolution_outfmap and psum_values to all 0.
    // Also reset all the variables used to loop through the input image to create the correct image tiles
    if(!rst_cnn) begin
        convolution_outfmap <= '{default: 'X};
        pooled_outfmap <= '{default: 'X};
        flattened_outfmap <= '{default: 'X};
        fullyconected_output <= '{default: 'X};
        image_row <= 0;
        image_col <= 0;
        state <= IDLE;
    end
    // Block to update the clocked state to the next state that is determined combinationally
    else begin
        state <= next_state;
        pooled_outfmap <= pooled_outfmap_c;
        flattened_outfmap <= flattened_outfmap_c;
        fullyconected_output <= fullyconnected_output_c;
        // If FSM is in state CONVOLUTION
        if (state == CONVOLUTION) begin
            // Combinational process to update the last psum value in the accumulation back into convolution_outfmap for all features
            for (int feature_index = 0; feature_index < NUM_FEATURES; feature_index = feature_index + STRIDE) begin
                // If the resulting psum value is negative, then enter a 0 into the convolution_outfmap (ReLU or rectified linear unit)
                if (psum_values[feature_index][KERNEL_SIZE*KERNEL_SIZE - 1] < 0)
                    convolution_outfmap[feature_index][image_row][image_col] <= 0;
                else
                    // [QUESTION]: In non-quantized convolution, we divide by KERNEL_SIZE * KERNEL_SIZE, not sure if we do it here
                    // SRA by 4 bits is dividing by 16
                    convolution_outfmap[feature_index][image_row][image_col] <= (psum_values[feature_index][KERNEL_SIZE*KERNEL_SIZE - 1] >>> 4) ;
            end
            // Increment image_col by STRIDE till the next tile is out of bounds, then increment image_row by STRIDE and set image_col back to 0
            if ((image_col + STRIDE) == CONVOLUTION_WIDTH) begin
                image_col <= 0;
                image_row <= image_row + STRIDE;
            end
            else
                image_col <= image_col + STRIDE;
            
        end
        // If FSM is in state OUTPUT, output CNN output to fullyconnected_output
        if (state == OUTPUT) 
            cnn_output <= fullyconected_output;
    end  
end    

always_comb begin

    // Default variable assignments
    next_state = state;
    infmap_tile = '{default: '0};
    // pooled_outfmap_c = pooled_outfmap;
    // flattened_outfmap_c = flattened_outfmap;
    // fullyconnected_output_c = fullyconected_output;
    pool_start = 0;
    flatten_start = 0;
    fullyconnect_start = 0;

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
            // Start signal to start pooling inside of pooling_block
            pool_start = 1;
            next_state = FLATTENING;
        end

        // Flattening state flattens all the pooled_outfmaps into a 1 dimensional array
        FLATTENING: begin
            // Start signal to start flattening inside of flattening_block
            flatten_start = 1;
            next_state = FULLYCONNECTED;
        end

        // Fully connected layer (with no hidden layers) applies a generated set of weights to each 
        // value in the flattened values to generate 1 single output value for the CNN
        FULLYCONNECTED: begin
            // Start signal so start the fully connected layer
            fullyconnect_start = 1;
            next_state = OUTPUT;
        end

        // During this state, the clocked always block will update CNN output to fullyconnected_output
        OUTPUT: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;

    endcase
            

end

// Generate PEs in a (KERNEL_SIZE * KERNEL_SIZE) x NUM_FEATURES 2D array
genvar pe_row, pe_col;
// Columns of the PE array are the features and rows are the inputs tile values (infmap values)
for (pe_col = 0; pe_col < NUM_FEATURES; pe_col = pe_col + 1) begin
    for (pe_row = 0; pe_row < (KERNEL_SIZE * KERNEL_SIZE); pe_row = pe_row + 1) begin

        // First row PE takes an inpsum of 0 as accumulation has not started yet
        if (pe_row == 0) 
            ConvolutionPE #(DATA_WIDTH,PSUM_DATA_WIDTH) first_PE(.inpsum('{default: '0}),
                                   .weight(feature_weights[pe_col][pe_row]),
                                   .bias(bias_weights[pe_col]),
                                   .infmap_value(infmap_tile[pe_row]),
                                   .outpsum(psum_values[pe_col][pe_row]));

        // Other PEs take an inpsum from the previous PE's outpsum
        // The last PE will leave the accumulated psum in the last index of psum_values for the corresponding feature
        else
            ConvolutionPE #(DATA_WIDTH,PSUM_DATA_WIDTH) middle_PE(.inpsum(psum_values[pe_col][pe_row - 1]),
                                    .weight(feature_weights[pe_col][pe_row]),
                                    .bias(bias_weights[pe_col]),
                                    .infmap_value(infmap_tile[pe_row]),
                                    .outpsum(psum_values[pe_col][pe_row]));
    end
end

endmodule 