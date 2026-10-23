`timescale 1ns/1ps
// RX 드라이버와 모니터를 먼저 정의한 뒤 공통 조립 클래스를 포함한다.
// TX 패키지에서도 TX 폴더의 driver/monitor를 먼저 포함하면 같은 구조를 사용할 수 있다.
package tb_UART_rx_pkg;

    import uvm_pkg::*;
    import uart_pkg::*;
    `include "uvm_macros.svh"

    `include "uvm_UART_rx_driver.svh"
    `include "uvm_UART_rx_monitor.svh"

    `include "UART_agent.svh"
    `include "UART_env.svh"
    `include "UART_test.svh"

endpackage
