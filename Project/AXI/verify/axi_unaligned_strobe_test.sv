`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_unaligned_strobe_base_seq extends uvm_sequence #(axi_transaction);
  `uvm_object_utils(axi_unaligned_strobe_base_seq)

  function new(string name = "axi_unaligned_strobe_base_seq");
    super.new(name);
  endfunction

  task send_unaligned_write_read_pair(
      bit [`AXI_ADDR_WIDTH-1:0] start_addr, bit [`AXI_LEN_WIDTH-1:0] burst_len,
      bit [`AXI_SIZE_WIDTH-1:0] burst_size, bit [3:0] strobe_beat0, bit [3:0] strobe_beat1,
      bit [`AXI_DATA_WIDTH-1:0] data_beat0, bit [`AXI_DATA_WIDTH-1:0] data_beat1);
    axi_transaction wr_tr;
    axi_transaction rd_tr;

    wr_tr = axi_transaction::type_id::create("wr_tr");
    wr_tr.c_aligned_addr.constraint_mode(0);

    start_item(wr_tr);
    if (!wr_tr.randomize() with {
          is_write == 1'b1;
          id inside {[0 : 15]};
          addr == local:: start_addr;
          len == local:: burst_len;
          size == local:: burst_size;
          burst == `AXI_BURST_INCR;
          data[0] == local:: data_beat0;
          data[1] == local:: data_beat1;
          wstrb[0] == local:: strobe_beat0;
          wstrb[1] == local:: strobe_beat1;
        }) begin
      `uvm_fatal("UNALIGN_SEQ", "Randomize failed for unaligned write")
    end
    finish_item(wr_tr);

    rd_tr = axi_transaction::type_id::create("rd_tr");
    rd_tr.c_aligned_addr.constraint_mode(0);

    start_item(rd_tr);
    if (!rd_tr.randomize() with {
          is_write == 1'b0;
          id == wr_tr.id;
          addr == local:: start_addr;
          len == local:: burst_len;
          size == local:: burst_size;
          burst == `AXI_BURST_INCR;
        }) begin
      `uvm_fatal("UNALIGN_SEQ", "Randomize failed for unaligned read")
    end
    finish_item(rd_tr);

    `uvm_info(
        "UNALIGN_SEQ",
        $sformatf(
            "Issued unaligned WR/RD pair: addr=%0h len=%0d size=%0d wstrb[0]=%0b wstrb[1]=%0b",
            start_addr, burst_len, burst_size, strobe_beat0, strobe_beat1), UVM_LOW)
  endtask

  task send_single_beat_write_read_pair(bit [`AXI_ADDR_WIDTH-1:0] start_addr,
                                        bit [`AXI_SIZE_WIDTH-1:0] burst_size, bit [3:0] strobe,
                                        bit [`AXI_DATA_WIDTH-1:0] data_word);
    axi_transaction wr_tr;
    axi_transaction rd_tr;
    bit             unaligned;

    unaligned = ((start_addr % (1 << burst_size)) != 0);

    wr_tr     = axi_transaction::type_id::create("wr_tr_1b");
    if (unaligned) wr_tr.c_aligned_addr.constraint_mode(0);

    start_item(wr_tr);
    if (!wr_tr.randomize() with {
          is_write == 1'b1;
          id inside {[0 : 15]};
          addr == local:: start_addr;
          len == 0;
          size == local:: burst_size;
          burst == `AXI_BURST_INCR;
          data[0] == local:: data_word;
          wstrb[0] == local:: strobe;
        }) begin
      `uvm_fatal("MATRIX_SEQ", "Randomize failed for single-beat write")
    end
    finish_item(wr_tr);

    rd_tr = axi_transaction::type_id::create("rd_tr_1b");
    if (unaligned) rd_tr.c_aligned_addr.constraint_mode(0);

    start_item(rd_tr);
    if (!rd_tr.randomize() with {
          is_write == 1'b0;
          id == wr_tr.id;
          addr == local:: start_addr;
          len == 0;
          size == local:: burst_size;
          burst == `AXI_BURST_INCR;
        }) begin
      `uvm_fatal("MATRIX_SEQ", "Randomize failed for single-beat read")
    end
    finish_item(rd_tr);
  endtask

  virtual task body();
  endtask
endclass


class axi_size_align_strobe_matrix_seq extends axi_unaligned_strobe_base_seq;
  `uvm_object_utils(axi_size_align_strobe_matrix_seq)

  function new(string name = "axi_size_align_strobe_matrix_seq");
    super.new(name);
  endfunction

  function automatic bit [`AXI_ADDR_WIDTH-1:0] gen_case_addr(int size_code, bit want_unaligned,
                                                             int case_idx);
    bit [`AXI_ADDR_WIDTH-1:0] raw_addr;
    int                       beat_bytes;

    beat_bytes = (1 << size_code);
    raw_addr   = 16'h0200 + (case_idx * 8);

    if (want_unaligned && (beat_bytes > 1)) begin
      if ((raw_addr % beat_bytes) == 0) raw_addr = raw_addr + 1;
    end
    else begin
      if ((raw_addr % beat_bytes) != 0) raw_addr = raw_addr - (raw_addr % beat_bytes);
    end

    return raw_addr;
  endfunction

  virtual task body();
    int size_list   [$];
    int total_cases;
    int case_idx;

    size_list.push_back(`AXI_SIZE_1_BYTE);
    size_list.push_back(`AXI_SIZE_2_BYTE);
    size_list.push_back(`AXI_SIZE_4_BYTE);

    total_cases = 0;
    case_idx    = 0;

    `uvm_info("MATRIX_SEQ", "Starting exhaustive size x align x strobe matrix sequence...", UVM_LOW)

    foreach (size_list[s]) begin
      for (int align_mode = 0; align_mode <= 1; align_mode++) begin
        bit want_unaligned;
        want_unaligned = (align_mode == 1);

        for (int strobe = 0; strobe < 16; strobe++) begin
          bit [`AXI_ADDR_WIDTH-1:0] addr;
          bit [`AXI_DATA_WIDTH-1:0] data_word;

          addr      = gen_case_addr(size_list[s], want_unaligned, case_idx);
          data_word = {8'(size_list[s]), 7'(align_mode), 9'(strobe), 8'(case_idx)};

          send_single_beat_write_read_pair(addr, size_list[s], strobe[3:0], data_word);

          total_cases++;
          case_idx++;
        end
      end
    end

    `uvm_info("MATRIX_SEQ", $sformatf("Matrix sequence finished. Total WR/RD pairs issued: %0d",
                                      total_cases), UVM_LOW)

    #1000ns;
  endtask
endclass


class axi_size_align_strobe_matrix_test extends axi_base_test;
  `uvm_component_utils(axi_size_align_strobe_matrix_test)

  function new(string name = "axi_size_align_strobe_matrix_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_size_align_strobe_matrix_seq seq;

    phase.raise_objection(this);

    seq = axi_size_align_strobe_matrix_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #2000ns;
    phase.drop_objection(this);
  endtask
endclass


class axi_unaligned_strobe_must_pass_seq extends axi_unaligned_strobe_base_seq;
  `uvm_object_utils(axi_unaligned_strobe_must_pass_seq)

  function new(string name = "axi_unaligned_strobe_must_pass_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("UNALIGN_SEQ", "Starting unaligned must-pass sequence...", UVM_LOW)

    // 2-byte transfer, address unaligned(+1), byte-lane selection by strobe
    send_unaligned_write_read_pair(16'h0343, 8'd1, `AXI_SIZE_2_BYTE, 4'b0010, 4'b0001,
                                   32'h5566_7788, 32'h99AA_BBCC);

    #500ns;
    `uvm_info("UNALIGN_SEQ", "Unaligned must-pass sequence finished.", UVM_LOW)
  endtask
endclass


class axi_unaligned_strobe_expected_fail_seq extends axi_unaligned_strobe_base_seq;
  `uvm_object_utils(axi_unaligned_strobe_expected_fail_seq)

  function new(string name = "axi_unaligned_strobe_expected_fail_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("UNALIGN_SEQ", "Starting unaligned expected-fail sequence...", UVM_LOW)

    // 已知限制场景：4-byte transfer + unaligned addr + partial strobe
    send_unaligned_write_read_pair(16'h0121, 8'd1, `AXI_SIZE_4_BYTE, 4'b1110, 4'b0001,
                                   32'hA1B2_C3D4, 32'h1122_3344);

    #500ns;
    `uvm_info("UNALIGN_SEQ", "Unaligned expected-fail sequence finished.", UVM_LOW)
  endtask
endclass


class axi_unaligned_strobe_must_pass_test extends axi_base_test;
  `uvm_component_utils(axi_unaligned_strobe_must_pass_test)

  function new(string name = "axi_unaligned_strobe_must_pass_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_unaligned_strobe_must_pass_seq seq;

    phase.raise_objection(this);

    seq = axi_unaligned_strobe_must_pass_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #1000ns;
    phase.drop_objection(this);
  endtask
endclass


class axi_unaligned_strobe_expected_fail_test extends axi_base_test;
  `uvm_component_utils(axi_unaligned_strobe_expected_fail_test)

  function new(string name = "axi_unaligned_strobe_expected_fail_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_unaligned_strobe_expected_fail_seq seq;

    phase.raise_objection(this);

    seq = axi_unaligned_strobe_expected_fail_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #1000ns;
    phase.drop_objection(this);
  endtask
endclass


// 兼容保留：默认改为 must-pass 子集
class axi_unaligned_strobe_test extends axi_base_test;
  `uvm_component_utils(axi_unaligned_strobe_test)

  function new(string name = "axi_unaligned_strobe_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_unaligned_strobe_must_pass_seq seq;

    phase.raise_objection(this);

    seq = axi_unaligned_strobe_must_pass_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    #1000ns;
    phase.drop_objection(this);
  endtask
endclass
