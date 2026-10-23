module axi_UART #(
    parameter int unsigned BAUD_DIV_INT_WIDTH  = 16,
    parameter int unsigned BAUD_DIV_FRAC_WIDTH = 16,
    parameter int unsigned OVERSAMPLING_RATE = 16
    parameter int unsigned BITWIDTH = 32;
) (
    // ********************************
    // UART Interface
    // ********************************
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        uart_rxd,
    output logic        uart_txd,

    // RX 
    input  logic        rx_ready,
    output logic        rx_valid,
    output logic [7:0]  rx_data,

    // TX
    output logic        tx_ready,
    input  logic        tx_valid,
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
// internal port handshake
// ************************************
typedef enum logic [1:0] {
    WAIT        = 2'b01,
    RUN         = 2'b10
} state_t;

state_t tx_state;
logic [7:0] tx_buf;
logic [7:0] tx_inner_data;
logic tx_hk;
logic tx_inner_hk;
logic tx_inner_valid;
logic tx_inner_ready;

state_t rx_state;
logic [7:0] rx_buf;
logic [7:0] rx_inner_data;
logic rx_hk;
logic rx_inner_hk;
logic rx_inner_valid;

assign tx_hk = tx_valid & tx_ready;
assign tx_inner_hk = tx_inner_valid & tx_inner_ready;
assign tx_ready = tx_state[0];
assign tx_inner_ready = tx_state[1];
assign tx_data

assign rx_hk = rx_valid & rx_ready;
assign rx_ready = rx_state[0];

logic [7:0] tx_data8;
assign rx_data = {1'b0, rx_buf, 23'b0};
assign tx_data8 = tx_data[7:0];

always_ff @(negedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        tx_state <= WAIT;
    end else begin
        case (tx_state):
            WAIT : tx_state <= (tx_hk) ? RUN : WAIT;
            RUN  : tx_state <= (tx_inner_hk) ? WAIT : RUN;
            default : tx_state <= WAIT; 
        endcase
    end 
end

always_ff @(negedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        rx_state <= RUN;
    end else begin
        case (rx_state):
            WAIT : rx_state <= (rx_hk) ? RUN : WAIT;
            RUN  : rx_state <= (rx_inner_ready) ? WAIT : RUN;
            default : rx_state <= RUN; 
        endcase
    end 
end


always_ff @(negedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        tx_buf <= 0';
    end else if (tx_inner_hk) begin
        tx_buf <= tx_data8;
    end else begin
        tx_buf <= tx_buf;
    end
end

always_ff @(negedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        rx_buf <= 0';
    end else if (rx_inner_ready) begin
        rx_buf <= rx_inner_data;
    end else begin
        rx_buf <= rx_buf;
    end
end


// ************************************
// AXI4-Lite : Baud rate register
// ************************************
logic [BAUD_DIV_INT_WIDTH-1:0] baud_div_int;
logic [BAUD_DIV_FRAC_WIDTH-1:0] baud_div_frac;

// Configuration register block
axi_lite_reg u_regs (
    .s_axi_aclk    (aclk),
    .s_axi_aresetn (aresetn),
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
    .clk           (aclk),
    .nrst          (aresetn),
    .rxd      (uart_rxd),
    .txd      (uart_txd),
    .rx_valid      (rx_inner_valid),
    .rx_data       (rx_inner_data),
    .tx_ready      (tx_inner_ready),
    .tx_valid      (tx_inner_valid),
    .tx_data       (tx_inner_data),
    .baud_div_int  (baud_div_int),
    .baud_div_frac (baud_div_frac)
);

endmodule
