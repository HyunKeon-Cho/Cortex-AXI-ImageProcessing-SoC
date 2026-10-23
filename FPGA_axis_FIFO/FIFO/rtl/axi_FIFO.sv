
module axi_FIFO #(
    // bitwidth
    parameter int unsigned BITWIDTH                 = 32,
    // buffer
    parameter int unsigned BUFFER_LOG2_CAPACITY     = 10,
    // Burst mode
    parameter int unsigned AXI_BURST_LEN            = 64-1,
    parameter int unsigned AXI_BURST_SIZE           = 2,
    parameter int unsigned AXI_BURST_BURST          = 1,
    // exclusive access
    parameter int unsigned AXI_EXCLUSIVE            = 0,
    // transition property
    parameter int unsigned AXI_TRANSITION_CACHE     = 0,
    parameter int unsigned AXI_TRANSITION_PORT      = 0,
    parameter int unsigned AXI_QOS                  = 0,
    // address
    parameter int unsigned ID_WIDTH                 = 4,
    parameter int unsigned ADDR_WIDTH               = 32,
    parameter int unsigned ARUSER_WIDTH             = 1,
    parameter int unsigned RUSER_WIDTH              = 1,

    localparam int unsigned DATA_WIDTH              = BITWIDTH,
    localparam int unsigned STRB_WIDTH              = BITWIDTH / 8,
    localparam int unsigned FIFO_BITWIDTH           = BITWIDTH

)(
    input  logic                    aclk,
    input  logic                    aresetn,

    // ********************************
    // Port interface
    // ********************************
    // write
    output logic                             p_wvalid,
    input  logic                             p_wready,
    output logic [FIFO_BITWIDTH-1:0]         p_wdata,
    // read
    input  logic                             p_rvalid,
    output logic                             p_rready,
    input  logic [FIFO_BITWIDTH-1:0]         p_rdata,

    // ********************************
    // AXI4-Full Slave Interface
    // ********************************
    // Write Address Channel (AW)
    input  logic [ID_WIDTH-1:0]     s_axi_awid,     // address
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [7:0]              s_axi_awlen,    // burst mode
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,
    input  logic                    s_axi_awlock,   // exclusive access
    input  logic [3:0]              s_axi_awcache,  // transition
    input  logic [2:0]              s_axi_awprot,
    input  logic [3:0]              s_axi_awqos,    // QoS
    input  logic                    s_axi_awvalid,  // handshake
    output logic                    s_axi_awready,
    // Write Data Channel (W)
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,    // data
    input  logic [STRB_WIDTH-1:0]   s_axi_wstrb,    // strobe
    input  logic                    s_axi_wlast,    // last
    input  logic                    s_axi_wvalid,   // handshake
    output logic                    s_axi_wready,
    // Write Response Channel (B)
    output logic [ID_WIDTH-1:0]     s_axi_bid,      // address
    output logic [1:0]              s_axi_bresp,    // result
    output logic                    s_axi_bvalid,   // handshake
    input  logic                    s_axi_bready,
    // Read Address Channel (AR)
    input  logic [ID_WIDTH-1:0]     s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,
    input  logic                    s_axi_arlock,
    input  logic [3:0]              s_axi_arcache,
    input  logic [2:0]              s_axi_arprot,
    input  logic [3:0]              s_axi_arqos,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    // Read Data Channel (R)
    output logic [ID_WIDTH-1:0]     s_axi_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready
);

typedef enum logic [2:0] {
    WAIT        = 3'b001,
    RUN         = 3'b010,
    RESPONSE    = 3'b100
} state_t;


// ********************************
// write FIFO
// ********************************
// write
logic                   wbuf_wready;
logic                   wbuf_wvalid;
logic [BITWIDTH-1:0]    wbuf_wdata;
// read
logic                   wbuf_rready;
logic                   wbuf_rvalid;
logic [BITWIDTH-1:0]    wbuf_rdata;
// state
logic                   wbuf_full;
logic                   wbuf_empty;

FIFO #(
    .BITWIDTH       (BITWIDTH),
    .ADDRESS_WIDTH  (BUFFER_LOG2_CAPACITY)
) wbuf (
    .rst            (!aresetn),
    .clr            (!aresetn),
    .aclk           (aclk),
    // write
    .wr_rdy         (wbuf_wready),
    .wr_vld         (wbuf_wvalid),
    .wr_din         (wbuf_wdata),
    // read
    .rd_rdy         (wbuf_rready),
    .rd_vld         (wbuf_rvalid),
    .rd_dout        (wbuf_rdata),
    // state
    .full           (wbuf_full),
    .empty          (wbuf_empty)
);

// ************************************
// write
// ************************************
/**** logic ****/
// AW
logic                   aw_hk;      // handshake
logic [ID_WIDTH-1:0]    aw_id;      // address
logic [ADDR_WIDTH-1:0]  aw_addr;
logic [7:0]             aw_len;
// W
logic                   w_hk;
// B
logic                   b_hk;
// controller
state_t                 wstate;

/**** assignment ****/
// AW
assign aw_hk         = s_axi_awready & s_axi_awvalid;
assign s_axi_awready = wstate[0] & ~wbuf_full;

