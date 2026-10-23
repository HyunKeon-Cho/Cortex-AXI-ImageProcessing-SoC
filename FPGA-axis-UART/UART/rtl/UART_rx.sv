module UART_rx #(
    parameter int unsigned OVERSAMPLING_RATE = 16,
    parameter int unsigned BITWIDTH = 8
) (
    input  logic                           clk,
    input  logic                           nrst,

    input  logic                           indata,
    output logic [7:0]                     outdata,
    output logic                           valid
);

// ********************************
// bit detector
// ********************************
localparam bd_bitwidth = 3;
logic [bd_bitwidth-1:0] bd_fifo;
logic bd_detected_data;

assign bd_detected_data =   (bd_fifo[bd_bitwidth-1] & bd_fifo[bd_bitwidth-2])
                          | (bd_fifo[bd_bitwidth-2] & bd_fifo[bd_bitwidth-3])
                          | (bd_fifo[bd_bitwidth-3] & bd_fifo[bd_bitwidth-1]);

always_ff @(negedge clk or negedge nrst) begin
    if (!nrst) begin
        bd_fifo <= '1;
    end else begin
        bd_fifo <= {bd_fifo[bd_bitwidth-2:0], indata};
    end
end

// ********************************
// FIFO
// ********************************
logic [BITWIDTH:0] fifo;
logic enable;

always_ff @(negedge enable or negedge nrst) begin
    if (!nrst) begin
        fifo <= 0;
    end else begin
        fifo <= {bd_detected_data, fifo[BITWIDTH:1]};
    end
end

// ********************************
// BUF
// ********************************
logic [BITWIDTH-1:0] rx_buf;

assign outdata = rx_buf;

always_ff @(posedge valid or negedge nrst) begin
    if (!nrst) begin
        rx_buf <= 0;
    end else begin
        rx_buf <= fifo[BITWIDTH-1:0];
    end
end

// ********************************
// Controller
// ********************************
rx_controller #(
    .OVERSAMPLING_RATE(OVERSAMPLING_RATE),
    .BITWIDTH(BITWIDTH)
) controller (
    .clk          (clk),
    .indata       (bd_detected_data),
    .nrst         (nrst),
    .enable       (enable),
    .valid     (valid)
);

endmodule
