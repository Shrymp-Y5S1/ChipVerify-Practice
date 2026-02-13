class my_monitor extends uvm_monitor;
  // 从uvm_monitor继承，my_monitor是一个监视器组件类
  `uvm_component_utils(my_monitor)
  // 注册类，以便UVM的factory机制能够识别和使用它，注意这里是uvm_component_utils而不是uvm_object_utils，因为my_monitor是一个组件类
  // 构造函数，默认名称为my_monitor，接受一个父组件作为参数
  function new(string name = "my_monitor", uvm_component parent);
    super.new(name, parent);  // 调用父类的构造函数，传递名称和父组件
  endfunction

  // 虽然在my_monitor的reset_phase没有使用raise_objection和drop_objection方法，但只要要其他组件的reset_phase中调用了这些方法，UVM的objection机制就会确保reset_phase不会提前结束，从而保证所有组件都有机会完成它们的reset_phase任务（在有objection的同名phase未执行完消耗时间的语句前）
  virtual task reset_phase(uvm_phase phase);
    #50;
    `uvm_info("MON_RESET_PHASE", "Monitor reset complete", UVM_MEDIUM)
  endtask

  // 定义run_phase任务，这是UVM组件的一个生命周期方法，在仿真运行阶段被调用。uvm_phase类型的参数phase表示当前的仿真阶段
  virtual task run_phase(uvm_phase phase);
    forever begin
      // 在监视器的run_phase中，我们可以添加代码来监视信号或总线的活动。这里我们简单地打印一条信息，并等待一段时间。
      `uvm_info("MON_RUN_PHASE", "Monitor run", UVM_MEDIUM)
      #100;
    end
  endtask

endclass
