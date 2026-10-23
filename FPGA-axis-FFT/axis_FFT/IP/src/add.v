module add
(
    input clk,
    input signed [15:0] in_re0, //From REGA 2,14
    input signed [15:0] in_im0, //From REGA
    input signed [15:0] in_re1, //From REGB 3,13
    input signed [15:0] in_im1, //From REGB
    output signed [31:0] out0
);
//Imag [31:16], Real [15:0]

wire signed [16:0] tmp_re0;
wire signed [16:0] tmp_im0;

reg signed [16:0] tmp_re0_DFF;
reg signed [16:0] tmp_im0_DFF;

always @(posedge clk) begin
    tmp_re0_DFF<=tmp_re0;
    tmp_im0_DFF<=tmp_im0;
end

assign tmp_re0 = in_re0 + in_re1; //real - real
assign tmp_im0 = in_im0 + in_im1; //real + real

assign out0 = {tmp_im0_DFF[16:1], tmp_re0_DFF[16:1]};

endmodule