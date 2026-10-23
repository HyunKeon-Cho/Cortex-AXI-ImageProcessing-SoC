`timescale 1ns/1ps

interface UART_tx_if(input logic clk);
    // RX와 동일하게 TB에서 UART_BAUD_RATE로 계산한다.
    int unsigned bit_cycles = 0;
    logic [15:0] baud_div_int = 0;
    logic [15:0] baud_div_frac = 0;
    time bit_period;

    // input
    logic nrst = 0;
    logic wr_en = 0;
    logic [7:0] tx_data = 0;

    // output
    logic ready;
    logic txd;

    // RX와 동일한 기준 클록에서 입력을 구동하고 출력을 관찰한다.
    clocking cb @(posedge clk);
        default input #1step output #0;
        input nrst, ready, txd;
        output wr_en, tx_data;
    endclocking
endinterface
