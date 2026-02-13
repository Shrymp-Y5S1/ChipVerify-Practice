module test ();
  import uvm_pkg::*;
  `include "uvm_pkg.svh"

  //   `include "my_transaction.sv"
  //   `include "my_sequence.sv"
  //   `include "my_sequencer.sv"

  //   `include "my_monitor.sv"
  //   `include "my_driver.sv"
  //   `include "my_agent.sv"
  //   `include "my_environment.sv"
  //   `include "my_test.sv"

  initial begin
    // 在仿真开始时调用UVM的run_test函数，启动UVM测试的执行。run_test函数会自动创建和运行UVM测试环境中的组件，并执行测试序列。
    run_test();
  end

endmodule
