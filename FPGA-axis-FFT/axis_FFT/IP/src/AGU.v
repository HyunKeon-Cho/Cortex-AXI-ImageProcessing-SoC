module AGU
#(parameter
    N_BANK = 4,
    N_DATAPATH = 1,
    WIDTH_BANK_ADDR = 8,
    WIDTH_CROM_ADDR = 6,
    LEN_CNT = 4,
    N_BF = 16,
    PIPELINE_LVL = 8,
    IDLE = 4'b0000,
    STAGE0 = 4'b0001,
    STAGE1 = 4'b0010,
    STAGE2 = 4'b0011,
    WAIT = 4'b0101
)(
    input nrst, clk,
    input [LEN_CNT-1:0] cnt,
    input [3:0] cstate,
    input is_DIF,
    output [N_BANK-1:0] s_we_FFT,
    output [WIDTH_BANK_ADDR*N_BANK-1:0] s_addr_wr_FFT,
    output [WIDTH_BANK_ADDR*N_BANK-1:0] s_addr_rd_FFT,
    output [1:0] sel_swap_in, sel_swap_out,
    output [WIDTH_CROM_ADDR*N_DATAPATH*3-1:0] s_addr_CROM,
    output last_commit
);
genvar i, j;

wire issue_vld;
wire [1:0] phase;
wire [1:0] stage;
wire [LEN_CNT-1:0] cnt_BANK;
wire [WIDTH_BANK_ADDR-1:0] addr_rd_FFT[0:N_BANK-1];
wire [3:0] addr_rd_FFT64PT_BANK[0:N_BANK-1];
wire [1:0] sel_swap_in_tmp, sel_swap_out_tmp;
wire [1:0] swap_in, swap_out;
wire [WIDTH_CROM_ADDR-1:0] addr_CROM[0:N_DATAPATH*3-1];
wire [WIDTH_CROM_ADDR-1:0] addr_CROM_base;

assign issue_vld = (cstate == STAGE0 || cstate == STAGE1 || cstate == STAGE2);
assign phase = (cstate == STAGE0) ? 0 :
               (cstate == STAGE2 || cstate == WAIT) ? 2 : 1;
assign stage = (is_DIF) ? phase : 2-phase;
assign cnt_BANK = ((is_DIF && phase == 0) || (!is_DIF && phase != 0)) ?
                  {cnt[1:0],cnt[3:2]} : cnt;
assign swap_in = (stage == 0) ? 0 :
                (stage == 1) ? cnt_BANK[3:2] : cnt_BANK[1:0];
assign swap_out = (stage == 0) ? cnt_BANK[3:2] :
                 (stage == 1) ? cnt_BANK[1:0] : 0;
assign sel_swap_in_tmp = (is_DIF) ? swap_in : swap_out;
assign sel_swap_out_tmp = (is_DIF) ? swap_out : swap_in;

for (i=0; i<N_BANK; i=i+1) begin
    for (j=0; j<4; j=j+2) begin
        assign addr_rd_FFT64PT_BANK[i][j+1:j] =
            (j/2 < 2-stage) ? cnt_BANK[j+1:j] : i-cnt_BANK[j+1:j];
    end
    assign addr_rd_FFT[i] = {4'b0000,addr_rd_FFT64PT_BANK[i]};
    assign s_addr_rd_FFT[WIDTH_BANK_ADDR*(i+1)-1:WIDTH_BANK_ADDR*i] = addr_rd_FFT[i];
end

DFF #(2, 1) DFF_swap_in (nrst, clk, sel_swap_in_tmp, sel_swap_in);
DFF #(2, 1) DFF_swap_out (nrst, clk, sel_swap_out_tmp, sel_swap_out);
DFF #(WIDTH_BANK_ADDR*N_BANK, PIPELINE_LVL) DFF_s_addr_wr_FFT (nrst, clk, s_addr_rd_FFT, s_addr_wr_FFT);
DFF #(N_BANK, PIPELINE_LVL) DFF_s_we_FFT (nrst, clk, {N_BANK{issue_vld}}, s_we_FFT);
DFF #(1, PIPELINE_LVL) DFF_last_commit (nrst, clk, issue_vld && cstate == STAGE2 && cnt == N_BF-1, last_commit);

assign addr_CROM_base = (stage == 0) ? {2'b00,cnt_BANK} :
                        (stage == 1) ? {2'b00,cnt_BANK[1:0],2'b00} : 0;
for (i=0; i<N_DATAPATH*3; i=i+1) begin
    assign addr_CROM[i] = addr_CROM_base*(i%3+1);
    assign s_addr_CROM[(i+1)*WIDTH_CROM_ADDR-1:i*WIDTH_CROM_ADDR] = addr_CROM[i];
end
endmodule
