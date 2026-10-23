module tb_rx_controller();
    
    int clk_period = 10;
    int rx_clk_rate = 10;
    
    logic [31:0] cnt = 0;
    logic [31:0] rx_cnt = 0;
    
    logic clk, nrst;
    logic rx_clk;
    logic start;
    logic clock_enable;
    logic rx_valid;
    
    rx_controller #(
        .OVERSAMPLING_RATE(16),
        .BITWIDTH(8)
    ) dut (
        .clk(clk),
        .nrst(nrst),
        .rx_clk(rx_clk),
        .start(start),
        .clock_enable(clock_enable),
        .rx_valid(rx_valid)
    );
    
    
    always #(clk_period/2) clk = ~clk;
    always @(negedge clk) begin
        if (rx_cnt == rx_clk_rate-1) begin
            rx_cnt <= 0;
            start <= $urandom(); 
        end else rx_cnt <= rx_cnt + 1;
    end
    always @(negedge clk) begin
        if (cnt == rx_clk_rate/2-2) begin 
            rx_clk <= 0;
            #(clk_period/2);
            rx_clk <= 1;
        end
        
        if (clock_enable) begin
            if (cnt == rx_clk_rate-1) cnt <= 0;
            else                      cnt <= cnt + 1;
        end else begin
            cnt <= 0;
        end     
    end
    
    initial begin
        clk = 1;
        rx_clk = 1;
        nrst = 0;
        start = 0;
    
        #(clk_period/2-3);
        nrst = 1;
    
        #(clk_period*3000);        
        $finish;
    end
    
endmodule