class slave_agent extends uvm_agent;

  `uvm_component_utils(slave_agent)

  out_monitor                               my_moni;

  agent_config                              my_agent_cfg;

  uvm_blocking_put_export #(my_transaction) s_a2s_export;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    this.s_a2s_export = new("s_a2s_export", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(agent_config)::get(this, "", "my_agent_cfg", my_agent_cfg)) begin
      `uvm_fatal("CONFIG_FATAL", "Failed to get agent_config from uvm_config_db")
    end

    uvm_config_db#(virtual dut_interface)::set(this, "my_moni", "vif", my_agent_cfg.my_vif);

    my_moni = out_monitor::type_id::create("my_moni", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    my_moni.m2s_port.connect(this.s_a2s_export);
  endfunction

endclass
