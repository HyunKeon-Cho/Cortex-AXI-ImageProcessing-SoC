// 트랜잭션: 핀 파형 대신 전송할 바이트와 프레임 사이 간격을 표현하는 객체이다.
class item extends uvm_sequence_item;

    rand bit [7:0]     data;
    rand int unsigned gap_bits;

    constraint c_gap {
        gap_bits inside {[0:3]};
    }

    // 팩토리에 객체를 등록하고 data와 gap_bits를 복사·비교·출력 대상 필드로 등록한다.
    `uvm_object_utils_begin(item)
        `uvm_field_int(data, UVM_DEFAULT)
        `uvm_field_int(gap_bits, UVM_DEFAULT)
    `uvm_object_utils_end

    // 생성자
    function new(string name = "item");
        super.new(name);
    endfunction

endclass
