module tx_controller #(
    parameter int unsigned OVERSAMPLING_RATE = 16,
    parameter int unsigned BITWIDTH = 8
) (
    input  logic clk,
    input  logic nrst,
    input  logic wr_en,
    output logic state_bit,
    output logic send,
    output logic tx_clk,
    output logic ready
);
    localparam int COUNTER_BITWIDTH = (OVERSAMPLING_RATE > 1) ? $clog2(OVERSAMPLING_RATE) : 1;
    localparam int TX_COUNTER_BITWIDTH = (BITWIDTH > 1) ? $clog2(BITWIDTH) : 1;
    typedef enum logic [3:0] {
        IDLE = 4'b0001, IN = 4'b0010, PROC = 4'b0100, OUT = 4'b1000
    } state_t;
    state_t cstate, nstate;
    logic [COUNTER_BITWIDTH-1:0] cnt;
    logic [TX_COUNTER_BITWIDTH-1:0] tx_cnt;
    logic bit_done;

    assign bit_done = (cnt == OVERSAMPLING_RATE-1);
    // UART_tx shifts at the falling clk edge that completes each data bit.
    assign tx_clk = !bit_done;
    assign send = (cstate == PROC);
    assign ready = (cstate == IDLE || cstate == OUT);
    assign state_bit = (cstate == IDLE || cstate == OUT);

    always_ff @(negedge clk or negedge nrst) begin
        if (!nrst) begin
            cstate <= IDLE;
            cnt <= '0;
            tx_cnt <= '0;
        end else begin
            cstate <= nstate;
            if (cstate == IDLE || bit_done) cnt <= '0;
            else cnt <= cnt + 1'b1;
            if (cstate != PROC) tx_cnt <= '0;
            else if (bit_done) tx_cnt <= tx_cnt + 1'b1;
        end
    end

    always_comb begin
        nstate = cstate;
        case (cstate)
            IDLE: if (wr_en) nstate = IN;
            IN: if (bit_done) nstate = PROC;
            PROC: if (bit_done && tx_cnt == BITWIDTH-1) nstate = OUT;
            // Complete a full stop bit, then start a full start bit.
            OUT: if (bit_done) nstate = wr_en ? IN : IDLE;
            default: nstate = IDLE;
        endcase
    end
endmodule
