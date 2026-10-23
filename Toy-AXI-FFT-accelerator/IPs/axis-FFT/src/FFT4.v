module FFT4
(
    input clk,
    input nrst,
    
    input [31:0] data_in_0, data_in_1, data_in_2, data_in_3,
    input [31:0] data_CROM_1, data_CROM_2, data_CROM_3,
    
    input [1:0] swap_in, swap_out,
    
    output [31:0] data_out_0, data_out_1, data_out_2, data_out_3,
    
    input is_DIF,    
    input is_radix2
);
genvar i,j;

wire [31:0] data_out[0:3];

wire [31:0] data_CROM[0:2];

wire [31:0] data_out_mult_DIT[0:3]; 
wire [31:0] data_out_mult_DIF[0:3]; 

wire [31:0] data_in_bf[0:3];
wire [31:0] data_out_bf[0:3];
wire [31:0] data_out_bf_dly[0:3];

wire [31:0] data_out_swap_in[0:3];
wire [31:0] DFF_2_data_out_swap_in;
wire [31:0] DFF_2_data_out_bf;
reg [31:0] DFF_1_data_out_swap_in[0:3];

wire [31:0] data_CROM_dly[0:2];
wire [1:0]  swap_out_dly;
wire        is_DIF_dly_1;
wire        is_DIF_dly_2;
wire        is_radix2_dly;
wire [31:0] data_out_swap_in_dly[0:3];

wire [31:0] data_out_swap_out[0:3];


// step 0 ; intitialization
assign data_CROM[0] = data_CROM_1;
assign data_CROM[1] = data_CROM_2;
assign data_CROM[2] = data_CROM_3;




// step -1 : input swap
swap_in4 swap_in4(
    clk, nrst, 
    swap_in,
    data_in_0, data_in_1,data_in_2, data_in_3,
    data_out_swap_in[0], data_out_swap_in[1], data_out_swap_in[2], data_out_swap_in[3]
);

////////////////////pipeline1/////////////////////////////////
for (j = 0; j< 4; j=j+1)begin
    always @(posedge clk) begin
        if(!nrst) DFF_1_data_out_swap_in[j] <= 0;
        else DFF_1_data_out_swap_in[j] <= data_out_swap_in[j];
    end
end


//////////////////////////////////////////////////////////////
// step 1 : MULT for DIT FFT
DFF #(32, 2) DFF0 (nrst, clk, DFF_1_data_out_swap_in[0], DFF_2_data_out_swap_in);
assign data_out_mult_DIT[0] = DFF_2_data_out_swap_in;

for (i=1; i<4; i=i+1) begin
    wire [31:0] data_in_MULT_DIT = DFF_1_data_out_swap_in[i];
    wire [31:0] data_tw_MULT_DIT = data_CROM[i-1];
/////////////////pipeline2~3////////////////////////////////
    MULT MULT_DIT(clk,nrst, 
        data_in_MULT_DIT[15:0], data_in_MULT_DIT[31:16],
        data_tw_MULT_DIT[15:0], data_tw_MULT_DIT[31:16],
        data_out_mult_DIT[i]
    );
end

// step 2 : BF
DFF #(1, 3) DFF_is_DIF_1 (nrst, clk, is_DIF, is_DIF_dly_1);
for (i=0; i<4; i=i+1) begin
    DFF #(32, 2) DFF0 (nrst, clk, DFF_1_data_out_swap_in[i], data_out_swap_in_dly[i]);
end

for (i=0; i<4; i=i+1) begin
    assign data_in_bf[i] = (is_DIF_dly_1) ? data_out_swap_in_dly[i] : data_out_mult_DIT[i];
end

DFF #(1, 3) DFF_is_radix2 (nrst, clk, is_radix2, is_radix2_dly);
/////////////pipeline4~5//////////////////////
BF4 BF(clk,nrst,
    is_radix2_dly,
    data_in_bf[0], data_in_bf[1], data_in_bf[2],data_in_bf[3],
    data_out_bf[0], data_out_bf[1], data_out_bf[2], data_out_bf[3]
);

// step 1 : MULT for DIF FFT
for (i=0; i<3; i=i+1) begin
    DFF #(32, 4) DFF0 (nrst, clk, data_CROM[i], data_CROM_dly[i]);//1cycle¶¯°ÜÁü
end

DFF #(32, 2) DFF1 (nrst, clk, data_out_bf[0], DFF_2_data_out_bf);
assign data_out_mult_DIF[0] = DFF_2_data_out_bf;

for (i=1; i<4; i=i+1) begin
    wire [31:0] data_in_MULT_DIF = data_out_bf[i];
    wire [31:0] data_tw_MULT_DIF = data_CROM_dly[i-1];
////////////////////pipeline6~7///////////////////////
    MULT MULT_DIF(clk,nrst, 
        data_in_MULT_DIF[15:0], data_in_MULT_DIF[31:16],
        data_tw_MULT_DIF[15:0], data_tw_MULT_DIF[31:16],
        data_out_mult_DIF[i]
    );
end
for (i=0; i<4; i=i+1) begin
    DFF #(32, 2) DFF0 (nrst, clk, data_out_bf[i], data_out_bf_dly[i]);
end
//////////////////////////////////////////////////////////
// step 2 : select output data
DFF #(1, 7) DFF_is_DIF_2 (nrst, clk, is_DIF, is_DIF_dly_2);
for (i=0; i<4; i=i+1) begin
    assign data_out[i] = (is_DIF_dly_2) ? data_out_mult_DIF[i] : data_out_bf_dly[i];
end

DFF #(2, 7) DFF_swap_out (nrst, clk, swap_out, swap_out_dly);
swap_out4 swap_out4(
    clk, nrst,
    swap_out_dly,
    data_out[0], data_out[1], data_out[2], data_out[3],
    data_out_0, data_out_1, data_out_2,data_out_3
);

endmodule