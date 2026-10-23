`timescale 1ns/1ps
// TX 드라이버와 모니터를 정의한 뒤 RX와 같은 공통 조립 클래스를 포함한다.
package tb_UART_tx_pkg;

    import uvm_pkg::*;
    import uart_pkg::*;
    `include "uvm_macros.svh"

    `include "uvm_UART_tx_driver.svh"
    `include "uvm_UART_tx_monitor.svh"

    `include "UART_agent.svh"
    `include "UART_env.svh"
    `include "UART_test.svh"

    // 공통 scoreboard를 상속하고 TX의 데이터 불일치만 오류로 보고한다.
    class tx_scoreboard extends scoreboard;

        `uvm_component_utils(tx_scoreboard)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void write_actual(observation txn);
            bit had_expected;
            bit [7:0] expected;

            had_expected = (pending.size() != 0);
            if (had_expected)
                expected = pending[0];

            super.write_actual(txn);
            if (had_expected && txn.data !== expected)
                `uvm_error(
                    "TX_MISMATCH",
                    $sformatf("expected=%02h actual=%02h", expected, txn.data)
                )
        endfunction

    endclass

endpackage
