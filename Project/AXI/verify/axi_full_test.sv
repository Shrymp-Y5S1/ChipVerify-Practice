`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_full_test extends axi_base_test; // 继承 base_test 复用环境配置
    `uvm_component_utils(axi_full_test)

    function new(string name = "axi_full_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_full_seq seq;

        phase.raise_objection(this);

        `uvm_info("TEST", "Starting Full Coverage Test...", UVM_NONE)

        seq = axi_full_seq::type_id::create("seq");
        seq.start(env.agent.sqr);

        // 等待残留的事务完成
        #2000ns;

        phase.drop_objection(this);
    endtask
endclass
