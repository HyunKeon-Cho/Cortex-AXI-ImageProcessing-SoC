module rx_controller #(
    parameter int unsigned OVERSAMPLING_RATE = 16,
    parameter int unsigned BITWIDTH = 8
)(
    input  logic clk,
    input  logic nrst,
    input  logic indata,
    output logic enable,
    output logic valid
);

localparam  int unsigned COUNTER_BITWIDTH = $clog2(OVERSAMPLING_RATE)+1;
localparam  int unsigned RX_COUNTER_BITWIDTH = $clog2(BITWIDTH)+1;

// ********************************
// logic define
// ********************************
// FSM
typedef enum logic [3:0] {
    IDLE = 4'b0001,
    IN   = 4'b0010,
    PROC = 4'b0100,
    OUT  = 4'b1000
} state_t;

state_t cstate, nstate;

// counter
logic [COUNTER_BITWIDTH-1:0] cnt;
logic [RX_COUNTER_BITWIDTH-1:0] rx_cnt;
logic cnt_reset_triger;
logic rx_cnt_reset_triger;


// ********************************
// counter
// ********************************
assign cnt_reset_triger = nrst & (cnt != OVERSAMPLING_RATE) & cstate[2];

always_ff @(negedge clk or negedge cnt_reset_triger) begin
    if (!cnt_reset_triger) begin
        cnt <= 0;
    end else begin
        cnt <= cnt + 1;
    end
end

assign rx_cnt_reset_triger = nrst & cstate[2];


always_ff @(negedge enable or negedge rx_cnt_reset_triger) begin
    if (!rx_cnt_reset_triger) begin
        rx_cnt <= 0;
    end else begin
        rx_cnt <= rx_cnt + 1;
    end
end

// ********************************
// FSM
// ********************************
always_ff @(negedge clk or negedge nrst) begin
    if (!nrst) begin
        cstate <= IDLE;
    end else begin
        cstate <= nstate;
    end
end

always_comb begin
    nstate = cstate;
    case(cstate) 
        IDLE : begin
            if (indata == 0) begin
                nstate = IN;
            end
        end
        IN : begin
            nstate = PROC;
        end
        PROC : begin
            if (rx_cnt == BITWIDTH+2) begin
                nstate = OUT;
            end
        end
        OUT : begin
            if (indata == 0) begin
                nstate = IN;
            end else begin
                nstate = IDLE;
            end
        end
        default : begin
            nstate = IDLE;
        end
    endcase
end

// ********************************
// reg update
// ********************************

always_ff @(negedge clk or negedge nrst) begin
    if (!nrst) begin     
        valid <= 1'b0;
        enable <= 1'b1;
    end else if (cstate == IN) begin
        valid <= 0;
        enable <= 1'b1;
    end else if (cstate == PROC) begin
        valid <= 0;
        enable <= (cnt == (OVERSAMPLING_RATE >> 1)) ? 1'b0 : 1'b1;
    end else if (cstate == OUT) begin
        valid <= 1;
        enable <= 1'b1;
    end else begin
        valid <= 0;
        enable <= 1'b1;
    end
end

endmodule