// W
assign w_hk          = s_axi_wvalid & s_axi_wready;
assign wbuf_wvalid   = wstate[1] & s_axi_wvalid;
assign s_axi_wready  = wstate[1] & wbuf_wready;
assign wbuf_wdata    = s_axi_wdata;

// B
assign b_hk          = s_axi_bready & s_axi_bvalid;
assign s_axi_bvalid  = wstate[2];
assign s_axi_bid     = aw_id;
assign s_axi_bresp   = 2'b00;

// device
assign p_wvalid      = wbuf_rvalid;
assign wbuf_rready   = p_wready;
assign p_wdata       = wbuf_rdata;

// controller
always_ff @(posedge aclk or negedge aresetn) begin : write_controller
    if (!aresetn) begin
        wstate <= WAIT;
    end else begin
        case (wstate)
            WAIT    : wstate <= (aw_hk)              ? RUN      : WAIT;
            RUN     : wstate <= (w_hk & s_axi_wlast) ? RESPONSE : RUN;
            RESPONSE: wstate <= (b_hk)               ? WAIT     : RESPONSE;
            default : wstate <= WAIT;
        endcase
    end
end

// AW register
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        aw_id   <= 0;
        aw_addr <= 0;
        aw_len  <= 0;
    end else if (aw_hk) begin
        aw_id   <= s_axi_awid;
        aw_addr <= s_axi_awaddr;
        aw_len  <= s_axi_awlen;
    end else begin
        aw_id   <= aw_id;
        aw_addr <= aw_addr;
        aw_len  <= aw_len;
    end
end


// ********************************
// read FIFO
// ********************************
// write
logic                   rbuf_wready;
logic                   rbuf_wvalid;
logic [BITWIDTH-1:0]    rbuf_wdata;
// read
logic                   rbuf_rready;
logic                   rbuf_rvalid;
logic [BITWIDTH-1:0]    rbuf_rdata;
// state
logic                   rbuf_full;
logic                   rbuf_empty;

FIFO #(
    .BITWIDTH       (BITWIDTH),
    .ADDRESS_WIDTH  (BUFFER_LOG2_CAPACITY)
) rbuf (
    .rst            (!aresetn),
    .clr            (!aresetn),
    .aclk           (aclk),
    // write
    .wr_rdy         (rbuf_wready),
    .wr_vld         (rbuf_wvalid),
    .wr_din         (rbuf_wdata),
    // read
    .rd_rdy         (rbuf_rready),
    .rd_vld         (rbuf_rvalid),
    .rd_dout        (rbuf_rdata),
    // state
    .full           (rbuf_full),
    .empty          (rbuf_empty)
);

// ********************************
// read
// ********************************
/**** logic ****/
// AR
logic                   ar_hk;      // handshake
logic [ID_WIDTH-1:0]    ar_id;      // address
logic [ADDR_WIDTH-1:0]  ar_addr;
logic [7:0]             ar_len;
// R
logic                   r_hk;
// controller
state_t                 rstate;
logic [7:0]             r_cnt;

/**** assignment ****/
// AR
assign ar_hk         = s_axi_arready & s_axi_arvalid;
assign s_axi_arready = rstate[0] & ~rbuf_empty;

// R
assign r_hk          = s_axi_rvalid & s_axi_rready;
assign rbuf_rready   = rstate[1] & s_axi_rready;
assign s_axi_rvalid  = rstate[1] & rbuf_rvalid;
assign s_axi_rdata   = rbuf_rdata;
assign s_axi_rid     = ar_id;
assign s_axi_rresp   = 2'b00;
assign s_axi_rlast   = s_axi_rvalid & (r_cnt == ar_len);

// device
assign rbuf_wvalid   = p_rvalid;
assign p_rready      = rbuf_wready;
assign rbuf_wdata    = p_rdata;

/**** controller ****/
// controller
always_ff @(posedge aclk or negedge aresetn) begin : read_controller
    if (!aresetn) begin
        rstate <= WAIT;
    end else begin
        case (rstate)
            WAIT    : rstate <= (ar_hk)                ? RUN  : WAIT;
            RUN     : rstate <= (r_hk & s_axi_rlast)  ? WAIT : RUN;
            default : rstate <= WAIT;
        endcase
    end
end

// R counter
always_ff @(posedge aclk or negedge aresetn) begin : read_counter
    if (!aresetn) begin
        r_cnt <= 0;
    end else if (rstate == RUN) begin
        if (r_hk && !s_axi_rlast)
            r_cnt <= r_cnt + 1'b1;
    end else begin
        r_cnt <= 0;
    end
end

// AR register
always_ff @(posedge aclk or negedge aresetn) begin : AR_buffer
    if (!aresetn) begin
        ar_id   <= 0;
        ar_addr <= 0;
        ar_len  <= 0;
    end else if (ar_hk) begin
        ar_id   <= s_axi_arid;
        ar_addr <= s_axi_araddr;
        ar_len  <= s_axi_arlen;
    end else begin
        ar_id   <= ar_id;
        ar_addr <= ar_addr;
        ar_len  <= ar_len;
    end
end

endmodule
