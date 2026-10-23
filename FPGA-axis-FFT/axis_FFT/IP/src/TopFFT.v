module TopFFT (
    input clk, nrst,
    input in_vld, out_rdy,
    output in_rdy, out_vld,
    input [31:0] ext_data_input,
    output [31:0] ext_data_output
);
genvar i, j;

parameter N_MEM = 2;
parameter N_BANK = 4;
parameter BIT_WIDTH = 64;
parameter N_DATAPATH = 1;
parameter WIDTH_BANK_ADDR = 8;
parameter WIDTH_CROM_ADDR = 6;
parameter LOG2_N_BANK = 2;

wire we_BANK[0:N_MEM-1][0:N_BANK-1];
wire [WIDTH_BANK_ADDR-1:0] addr_wr_BANK[0:N_MEM-1][0:N_BANK-1];
wire [WIDTH_BANK_ADDR-1:0] addr_rd_BANK[0:N_MEM-1][0:N_BANK-1];
wire [BIT_WIDTH-1:0] data_wr_BANK[0:N_MEM-1][0:N_BANK-1];
wire [BIT_WIDTH-1:0] data_rd_BANK[0:N_MEM-1][0:N_BANK-1];

wire [N_MEM*N_BANK-1:0] s_we_BANK;
wire [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_wr_BANK;
wire [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_rd_BANK;
wire [32*N_BANK-1:0] s_data_wr_BANK;
wire [32*N_BANK-1:0] s_data_rd_BANK;

wire input_MEM, output_MEM, processing_MEM;
wire [LOG2_N_BANK-1:0] input_BANK, output_BANK;
wire hk_in, rd_output;
reg output_MEM_dly;
reg [LOG2_N_BANK-1:0] output_BANK_dly;
reg output_hold;
reg [31:0] output_hold_data;
wire [31:0] ext_data_output_dly;

wire [WIDTH_CROM_ADDR-1:0] addr_CROM[0:N_DATAPATH*3-1];
wire [31:0] data_rd_CROM[0:N_DATAPATH*3-1];
wire [WIDTH_CROM_ADDR*N_DATAPATH*3-1:0] s_addr_CROM;
wire [32*N_DATAPATH*3-1:0] s_data_rd_CROM;

for (i=0; i<N_MEM; i=i+1) begin
    for (j=0; j<N_BANK; j=j+1) begin
        assign we_BANK[i][j] = s_we_BANK[i*N_BANK+j];
        assign addr_wr_BANK[i][j] = s_addr_wr_BANK[(i*N_BANK+j+1)*WIDTH_BANK_ADDR-1:(i*N_BANK+j)*WIDTH_BANK_ADDR];
        assign addr_rd_BANK[i][j] = s_addr_rd_BANK[(i*N_BANK+j+1)*WIDTH_BANK_ADDR-1:(i*N_BANK+j)*WIDTH_BANK_ADDR];
        assign data_wr_BANK[i][j] = (hk_in && input_MEM == i && input_BANK == j) ?
                                    {32'b0,ext_data_input} :
                                    {32'b0,s_data_wr_BANK[(j+1)*32-1:j*32]};

        blk_mem_gen_0 BANK (
            .clka(clk),
            .clkb(clk),
            .wea(we_BANK[i][j]),
            .addra(addr_wr_BANK[i][j]),
            .dina(data_wr_BANK[i][j]),
            .addrb(addr_rd_BANK[i][j]),
            .doutb(data_rd_BANK[i][j])
        );
    end
end

for (j=0; j<N_BANK; j=j+1) begin
    assign s_data_rd_BANK[(j+1)*32-1:j*32] = data_rd_BANK[processing_MEM][j][31:0];
end

for (i=0; i<N_DATAPATH*3; i=i+1) begin
    assign addr_CROM[i] = s_addr_CROM[(i+1)*WIDTH_CROM_ADDR-1:i*WIDTH_CROM_ADDR];
    assign s_data_rd_CROM[(i+1)*32-1:i*32] = data_rd_CROM[i];

    twiddle_factor_generator #(
        WIDTH_CROM_ADDR, 32
    ) twiddle_factor_generator (
        .nrst(nrst),
        .clka(clk),
        .addra(addr_CROM[i]),
        .douta(data_rd_CROM[i])
    );
end

always @(posedge clk) begin
    if (!nrst) begin
        output_MEM_dly <= 0;
        output_BANK_dly <= 0;
    end
    else if (rd_output) begin
        output_MEM_dly <= output_MEM;
        output_BANK_dly <= output_BANK;
    end
end

always @(posedge clk) begin
    if (!nrst)
        output_hold <= 0;
    else if (rd_output)
        output_hold <= 0;
    else if (out_vld && !out_rdy && !output_hold)
        output_hold <= 1;
end

always @(posedge clk) begin
    if (!nrst)
        output_hold_data <= 0;
    else if (out_vld && !out_rdy && !output_hold)
        output_hold_data <= ext_data_output_dly;
end

assign ext_data_output_dly = data_rd_BANK[output_MEM_dly][output_BANK_dly][31:0];
assign ext_data_output = (output_hold) ? output_hold_data : ext_data_output_dly;

FFTcore #(
    N_MEM, N_BANK, N_DATAPATH, WIDTH_BANK_ADDR, WIDTH_CROM_ADDR, LOG2_N_BANK, 32
) FFTcore (
    clk, nrst,
    in_vld, out_rdy,
    in_rdy, out_vld,
    s_we_BANK, s_addr_wr_BANK, s_addr_rd_BANK,
    s_data_wr_BANK, s_data_rd_BANK,
    s_addr_CROM, s_data_rd_CROM,
    input_MEM, output_MEM,
    input_BANK, output_BANK,
    processing_MEM,
    hk_in, rd_output
);
endmodule
