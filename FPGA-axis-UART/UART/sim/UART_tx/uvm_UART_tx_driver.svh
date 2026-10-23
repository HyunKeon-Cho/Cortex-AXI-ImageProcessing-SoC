// 드라이버: 준비된 TX에 바이트와 write 요청을 전달한다.
class driver extends uvm_driver #(item);
    `uvm_component_utils(driver)

    virtual UART_tx_if vif;
    uvm_analysis_port #(item) expected_ap;

    // 생성자
    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_ap = new("expected_ap", this);
    endfunction

    // 설정 단계: 인터페이스 핸들을 가져온다.
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual UART_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "TX interface is missing")
    endfunction

    // 실행 단계
    task run_phase(uvm_phase phase);
        item req;

        // 리셋 중에는 write 요청을 비활성화한다.
        vif.cb.wr_en <= 0;
        vif.cb.tx_data <= 0;
        do
            @(vif.cb);
        while (vif.cb.nrst !== 1'b1);

        if (vif.bit_cycles == 0 || vif.bit_period == 0)
            `uvm_fatal("TIMING", "TX bit timing must be positive")

        forever begin
            seq_item_port.get_next_item(req);
            // 송신 준비 확인. 준비되지 않는 DUT도 무한 대기하지 않는다.
            fork
                begin
                    do @(vif.cb); while (vif.cb.ready !== 1'b1);
                end
                begin
                    #(12 * vif.bit_period);
                    `uvm_fatal("TX_READY_TIMEOUT", "TX did not become ready")
                end
            join_any
            disable fork;

            expected_ap.write(req);

            // DUT가 ready를 내릴 때까지 데이터와 write 요청을 유지한다.
            vif.cb.tx_data <= req.data;
            vif.cb.wr_en <= 1;

            fork
                begin
                    do @(vif.cb); while (vif.cb.ready !== 1'b0);
                end
                begin
                    #(12 * vif.bit_period);
                    vif.cb.wr_en <= 0;
                    `uvm_fatal("TX_ACCEPT_TIMEOUT", "TX did not lower ready after a write request")
                end
            join_any
            disable fork;

            vif.cb.wr_en <= 0;

            // 실제 시작 비트를 기다려 write부터 송신 시작까지의 지연을 반영한다.
            fork
                begin
                    do @(vif.cb); while (vif.cb.txd !== 1'b0);
                end
                begin
                    #(12 * vif.bit_period);
                    `uvm_fatal("TX_START_TIMEOUT", "TX did not start after a write request")
                end
            join_any
            disable fork;

            // 8N1 프레임이 끝날 때까지 데이터를 유지한다.
            #(10 * vif.bit_period);
            #(req.gap_bits * vif.bit_period);
            seq_item_port.item_done();
        end
    endtask
endclass
