`timescale 1ns/1ps

module CNN_tb #(
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

    // Files reading/writing variables
    int infile,convolution_outfile,pooled_outfile,flattened_outfile;

    // Instantiating an instance of CNN
    CNN #(.IMAGE_WIDTH(IMAGE_WIDTH),.IMAGE_HEIGHT(IMAGE_HEIGHT),.NUM_FEATURES(NUM_FEATURES),.KERNEL_SIZE(KERNEL_SIZE),.DATA_WIDTH(DATA_WIDTH))
    CNN_dut(.image_input(image),.weights_input(feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),
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
        // Wait 1 clock pulse for feature map to loaded into memory
        @(negedge clk);
        @(negedge clk);
        // Write second feature map into feature memory
        feature_addr = 1;
        feature = '{1,1,1,1,1,1,1,1,1};
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
        @(posedge clk);
        enable = 1;

        // Wait until state == POOLING to check convolution output
        wait(CNN_dut.state == POOLING);

        #20

        $display($time,"ns: Writing convolution_outfmap results into convolution_output text file...\n");

        // Write out convolution_outfmap back into a text file to easily analyze
        convolution_outfile = $fopen("convolution_output.txt","w");
        if (convolution_outfile)  $display("File was opened successfully : %0d\n", convolution_outfile);
        else         $display("File was NOT opened successfully : %0d\n", convolution_outfile);

        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            $fwrite(convolution_outfile,"convolution_outfmap for feature %0d: \n",(feature+1));
            for (int i = 0; i < CONVOLUTION_HEIGHT; i = i + 1) begin
                for (int j = 0; j < CONVOLUTION_WIDTH; j = j + 1) begin
                    $fwrite(convolution_outfile,"%0d ",CNN_dut.convolution_outfmap[feature][i][j]);
                end
                $fwrite(convolution_outfile,"\n");
            end
            $fwrite(convolution_outfile,"\n");
        end

        $fclose(convolution_outfile);

        // Wait until state == FLATTENING to check pooling output
        wait(CNN_dut.state == FLATTENING);

        #20 

        $display($time,"ns: Writing pooled_outfmap results into pooled_output text file...\n");

        // write out pooled_outfmap back into a text file
        pooled_outfile = $fopen("pooled_output.txt","w");
        if (pooled_outfile)  $display("File was opened successfully : %0d\n", pooled_outfile);
        else         $display("File was NOT opened successfully : %0d\n", pooled_outfile);

        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            $fwrite(pooled_outfile,"pooled_outfmap for feature %0d: \n",(feature+1));
            for (int i = 0; i < POOLED_HEIGHT; i = i + 1) begin
                for (int j = 0; j < POOLED_WIDTH; j = j + 1) begin
                    $fwrite(pooled_outfile,"%0d ",CNN_dut.pooled_outfmap[feature][i][j]);
                end
                $fwrite(pooled_outfile,"\n");
            end
            $fwrite(pooled_outfile,"\n");
        end

        $fclose(pooled_outfile);

        // Wait until state == DENSE to check flattening output
        wait(CNN_dut.state == DENSE);

        #20 

        $display($time,"ns: Writing flattened_outfmap results into flattened_output text file...\n");

        // write out pooled_outfmap back into a text file
        flattened_outfile = $fopen("flattened_output.txt","w");
        if (flattened_outfile)  $display("File was opened successfully : %0d\n", flattened_outfile);
        else         $display("File was NOT opened successfully : %0d\n", flattened_outfile);

        for (int feature = 0; feature < NUM_FEATURES; feature = feature + 1) begin
            $fwrite(flattened_outfile,"flattened_outfmap for feature %0d: \n",(feature+1));
            for (int i = 0; i < FLATTENED_LENGTH; i = i + 1) begin
                $fwrite(flattened_outfile,"%0d\n",CNN_dut.flattened_outfmap[feature][i]);
            end
            $fwrite(flattened_outfile,"\n");
        end

        $fclose(flattened_outfile);

        $display($time,"ns: Finished testing...\n");
        
        $finish;
    end


endmodule