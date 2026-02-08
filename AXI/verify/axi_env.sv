`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_env extends uvm_env;

    // 注册
    `uvm_component_utils(axi_env)

    // 组件句柄
    axi_agent      agent;
    axi_scoreboard scb;
    axi_coverage   cov;

    // 构造函数
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Build Phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 1. 创建 Agent
        agent = axi_agent::type_id::create("agent", this);

        // 2. 创建 Scoreboard
        scb = axi_scoreboard::type_id::create("scb", this);

        // 3. 创建 Coverage
        cov = axi_coverage::type_id::create("cov", this);
    endfunction

    // Connect Phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 连接 Monitor 数据流到 Scoreboard
        agent.item_collected_port.connect(scb.item_export);
        agent.item_collected_port.connect(cov.analysis_export);
    endfunction

endclass
