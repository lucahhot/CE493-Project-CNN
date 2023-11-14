`timescale 1ns/1ps

module CNN_tb #(
    parameter IMAGE_WIDTH = 12,
    parameter IMAGE_HEIGHT = 12,
    parameter NUM_FEATURES = 1,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1
);

    logic image [IMAGE_HEIGHT][IMAGE_WIDTH];
    logic feature [KERNEL_SIZE*KERNEL_SIZE];
    logic feature_addr;
    logic feature_WrEn;
    logic clk;
    logic rst_cnn;
    logic rst_weights;
    logic enable;
    logic [31:0] outfmap [NUM_FEATURES][IMAGE_HEIGHT][IMAGE_WIDTH];

    // File reading/writing variables
    int infile;
    string line;

    // Instantiating an instance of CNN
    CNN #(.IMAGE_WIDTH(IMAGE_WIDTH),.IMAGE_HEIGHT(IMAGE_HEIGHT),.NUM_FEATURES(NUM_FEATURES),.KERNEL_SIZE(KERNEL_SIZE),.STRIDE(STRIDE))
    CNN_dut(.image_input(image),.weights_input(feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),
            .clk(clk),.rst_cnn(rst_cnn),.rst_weights(rst_weights),.convolution_enable(enable),.outfmap1(outfmap));

    // Clock with a period of 20ns
    always
     #10 clk = ~clk;

    initial begin

        $display("\nStarting testing...\n");

        // Reset the CNN
        rst_cnn = 1;
        rst_weights = 1;
        #10
        rst_cnn = 0;
        rst_weights = 0;
        #10
        rst_cnn = 1;
        rst_weights = 1;

        // Write single feature map into feature memory
        enable = 1;
        feature_WrEn = 0;
        feature_addr = 0;
        // Feature is an "X" shape (flattened)
        feature = '{1,0,1,0,1,0,1,0,1};
        // Wait 1 clock pulse for feature map to loaded into memory
        wait(clk == 1);
        wait(clk == 0);
        wait(clk == 1);
        feature_WrEn = 1;

        // Reading in 2D image from a text file
  
        infile = $fopen("image_input.txt","r");
        if (infile)  $display("File was opened successfully : %0d", infile);
        else         $display("File was NOT opened successfully : %0d", infile);

        for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            $fgets(line,infile);
            for (int j = 0; i < IMAGE_WIDTH; j = j + 1) begin
                $sscanf(line,"%d",image[i][j]);
            end
        end
        $fclose(infile);

        #10

        $display("\nFinished testing...\n");
        
        $finish;
    end


endmodule