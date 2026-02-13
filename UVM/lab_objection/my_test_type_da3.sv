class my_test_type_da3 extends my_test;

  `uvm_component_utils(my_test_type_da3)

  function new(string name = "my_test_type_da3", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 在build_phase中使用工厂方法set_type_override_by_type将my_transaction的类型覆盖为my_transaction_da3，这样在仿真过程中，当需要创建my_transaction类型的对象时，实际上会创建my_transaction_da3类型的对象，从而应用my_transaction_da3中定义的约束条件（da == 3）
    set_type_override_by_type(my_transaction::get_type(), my_transaction_da3::get_type());
  endfunction

  // 在report_phase中调用父类的report_phase方法，并使用工厂的print方法打印当前工厂中注册的类型信息，这有助于验证类型覆盖是否成功，以及查看当前工厂中有哪些类型被注册和覆盖
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    factory.print();
  endfunction

endclass
