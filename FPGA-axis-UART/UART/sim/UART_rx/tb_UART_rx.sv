`timescale 1ns/1ps

module tb_UART_rx;
    import uvm_pkg::*;
    import tb_UART_rx_pkg::*;

    // ********************************
    // hyperparameters
    // ********************************
    // clock
    localparam int INTERNAL_CLK_RATE = 50_000_000;
    localparam time CLK_PERIOD = 1s / INTERNAL_CLK_RATE;

    // DUT
    localparam int BAUD_DIV_INT_WIDTH = 16;
    localparam int BAUD_DIV_FRAC_WIDTH = 16;
    localparam int OVERSAMPLING_RATE = 16;
    localparam int BITWIDTH = 8;
    
    // UART
    localparam int UART_BAUD_RATE = 9600;
    localparam int TEST_N = 32;
    localparam int CHANNEL_SKEW_RATE = 50; // 0.1% units: 50 means +/-5% per bit.
    localparam int CHANNEL_NOISE_RATE = 10; // 0.1% units: 10 means 1% per clock.

    // UART timing has one source: UART_BAUD_RATE. Round up to the
    // system-clock resolution used by the UVM driver.
    localparam int BIT_CYCLES = int'($ceil(real'(INTERNAL_CLK_RATE) / UART_BAUD_RATE));
    localparam time BIT_PERIOD = BIT_CYCLES * CLK_PERIOD;

    // oclk toggles twice per oversampling period. The current RTL stalls
    // its integer counter on fractional carry: D = (I - f) / (1 - f).
    localparam real OVERSAMPLING_DIV = real'(INTERNAL_CLK_RATE)
                                      / (UART_BAUD_RATE * OVERSAMPLING_RATE * 2.0);
    localparam int BAUD_DIV_INT = int'($floor(OVERSAMPLING_DIV));
    localparam int BAUD_DIV_FRAC = int'(
        (OVERSAMPLING_DIV - BAUD_DIV_INT) / (OVERSAMPLING_DIV - 1.0)
        * (2.0 ** BAUD_DIV_FRAC_WIDTH));

    // Each 8N1 frame takes 10 bits plus up to 3 idle bits. Reserve another
    // 12 bits for the final receive, 2 for duplicate detection, and 2 margin.
    localparam time MAX_BIT_PERIOD = int'($ceil(
        BIT_CYCLES * (1.0 + CHANNEL_SKEW_RATE / 1000.0))) * CLK_PERIOD;
    localparam time TEST_TIMEOUT = 13 * TEST_N * MAX_BIT_PERIOD + 16 * BIT_PERIOD;

    // ********************************
    // clock
    // ********************************
    bit clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;
    
    // ********************************
    // UVM
    // ********************************
    UART_rx_if uart_if(clk);
    
    // ********************************
    // DUT
    // ********************************
    // TX is unused in the RX test: disable writes and terminate outputs.
    logic unused_txd;
    logic unused_tx_ready;

    top_UART
`ifndef UART_SYNTH_NETLIST
    #(
        .BAUD_DIV_INT_WIDTH(BAUD_DIV_INT_WIDTH), 
        .BAUD_DIV_FRAC_WIDTH(BAUD_DIV_FRAC_WIDTH),
        .OVERSAMPLING_RATE(OVERSAMPLING_RATE), 
        .BITWIDTH(BITWIDTH)
    )
`endif
    dut (
        .clk(clk), 
        .nrst(uart_if.nrst), 
        .rxd(uart_if.indata),
        .txd(unused_txd),
        .rx_data(uart_if.outdata), 
        .rx_valid(uart_if.valid),
        .tx_ready(unused_tx_ready),
        .tx_wr_en(1'b0),
        .tx_data(8'h00),
        .baud_div_int(uart_if.baud_div_int), 
        .baud_div_frac(uart_if.baud_div_frac)
    );

    // ********************************
    // main
    // ********************************
    initial begin
        uvm_report_server server;
        uvm_root root;

        // UVM setup
        if (UART_BAUD_RATE <= 0 || BAUD_DIV_INT < 2
            || BAUD_DIV_INT >= (2.0 ** BAUD_DIV_INT_WIDTH))
            $fatal(1, "UART baud rate is outside the supported divider range");

        uart_if.bit_cycles = BIT_CYCLES;
        uart_if.baud_div_int = BAUD_DIV_INT;
        uart_if.baud_div_frac = BAUD_DIV_FRAC;

        uvm_config_db#(virtual UART_rx_if)::set(null, "uvm_test_top*", "vif", uart_if);
        uvm_config_db#(time)::set(null, "uvm_test_top", "bit_period", BIT_PERIOD);
        uvm_config_db#(int)::set(null, "uvm_test_top", "test_N", TEST_N);
        uvm_config_db#(int)::set(null, "uvm_test_top.env.agent.driver",
                                "channel_skew_rate", CHANNEL_SKEW_RATE);
        uvm_config_db#(int)::set(null, "uvm_test_top.env.agent.driver",
                                "channel_noise_rate", CHANNEL_NOISE_RATE);

        $display("UART timing: baud=%0d bit_cycles=%0d bit_period=%0t timeout=%0t",
                 UART_BAUD_RATE, BIT_CYCLES, BIT_PERIOD, TEST_TIMEOUT);

        root = uvm_root::get();
        root.finish_on_completion = 0;
        
        // run
        run_test("test");

        // scoreboard check
        server = uvm_report_server::get_server();
        if (server.get_severity_count(UVM_ERROR) != 0 || server.get_severity_count(UVM_FATAL) != 0) begin
            $display("RESULT: FAIL");
            $fatal(1, "UART UVM test failed; inspect the UVM report");
        end
            
        $display("RESULT: PASS");
        $display("UART_UVM_PASS");
        $finish;
    end

    // UVM reset
    initial begin
        repeat (8) @(posedge clk);
        uart_if.nrst <= 1;
    end
    
    // UVM timeout
    initial begin
        wait (uart_if.nrst === 1'b1);

        #(TEST_TIMEOUT);
        $display("RESULT: FAIL");
        $fatal(1, "UART UVM simulation timeout");
    end
endmodule
