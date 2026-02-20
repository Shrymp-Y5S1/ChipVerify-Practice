class my_adapter extends uvm_reg_adapter;
  `uvm_object_utils(my_adapter)
  function new(string name = "my_adapter");
    super.new(name);
  endfunction

  // 实现reg2bus函数，将寄存器访问转换为总线事务
  function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    // const ref表示rw是一个常量引用，不能修改它的值
    cpu_trans cpu_tr;
    cpu_tr      = cpu_trans::type_id::create("cpu_tr");
    cpu_tr.addr = rw.addr;
    cpu_tr.acc  = (rw.kind == UVM_READ) ? CPU_R : CPU_W;
    if (cpu_tr.acc == CPU_R) cpu_tr.data = rw.data;
    return cpu_tr;
  endfunction

  // 实现bus2reg函数，将总线事务转换为寄存器访问
  function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    // ref表示rw是一个引用，可以修改它的值
    cpu_trans cpu_tr;
    if (!$cast(cpu_tr, bus_item)) begin
      `uvm_fatal("ADAPTER", "Invalid bus item type")
      return;
    end
    rw.kind    = (cpu_tr.acc == CPU_R) ? UVM_READ : UVM_WRITE;
    rw.addr    = cpu_tr.addr;
    rw.byte_en = 0;
    rw.data    = cpu_tr.data;
    rw.status  = UVM_IS_OK;
  endfunction

endclass
