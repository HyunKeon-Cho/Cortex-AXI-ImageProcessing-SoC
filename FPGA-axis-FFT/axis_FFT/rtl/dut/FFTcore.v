module FFTcore
#(parameter
    N_MEM = 2,
    N_BANK = 4,
    N_DATAPATH = 1,
    WIDTH_BANK_ADDR = 8,
    WIDTH_CROM_ADDR = 6,
    LOG2_N_BANK = 2,
    BIT_WIDTH = 32
)(
    input clk,nrst,
    input in_vld, out_rdy,
    output in_rdy, out_vld,
    output [N_MEM*N_BANK-1:0] s_we_BANK,
    output [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_wr_BANK,
    output [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_rd_BANK,
    output [BIT_WIDTH*N_BANK-1:0] s_data_wr_BANK,
    input [BIT_WIDTH*N_BANK-1:0] s_data_rd_BANK,
    output [WIDTH_CROM_ADDR*N_DATAPATH*3-1:0] s_addr_CROM,
    input [32*N_DATAPATH*3-1:0] s_data_rd_CROM,
    output input_MEM, output_MEM,
    output [LOG2_N_BANK-1:0] input_BANK, output_BANK,
    output processing_MEM,
    output hk_in, rd_output
);
genvar i, j;

wire [1:0] swap_in, swap_out;
wire is_DIF;
wire is_DIF_dly;
wire [31:0] data_rd_CROM[0:N_DATAPATH*3-1];
wire [31:0] data_in_DATAPATH[0:N_BANK-1];
wire [31:0] data_out_DATAPATH[0:N_BANK-1];

for (i=0; i<N_DATAPATH*3; i=i+1) begin
    assign data_rd_CROM[i] = s_data_rd_CROM[(i+1)*32-1:i*32];
end

for (j=0; j<N_BANK; j=j+1) begin
    assign data_in_DATAPATH[j] = s_data_rd_BANK[(j+1)*32-1:j*32];
    assign s_data_wr_BANK[(j+1)*32-1:j*32] = data_out_DATAPATH[j];
end

DFF #(1, 1) DFF_is_DIF (nrst, clk, is_DIF, is_DIF_dly);

for (j=0; j<N_DATAPATH; j=j+1) begin
    FFT4 FFT0 (
        clk,
        nrst,
        data_in_DATAPATH[j*4],
        data_in_DATAPATH[j*4+1],
        data_in_DATAPATH[j*4+2],
        data_in_DATAPATH[j*4+3],
        data_rd_CROM[j*3],
        data_rd_CROM[j*3+1],
        data_rd_CROM[j*3+2],
        swap_in, swap_out,
        data_out_DATAPATH[j*4],
        data_out_DATAPATH[j*4+1],
        data_out_DATAPATH[j*4+2],
        data_out_DATAPATH[j*4+3],
        is_DIF_dly,
        1'b0
    );
end

controller #(
    N_MEM, N_BANK, N_DATAPATH, WIDTH_BANK_ADDR, WIDTH_CROM_ADDR, LOG2_N_BANK
) controller (
    clk, nrst,
    in_vld, out_rdy,
    in_rdy, out_vld,
    s_we_BANK, s_addr_wr_BANK, s_addr_rd_BANK,
    s_addr_CROM,
    is_DIF,
    swap_in, swap_out,
    input_MEM, output_MEM,
    input_BANK, output_BANK,
    processing_MEM,
    hk_in, rd_output
);
endmodule
