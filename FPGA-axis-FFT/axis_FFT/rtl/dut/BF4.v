module BF4
(
    input clk,nrst,
    input is_radix2,
    input [31:0] data_in_0, data_in_1, data_in_2, data_in_3,
    output [31:0] data_out_0, data_out_1, data_out_2, data_out_3
);
genvar i, j;

wire signed [31:0] data[5:0];
wire signed [31:0] data_BF2[3:0];
wire signed [31:0] data_BF2_dly[3:0];
wire signed [31:0] data_BF4[3:0];
wire is_radix2_dly;

// lvl 1 : radi-2
BF BF00(
    .clk(clk),
    .in_re0(data_in_0[15:0]),.in_im0(data_in_0[31:16]),
    .in_re1(data_in_1[15:0]),.in_im1(data_in_1[31:16]),
    .out0_BF(data[0]),.out1_BF(data[1])
);
 
BF BF01(
    .clk(clk),
    .in_re0(data_in_2[15:0]),.in_im0(data_in_2[31:16]),
    .in_re1(data_in_3[15:0]),.in_im1(data_in_3[31:16]),
    .out0_BF(data[2]),.out1_BF(data[3])
);

sub sub5(
    clk, 
    data_in_0[15:0], data_in_0[31:16],
    data_in_2[15:0], data_in_2[31:16],
    data[4]
);

sub sub6(
    clk, 
    data_in_1[15:0], data_in_1[31:16],
    data_in_3[15:0], data_in_3[31:16],
    data[5]
);

/////////////
add add0(
    clk, 
    data[0][15:0], data[0][31:16],
    data[2][15:0], data[2][31:16],
    data_BF4[0]
);

add add1(
    clk, 
    data[4][15:0], data[4][31:16],
    data[5][31:16], -data[5][15:0],
    data_BF4[1]
);

add add2(
    clk, 
    data[1][15:0], data[1][31:16],
    data[3][15:0], data[3][31:16],
    data_BF4[2]
);

add add3(
    clk, 
    data[4][15:0], data[4][31:16],
    -data[5][31:16], data[5][15:0],
    data_BF4[3]
);

assign data_BF2[0] = data[0];
assign data_BF2[1] = data[1];
assign data_BF2[2] = data[2];
assign data_BF2[3] = data[3];


for (i=0; i<4; i=i+1) begin
    DFF #(32, 1) DFF0 (nrst, clk, data_BF2[i], data_BF2_dly[i]);
end
DFF #(1, 2) DFF_is_radix2 (nrst, clk, is_radix2, is_radix2_dly);
assign data_out_0 = (is_radix2_dly) ? data_BF2_dly[0] : data_BF4[0];
assign data_out_1 = (is_radix2_dly) ? data_BF2_dly[1] : data_BF4[1];
assign data_out_2 = (is_radix2_dly) ? data_BF2_dly[2] : data_BF4[2];
assign data_out_3 = (is_radix2_dly) ? data_BF2_dly[3] : data_BF4[3];


endmodule