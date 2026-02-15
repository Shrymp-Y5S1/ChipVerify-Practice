`include "uvm_macros.svh"
import uvm_pkg::*;

// ----------------------------------------------------------------
// 压力 Sequence
// ----------------------------------------------------------------
class axi_stress_seq extends uvm_sequence #(axi_transaction);
  `uvm_object_utils(axi_stress_seq)

  function new(string name = "axi_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction tr;

    `uvm_info("SEQ", "Starting AXI Stress Sequence (1000 items)...", UVM_NONE)

    // 循环 1000 次，尽可能覆盖所有随机情况
    repeat (1000) begin
      `uvm_do_with(tr,
                   {
                // 约束 burst 长度在有效范围内
                len <= 7;

                // 覆盖三种 burst 类型
                burst dist {
                    `AXI_BURST_INCR  := 60,
                    `AXI_BURST_WRAP  := 30,
                    `AXI_BURST_FIXED := 10
                };

                // 约束 strobe 必须有效 (防止稀疏写导致的 mismatch)
                // 注意：如果想测稀疏写，需要更复杂的 Scoreboard/Slave
                foreach(wstrb[i]) wstrb[i] == 4'hF;

                // 读操作的 size 必须也是 4 字节 (与写一致)
                // 或者是为了测试窄读，需要确保地址对齐
                size == `AXI_SIZE_4_BYTE;
            })
    end

    `uvm_info("SEQ", "AXI Stress Sequence Finished!", UVM_NONE)
  endtask
endclass

// ----------------------------------------------------------------
// 压力 Test
// ----------------------------------------------------------------
class axi_stress_test extends axi_base_test;  // 继承自 base_test，复用 env 配置
  `uvm_component_utils(axi_stress_test)

  function new(string name = "axi_stress_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_stress_seq seq;
    phase.raise_objection(this);

    seq = axi_stress_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    // 等待所有 outstanding 事务完成
    #1000ns;

    phase.drop_objection(this);
  endtask
endclass
