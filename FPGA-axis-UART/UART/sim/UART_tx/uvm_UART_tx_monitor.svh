// 모니터: TX 핀 파형을 8N1 바이트로 복원해 공통 scoreboard에 전달한다.
class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    virtual UART_tx_if vif;
    uvm_analysis_port #(observation) actual_ap;

    // 생성자
    function new(string name, uvm_component parent);
        super.new(name, parent);
        actual_ap = new("actual_ap", this);
    endfunction

    // 설정 단계: 인터페이스 핸들을 가져온다.
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual UART_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "TX interface is missing")
    endfunction

    // 실행 단계
    task run_phase(uvm_phase phase);
        observation obs;
        wait (vif.nrst === 1'b1);
        // Reset must leave the UART line at idle high.
        @(vif.cb);
        if (vif.cb.txd !== 1'b1)
            `uvm_error("TX_IDLE", "TX must be high after reset")

        forever begin
            @(negedge vif.txd);
            if (vif.nrst === 1'b1) begin
                #(vif.bit_period / 2);
                if (vif.txd !== 1'b0) begin
                    `uvm_error("TX_START", "Invalid start bit")
                end else begin
                    obs = observation::type_id::create("obs");
                    // Decode 8N1 independently from the DUT's internal clock
                    // and controller state; preserve X/Z in received data.
                    for (int i = 0; i < 8; i++) begin
                        #(vif.bit_period);
                        obs.data[i] = vif.txd;
                    end
                    #(vif.bit_period);
                    if (vif.txd !== 1'b1)
                        `uvm_error("TX_STOP", "Stop bit must be high")
                    actual_ap.write(obs);
                end
            end
        end
    endtask
endclass
