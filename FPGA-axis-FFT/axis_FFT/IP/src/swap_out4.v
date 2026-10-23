module swap_out4(
    input clk, nrst,
    input [1:0] sel_swap,
    input [31:0] data_in0,
    input [31:0] data_in1,
    input [31:0] data_in2,
    input [31:0] data_in3,
    output [31:0] data_out0,
    output [31:0] data_out1,
    output [31:0] data_out2,
    output [31:0] data_out3
    );
   

assign data_out0 =  (sel_swap == 0) ? data_in0 : (sel_swap == 1) ? data_in3 : (sel_swap == 2) ? data_in2 : data_in1;
assign data_out1 =  (sel_swap == 0) ? data_in1 : (sel_swap == 1) ? data_in0 : (sel_swap == 2) ? data_in3 : data_in2;
assign data_out2 =  (sel_swap == 0) ? data_in2 : (sel_swap == 1) ? data_in1 : (sel_swap == 2) ? data_in0 : data_in3;
assign data_out3 =  (sel_swap == 0) ? data_in3 : (sel_swap == 1) ? data_in2 : (sel_swap == 2) ? data_in1 : data_in0; 
    
endmodule
