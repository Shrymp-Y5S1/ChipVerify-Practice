`include "uvm_macros.svh"
import uvm_pkg::*;

// ----------------------------------------------------------------
// 1. 定义一个基础序列 (Sequence) - 这是"剧本"
// ----------------------------------------------------------------
class axi_base_seq extends uvm_sequence #(axi_transaction);

  // 注册
  `uvm_object_utils(axi_base_seq)

  // 构造函数
  function new(string name = "axi_base_seq");
    super.new(name);
  endfunction

  // Body 任务：定义具体的激励生成逻辑
  virtual task body();
    axi_transaction tr;

    `uvm_info("SEQ", "Starting AXI Base Sequence...", UVM_LOW)

    // 1. 发送 10 个随机包
    repeat (10) begin
      `uvm_do(tr)
    end

    // 2. 发送一个定向测试包：写操作，地址 0x1000，长度 3 (4 beats)
    `uvm_do_with(tr,
                 {
            is_write == 1;
            addr == 32'h1000;
            len == 3;
            size == `AXI_SIZE_4_BYTE;
            burst == `AXI_BURST_INCR;
            foreach (wstrb[i]) wstrb[i] == 4'hF;
        })

    // 3. 发送一个定向测试包：读操作，地址 0x1000
    `uvm_do_with(tr,
                 {
            is_write == 0;
            addr == 32'h1000;
            len == 3;
            size == `AXI_SIZE_4_BYTE;
            burst == `AXI_BURST_INCR;
        })

    // 等待一点时间，让最后一笔传输完成
    #1000ns;

    `uvm_info("SEQ", "AXI Base Sequence Finished!", UVM_LOW)
  endtask

endclass


// ----------------------------------------------------------------
// 2. 定义测试用例 (Test) - 这是"驾驶员"
// ----------------------------------------------------------------
class axi_base_test extends uvm_test;

  // 注册
  `uvm_component_utils(axi_base_test)

  // 环境句柄
  axi_env env;

  // 构造函数
  function new(string name = "axi_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: 创建环境
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 创建顶层环境
    env = axi_env::type_id::create("env", this);
  endfunction

  // End of Elaboration: 打印拓扑结构
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("TOPO", this.sprint(), UVM_LOW)
  endfunction

  // Run Phase: 启动测试
  task run_phase(uvm_phase phase);
    axi_base_seq seq;

    // 1. 举手 (Raise Objection) - 告诉 UVM "别停，我还要干活"
    phase.raise_objection(this);

    // 2. 创建序列
    seq = axi_base_seq::type_id::create("seq");

    // 3. 启动序列 (挂载到 Agent 的 Sequencer 上)
    // 注意：env.agent.sqr 的路径必须与 axi_env 中实例化的一致
    if (env.agent.sqr == null) begin
      `uvm_fatal("TEST", "Sequencer handle is NULL! Check Agent is_active setting.")
    end
    seq.start(env.agent.sqr);

    // 4. 放手 (Drop Objection) - 告诉 UVM "我干完了，可以结束仿真了"
    phase.drop_objection(this);
  endtask

endclass
