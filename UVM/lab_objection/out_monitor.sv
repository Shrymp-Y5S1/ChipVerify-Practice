class out_monitor extends uvm_monitor;
  `uvm_component_utils(out_monitor)

  virtual dut_interface                   my_vif;

  uvm_blocking_put_port #(my_transaction) m2s_port;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    this.m2s_port = new("m2s_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("TRACE", $sformat("%m"), UVM_MEDIUM)
    if (!uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif)) begin
      `uvm_fatal("CONFIG_FATAL", "Out Monitor can not get the interface")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_transaction       tr;
    int                  active_port;
    logic          [7:0] temp;
    int                  count;

    forever begin
      active_port = -1;
      count       = 0;

      tr          = my_transaction::type_id::create("tr", this);

      // wait for bus active
      while (1) begin
        @(my_vif.o_monitor_cb);
        foreach (my_vif.o_monitor_cb.frameo_n[i]) begin
          if (my_vif.o_monitor_cb.frameo_n[i] == 0) begin
            active_port = i;
          end
        end

        if (active_port != -1) begin
          break;
        end
      end

      // active port has been detected, get the source address
      tr.da = active_port;

      // get the payload
      forever begin
        if (my_vif.o_monitor_cb.valido_n[tr.da] == 0) begin
          temp[count] = my_vif.o_monitor_cb.dout[tr.da];
          count++;
          if (count == 8) begin
            tr.payload.push_back(temp);
            count = 0;
          end
        end

        if (my_vif.o_monitor_cb.frameo_n[tr.da]) begin
          if (count != 0) begin
            tr.payload.push_back(temp);
            `uvm_warning("PAYLOAD_WARNING", "Payload not byte aligned")
          end
          break;
        end
        @(my_vif.o_monitor_cb);
      end
      `uvm_info("OUT_MONITOR", {"\n", "Got transaction: \n", tr.sprint()}, UVM_MEDIUM)
      `uvm_info("OUT_MONITOR", "Now out monitor send the transaction to the Scoreboard", UVM_MEDIUM)
      this.m2s_port.put(tr);
    end
  endtask

endclass
