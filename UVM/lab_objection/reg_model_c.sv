class reg_model_c extends uvm_reg_block;
  `uvm_object_utils(reg_model_c)

  rand config_reg_c config_reg;
  rand mode_reg_c   mode_reg;
  data_mem_c        data_mem;

  // 在build函数中创建寄存器和内存实例，并将它们添加到寄存器块中
  virtual function void build();
    config_reg = config_reg_c::type_id::create("config_reg");
    // 将config_reg添加到寄存器块中，null表示没有父寄存器，"config_reg"是寄存器的名称
    config_reg.configure(this, null, "config_reg");
    config_reg.build();

    mode_reg = mode_reg_c::type_id::create("mode_reg");
    mode_reg.configure(this, null, "mode_reg");
    mode_reg.build();

    data_mem = data_mem_c::type_id::create("data_mem");
    data_mem.configure(this, "data_mem");

    default_map = create_map("default_map", 0, 1, UVM_LITTLE_ENDIAN);
    default_map.add_reg(config_reg, 'h001c, "RW");
    default_map.add_reg(mode_reg, 'h002d, "RW");
    default_map.add_mem(data_mem, 'h1000);
  endfunction

  function new(string name = "reg_model_c");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

endclass
