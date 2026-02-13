class my_test_inst_drvcnt extends my_test;

  `uvm_component_utils(my_test_inst_drvcnt)

  function new(string name = "my_test_inst_drvcnt", uvm_component parent);
    super.new(name, parent);
  endfunction

  // 在build_phase中创建测试内部的组件实例，并将当前测试作为它们的父组件
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    set_inst_override_by_type("my_env.my_agent.my_driv", my_driver::get_type(),
                              my_driver_count::get_type());
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    factory.print();
  endfunction

endclass
