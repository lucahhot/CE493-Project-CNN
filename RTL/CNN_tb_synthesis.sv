`timescale 1ns/1ps

module CNN_tb_synthesis #(
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
    parameter FULLYCONNECTED_DATA_WIDTH = 32
);

    logic image [IMAGE_HEIGHT][IMAGE_WIDTH];

    logic signed [DATA_WIDTH-1:0] feature [KERNEL_SIZE*KERNEL_SIZE];
    logic [1:0] feature_addr;
    logic feature_WrEn;
    logic rst_feature_weights;

    logic signed [DATA_WIDTH-1:0] biases [NUM_FEATURES+1];
    logic bias_WrEn;
    logic rst_bias_weights;

    logic signed [DATA_WIDTH-1:0] fullyconnected_weights_input [16];
    logic [4:0] fullyconnected_writeAddr;
    logic fullyconnected_WrEn;
    logic rst_fullyconnected_weights;

    logic clk;
    logic rst_cnn;
    logic enable;

    logic [DATA_WIDTH-1:0] cnn_output;

    parameter IDLE = 0, CONVOLUTION = 1, POOLING = 2, FLATTENING = 3, FULLYCONNECTED = 4, OUTPUT = 5;

    // Packed array of image_input to feed into synthesized netlist (for some reason it only accepts a packed array
    // since it's written in verilog which doesn't support unpacked array IO ports)
    logic signed [(IMAGE_HEIGHT*IMAGE_WIDTH)-1:0] packed_image;

    // Packed array of feature to feed into synthesized netlist 
    logic signed [(DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] packed_feature;

    // Packed array of fully connected weights to feed into synthesized netlist
    logic signed [(DATA_WIDTH*FLATTENED_LENGTH)-1:0] packed_fullyconnected_weights;

    // Packed array of bias weights to feed into synthesized netlist
    logic signed [(DATA_WIDTH*(NUM_FEATURES+1))-1:0] packed_bias_weights;

    // Calling functions to pack the unpacked arrays
    pack2d_module #(IMAGE_HEIGHT,IMAGE_WIDTH,1) u1 ();

    pack1d_module #(KERNEL_SIZE*KERNEL_SIZE,DATA_WIDTH) u2 ();

    pack1d_module #(16,DATA_WIDTH) u3 ();

    pack1d_module #((NUM_FEATURES+1),DATA_WIDTH) u4 ();

    // Files reading/writing variables
    int infile,convolution_outfile,pooled_outfile,flattened_outfile,fullyconnected_infile,cnn_outfile;

    // Instantiating an instance of CNN
    CNN CNN_dut(.image_input(packed_image),.feature_weights_input(packed_feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),.rst_feature_weights(rst_feature_weights),.bias_weights_input(packed_bias_weights),.bias_WrEn(bias_WrEn),.rst_bias_weights(rst_bias_weights),
                .fullyconnected_weights_input(packed_fullyconnected_weights),.fullyconnected_writeAddr(fullyconnected_writeAddr),.fullyconnected_WrEn(fullyconnected_WrEn),.rst_fullyconnected_weights(rst_fullyconnected_weights),.clk(clk),.rst_cnn(rst_cnn),.convolution_enable(enable),.cnn_output(cnn_output));


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
        rst_feature_weights = 1;
        rst_bias_weights = 1;
        rst_fullyconnected_weights = 1;
        #10
        rst_cnn = 0;
        rst_feature_weights = 0;
        rst_bias_weights = 0;
        rst_fullyconnected_weights = 0;
        #10
        rst_cnn = 1;
        rst_feature_weights = 1;
        rst_bias_weights = 1;
        rst_fullyconnected_weights = 1;

        $display($time,"ns: Finished reseting CNN, loading feature maps into feature memory...\n");

        // Write single feature map into feature memory
        feature_WrEn = 0;
        feature_addr = 0;
        // Feature is an "X" shape (flattened)
        // feature = '{127,-127,127,-127,-127,127,-127,-127,127,-127,127,-127,-127,-127,-127,-127};
        // Feature #1 for quantized model (12/04/23)
        feature = '{-53,43,-53,-83,-10,11,-26,72,-2,75,55,-36,-24,62,39,26};
        packed_feature = u2.pack1d(feature);
        // Wait 1 clock pulse for feature map to loaded into memory
        @(negedge clk);
        @(negedge clk);
        // Write second feature map into feature memory
        feature_addr = 1;
        // feature = '{127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127};
        // Feature #2 for quantized model (12/04/23)
        feature = '{-35,-17,49,-37,-93,49,88,-40,-39,15,-3,22,74,76,-59,21};
        packed_feature = u2.pack1d(feature);
        @(negedge clk);
        @(negedge clk);
        // Write third feature map into feature memory
        feature_addr = 2;
        // feature = '{-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127,-127};
        // Feature #3 for quantized model (12/04/23)
        feature = '{31,2,-47,69,64,16,-4,-83,42,40,66,-50,3,-59,69,18};
        packed_feature = u2.pack1d(feature);
        @(negedge clk);
        @(negedge clk);
        feature_WrEn = 1;

        // Write biases into bias memory
        bias_WrEn = 0;
        // Biases for quantized model (12/04/23)
        biases = '{10,0,0,-8};
        packed_bias_weights = u4.pack1d(biases);
        @(negedge clk);
        @(negedge clk);
        bias_WrEn = 1;

        $display($time,"ns: Finished loading feature maps, loading fully connected weights into fully connected memory...\n");

        fullyconnected_WrEn = 0;
        // Reading in fullyconnected weights from a text file
        fullyconnected_infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/fullyconnected_input.txt","r");
        if (fullyconnected_infile)  $display("File was opened successfully : %0d\n", fullyconnected_infile);
        else         $display("File was NOT opened successfully : %0d\n", fullyconnected_infile);

        fullyconnected_writeAddr = 0;
        
        for(int fullyconnected_index = 0; fullyconnected_index < FLATTENED_LENGTH; fullyconnected_index = fullyconnected_index + 16) begin
            for(int i = 0; i < 16; i = i + 1) begin
                void'($fscanf(fullyconnected_infile,"%d",fullyconnected_weights_input[i]));
            end
            packed_fullyconnected_weights = u3.pack1d(fullyconnected_weights_input);
            @(negedge clk);
            @(negedge clk);
            fullyconnected_writeAddr = fullyconnected_writeAddr + 1;
        end
        $fclose(fullyconnected_infile);

        fullyconnected_WrEn = 1;

        $display($time,"ns: Reading 2D input image from input text file...\n");

        // Reading in 2D image from a text file
        infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/image_input.txt","r");
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

        // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        wait(CNN_dut.state == IDLE);

        #20

        $display($time,"ns: Writing cnn_output into cnn_output text file...\n");

        // write out cnn_output back into a text file
        cnn_outfile = $fopen("cnn_output_synthesis.txt","w");
        if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        $fwrite(cnn_outfile,"cnn_output: \n");
        $fwrite(cnn_outfile,"%0d\n",cnn_output);
        $fwrite(cnn_outfile,"\n");

        $fclose(cnn_outfile);

        $display($time,"ns: Finished testing...\n");
        
        $finish;
    end


endmodule


// Module/function to pack a 2D unpacked array into a 1D packed array (MUST OVERWRITE PARAMETERS)
module pack2d_module #(parameter HEIGHT = 10, parameter WIDTH = 10, parameter BIT_WIDTH = 2)();

    function bit[(BIT_WIDTH*WIDTH*HEIGHT)-1:0] pack2d;
        input [BIT_WIDTH-1:0] unpacked [HEIGHT][WIDTH];

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

// Module/function to pack a 1D unpacked array into a 1D packed array (MUST OVERWRITE PARAMETERS)
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




