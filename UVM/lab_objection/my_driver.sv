class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)

  virtual dut_interface my_vif;  // 声明虚拟接口指针句柄，用于访问接口信号
  int unsigned pad_cycles;  // 声明一个整数变量，用于存储pad_cycles的配置值

  function new(string name = "my_driver", uvm_component parent);
    super.new(name, parent);  // 调用父类的构造函数，传递名称和父组件
  endfunction

  // 在build_phase中获取接口的虚拟指针
  virtual function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(int unsigned)::get(this, "", "pad_cycles", pad_cycles)) begin
      `uvm_fatal("CONFIG_FATAL", "Failed to get pad_cycles from uvm_config_db")
    end
    if (!uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif)) begin
      `uvm_fatal("CONFIG_FATAL", "Failed to get virtual interface from uvm_config_db")
    end

  endfunction

  // 在pre_reset_phase中对接口信号进行初始化，确保在复位之前所有信号都处于已知状态
  virtual task pre_reset_phase(uvm_phase phase);
    super.pre_reset_phase(phase);
    `uvm_info("TRACE", $sformatf("%m"), UVM_HIGH)
    phase.raise_objection(this);
    my_vif.driver_cb.frame_n <= 'x;
    my_vif.driver_cb.valid_n <= 'x;
    my_vif.driver_cb.din     <= 'x;
    my_vif.driver_cb.rst_n   <= 'x;
    phase.drop_objection(this);
  endtask


  virtual task reset_phase(uvm_phase phase);
    super.reset_phase(phase);  // 调用父类的reset_phase方法，确保正确执行复位流程
    `uvm_info("TRACE", $sformatf("%m"), UVM_HIGH)
    phase.raise_objection(this);
    my_vif.driver_cb.frame_n <= '1;
    my_vif.driver_cb.valid_n <= '1;
    my_vif.driver_cb.din     <= '0;
    my_vif.driver_cb.rst_n   <= '1;
    // 等待interface中driver_cb时钟域的5个时钟周期
    repeat (5) @(my_vif.driver_cb);
    my_vif.driver_cb.rst_n <= '0;
    // 再等待interface中driver_cb时钟域的5个时钟周期
    repeat (5) @(my_vif.driver_cb);
    my_vif.driver_cb.rst_n <= '1;
    phase.drop_objection(this);
  endtask

  virtual task configure_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    `uvm_info("DRV_CONFIGURE_PHASE", "NOW driver configure the DUT...", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask

  virtual task run_phase(uvm_phase phase);
    logic [7:0] temp;
    repeat (15) @(my_vif.driver_cb);
    forever begin
      // 从sequence中获取一个transaction对象，存储在继承自uvm_driver的类成员变量req中
      seq_item_port.get_next_item(req);
      `uvm_info("DRV_RUN_PHASE", req.sprint(), UVM_MEDIUM)
      // send address
      my_vif.driver_cb.frame_n[req.sa] <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        my_vif.driver_cb.din[req.sa] <= req.da[i];
        @(my_vif.driver_cb);
      end
      // send pad
      my_vif.driver_cb.din[req.sa]     <= 1'b1;
      my_vif.driver_cb.valid_n[req.sa] <= 1'b1;
      repeat (pad_cycles) @(my_vif.driver_cb);
      // send payload
      while (!my_vif.driver_cb.busy_n[req.sa]) @(my_vif.driver_cb);
      // 用foreach遍历transaction中的payload数组，逐字节发送数据
      // foreach循环：遍历transaction中的payload数组，index是当前元素的索引（index变量由foreach自动生成）
      foreach (req.payload[index]) begin
        temp = req.payload[index];
        for (int i = 0; i < 8; i++) begin
          my_vif.driver_cb.din[req.sa]     <= temp[i];
          my_vif.driver_cb.valid_n[req.sa] <= 1'b0;
          my_vif.driver_cb.frame_n[req.sa] <= ((req.payload.size() - 1) == index) && (i == 7);
          @(my_vif.driver_cb);
        end
      end
      my_vif.driver_cb.valid_n[req.sa] <= 1'b1;

      rsp = my_transaction::type_id::create("rsp");
      $cast(rsp, req.clone());
      rsp.set_id_info(req);
      seq_item_port.put_response(rsp);

      seq_item_port.item_done();  // 通知sequence当前transaction已经完成，可以继续下
    end
  endtask

endclass
