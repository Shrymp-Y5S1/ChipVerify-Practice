class my_driver_count extends my_driver;

  `uvm_component_utils(my_driver_count)

  function new(string name = "my_driver_count", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    int i = 0;
    forever begin
      seq_item_port.get_next_item(req);  // 从序列项端口获取下一个事务对象
      `uvm_info("DRV_RUN_PHASE", req.sprint(), UVM_MEDIUM)  // 打印事务对象的信息
      #100;
      `uvm_info("DRV_COUNT", $sformatf("Driver get the %0dth item", i),
                UVM_MEDIUM)  // 打印当前是第几个事务对象
      seq_item_port.item_done();  // 标记事务处理完成
      i++;  // 计数器递增
    end
  endtask

endclass
