class config_reg_c extends uvm_reg;
  // 从uvm_reg继承，config_reg_c是一个寄存器类
  `uvm_object_utils(config_reg_c)

  // 使用uvm_reg_field类型，rand是为了让这些字段在随机化过程中被随机化
  rand uvm_reg_field f1;
  rand uvm_reg_field f2;
  rand uvm_reg_field f3;
  rand uvm_reg_field f4;

  virtual function void build();
    // 在build函数中创建寄存器字段实例
    f1 = uvm_reg_field::type_id::create("f1");
    f2 = uvm_reg_field::type_id::create("f2");
    f3 = uvm_reg_field::type_id::create("f3");
    f4 = uvm_reg_field::type_id::create("f4");
    // 配置寄存器字段，参数分别是：父寄存器、位宽、位位置、访问权限、复位值、复位掩码、是否可随机化、是否可覆盖、是否可强制覆盖
    f1.configure(this, 1, 0, "RW", 0, 'h0, 1, 1, 1);
    f2.configure(this, 1, 1, "RO", 0, 'h0, 1, 1, 1);
    f3.configure(this, 5, 2, "RW", 0, 'h0, 1, 1, 1);
    f4.configure(this, 1, 7, "WO", 0, 'h0, 1, 1, 1);
  endfunction

  function new(string name = "config_reg_c");
    // 调用父类构造函数，参数分别是：寄存器名称、寄存器位宽8、覆盖选项（不进行覆盖分析）
    super.new(name, 8, UVM_NO_COVERAGE);
  endfunction

endclass
