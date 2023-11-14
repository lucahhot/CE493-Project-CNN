`timescale 1ns/1ps

module CNN_tb #(
    parameter IMAGE_WIDTH = 12,
    parameter IMAGE_HEIGHT = 12,
    parameter NUM_FEATURES = 1,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1
);

    logic signed [1:0] image [IMAGE_HEIGHT][IMAGE_WIDTH];
    logic signed [1:0] feature [KERNEL_SIZE*KERNEL_SIZE];
    logic feature_addr;
    logic feature_WrEn;
    logic clk;
    logic rst_cnn;
    logic rst_weights;
    logic enable;

    parameter OUTPUT_WIDTH = (IMAGE_WIDTH-KERNEL_SIZE)/STRIDE+1;
    parameter OUTPUT_HEIGHT = (IMAGE_HEIGHT-KERNEL_SIZE)/STRIDE+1;
    logic signed [31:0] outfmap [NUM_FEATURES][OUTPUT_HEIGHT][OUTPUT_WIDTH];

    // Files reading/writing variables
    int infile, outfile;

    // Instantiating an instance of CNN
    CNN #(.IMAGE_WIDTH(IMAGE_WIDTH),.IMAGE_HEIGHT(IMAGE_HEIGHT),.NUM_FEATURES(NUM_FEATURES),.KERNEL_SIZE(KERNEL_SIZE),.STRIDE(STRIDE))
    CNN_dut(.image_input(image),.weights_input(feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),
            .clk(clk),.rst_cnn(rst_cnn),.rst_weights(rst_weights),.convolution_enable(enable),.outfmap(outfmap));

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
        // Wait 1 clock pulse for feature map to loaded into memory
        @(negedge clk);
        @(negedge clk);
        feature_WrEn = 1;

        $display($time,"ns: Reading 2D input image from input text file...\n");

        // Reading in 2D image from a text file
        infile = $fopen("image_input.txt","r");
        if (infile)  $display("File was opened successfully : %0d\n", infile);
        else         $display("File was NOT opened successfully : %0d\n", infile);

        for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                void'($fscanf(infile,"%d",image[i][j]));
            end
        end
        $fclose(infile);

        #10

        $display($time,"ns: Starting convolution...\n");

        // Start convolution
        enable = 0; 

        // Wait until done = 1
        wait(CNN_dut.done == 1);

        #20

        $display($time,"ns: Writing outfmap results into output text file...\n");

        // Write out outfmap back into a text file to easily analyze
        outfile = $fopen("CNN_output.txt","w");
        if (outfile)  $display("File was opened successfully : %0d\n", infile);
        else         $display("File was NOT opened successfully : %0d\n", infile);

        for (int i = 0; i < OUTPUT_HEIGHT; i = i + 1) begin
            for (int j = 0; j < OUTPUT_WIDTH; j = j + 1) begin
                $fwrite(outfile,"%0d ",outfmap[0][i][j]);
            end
            $fwrite(outfile,"\n");
        end
        $fclose(outfile);

        $display($time,"ns: Finished testing...\n");
        
        $finish;
    end


endmodule