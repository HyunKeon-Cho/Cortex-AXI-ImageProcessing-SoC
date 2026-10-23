module top_UART #(
    parameter int unsigned BAUD_DIV_INT_WIDTH  = 16,
    parameter int unsigned BAUD_DIV_FRAC_WIDTH = 16,
    parameter int unsigned OVERSAMPLING_RATE = 16,
    parameter int unsigned BITWIDTH = 8
) (
    input  logic                           clk,
    input  logic                           nrst,
    // UART Interfacce                     
    input  logic                           rxd,
    output logic                           txd,
    // RX                      
    output logic                           rx_valid,
    output logic [BITWIDTH-1:0]                     rx_data,
    // TX                      
    output logic                           tx_ready,
    input  logic                           tx_wr_en,
    input  logic [BITWIDTH-1:0]                     tx_data,
    // baud_div_parameter
    input  logic [BAUD_DIV_INT_WIDTH-1:0]  baud_div_int,
    input  logic [BAUD_DIV_FRAC_WIDTH-1:0] baud_div_frac
);

logic oclk;

clock_generator #(
    .BAUD_DIV_INT_WIDTH  (BAUD_DIV_INT_WIDTH),
    .BAUD_DIV_FRAC_WIDTH (BAUD_DIV_FRAC_WIDTH)
) clk_gen (
    .clk(clk),
    .nrst(nrst),
    .div_int(baud_div_int),
    .div_frac  (baud_div_frac),
    .oclk(oclk)
);

UART_rx #(
    .OVERSAMPLING_RATE(OVERSAMPLING_RATE),
    .BITWIDTH(BITWIDTH)
) rx (
    .clk            (oclk),
    .nrst           (nrst),
    .indata         (rxd),
    .outdata        (rx_data),
    .valid          (rx_valid)
);

UART_tx #(
    .OVERSAMPLING_RATE(OVERSAMPLING_RATE),
    .BITWIDTH(BITWIDTH)
) tx (
    .clk    (oclk),
    .nrst   (nrst),
    .indata (tx_data),
    .wr_en  (tx_wr_en),
    .ready  (tx_ready),
    .outdata(txd)
);

endmodule
