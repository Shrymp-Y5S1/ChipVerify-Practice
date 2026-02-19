class agent_config extends uvm_object;
  `uvm_object_utils(agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE
      ;  // 通过内置的枚举类型定义一个枚举类型成员变量，表示Agent的类型（主动或被动）
  int unsigned pad_cycles = 5;
  virtual dut_interface my_vif;

  `uvm_object_utils_begin(agent_config)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
    `uvm_field_int(pad_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "agent_config");
    super.new(name);  // 调用父类的构造函数，传递名称
  endfunction
endclass
