class my_sequence extends uvm_sequence #(my_transaction);

  `uvm_object_utils(my_sequence)

  int item_num = 10;

  function new(string name = "my_sequence");
    super.new(name);
  endfunction

  // 在pre_randomize方法中从uvm_config_db获取配置项item_num的值，并将其赋值给item_num变量，这样在序列执行时就会使用这个值来控制生成事务的数量
  function void pre_randomize();
    uvm_config_db#(int)::get(my_seqr, "", "item_num", item_num);
  endfunction

  virtual task body();
    if (starting_phase != null) begin
      starting_phase.raise_objection(this);
    end

    // 在body方法中使用一个循环来生成和发送事务，循环的次数由item_num变量控制
    repeat (item_num) begin
      req = my_transaction::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_error("RND", "Randomization failed for transaction")
      finish_item(req);

      get_response(rsp);  // rsp为泛型继承，无需提前定义
    end

    #100;
    if (starting_phase != null) begin
      starting_phase.drop_objection(this);
    end

  endtask

endclass
