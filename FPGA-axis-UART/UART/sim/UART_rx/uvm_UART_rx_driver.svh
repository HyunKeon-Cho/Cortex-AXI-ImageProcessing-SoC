// 드라이버: 트랜잭션을 시작 비트·데이터 비트·정지 비트의 UART 입력 파형으로 바꾼다.
class driver extends uvm_driver #(item);

    `uvm_component_utils(driver)

    virtual UART_rx_if vif;

    uvm_analysis_port #(item) expected_ap;

    int channel_skew_rate;  // TB 설정, 0.1% 단위의 비트 길이 편차
    int channel_noise_rate; // TB 설정, 0.1% 단위의 클록당 입력 반전 확률
    bit indata = 1'b1;           // UART idle 상태

    // 생성자
    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_ap = new("expected_ap", this);
    endfunction

    // 설정 단계: 인터페이스 핸들을 가져온다.
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual UART_rx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "UART interface is missing")

        if (!uvm_config_db#(int)::get(this, "", "channel_skew_rate", channel_skew_rate))
            `uvm_fatal("SKEW", "channel_skew_rate is missing")

        if (!uvm_config_db#(int)::get(this, "", "channel_noise_rate", channel_noise_rate))
            `uvm_fatal("NOISE", "channel_noise_rate is missing")

        if (channel_skew_rate < 0 || channel_skew_rate >= 1000)
            `uvm_fatal("SKEW", "channel_skew_rate must be between 0 and 999")

        if (channel_noise_rate < 0 || channel_noise_rate > 100)
            `uvm_fatal("NOISE", "channel_noise_rate must be between 0 and 100")
    endfunction

    // 지정된 비트 수만큼 구동하며 skew와 noise를 적용한다.
    task clock(int cycles);
        for (int i = 0; i < cycles; i++) begin
            real channel_skew;
            int channel_noise;

            // -rate부터 +rate까지 0.1% 단위로 매 비트의 편차를 선택한다.
            channel_skew =
                (int'($urandom_range(2 * channel_skew_rate, 0))
                - channel_skew_rate) / 1000.0;
            for (int j = 0;
                 j < vif.bit_cycles * (1.0 + channel_skew);
                 j++) begin

                channel_noise = $urandom_range(999, 0);

                // 내부 기준값은 유지하고 실제 입력만 확률적으로 반전한다.
                vif.cb.indata <=
                    (channel_noise < channel_noise_rate)
                    ? ~indata : indata;

                @(vif.cb);
            end
        end
    endtask

    // UART 한 비트 구동
    task drive_bit(bit value);
        indata = value;
        clock(1);
    endtask

    // 실행 단계
    task run_phase(uvm_phase phase);
        item req;

        // 리셋 중에는 UART 입력을 idle 상태로 유지한다.
        indata = 1'b1;
        vif.cb.indata <= indata;

        // X/Z를 리셋 해제 상태로 인정하지 않는다.
        do
            @(vif.cb);
        while (vif.cb.nrst !== 1'b1);

        if (vif.bit_cycles == 0)
            `uvm_fatal("TIMING", "bit_cycles must be positive")

        forever begin
            seq_item_port.get_next_item(req);
            expected_ap.write(req);

            // 시작 비트
            drive_bit(1'b0);

            // 데이터: 최하위 비트부터 전송
            for (int i = 0; i < 8; i++)
                drive_bit(req.data[i]);

            // 정지 비트
            drive_bit(1'b1);

            // 프레임 사이 idle 구간에도 skew와 noise를 적용한다.
            clock(req.gap_bits);

            seq_item_port.item_done();
        end
    endtask

endclass
