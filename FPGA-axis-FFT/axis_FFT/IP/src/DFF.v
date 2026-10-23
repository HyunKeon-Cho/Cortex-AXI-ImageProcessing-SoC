module DFF
#(parameter
    WIDTH = 10,
    DEPTH = 10
)(
    input nrst, clk,
    input [WIDTH-1:0] data_in, 
    output [WIDTH-1:0] data_out
);
genvar i;

reg [WIDTH-1:0] DFF [DEPTH-1:0];

for (i=0; i<DEPTH; i=i+1) begin
    always @(posedge clk) begin
        if (!nrst) begin
            DFF[i] <= 0;
        end
        else begin 
            DFF[i] <= (i==0) ? data_in : DFF[i-1];
        end
    end
end

assign data_out = DFF[DEPTH-1];
endmodule
