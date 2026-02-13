class my_transaction extends uvm_sequence_item;  // 从uvm_sequence_item继承
  rand bit [3:0] sa;
  rand bit [3:0] da;
  rand reg [7:0] payload[$];  // 动态数组

  // 注册类和成员变量，以便UVM的factory机制能够识别和使用它们
  `uvm_object_utils_begin(my_transaction)
    `uvm_field_int(sa, UVM_ALL_ON)  // 注册普通变量
    `uvm_field_int(da, UVM_ALL_ON)
    `uvm_field_queue_int(payload, UVM_ALL_ON)  // 注册动态数组
  `uvm_object_utils_end

  // 定义一个约束，限制sa和da的范围，以及payload的大小
  constraint Limit {
    sa inside {[0 : 15]};
    da inside {[0 : 15]};
    payload.size() inside {[2 : 4]};
  }

  function new(string name = "my_transaction");  // 构造函数，默认名称为my_transaction
    super.new(name);  // 调用父类的构造函数
  endfunction
endclass
