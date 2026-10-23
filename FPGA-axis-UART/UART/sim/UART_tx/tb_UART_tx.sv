`timescale 1ns/1ps

module tb_UART_tx;
    import uvm_pkg::*;
    import uart_pkg::*;
    import tb_UART_tx_pkg::*;

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

    // TX may take one bit to start after a write request. Allow ten frame
    // bits, up to three idle bits, and sixteen bits for the final checks.
    localparam time TEST_TIMEOUT = 14 * TEST_N * BIT_PERIOD + 16 * BIT_PERIOD;

    // ********************************
    // clock
    // ********************************
    bit clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ********************************
    // UVM
    // ********************************
    UART_tx_if uart_if(clk);

    // ********************************
    // DUT
    // ********************************
    // RX is unused in the TX test: hold rxd at idle and terminate outputs.
    logic [BITWIDTH-1:0] unused_rx_data;
    logic unused_rx_valid;

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
        .rxd(1'b1),
        .txd(uart_if.txd),
        .rx_data(unused_rx_data),
        .rx_valid(unused_rx_valid),
        .tx_ready(uart_if.ready),
        .tx_wr_en(uart_if.wr_en),
        .tx_data(uart_if.tx_data),
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
        uart_if.bit_period = BIT_PERIOD;
        uart_if.baud_div_int = BAUD_DIV_INT;
        uart_if.baud_div_frac = BAUD_DIV_FRAC;

        uvm_config_db#(virtual UART_tx_if)::set(null, "uvm_test_top*", "vif", uart_if);
        uvm_config_db#(time)::set(null, "uvm_test_top", "bit_period", BIT_PERIOD);
        uvm_config_db#(int)::set(null, "uvm_test_top", "test_N", TEST_N);

        $display("UART timing: baud=%0d bit_cycles=%0d bit_period=%0t timeout=%0t",
                 UART_BAUD_RATE, BIT_CYCLES, BIT_PERIOD, TEST_TIMEOUT);

        root = uvm_root::get();
        root.finish_on_completion = 0;

        // TX keeps the shared scoreboard and reports data mismatches as errors.
        scoreboard::type_id::set_type_override(tx_scoreboard::get_type());

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
