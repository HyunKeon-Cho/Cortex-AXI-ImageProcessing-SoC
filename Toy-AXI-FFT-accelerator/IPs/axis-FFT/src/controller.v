module controller
#(parameter
    N_MEM = 2,
    N_BANK = 4,
    N_DATAPATH = 1,
    WIDTH_BANK_ADDR = 8,
    WIDTH_CROM_ADDR = 6,
    LOG2_N_BANK = 2
)(
    input clk,nrst,
    input in_vld, out_rdy,
    output in_rdy,
    output reg out_vld,
    output [N_MEM*N_BANK-1:0] s_we_BANK,
    output [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_wr_BANK,
    output [WIDTH_BANK_ADDR*N_MEM*N_BANK-1:0] s_addr_rd_BANK,
    output [WIDTH_CROM_ADDR*N_DATAPATH*3-1:0] s_addr_CROM,
    output is_DIF_processing_MEM,
    output [1:0] sel_swap_in, sel_swap_out,
    output reg input_MEM,
    output reg output_MEM,
    output [LOG2_N_BANK-1:0] input_BANK, output_BANK,
    output reg processing_MEM,
    output hk_in, rd_output
);
genvar i;

localparam
    N = 64,
    RADIX = 4,
    PARALLEL = 1,
    N_BF = N/RADIX/PARALLEL,
    LEN_CNT = 4,
    LEN_IN = 6,
    N_STAGE = 3,
    PIPELINE_LVL = 8,
    STAGE_DEL = 5;

localparam
    IDLE = 4'b0000,
    STAGE0 = 4'b0001,
    STAGE1 = 4'b0010,
    STAGE2 = 4'b0011,
    STAGE_WAIT = 4'b0100,
    WAIT = 4'b0101;

wire MEM_rdy[0:N_MEM-1];
reg [3:0] state;
reg [LEN_CNT-1:0] cnt;
reg [2:0] cnt_wait;
wire [1:0] phase;
wire issue_vld;
wire start_process;
wire is_last_process;
wire last_commit;

reg [LEN_IN-1:0] cnt_in;
wire [LEN_IN-1:0] order_input;
wire [3:0] addr_input;
wire [1:0] addr_input_DIT_1, addr_input_DIT_0;
wire is_last_input[0:N_MEM-1];
reg inputting[0:N_MEM-1];
wire input_safe;

wire hk_out;
reg [LEN_IN-1:0] cnt_out;
wire [LEN_IN-1:0] order_output;
wire [3:0] addr_output;
wire [1:0] addr_output_DIF_1, addr_output_DIF_0;
wire is_last_output[0:N_MEM-1];
reg outputting[0:N_MEM-1];

reg is_DIF[0:N_MEM-1];
wire [N_BANK-1:0] s_we_FFT;
wire [WIDTH_BANK_ADDR*N_BANK-1:0] s_addr_wr_FFT;
wire [WIDTH_BANK_ADDR*N_BANK-1:0] s_addr_rd_FFT;

assign phase = (state == STAGE0) ? 0 :
               (state == STAGE2 || state == WAIT) ? 2 : 1;
assign issue_vld = (state == STAGE0 || state == STAGE1 || state == STAGE2);
assign start_process = (state == IDLE && MEM_rdy[processing_MEM]);
assign is_last_process = (state == WAIT && last_commit);
assign is_DIF_processing_MEM = is_DIF[processing_MEM];

always @(posedge clk) begin
    if (!nrst)
        state <= IDLE;
    else if (state == IDLE) begin
        if (start_process) state <= STAGE0;
    end
    else if (state == STAGE0 && cnt == N_BF-1)
        state <= STAGE_WAIT;
    else if (state == STAGE_WAIT && cnt_wait == STAGE_DEL-1)
        state <= STAGE1;
    else if (state == STAGE1 && cnt == N_BF-1)
        state <= STAGE2;
    else if (state == STAGE2 && cnt == N_BF-1)
        state <= WAIT;
    else if (is_last_process)
        state <= IDLE;
end

always @(posedge clk) begin
    if (!nrst)
        cnt <= 0;
    else if (!issue_vld || cnt == N_BF-1)
        cnt <= 0;
    else
        cnt <= cnt+1'b1;
end

always @(posedge clk) begin
    if (!nrst)
        cnt_wait <= 0;
    else if (state != STAGE_WAIT)
        cnt_wait <= 0;
    else
        cnt_wait <= cnt_wait+1'b1;
end

always @(posedge clk) begin
    if (!nrst)
        processing_MEM <= 0;
    else if (is_last_process)
        processing_MEM <= ~processing_MEM;
end

assign hk_in = in_rdy & in_vld;
assign input_safe = !outputting[input_MEM] ||
                    (input_MEM == output_MEM && cnt_in < cnt_out);
assign in_rdy = inputting[input_MEM] &&
                !(state != IDLE && input_MEM == processing_MEM) && input_safe;
assign order_input = cnt_in;
assign input_BANK = order_input[LEN_IN-1:LEN_IN-LOG2_N_BANK];
assign addr_input_DIT_1 = input_BANK-order_input[1:0];
assign addr_input_DIT_0 = input_BANK-order_input[3:2];
assign addr_input = (is_DIF[input_MEM]) ? order_input[3:0] :
                   {addr_input_DIT_1,addr_input_DIT_0};

always @(posedge clk) begin : WHICH_MEM_IS_IN_INPUT
    if (!nrst)
        input_MEM <= 0;
    else if (hk_in && cnt_in == N-1)
        input_MEM <= ~input_MEM;
end

always @(posedge clk) begin : INPUT_COUNTER
    if (!nrst)
        cnt_in <= 0;
    else if (hk_in)
        cnt_in <= cnt_in+1'b1;
end

assign hk_out = out_rdy & out_vld;
assign rd_output = outputting[output_MEM] && (!out_vld || hk_out);
assign order_output = cnt_out;
assign output_BANK = order_output[LEN_IN-1:LEN_IN-LOG2_N_BANK];
assign addr_output_DIF_1 = output_BANK-order_output[1:0];
assign addr_output_DIF_0 = output_BANK-order_output[3:2];
assign addr_output = (is_DIF[output_MEM]) ? order_output[3:0] :
                    {addr_output_DIF_1,addr_output_DIF_0};

always @(posedge clk) begin : WHICH_MEM_IS_IN_OUTPUT
    if (!nrst)
        output_MEM <= 0;
    else if (rd_output && cnt_out == N-1)
        output_MEM <= ~output_MEM;
end

always @(posedge clk) begin : OUTPUT_COUNTER
    if (!nrst)
        cnt_out <= 0;
    else if (rd_output)
        cnt_out <= cnt_out+1'b1;
end

always @(posedge clk) begin
    if (!nrst)
        out_vld <= 0;
    else if (rd_output)
        out_vld <= 1;
    else if (hk_out)
        out_vld <= 0;
end

for (i=0; i<N_MEM; i=i+1) begin
    assign MEM_rdy[i] = inputting[i] == 0 && outputting[i] == 0;
    assign is_last_input[i] = (input_MEM == i && hk_in && cnt_in == N-1);
    assign is_last_output[i] = (output_MEM == i && rd_output && cnt_out == N-1);

    always @(posedge clk) begin : IS_DIT_OR_DIF
        if (!nrst)
            is_DIF[i] <= 0;
        else if (processing_MEM == i && is_last_process)
            is_DIF[i] <= ~is_DIF[i];
    end

    always @(posedge clk) begin : IS_THE_MEM_INPUTTING
        if (!nrst)
            inputting[i] <= 1;
        else if (is_last_input[i])
            inputting[i] <= 0;
        else if (processing_MEM == i && is_last_process)
            inputting[i] <= 1;
    end

    always @(posedge clk) begin : IS_THE_MEM_OUTPUTTING
        if (!nrst)
            outputting[i] <= 0;
        else if (is_last_output[i])
            outputting[i] <= 0;
        else if (processing_MEM == i && is_last_process)
            outputting[i] <= 1;
    end
end

for (i=0; i<N_MEM*N_BANK; i=i+1) begin
    wire we_input;
    wire we_FFT;
    wire rd_FFT;
    wire rd_output_BANK;

    assign we_input = (hk_in && input_MEM == i/N_BANK && input_BANK == i%N_BANK);
    assign we_FFT = (s_we_FFT[i%N_BANK] && processing_MEM == i/N_BANK);
    assign rd_FFT = (issue_vld && processing_MEM == i/N_BANK);
    assign rd_output_BANK = (rd_output && output_MEM == i/N_BANK && output_BANK == i%N_BANK);
    assign s_we_BANK[i] = we_input || we_FFT;
    assign s_addr_wr_BANK[(i+1)*WIDTH_BANK_ADDR-1:i*WIDTH_BANK_ADDR] =
        (we_input) ? {4'b0000,addr_input} :
        s_addr_wr_FFT[(i%N_BANK+1)*WIDTH_BANK_ADDR-1:(i%N_BANK)*WIDTH_BANK_ADDR];
    assign s_addr_rd_BANK[(i+1)*WIDTH_BANK_ADDR-1:i*WIDTH_BANK_ADDR] =
        (rd_FFT) ? s_addr_rd_FFT[(i%N_BANK+1)*WIDTH_BANK_ADDR-1:(i%N_BANK)*WIDTH_BANK_ADDR] :
        (rd_output_BANK) ? {4'b0000,addr_output} : {WIDTH_BANK_ADDR{1'b1}};
end

AGU #(
    N_BANK, N_DATAPATH, WIDTH_BANK_ADDR, WIDTH_CROM_ADDR,
    LEN_CNT, N_BF, PIPELINE_LVL,
    IDLE, STAGE0, STAGE1, STAGE2, WAIT
) address_generator (
    nrst, clk,
    cnt, state, is_DIF_processing_MEM,
    s_we_FFT, s_addr_wr_FFT, s_addr_rd_FFT,
    sel_swap_in, sel_swap_out,
    s_addr_CROM, last_commit
);
endmodule
