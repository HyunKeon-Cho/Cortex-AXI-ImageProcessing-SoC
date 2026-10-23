`timescale 1ns/1ps
// 방향과 무관한 데이터·시퀀스·스코어보드 타입은 한 번만 정의한다.
package uart_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "UART_item.svh"
    `include "UART_observation.svh"
    `include "UART_sequencer.svh"
    `include "UART_scoreboard.svh"
    `include "UART_sequence.svh"

endpackage
