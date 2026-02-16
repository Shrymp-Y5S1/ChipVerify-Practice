`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_error_resp_seq extends uvm_sequence #(axi_transaction);
  `uvm_object_utils(axi_error_resp_seq)

  function new(string name = "axi_error_resp_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction tr;

    `uvm_info("ERR_SEQ", "Starting AXI Error Response Sequence...", UVM_NONE)

    repeat (300) begin
      `uvm_do_with(tr,
                   {
        is_write == 1;
        len <= 3;
        size inside {`AXI_SIZE_1_BYTE, `AXI_SIZE_2_BYTE, `AXI_SIZE_4_BYTE};
        burst inside {`AXI_BURST_INCR, `AXI_BURST_FIXED};
      })
    end

    #1000ns;
    `uvm_info("ERR_SEQ", "AXI Error Response Sequence Finished.", UVM_NONE)
  endtask
endclass


class axi_error_resp_test extends axi_base_test;
  `uvm_component_utils(axi_error_resp_test)

  function new(string name = "axi_error_resp_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_error_resp_seq seq;

    phase.raise_objection(this);

    `uvm_info(
        "ERR_TEST",
        "Starting Error Response Test. TB default injection is enabled for this test unless overridden by +SLV_ERR_PCT/+DEC_ERR_PCT.",
        UVM_NONE)

    seq = axi_error_resp_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #2000ns;
    phase.drop_objection(this);
  endtask
endclass
