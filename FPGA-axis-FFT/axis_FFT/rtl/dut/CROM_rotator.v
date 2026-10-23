module twiddle_factor_generator
#(parameter
    WIDTH_ADDR = 6,
    WIDTH_DATA = 32,
    MEM_FILE = "twiddle64.mem"
)(
    input nrst, clka,
    input [WIDTH_ADDR-1:0] addra,
    output reg [WIDTH_DATA-1:0] douta
);
reg [WIDTH_DATA-1:0] CROM[0:8];
reg [WIDTH_ADDR-3:0] addr_CROM;
reg sel_swap;
reg sel_neg_re, sel_neg_im;
wire signed [WIDTH_DATA/2-1:0] dout_CROM_re, dout_CROM_im;
wire [WIDTH_DATA/2-1:0] dout_rotator_re, dout_rotator_im;

initial begin
    $readmemh(MEM_FILE, CROM);
end

always @(posedge clka) begin
    if (!nrst) begin
        addr_CROM <= 0;
        sel_swap <= 0;
        sel_neg_re <= 0;
        sel_neg_im <= 0;
    end
    else begin
        addr_CROM <= (addra[3]) ? 4'd0-addra[3:0] : addra[3:0];
        sel_swap <= addra[3]^addra[4];
        sel_neg_re <= addra[5]^addra[3];
        sel_neg_im <= addra[5]^addra[4]^addra[3];
    end
end

assign dout_CROM_re = (sel_swap) ? CROM[addr_CROM][WIDTH_DATA-1:WIDTH_DATA/2] :
                                 CROM[addr_CROM][WIDTH_DATA/2-1:0];
assign dout_CROM_im = (sel_swap) ? CROM[addr_CROM][WIDTH_DATA/2-1:0] :
                                 CROM[addr_CROM][WIDTH_DATA-1:WIDTH_DATA/2];
assign dout_rotator_re = (sel_neg_re) ? -dout_CROM_re : dout_CROM_re;
assign dout_rotator_im = (sel_neg_im) ? -dout_CROM_im : dout_CROM_im;

always @(posedge clka) begin
    if (!nrst)
        douta <= 0;
    else
        douta <= {dout_rotator_im,dout_rotator_re};
end
endmodule
