`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_agent extends uvm_agent;

    // 注册
    `uvm_component_utils(axi_agent)

    // 组件句柄
    axi_driver    drv;
    axi_monitor   mon;
    axi_sequencer sqr;

    // Analysis Port (用于把 Monitor 抓到的数据转发给 Env/Scoreboard)
    uvm_analysis_port #(axi_transaction) item_collected_port;

    // 构造函数
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Build Phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 1. 始终创建 Monitor (无论是 Active 还是 Passive 模式都需要观测)
        mon = axi_monitor::type_id::create("mon", this);

        // 2. 只有在 Active 模式下才创建 Driver 和 Sequencer
        // (get_is_active() 是 uvm_agent 的内置函数，默认是 UVM_ACTIVE)
        if(get_is_active() == UVM_ACTIVE) begin
            drv = axi_driver::type_id::create("drv", this);
            sqr = axi_sequencer::type_id::create("sqr", this);
        end
    endfunction

    // Connect Phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 1. 连接 Monitor 的端口到 Agent 的端口 (透传)
        // 这样 Env 只需要连 Agent 的端口，不需要深入内部找 Monitor
        item_collected_port = mon.item_collected_port;

        // 2. 连接 Driver 和 Sequencer (核心握手连接)
        if(get_is_active() == UVM_ACTIVE) begin
            // driver.seq_item_port 连接到 sequencer.seq_item_export
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

endclass
