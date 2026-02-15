`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_coverage extends uvm_subscriber #(axi_transaction);

  `uvm_component_utils(axi_coverage)

  // ----------------------------------------------------------------
  // 定义 Covergroup
  // ----------------------------------------------------------------
  bit                   unaligned_addr;
  bit                   partial_strobe;
  int                   wr_outstanding;
  int                   rd_outstanding;
  bit                   ooo_b_seen;
  bit                   ooo_r_seen;
  bit                   r_interleave_seen;

  int                   wr_issue_id_q     [$];
  int                   rd_issue_id_q     [$];

  virtual axi_interface vif;

  covergroup axi_cg;
    option.per_instance = 1;
    option.comment = "AXI Protocol Coverage";

    // 1. 读写类型覆盖
    cp_rw: coverpoint tr.is_write {
      bins write = {1}; bins read = {0};
    }

    // 2. 突发长度覆盖 (RTL MAX=8)
    cp_len: coverpoint tr.len {
      bins min_len = {0};  // 1 beat
      bins mid_len = {[1 : 6]};  // 2-7 beats
      bins max_len = {7};  // 8 beats (RTL 极限)
    }

    // 3. 突发大小覆盖
    cp_size: coverpoint tr.size {
      bins size_1b = {`AXI_SIZE_1_BYTE};
      bins size_2b = {`AXI_SIZE_2_BYTE};
      bins size_4b = {`AXI_SIZE_4_BYTE};
    }

    // 4. 突发类型 (目前主要测 INCR)
    cp_burst: coverpoint tr.burst {
      bins fixed = {`AXI_BURST_FIXED};
      bins incr = {`AXI_BURST_INCR};
      bins wrap = {`AXI_BURST_WRAP};  // 如果不支持可注释掉
    }

    // 5. 交叉覆盖：写操作 x 最大长度 (压力点)
    cross_wr_max_len: cross cp_rw, cp_len{
      bins wr_max = binsof (cp_rw.write) && binsof (cp_len.max_len);
      bins rd_max = binsof (cp_rw.read) && binsof (cp_len.max_len);
    }

    // 6. 非对齐地址覆盖
    cp_unaligned: coverpoint unaligned_addr {
      bins aligned = {0}; bins unaligned = {1};
    }

    // 7. 写 strobe 覆盖（是否出现部分字节写）
    cp_partial_strobe: coverpoint partial_strobe {
      bins full_write = {0}; bins partial_write = {1};
    }

    // 8. 交叉覆盖：非对齐 x 部分写
    cross_unalign_strobe: cross cp_unaligned, cp_partial_strobe{
      bins unaligned_partial = binsof (cp_unaligned.unaligned) &&
          binsof (cp_partial_strobe.partial_write);
    }

  endgroup

  covergroup axi_stress_cg;
    option.per_instance = 1;
    option.comment = "AXI Outstanding/OoO/Interleave Coverage";

    cp_wr_outstanding: coverpoint wr_outstanding {
      bins wr_low = {[0 : 4]}; bins wr_mid = {[5 : 15]}; bins wr_full = {16};
    }

    cp_rd_outstanding: coverpoint rd_outstanding {
      bins rd_low = {[0 : 4]}; bins rd_mid = {[5 : 15]}; bins rd_full = {16};
    }

    cp_ooo_b: coverpoint ooo_b_seen {bins seen = {1};}
    cp_ooo_r: coverpoint ooo_r_seen {bins seen = {1};}
    cp_r_interleave: coverpoint r_interleave_seen {bins seen = {1};}
  endgroup

  // ----------------------------------------------------------------
  // Transaction 句柄
  // ----------------------------------------------------------------
  axi_transaction tr;

  // ----------------------------------------------------------------
  // 构造函数
  // ----------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg        = new();  // 实例化 covergroup
    axi_stress_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_interface)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
    end
  endfunction

  function int find_id_idx(int q[$], int id);
    foreach (q[i]) begin
      if (q[i] == id) return i;
    end
    return -1;
  endfunction

  task run_phase(uvm_phase phase);
    int prev_rid;
    bit prev_rvalid_hs;
    bit prev_rlast;

    wr_outstanding    = 0;
    rd_outstanding    = 0;
    ooo_b_seen        = 0;
    ooo_r_seen        = 0;
    r_interleave_seen = 0;
    prev_rid          = 0;
    prev_rvalid_hs    = 0;
    prev_rlast        = 0;

    forever begin
      @(posedge vif.clk);

      if (!vif.rst_n) begin
        wr_outstanding    = 0;
        rd_outstanding    = 0;
        ooo_b_seen        = 0;
        ooo_r_seen        = 0;
        r_interleave_seen = 0;
        wr_issue_id_q.delete();
        rd_issue_id_q.delete();
        prev_rvalid_hs = 0;
      end
      else begin
        if (vif.awvalid && vif.awready) begin
          wr_outstanding++;
          wr_issue_id_q.push_back(vif.awid);
        end

        if (vif.bvalid && vif.bready) begin
          int idx;
          idx = find_id_idx(wr_issue_id_q, vif.bid);
          if (idx > 0) ooo_b_seen = 1;
          if (idx >= 0) wr_issue_id_q.delete(idx);
          if (wr_outstanding > 0) wr_outstanding--;
        end

        if (vif.arvalid && vif.arready) begin
          rd_outstanding++;
          rd_issue_id_q.push_back(vif.arid);
        end

        if (vif.rvalid && vif.rready) begin
          if (prev_rvalid_hs && !prev_rlast && (vif.rid != prev_rid)) begin
            r_interleave_seen = 1;
          end

          prev_rid       = vif.rid;
          prev_rlast     = vif.rlast;
          prev_rvalid_hs = 1;

          if (vif.rlast) begin
            int idx;
            idx = find_id_idx(rd_issue_id_q, vif.rid);
            if (idx > 0) ooo_r_seen = 1;
            if (idx >= 0) rd_issue_id_q.delete(idx);
            if (rd_outstanding > 0) rd_outstanding--;
          end
        end

        axi_stress_cg.sample();
      end
    end
  endtask

  // ----------------------------------------------------------------
  // 采样函数 (来自 uvm_subscriber)
  // ----------------------------------------------------------------
  virtual function void write(axi_transaction t);
    this.tr        = t;

    unaligned_addr = ((t.addr & ((1 << t.size) - 1)) != 0);
    partial_strobe = 0;

    if (t.is_write && t.wstrb.size() > 0) begin
      foreach (t.wstrb[i]) begin
        if (t.wstrb[i] != '0 && t.wstrb[i] != '1) begin
          partial_strobe = 1;
        end
      end
    end

    axi_cg.sample();  // 触发采样
  endfunction

endclass
