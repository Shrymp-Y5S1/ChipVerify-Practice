class env_config extends uvm_object;
  `uvm_object_utils(env_config)

  int is_coverage = 0;
  int is_check = 0;

  agent_config my_agent_config;

  `uvm_object_utils_begin(env_config)
    `uvm_field_int(is_coverage, UVM_ALL_ON)
    `uvm_field_int(is_check, UVM_ALL_ON)
    `uvm_field_object(my_agent_config, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "env_config");
    super.new(name);  // 调用父类的构造函数，传递名称
    my_agent_config = agent_config::type_id::create("my_agent_config");
  endfunction
endclass
