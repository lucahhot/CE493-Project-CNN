module CNN #(
    parameter IMAGE_WIDTH = 28,
    parameter IMAGE_HEIGHT = 28,
    parameter NUM_FEATURES = 10,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1
)(
    input logic image_input [IMAGE_WIDTH][IMAGE_HEIGHT], // 2D image input 
    input logic weights [KERNEL_SIZE*KERNEL_SIZE], // weights for 1 feature
    input logic [$clog2(feature_number)] feature_address, // address or feature number for which feature we want to load in
    input logic feature_WrEn // write enable for feature writing

    // NOT SURE WHAT OUTPUT WILL BE
    // This will be determined by how challenging it is to pass outfmaps back into the PE array
    // as new infmaps and go through several layers
);

// 3D array output of the first convolution layer (will end up with NUM_FEATURES 2D arrays)
// Using 32 bit precision for each pixel (might have to change)
logic [31:0] outfmap1 [NUM_FEATURES][IMAGE_WIDTH][IMAGE_HEIGHT];

// 2D array to hold values of psums from each PE to feed them into the next PEs
logic [31:0] psum_values [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];

// This KERNEL_SIZE * KERNEL_SIZE array will hold the current infmap tile values to feed into the 
// PE array and will be updated every clock cycle to hold a new tile from the image input
logic infmap_tile [KERNEL_SIZE*KERNEL_SIZE];

// Generate PEs in a (KERNEL_SIZE * KERNEL_SIZE) x NUM_FEATURES 2D array
genvar row, col;
for (col = 0; col < NUM_FEATURES; col = col + 1) begin
    for (row = 0; row < (KERNEL_SIZE * KERNEL_SIZE); row = row + 1) begin

        // First row PE takes an inpsum of 0 as accumulation has not started yet
        if (row == 0) 
            ConvolutionPE first_PE(.inpsum(0),
                                   .weight(feature_weights[row][col]),
                                   .infmap_value(infmap_tile[row]),
                                   .outpsum(psum_values[row][col]));

        // Other PEs take an inpsum from the previous PE's outpsum
        // The last PE will leave the accumulated psum in the last index of psum_values for the corresponding feature
        else
            ConvolutionPE middle_PE(.inpsum(psum_values[row - 1][col]),
                                    .weight(feature_weights[row][col]),
                                    .infmap_value(infmap_tile[row]),
                                    .outpsum(psum_values[row][col]));

    end
end

endmodule 

module feature_mem #(
    parameter KERNEL_SIZE = 3,
    parameter NUM_FEATURES = 10
)(
    input logic [$clog2(NUM_FEATURES):0] address_w,
    input logic [$clog2(NUM_FEATURES):0] address_r,
    input logic feature_WrEn,
    output logic feature_weights [KERNEL_SIZE*KERNEL_SIZE]
);

// Memory for weights stored in a 2D array:
// Each feature will have it's own KERNEL_SIZE * KERNELS_SIZE array of weight value
// For example, if the feature has a 3x3 feature map, the array will be a 1 dimensional
// 9 element flattened array of the weights. 
logic weights [NUM_FEATURES][KERNEL_SIZE*KERNEL_SIZE];
logic unknown_output [KERNEL_SIZE*KERNEL_SIZE];

// Assigning a default array to unknown in case of faulty read address
assign unknown_output = '{default: 'x};

always @ * begin
    // Checks if read address is valid or not
    feature_weights = (address_r >= 0 && address_r < NUM_FEATURES) ? weights[address_r] : unknown_output;
end






