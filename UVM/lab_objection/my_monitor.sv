class my_monitor extends uvm_monitor;
  // 从uvm_monitor继承，my_monitor是一个监视器组件类
  `uvm_component_utils(my_monitor)
  uvm_blocking_put_port #(my_transaction) m2r_port;
  // 注册类，以便UVM的factory机制能够识别和使用它，注意这里是uvm_component_utils而不是uvm_object_utils，因为my_monitor是一个组件类

  virtual dut_interface my_vif;  // 声明虚拟接口指针句柄，用于访问接口信号

  // 构造函数，默认名称为my_monitor，接受一个父组件作为参数
  function new(string name = "my_monitor", uvm_component parent);
    super.new(name, parent);  // 调用父类的构造函数，传递名称和父组件
  endfunction

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    this.m2r_port = new("m2r_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif)) begin
      `uvm_fatal("CONFIG_FATAL", "Failed to get virtual interface from uvm_config_db")
    end
  endfunction

  // 定义run_phase任务，这是UVM组件的一个生命周期方法，在仿真运行阶段被调用。uvm_phase类型的参数phase表示当前的仿真阶段
  virtual task run_phase(uvm_phase phase);
    my_transaction       tr;
    int                  active_port;
    logic          [7:0] temp;
    int                  count;
    forever begin
      active_port = -1;
      count       = 0;

      tr          = my_transaction::type_id::create("tr");
      // wait for bus active
      while (1) begin
        @(my_vif.i_monitor_cb);
        foreach (my_vif.i_monitor_cb.frame_n[i]) begin
          if (my_vif.i_monitor_cb.frame_n[i] == 0) begin
            active_port = i;
          end
        end
        if (active_port != -1) begin
          break;
        end
      end
      // get the active port id
      tr.sa = active_port;

      // get the target address
      for (int i = 0; i < 4; i++) begin
        tr.da[i] = my_vif.i_monitor_cb.din[tr.sa];
        @(my_vif.i_monitor_cb);
      end

      // get the payload
      forever begin
        if (my_vif.i_monitor_cb.valid_n[tr.sa] == 0) begin
          temp[count] = my_vif.i_monitor_cb.din[tr.sa];
          count++;
          if (count == 8) begin
            tr.payload.push_back(temp);
            count = 0;
          end
        end

        if (my_vif.i_monitor_cb.frame_n[tr.sa]) begin
          if (count != 0) begin
            tr.payload.push_back(temp);
            `uvm_warning("PAYLOAD_WARNING", "Payload not byte aligned")
          end
          break;
        end
        @(my_vif.i_monitor_cb);
      end
      `uvm_info("MONITOR_RUN_PHASE", {"\n", "Monitor got an input transaction: \n", tr.sprint()},
                UVM_MEDIUM)
      `uvm_info("MONITOR", "Monitor send the transaction to reference model...", UVM_MEDIUM)
      this.m2r_port.put(tr);
    end
  endtask

endclass
