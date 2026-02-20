class data_mem_c extends uvm_mem;

  // 使用UVM宏注册data_mem_c类，使其能够使用UVM的工厂机制创建实例
  `uvm_object_utils(data_mem_c)

  function new(string name = "data_mem_c");
    // 调用父类构造函数，参数分别是：内存名称、内存深度512、内存位宽16
    super.new(name, 512, 16);
  endfunction

endclass
