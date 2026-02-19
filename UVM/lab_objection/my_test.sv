class my_test extends uvm_test;
  // 从uvm_test继承，my_test是一个测试组件类
  // 注册类，以便UVM的factory机制能够识别和使用它，注意这里是uvm_component_utils而不是uvm_object_utils，因为my_test是一个组件类
  `uvm_component_utils(my_test)

  // 为测试内部的组件：环境声明句柄
  my_environment my_env;
  env_config my_env_config;

  // 构造函数，默认名称为my_test，接受一个父组件作为参数
  function new(string name = "my_test", uvm_component parent);
    super.new(name, parent);
    my_env_config = env_config::type_id::create("my_env_config");
  endfunction

  // 在build_phase中创建测试内部的组件实例，并将当前测试作为它们的父组件
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    my_env = my_environment::type_id::create("my_env", this);

    // 在build_phase中设置配置项，使用uvm_config_db将my_sequence的类型注册到my_seqr的run_phase中，这样当my_seqr的run_phase被调用时，就会使用my_sequence作为默认序列
    uvm_config_db#(uvm_object_wrapper)::set(this, "*.my_seqr.run_phase", "default_sequence",
                                            my_sequence::get_type());

    // 在build_phase中设置配置项，使用uvm_config_db将item_num的值设置为20，这样在my_sequence的pre_randomize方法中就会从uvm_config_db获取这个值，并使用它来控制生成事务的数量
    uvm_config_db#(int)::set(this, "*.my_seqr", "item_num", 20);

    // 普通的配置项设置，直接访问my_env_config对象的成员变量进行赋值
    my_env_config.is_coverage                = 1;
    my_env_config.is_check                   = 1;
    my_env_config.my_agent_config.is_active  = UVM_ACTIVE;
    my_env_config.my_agent_config.pad_cycles = 10;

    // interface的配置项设置，使用uvm_config_db将接口的虚拟指针注册到my_env_config对象的成员变量中，这样在my_env中就可以通过my_env_config.my_agent_config.my_vif来访问接口信号
    if (!uvm_config_db#(virtual dut_interface)::get(
            this, "", "top_if", my_env_config.my_agent_config.my_vif
        )) begin
      `uvm_fatal("CONFIG_ERROR", "Failed to get virtual interface from uvm_config_db")
    end

    // 经过上述对配置变量与接口虚拟指针的设置后，将my_env_config对象注册到uvm_config_db中，这样在my_env中就可以通过uvm_config_db获取这个配置对象，并访问其中的配置变量和接口虚拟指针
    uvm_config_db#(env_config)::set(this, "my_env", "env_config", my_env_config);
  endfunction

  // 在start_of_simulation_phase中打印组件层次结构
  virtual function void start_of_simulation_phase(uvm_phase phase);
    // 调用父类的start_of_simulation_phase方法，确保父类的行为得到执行
    super.start_of_simulation_phase(phase);
    // 使用uvm_top.print_topology方法打印组件层次结构，参数uvm_default_tree_printer指定使用默认的树形打印器来格式化输出
    uvm_top.print_topology(uvm_default_tree_printer);
  endfunction

endclass
