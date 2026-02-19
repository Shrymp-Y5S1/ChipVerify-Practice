class my_environment extends uvm_env;
  // 从uvm_env继承，my_env是一个环境组件类
  // 注册类，以便UVM的factory机制能够识别和使用它
  `uvm_component_utils(my_environment)
  // 为环境内部的组件：agent声明句柄
  master_agent                            my_agent;
  slave_agent                             my_slave_agent;
  env_config                              my_env_config;

  my_reference_model                      ref_model;
  my_scoreboard                           scb;

  uvm_tlm_analysis_fifo #(my_transaction) r2s_fifo;
  uvm_tlm_analysis_fifo #(my_transaction) s_a2s_fifo;

  // 构造函数，默认名称为my_environment，接受一个父组件作为参数
  function new(string name = "my_environment", uvm_component parent);
    super.new(name, parent);
    this.r2s_fifo   = new("r2s_fifo", this);
    this.s_a2s_fifo = new("s_a2s_fifo", this);
  endfunction

  // 在build_phase中创建环境内部的组件实例，并将当前环境作为它们的父组件
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 从上一层获取配置
    if (!uvm_config_db#(env_config)::get(this, "", "env_config", my_env_config)) begin
      `uvm_fatal("CONFIG_FATAL", "Failed to get env_config from uvm_config_db")
    end

    // 对agent进行配置
    uvm_config_db#(agent_config)::set(this, "my_agent", "my_agent_config",
                                      my_env_config.my_agent_config);
    uvm_config_db#(agent_config)::set(this, "my_slave_agent", "my_slave_agent_config",
                                      my_env_config.my_slave_agent_config);

    if (my_env_config.is_coverage) begin
      `uvm_info("COVERAGE_ENABLE", "Coverage is enabled in the environment.", UVM_LOW)
    end
    if (my_env_config.is_check) begin
      `uvm_info("CHECK_ENABLE", "Check is enabled in the environment.", UVM_LOW)
    end

    // 使用UVM的factory机制创建组件实例，注意这里是uvm_component_utils注册的类，所以使用create方法来创建组件实例
    my_agent       = master_agent::type_id::create("my_agent", this);
    my_slave_agent = slave_agent::type_id::create("my_slave_agent", this);
    scb            = my_scoreboard::type_id::create("scb", this);

    ref_model      = my_reference_model::type_id::create("ref_model", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info("ENV", "Connect the agent and reference model...", UVM_MEDIUM)
    my_agent.m_a2r_export.connect(this.r2s_fifo.blocking_put_export);
    my_slave_agent.s_a2s_export.connect(this.s_a2s_fifo.blocking_put_export);
    ref_model.i_m2r_port.connect(this.r2s_fifo.blocking_get_export);
    if (my_env_config.is_check) begin
      scb.r2s_port.connect(this.r2s_fifo.blocking_get_export);
      scb.s_a2s_port.connect(this.s_a2s_fifo.blocking_get_export);
    end
  endfunction

endclass
