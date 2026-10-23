module axi_UART #(
    parameter int unsigned BAUD_DIV_INT_WIDTH  = 16,
    parameter int unsigned BAUD_DIV_FRAC_WIDTH = 16,
    parameter int unsigned OVERSAMPLING_RATE = 16
) (
    // ********************************
    // UART Interface
    // ********************************
    input  logic        uart_rxd,
    output logic        uart_txd,

    
    // RX 
    output logic        rx_valid,
    output logic [7:0]  rx_data,

    // TX
    output logic        tx_ready,
    input  logic        tx_wr_en,
    input  logic [7:0]  tx_data,
    
    // ********************************
    // AXI4-Lite Slave Interface : Baud rate register
    // ********************************
    input  logic [31:0] s_axil_awaddr,   // Write address
    input  logic [2:0]  s_axil_awprot,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,    // Write data
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,    // Write response
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,
    input  logic [31:0] s_axil_araddr,   // Read address
    input  logic [2:0]  s_axil_arprot,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,    // Read data and response
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready
);
// ************************************
// AXI4-full slave : internal I/O
// ************************************

FIFO #(
    
)

// ************************************
// AXI4-Lite : Baud rate register
// ************************************
logic [BAUD_DIV_INT_WIDTH-1:0] baud_div_int;
logic [BAUD_DIV_FRAC_WIDTH-1:0] baud_div_frac;

// Configuration register block
axi_lite_reg u_regs (
    .s_axi_aclk    (s_axi_aclk),
    .s_axi_aresetn (s_axi_aresetn),
    .s_axi_awaddr  (s_axil_awaddr),
    .s_axi_awprot  (s_axil_awprot),
    .s_axi_awvalid (s_axil_awvalid),
    .s_axi_awready (s_axil_awready),
    .s_axi_wdata   (s_axil_wdata),
    .s_axi_wstrb   (s_axil_wstrb),
    .s_axi_wvalid  (s_axil_wvalid),
    .s_axi_wready  (s_axil_wready),
    .s_axi_bresp   (s_axil_bresp),
    .s_axi_bvalid  (s_axil_bvalid),
    .s_axi_bready  (s_axil_bready),
    .s_axi_araddr  (s_axil_araddr),
    .s_axi_arprot  (s_axil_arprot),
    .s_axi_arvalid (s_axil_arvalid),
    .s_axi_arready (s_axil_arready),
    .s_axi_rdata   (s_axil_rdata),
    .s_axi_rresp   (s_axil_rresp),
    .s_axi_rvalid  (s_axil_rvalid),
    .s_axi_rready  (s_axil_rready),
    .cfg_data      ({baud_div_int, baud_div_frac})
);

// ************************************
// UART 
// ************************************
top_UART #(
    .BAUD_DIV_INT_WIDTH  (BAUD_DIV_INT_WIDTH),
    .BAUD_DIV_FRAC_WIDTH (BAUD_DIV_FRAC_WIDTH),
    .OVERSAMPLING_RATE   (OVERSAMPLING_RATE)
) uart (
    .clk           (s_axi_aclk),
    .nrst          (s_axi_aresetn),
    .rxd      (uart_rxd),
    .txd      (uart_txd),
    .rx_valid      (rx_valid),
    .rx_data       (rx_data),
    .tx_ready      (tx_ready),
    .tx_wr_en      (tx_wr_en),
    .tx_data       (tx_data),
    .baud_div_int  (baud_div_int),
    .baud_div_frac (baud_div_frac)
);

endmodule
