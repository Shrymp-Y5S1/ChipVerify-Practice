// 从uvm_sequence继承，并指定my_transaction作为序列项的类型
class my_sequence extends uvm_sequence #(my_transaction);

  // 注册类，以便UVM的factory机制能够识别和使用它
  `uvm_object_utils(my_sequence)

  // 构造函数，默认名称为my_sequence，调用父类的构造函数
  function new(string name = "my_sequence");
    super.new(name);  // 调用父类的构造函数
  endfunction

  virtual task body();  // 定义序列的主体任务
    // 在序列开始时提出异议，防止仿真结束,this指当前序列对象
    if (starting_phase != null) begin
      starting_phase.raise_objection(this);
    end

    repeat (10) begin
      // start_item和finish_item是UVM序列中用于标记事务开始和结束的方法
      // req是uvm_sequence类中预定义的一个变量，用于存储当前的事务对象
      req = my_transaction::type_id::create("req");
      start_item(req);
      // 随机化事务对象，如果随机化失败则打印错误信息，并结束当前事务
      if (!req.randomize()) `uvm_error("RND", "Randomization failed for transaction")
      finish_item(req);
    end

    #100;
    if (starting_phase != null) begin
      starting_phase.drop_objection(this);
    end

  endtask

endclass
