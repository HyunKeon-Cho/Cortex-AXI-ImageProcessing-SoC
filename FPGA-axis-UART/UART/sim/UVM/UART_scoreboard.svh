// 하나의 스코어보드에 기대값과 실제값을 따로 전달하는 분석 입력을 선언한다.
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

// 스코어보드: 전송한 바이트와 DUT가 수신한 바이트를 순서대로 비교한다.
class scoreboard extends uvm_scoreboard;

    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_expected #(item, scoreboard) expected_imp;
    uvm_analysis_imp_actual #(observation, scoreboard) actual_imp;

    // 아직 수신 결과와 비교하지 않은 기대값 큐이다. [$]는 크기가 변하는 큐를 뜻한다.
    bit [7:0] pending[$];

    int unsigned sent     = 0;
    int unsigned received = 0;
    int unsigned matched  = 0;

    // 생성자
    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_imp = new("expected_imp", this);
        actual_imp   = new("actual_imp", this);
    endfunction

    // 전송할 기대값 저장
    function void write_expected(item txn);
        // 드라이버가 전송 전에 기대값을 큐 뒤에 넣는다. 객체 대신 데이터 값을 저장한다.
        pending.push_back(txn.data);
        sent++;
    endfunction

    // 수신 결과와 기대값 비교
    // analysis 입력에서도 TX 확장의 비교 함수를 호출할 수 있게 한다.
    virtual function void write_actual(observation txn);
        bit [7:0] expected;

        received++;

        if (pending.size() == 0) begin
            // 기대값 없이 결과가 들어오면 중복 출력 등 예상하지 못한 수신이다.
            `uvm_error(
                "UNEXPECTED",
                $sformatf("frame=%0d expected=N/A received=%08b (unexpected)", received, txn.data)
            )
            return;
        end

        expected = pending.pop_front();

        // 수신 즉시 기대값과 실제값을 8자리 이진수로 출력한다. X/Z도 그대로 표시된다.
        $display(
            "[ %4d ] %08b  →  %08b | %s",
            received, expected, txn.data,
            (txn.data === expected) ? "    " : "FAIL"
        );

        // !==로 비교하면 수신 데이터에 X/Z가 있어도 불일치로 검출한다.
        if (txn.data == expected)
            matched++;
    endfunction

    // 종료 후 누락된 결과 검사
    function void check_phase(uvm_phase phase);
        // 실행이 끝난 뒤 미전송 테스트와 수신되지 않은 기대값을 검사한다.
        super.check_phase(phase);
        if (sent == 0)
            `uvm_error("EMPTY", "No UART frames were sent")

        if (pending.size() != 0)
            `uvm_error(
                "MISSING",
                $sformatf("%0d UART frames were not received", pending.size())
            )
    endfunction

    // 검증 결과 요약
    function void report_phase(uvm_phase phase);
        // 마지막에 전송 수·수신 수·일치 수를 요약한다.
        super.report_phase(phase);
        $display("------------------------------------------------");
        $display("SENT      %4d   RECV      %4d", sent, received);
        $display("MATCH     %4d   MISMATCH  %4d", matched, received - matched);
        $display("PENDING   %4d", pending.size());
        $display("------------------------------------------------");
    endfunction

endclass
