// 모니터: DUT 신호를 관찰만 하고, valid가 알려 주는 수신 결과를 스코어보드로 전달한다.
class monitor extends uvm_monitor;

    `uvm_component_utils(monitor)

    virtual UART_rx_if vif;

    uvm_analysis_port #(observation) actual_ap;

    // 생성자
    function new(string name, uvm_component parent);
        super.new(name, parent);
        actual_ap = new("actual_ap", this);
    endfunction

    // 설정 단계: 인터페이스 또는 하위 컴포넌트 준비
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual UART_rx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "UART interface is missing")
    endfunction

    // 실행 단계
    task run_phase(uvm_phase phase);
        // 직전 valid를 기억해 연속된 High를 중복 수신으로 처리하지 않고 오류로 보고한다.
        logic previous_valid   = 0;
        bit   unknown_reported = 0;
        observation obs;

        forever begin
            @(vif.cb);

            if (vif.cb.nrst !== 1'b1) begin
                previous_valid   = 0;
                unknown_reported = 0;
            end else begin
                if ($isunknown(vif.cb.valid) && !unknown_reported) begin
                    // 리셋 후 valid의 X/Z는 한 번만 보고해 같은 오류가 반복 출력되는 것을 막는다.
                    `uvm_error("VALID_X", "valid contains X/Z after reset")
                    unknown_reported = 1;
                end

                
                if (vif.cb.valid === 1'b1) begin
                    if (previous_valid === 1'b1) begin
                        /*
                        `uvm_error(
                            "VALID_WIDTH",
                            "valid must be high for only one system clock cycle"
                        )*/
                    end else begin
                        obs = observation::type_id::create("obs");
                        // 수신마다 새 객체를 만들어 분석 포트로 전달한다.
                        obs.data = vif.cb.outdata;
                        actual_ap.write(obs);
                    end
                end
                
                previous_valid = vif.cb.valid;
            end
        end
    endtask

endclass
