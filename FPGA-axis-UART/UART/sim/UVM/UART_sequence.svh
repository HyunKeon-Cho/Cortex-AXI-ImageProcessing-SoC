// 랜덤 시퀀스: 전송할 바이트와 프레임 사이 간격을 매번 랜덤화한다.
// 시퀀스는 전송 내용을 정하고, 실제 핀 구동은 드라이버가 맡는다.
class uart_sequence extends uvm_sequence #(item);

    `uvm_object_utils(uart_sequence)

    int test_N;

    function new(string name = "uart_sequence");
        super.new(name);
    endfunction

    // 전송할 데이터 구성
    task body();
        item txn;

        for (int i = 0; i < test_N; i++) begin
            txn = item::type_id::create("item");

            start_item(txn);
            if (!txn.randomize()) `uvm_fatal("RAND", "트랜잭션 랜덤화 실패")
            //$display("[TX_ITEM] frame=%0d data=%02h gap_bits=%0d", i + 1, txn.data, txn.gap_bits);
            finish_item(txn);
        end
    endtask

endclass
