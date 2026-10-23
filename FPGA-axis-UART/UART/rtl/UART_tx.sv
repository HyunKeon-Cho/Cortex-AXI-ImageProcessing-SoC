module UART_tx #(
    parameter int unsigned OVERSAMPLING_RATE = 16,
    parameter int unsigned BITWIDTH = 8
) (
    input logic clk,
    input logic nrst,
    input logic [BITWIDTH-1:0] indata,
    input logic wr_en,
    output logic ready,
    output logic outdata
);
    // ********************************
    // define logic
    // ********************************
    // shift_BUF
    logic [BITWIDTH-1:0] shift_buf;

    // controller
    logic state_bit;
    logic send;
    logic tx_clk;
    logic enable;
    assign enable = ~ready;

    // ********************************
    // outdata
    // ********************************
    assign outdata = (send) ? shift_buf[0] : state_bit;

    // ********************************
    // cotroller
    // ********************************
    tx_controller #(
        .OVERSAMPLING_RATE(OVERSAMPLING_RATE),
        .BITWIDTH(BITWIDTH)
    ) controller (
        .clk(clk),
        .nrst(nrst),
        .wr_en(wr_en),
        .state_bit(state_bit),
        .send(send),
        .tx_clk(tx_clk),
        .ready(ready)
    );

    // ********************************
    // shift_BUF
    // ********************************
    always @(negedge clk or negedge nrst) begin
        if (!nrst) begin
            shift_buf <= 0;
        end else begin
            if (send) begin
                if (tx_clk == 0) begin
                    shift_buf <= {1'b0, shift_buf[BITWIDTH-1:1]};
                end else begin
                    shift_buf <= shift_buf;
                end
            end else if (wr_en) begin
                shift_buf <= indata;
            end else begin
                shift_buf <= shift_buf;
            end
        end
    end
    
endmodule