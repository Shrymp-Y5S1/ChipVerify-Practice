class my_environment extends uvm_env;
  // 从uvm_env继承，my_env是一个环境组件类
  // 注册类，以便UVM的factory机制能够识别和使用它
  `uvm_component_utils(my_environment)
  // 为环境内部的组件：agent声明句柄
  master_agent my_agent;

  // 构造函数，默认名称为my_environment，接受一个父组件作为参数
  function new(string name = "my_environment", uvm_component parent);
    super.new(name, parent);
  endfunction

  // 在build_phase中创建环境内部的组件实例，并将当前环境作为它们的父组件
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 使用UVM的factory机制创建组件实例，注意这里是uvm_component_utils注册的类，所以使用create方法来创建组件实例
    my_agent = master_agent::type_id::create("my_agent", this);
    // ...
  endfunction

endclass
