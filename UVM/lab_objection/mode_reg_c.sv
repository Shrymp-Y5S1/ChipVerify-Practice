class mode_reg_c extends uvm_reg;
  `uvm_object_utils(mode_reg_c)

  rand uvm_reg_field data;

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    // 配置寄存器字段，参数分别是：父寄存器、位宽、位位置、访问权限、复位值、复位掩码、是否可随机化、是否可覆盖、是否可强制覆盖
    data.configure(this, 8, 0, "RW", 0, 'h0, 1, 1, 1);
  endfunction

  function new(string name = "mode_reg_c");
    // 调用父类构造函数，参数分别是：寄存器名称、寄存器位宽8、覆盖选项（不进行覆盖分析）
    super.new(name, 8, UVM_NO_COVERAGE);
  endfunction

endclass
