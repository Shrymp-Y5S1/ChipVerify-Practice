class master_agent extends uvm_agent;
  // 从uvm_agent继承，master_agent是一个agent组件类
  `uvm_component_utils(master_agent)

  // 为agent内部的组件：sequencer、driver和monitor声明句柄
  my_sequencer my_seqr;
  my_driver my_driv;
  my_monitor my_moni;

  // 构造函数，默认名称为master_agent，接受一个父组件作为参数
  function new(string name = "master_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 在build_phase中创建agent内部的组件实例，并将当前agent作为它们的父组件
    // 使用UVM的factory机制创建组件实例，注意这里是uvm_component_utils注册的类，所以使用create方法来创建组件实例
    if (is_active == UVM_ACTIVE) begin  // is_active和UVM_ACTIVE是UVM中用于判断组件是否处于激活状态的变量和常量，只有当agent处于激活状态时才创建sequencer和driver组件
      my_seqr = my_sequencer::type_id::create("my_seqr", this);
      // 创建sequencer组件实例，名称为my_seqr，父组件为当前agent
      my_driv = my_driver::type_id::create("my_driv", this);
    end
    my_moni = my_monitor::type_id::create("my_moni", this);
  endfunction

  // 在connect_phase中连接agent内部组件之间的端口
  virtual function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) begin
      my_driv.seq_item_port.connect(my_seqr.seq_item_export);
      // seq_item_port.connect和seq_item_export是UVM中用于连接组件之间的端口的方法，这里将driver的seq_item_port端口连接到sequencer的seq_item_export端口，使得driver能够从sequencer获取事务
    end
  endfunction

endclass
