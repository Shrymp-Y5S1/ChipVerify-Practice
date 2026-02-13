class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)

  function new(string name = "my_driver", uvm_component parent);
    super.new(name, parent);  // 调用父类的构造函数，传递名称和父组件
  endfunction

  // 添加reset_phase，其中未加入raise_objection和drop_objection方法，仿真时不会打印DRV_RESET_PHASE的信息
  virtual task reset_phase(uvm_phase phase);
    #100;
    `uvm_info("DRV_RESET_PHASE", "NOW driver reset the DUT...", UVM_MEDIUM)
  endtask

  // 添加configure_phase，其中加入raise_objection和drop_objection方法，确保在configure_phase期间测试不会结束，仿真时会打印DRV_CONFIGURE_PHASE的信息
  virtual task configure_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    `uvm_info("DRV_CONFIGURE_PHASE", "NOW driver configure the DUT...", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask

  virtual task run_phase(uvm_phase phase);
    #3000;  // 在run_phase开始时等待一段时间，模拟驱动器的启动延迟
    my_transaction req;
    forever begin
      seq_item_port.get_next_item(req);

      `uvm_info("DRV_RUN_PHASE", req.sprint(), UVM_MEDIUM)
      #100;
      seq_item_port.item_done();
    end
  endtask

endclass
