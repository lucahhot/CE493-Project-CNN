`timescale 1ns/1ps

module ConvolutionPE (
    input logic signed [31:0] inpsum,
    input logic signed [1:0] weight,
    input logic signed [1:0] infmap_value,
    output logic signed [31:0] outpsum
);

// In order to try and replicate the zero gating logic from the Eyeriss paper,
// if infmap_vlaue == 0, then assign output to 0 and don't waste time putting the infmap_value
// and weight through a multiplication and accumulation.

// The Eyeriss paper says that this saves 45% of PE power consumption but that is because the PEs
// in the paper have to access SPAD memory elements and this is disabled if the input is 0. 
// Since we do not have SPADs within the PEs and everything is stored globally, I'm not sure how
// much power saving this actually results in. 

always_comb begin
    if (infmap_value == 0)
        outpsum = 0;
    else 
        outpsum = inpsum + (weight * infmap_value);
end

endmodule