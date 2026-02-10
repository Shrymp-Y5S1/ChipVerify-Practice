`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_sequencer extends uvm_sequencer #(axi_transaction);

    // 1. 注册 Component
    `uvm_component_utils(axi_sequencer)

    // 2. 构造函数
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
