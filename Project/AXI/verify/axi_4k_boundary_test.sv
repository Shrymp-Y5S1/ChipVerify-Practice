`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_4k_boundary_seq extends uvm_sequence #(axi_transaction);
  `uvm_object_utils(axi_4k_boundary_seq)

  function new(string name = "axi_4k_boundary_seq");
    super.new(name);
  endfunction

  task send_cross_4k_req(bit is_wr, bit [`AXI_ADDR_WIDTH-1:0] start_addr,
                         bit [`AXI_LEN_WIDTH-1:0] len, bit [`AXI_SIZE_WIDTH-1:0] size,
                         bit [`AXI_BURST_WIDTH-1:0] burst);
    axi_transaction tr;
    tr = axi_transaction::type_id::create("tr");

    tr.c_4k_boundary.constraint_mode(0);

    start_item(tr);
    if (!tr.randomize() with {
          is_write == local:: is_wr;
          id inside {[0 : 15]};
          addr == local:: start_addr;
          len == local:: len;
          size == local:: size;
          burst == local:: burst;
          foreach (wstrb[i]) wstrb[i] == 4'hF;
        }) begin
      `uvm_fatal("SEQ", "Randomize failed for cross-4K transaction")
    end
    finish_item(tr);

    `uvm_info("SEQ_4K", $sformatf("Sent cross-4K %s: addr=%0h len=%0d size=%0d burst=%0d",
                                  is_wr ? "WRITE" : "READ", start_addr, len, size, burst), UVM_LOW)
  endtask

  virtual task body();
    `uvm_info("SEQ_4K", "Starting AXI 4KB boundary crossing sequence...", UVM_LOW)

    // 4-byte beat, 8 beats => 32 bytes. Start at 0x0FF0 crosses to 0x1000 page.
    send_cross_4k_req(1'b1, 16'h0FF0, 8'd7, `AXI_SIZE_4_BYTE, `AXI_BURST_INCR);
    send_cross_4k_req(1'b0, 16'h0FF0, 8'd7, `AXI_SIZE_4_BYTE, `AXI_BURST_INCR);

    // Another crossing window at 0x1FF8, 2-byte beat, 8 beats => 16 bytes.
    send_cross_4k_req(1'b1, 16'h1FF8, 8'd7, `AXI_SIZE_2_BYTE, `AXI_BURST_INCR);
    send_cross_4k_req(1'b0, 16'h1FF8, 8'd7, `AXI_SIZE_2_BYTE, `AXI_BURST_INCR);

    #500ns;
    `uvm_info("SEQ_4K", "AXI 4KB boundary crossing sequence finished.", UVM_LOW)
  endtask
endclass

class axi_4k_boundary_test extends axi_base_test;
  `uvm_component_utils(axi_4k_boundary_test)

  function new(string name = "axi_4k_boundary_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_4k_boundary_seq seq;

    phase.raise_objection(this);

    seq = axi_4k_boundary_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #1000ns;
    phase.drop_objection(this);
  endtask
endclass
