class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_blocking_get_port #(my_transaction) r2s_port;
  uvm_blocking_get_port #(my_transaction) s_a2s_port;

  reg_model_c                             reg_model;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    this.r2s_port   = new("r2s_port", this);
    this.s_a2s_port = new("s_a2s_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_transaction dut_output_tr;
    my_transaction expected_tr;

    uvm_status_e   status;
    uvm_reg_data_t value;

    forever begin
      `uvm_info("SCOREBOARD",
                "Now waiting for getting the transaction from slave agent and reference model",
                UVM_MEDIUM)
      reg_model.config_reg.write(status, value, UVM_FRONTDOOR);
      fork
        r2s_port.get(expected_tr);
        s_a2s_port.get(dut_output_tr);
      join
      reg_model.mode_reg.read(status, value, UVM_FRONTDOOR);
      `uvm_info("CHECK", "DUT has completed a transaction. Now check the output...", UVM_MEDIUM)
      if (expected_tr.compare(dut_output_tr)) begin
        `uvm_info("CHECK", "Output is correct!", UVM_MEDIUM)
      end
      else begin
        `uvm_error("CHECK_ERROR", {
                   "Output is incorrect! \nExpected: \n",
                   expected_tr.sprint(),
                   "\nGot: \n",
                   dut_output_tr.sprint()
                   })
      end
    end
  endtask

endclass
