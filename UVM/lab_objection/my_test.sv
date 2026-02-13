class my_test extends uvm_test;
  // 从uvm_test继承，my_test是一个测试组件类
  // 注册类，以便UVM的factory机制能够识别和使用它，注意这里是uvm_component_utils而不是uvm_object_utils，因为my_test是一个组件类
  `uvm_component_utils(my_test)

  // 为测试内部的组件：环境声明句柄
  my_environment my_env;

  // 构造函数，默认名称为my_test，接受一个父组件作为参数
  function new(string name = "my_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // 在build_phase中创建测试内部的组件实例，并将当前测试作为它们的父组件
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    my_env = my_environment::type_id::create("my_env", this);
    // 在build_phase中设置配置项，使用uvm_config_db将my_sequence的类型注册到my_seqr的run_phase中，这样当my_seqr的run_phase被调用时，就会使用my_sequence作为默认序列
    uvm_config_db#(uvm_object_wrapper)::set(this, "*.my_seqr.run_phase", "default_sequence",
                                            my_sequence::get_type());
  endfunction

  // 在start_of_simulation_phase中打印组件层次结构
  virtual function void start_of_simulation_phase(uvm_phase phase);
    // 调用父类的start_of_simulation_phase方法，确保父类的行为得到执行
    super.start_of_simulation_phase(phase);
    // 使用uvm_top.print_topology方法打印组件层次结构，参数uvm_default_tree_printer指定使用默认的树形打印器来格式化输出
    uvm_top.print_topology(uvm_default_tree_printer);
  endfunction

endclass
