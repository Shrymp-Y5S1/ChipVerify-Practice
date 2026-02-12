class my_driver extends uvm_driver #(my_transaction);
  // 从uvm_driver继承，并指定my_transaction作为驱动的事务类型
  `uvm_component_utils(my_driver)
  // 注册类，以便UVM的factory机制能够识别和使用它，注意这里是uvm_component_utils而不是uvm_object_utils，因为my_driver是一个组件类

  // 构造函数，默认名称为my_driver，接受一个父组件作为参数
  function new(string name = "my_driver", uvm_component parent);
    super.new(name, parent);  // 调用父类的构造函数，传递名称和父组件
  endfunction

  virtual task run_phase(uvm_phase phase);
    // 定义run_phase任务，这是UVM组件的一个生命周期方法，在仿真运行阶段被调用
    my_transaction req;
    // 定义一个my_transaction类型的变量，用于接收从sequencer传来的事务
    // 进入一个无限循环，持续获取事务并处理它们
    forever begin
      seq_item_port.get_next_item(req);
      // 使用seq_item_port.get_next_item方法从sequencer获取下一个事务，并将其存储在req变量中

      `uvm_info("DRV_RUN_PHASE", req.sprint(), UVM_MEDIUM)
      // 打印获取到的事务的信息，使用sprint方法将事务转换为字符串格式，日志级别为UVM_MEDIUM
      #100;
      seq_item_port.item_done();
      // 使用seq_item_port.item_done方法通知sequencer当前事务已经处理完成，可以获取下一个事务
    end
  endtask

endclass
