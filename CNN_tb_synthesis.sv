`timescale 1ns/1ps

module CNN_tb_synthesis #(
    parameter IMAGE_WIDTH = 12,
    parameter IMAGE_HEIGHT = 12,
    parameter NUM_FEATURES = 2,
    parameter KERNEL_SIZE = 3,
    parameter DATA_WIDTH = 8
);

    logic signed [1:0] image [IMAGE_HEIGHT][IMAGE_WIDTH];
    logic signed [1:0] feature [KERNEL_SIZE*KERNEL_SIZE];
    logic [$clog2(NUM_FEATURES):0] feature_addr;
    logic feature_WrEn;
    logic clk;
    logic rst_cnn;
    logic rst_weights;
    logic enable;

    parameter IDLE = 0, CONVOLUTION = 1, POOLING = 2, FLATTENING = 3, DENSE = 4;
    parameter STRIDE = 1;
    parameter POOLING_STRIDE = 2;
    parameter CONVOLUTION_WIDTH = (IMAGE_WIDTH-KERNEL_SIZE)+1;
    parameter CONVOLUTION_HEIGHT = (IMAGE_HEIGHT-KERNEL_SIZE)+1;
    parameter POOLED_WIDTH = CONVOLUTION_WIDTH >> 1;
    parameter POOLED_HEIGHT = CONVOLUTION_HEIGHT >> 1;
    parameter FLATTENED_LENGTH = POOLED_WIDTH * POOLED_HEIGHT * NUM_FEATURES;

    logic [DATA_WIDTH-1:0] out;

    // Packed array of image_input to feed into synthesized netlist (for some reason it only accepts a packed array
    // since it's written in verilog which doesn't support unpacked array IO ports)
    logic signed [(2*IMAGE_HEIGHT*IMAGE_WIDTH)-1:0] packed_image;

    // Packed array of feature to feed into synthesized netlist 
    logic signed [(2*KERNEL_SIZE*KERNEL_SIZE)-1:0] packed_feature;

    // Files reading/writing variables
    int infile,convolution_outfile,pooled_outfile,flattened_outfile;

    // Calling functions to pack the unpacked arrays
    pack2d_module #(IMAGE_HEIGHT,IMAGE_WIDTH,2) u1 ();

    pack1d_module #(KERNEL_SIZE*KERNEL_SIZE,2) u2 ();

    // Instantiation of CNN for post-synthesized netlist (no parameters included)
    CNN CNN_dut(.image_input(packed_image),.weights_input(packed_feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),
                .clk(clk),.rst_cnn(rst_cnn),.rst_weights(rst_weights),.convolution_enable(enable),.out(out));


    // Clock with a period of 20ns
    always
        #10 clk = ~clk;

    initial begin

        $display($time,"ns: Starting testing...\n");

        clk = 1;

        // Reset the CNN
        enable = 1;
        feature_WrEn = 1;
        rst_cnn = 1;
        rst_weights = 1;
        #10
        rst_cnn = 0;
        rst_weights = 0;
        #10
        rst_cnn = 1;
        rst_weights = 1;

        $display($time,"ns: Finished reseting CNN, loading feature maps into feature memory...\n");

        // Write single feature map into feature memory
        feature_WrEn = 0;
        feature_addr = 0;
        // Feature is an "X" shape (flattened)
        feature = '{1, -1, 1, -1, 1, -1, 1, -1, 1};
        packed_feature = u2.pack1d(feature);
        // Wait 1 clock pulse for feature map to loaded into memory
        @(negedge clk);
        @(negedge clk);
        // Write second feature map into feature memory
        feature_addr = 1;
        feature = '{1,1,1,1,1,1,1,1,1};
        packed_feature = u2.pack1d(feature);
        @(negedge clk);
        @(negedge clk);
        feature_WrEn = 1;

        $display($time,"ns: Reading 2D input image from input text file...\n");

        // Reading in 2D image from a text file
        infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/image_input.txt","r");
        if (infile)  $display("File was opened successfully : %0d\n", infile);
        else         $display("File was NOT opened successfully : %0d\n", infile);

        for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                void'($fscanf(infile,"%d",image[i][j]));
            end
        end
        $fclose(infile);

        packed_image = u1.pack2d(image);

        #10

        $display($time,"ns: Starting convolution...\n");

        // Start convolution
        enable = 0; 
        @(posedge clk);
        enable = 1;

        // Wait until state == POOLING to check convolution output
        wait(CNN_dut.state == DENSE);

        #20

        $display($time,"ns: Finished testing...\n");
        
        $finish;
    end


endmodule


// Module/function to pack a 2D unpacked array into a 1D packed array
module pack2d_module #(parameter HEIGHT = 10, parameter WIDTH = 10, parameter BIT_WIDTH = 2)();

    function bit[(BIT_WIDTH*WIDTH*HEIGHT)-1:0] pack2d;
        input signed [BIT_WIDTH-1:0] unpacked [HEIGHT][WIDTH];

        bit [(BIT_WIDTH*WIDTH*HEIGHT)-1:0] out;
        int index;
        index = (BIT_WIDTH*WIDTH*HEIGHT)-1;
        for (int row = 0; row < HEIGHT; row = row + 1) begin
            for (int col = 0; col < WIDTH; col = col + 1) begin
                for (int i = index; i > (index - BIT_WIDTH); i = i - 1) begin
                    out[i] = unpacked[row][col][i-(index-BIT_WIDTH)-1];
                end
                index = index - BIT_WIDTH;
            end
        end
        return out;
    endfunction

endmodule

// Module/function to pack a 1D unpacked array into a 1D packed array
module pack1d_module #(parameter LENGTH = 10, parameter BIT_WIDTH = 2)();

    function bit[(BIT_WIDTH*LENGTH)-1:0] pack1d;
        input signed [BIT_WIDTH-1:0] unpacked [LENGTH];

        bit [(BIT_WIDTH*LENGTH)-1:0] out;
        int index;
        index = (BIT_WIDTH*LENGTH)-1;
        for (int row = 0; row < LENGTH; row = row + 1) begin
            for (int i = index; i > (index - BIT_WIDTH); i = i - 1) begin
                out[i] = unpacked[row][i-(index-BIT_WIDTH)-1];
            end
            index = index - BIT_WIDTH;
        end
        return out;
    endfunction

endmodule




