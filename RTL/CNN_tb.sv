`timescale 1ns/1ps

module CNN_tb #(
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
    parameter BIAS_DATA_WIDTH = 32,
    parameter PSUM_DATA_WIDTH = 32, // Need extra bits to add all the psums
    parameter FULLYCONNECTED_DATA_WIDTH = 32
);

    logic image [IMAGE_HEIGHT][IMAGE_WIDTH];

    logic signed [DATA_WIDTH-1:0] feature [KERNEL_SIZE*KERNEL_SIZE];
    logic [1:0] feature_addr;
    logic feature_WrEn;
    logic rst_feature_weights;

    logic signed [BIAS_DATA_WIDTH-1:0] biases [NUM_FEATURES+1];
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

    // Files reading/writing variables
    int infile,convolution_outfile,pooled_outfile,flattened_outfile,fullyconnected_infile,cnn_outfile;

    // Instantiating an instance of CNN
    CNN CNN_dut(.image_input(image),.feature_weights_input(feature),.feature_writeAddr(feature_addr),.feature_WrEn(feature_WrEn),.rst_feature_weights(rst_feature_weights),.bias_weights_input(biases),.bias_WrEn(bias_WrEn),.rst_bias_weights(rst_bias_weights),
                .fullyconnected_weights_input(fullyconnected_weights_input),.fullyconnected_writeAddr(fullyconnected_writeAddr),.fullyconnected_WrEn(fullyconnected_WrEn),.rst_fullyconnected_weights(rst_fullyconnected_weights),.clk(clk),.rst_cnn(rst_cnn),.convolution_enable(enable),.cnn_output(cnn_output));

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
        // Feature #1 for quantized model (12/06/23)
        feature = '{-127,-29,-90,9,113,37,65,-1,-86,-62,-103,20,-34,-123,95,92};
        // Wait 1 clock pulse for feature map to loaded into memory
        @(negedge clk);
        @(negedge clk);
        // Write second feature map into feature memory
        feature_addr = 1;
        // Feature #2 for quantized model (12/06/23)
        feature = '{-7,-127,-85,-98,38,94,-9,84,25,88,95,109,2,90,120,36};
        @(negedge clk);
        @(negedge clk);
        // Write third feature map into feature memory
        feature_addr = 2;
        // Feature #3 for quantized model (12/06/23)
        feature = '{-61,-4,-22,0,-50,74,87,60,-7,67,56,127,36,45,38,-59};
        @(negedge clk);
        @(negedge clk);
        feature_WrEn = 1;

        // Write biases into bias memory
        bias_WrEn = 0;
        // Biases for quantized model (12/04/23)
        biases = '{1256,-4126,-198,-871};
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
            @(negedge clk);
            @(negedge clk);
            fullyconnected_writeAddr = fullyconnected_writeAddr + 1;
        end
        $fclose(fullyconnected_infile);

        fullyconnected_WrEn = 1;

        $display($time,"ns: Reading 2D input image from input text file...\n");

        // Reading in 2D image from a text file
        infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_102.txt","r");
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
        convolution_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/convolution_output.txt","w");
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

        // Write out pooled_outfmap back into a text file
        pooled_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/pooled_output.txt","w");
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

        // Wait until state == IDLE to check cnn_output
        wait(CNN_dut.state == IDLE);

        #20
        
        $display($time,"ns: Writing cnn_output into cnn_output text file...\n");

        // Write out cnn_output back into a text file
        cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_102.txt","w");
        if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        $fwrite(cnn_outfile,"cnn_output: \n");
        $fwrite(cnn_outfile,"%0d\n",cnn_output);
        $fwrite(cnn_outfile,"\n");

        $fclose(cnn_outfile);

        // // TESTING 5 IMAGES 

        // // Reset the CNN
        // #10
        // rst_cnn = 0;
        // #10
        // rst_cnn = 1;

        // $display($time,"ns: Inputting image #1...\n");

        // // Reading in 2D image from a text file
        // infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_102.txt","r");
        // if (infile)  $display("File was opened successfully : %0d\n", infile);
        // else         $display("File was NOT opened successfully : %0d\n", infile);

        // for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
        //     for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
        //         void'($fscanf(infile,"%d",image[i][j]));
        //     end
        // end
        // $fclose(infile);

        // #10
        // $display($time,"ns: Starting convolution...\n");
        // // Start convolution
        // enable = 0; 
        // #20
        // enable = 1;
        // // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        // wait(CNN_dut.state == IDLE);
        // #20

        // $display($time,"ns: Writing cnn_output into text file for image #1...\n");

        // // Write out cnn_output back into a text file
        // cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_102.txt","w");
        // if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        // else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        // $fwrite(cnn_outfile,"cnn_output: \n");
        // $fwrite(cnn_outfile,"%0d\n",cnn_output);
        // $fwrite(cnn_outfile,"\n");

        // $fclose(cnn_outfile);

        // // Reset the CNN
        // #10
        // rst_cnn = 0;
        // #10
        // rst_cnn = 1;

        // $display($time,"ns: Inputting image #2...\n");

        //  // Reading in 2D image from a text file
        // infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_456.txt","r");
        // if (infile)  $display("File was opened successfully : %0d\n", infile);
        // else         $display("File was NOT opened successfully : %0d\n", infile);

        // for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
        //     for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
        //         void'($fscanf(infile,"%d",image[i][j]));
        //     end
        // end
        // $fclose(infile);

        // #10
        // $display($time,"ns: Starting convolution...\n");
        // // Start convolution
        // enable = 0; 
        // #20
        // enable = 1;
        // // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        // wait(CNN_dut.state == IDLE);
        // #20

        // $display($time,"ns: Writing cnn_output into text file for image #2...\n");

        // // Write out cnn_output back into a text file
        // cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_456.txt","w");
        // if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        // else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        // $fwrite(cnn_outfile,"cnn_output: \n");
        // $fwrite(cnn_outfile,"%0d\n",cnn_output);
        // $fwrite(cnn_outfile,"\n");

        // $fclose(cnn_outfile);

        // // Reset the CNN
        // #10
        // rst_cnn = 0;
        // #10
        // rst_cnn = 1;

        // $display($time,"ns: Inputting image #3...\n");

        //  // Reading in 2D image from a text file
        // infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_914.txt","r");
        // if (infile)  $display("File was opened successfully : %0d\n", infile);
        // else         $display("File was NOT opened successfully : %0d\n", infile);

        // for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
        //     for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
        //         void'($fscanf(infile,"%d",image[i][j]));
        //     end
        // end
        // $fclose(infile);

        // #10
        // $display($time,"ns: Starting convolution...\n");
        // // Start convolution
        // enable = 0; 
        // #20
        // enable = 1;
        // // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        // wait(CNN_dut.state == IDLE);
        // #20

        // $display($time,"ns: Writing cnn_output into text file for image #3...\n");

        // // Write out cnn_output back into a text file
        // cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_914.txt","w");
        // if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        // else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        // $fwrite(cnn_outfile,"cnn_output: \n");
        // $fwrite(cnn_outfile,"%0d\n",cnn_output);
        // $fwrite(cnn_outfile,"\n");

        // $fclose(cnn_outfile);

        // // Reset the CNN
        // #10
        // rst_cnn = 0;
        // #10
        // rst_cnn = 1;

        // $display($time,"ns: Inputting image #4...\n");

        //  // Reading in 2D image from a text file
        // infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_1003.txt","r");
        // if (infile)  $display("File was opened successfully : %0d\n", infile);
        // else         $display("File was NOT opened successfully : %0d\n", infile);

        // for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
        //     for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
        //         void'($fscanf(infile,"%d",image[i][j]));
        //     end
        // end
        // $fclose(infile);

        // #10
        // $display($time,"ns: Starting convolution...\n");
        // // Start convolution
        // enable = 0; 
        // #20
        // enable = 1;
        // // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        // wait(CNN_dut.state == IDLE);
        // #20

        // $display($time,"ns: Writing cnn_output into text file for image #4...\n");

        // // Write out cnn_output back into a text file
        // cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_1003.txt","w");
        // if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        // else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        // $fwrite(cnn_outfile,"cnn_output: \n");
        // $fwrite(cnn_outfile,"%0d\n",cnn_output);
        // $fwrite(cnn_outfile,"\n");

        // $fclose(cnn_outfile);

        // // Reset the CNN
        // #10
        // rst_cnn = 0;
        // #10
        // rst_cnn = 1;

        // $display($time,"ns: Inputting image #5...\n");

        //  // Reading in 2D image from a text file
        // infile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/binary_image_1126.txt","r");
        // if (infile)  $display("File was opened successfully : %0d\n", infile);
        // else         $display("File was NOT opened successfully : %0d\n", infile);

        // for (int i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
        //     for (int j = 0; j < IMAGE_WIDTH; j = j + 1) begin
        //         void'($fscanf(infile,"%d",image[i][j]));
        //     end
        // end
        // $fclose(infile);

        // #10
        // $display($time,"ns: Starting convolution...\n");
        // // Start convolution
        // enable = 0; 
        // #20
        // enable = 1;
        // // Wait until state == IDLE to check cnn_output, which should be the output of FULLYCONNECTED too
        // wait(CNN_dut.state == IDLE);
        // #20

        // $display($time,"ns: Writing cnn_output into text file for image #5...\n");

        // // Write out cnn_output back into a text file
        // cnn_outfile = $fopen("/home/luc/Documents/CE493/CE493_Project_CNN/textfiles/cnn_output_1126.txt","w");
        // if (cnn_outfile)  $display("File was opened successfully : %0d\n", cnn_outfile);
        // else         $display("File was NOT opened successfully : %0d\n", cnn_outfile);

        // $fwrite(cnn_outfile,"cnn_output: \n");
        // $fwrite(cnn_outfile,"%0d\n",cnn_output);
        // $fwrite(cnn_outfile,"\n");

        // $fclose(cnn_outfile);


        $display($time,"ns: Finished testing...\n");
        
        $finish;
    end


endmodule