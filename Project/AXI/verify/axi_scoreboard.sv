`include "uvm_macros.svh"
`include "axi_define.v"

import uvm_pkg::*;

class axi_scoreboard extends uvm_scoreboard;

  // 1. 注册 Component
  `uvm_component_utils(axi_scoreboard)

  // 2. 端口定义：接收来自 Monitor 的 Transaction
  uvm_analysis_imp #(axi_transaction, axi_scoreboard)       item_export;

  // 3. 内部数据结构
  // 3.1 Golden Memory: 模拟 DDR/SRAM (Byte addressable)
  // 使用关联数组，稀疏存储，节省空间
  bit                                                 [7:0] ref_mem[longint unsigned];

  // 3.2 待处理队列 (用于匹配 Address 和 Data/Response)
  // 写通道：假设 W 数据顺序必须跟随 AW 地址顺序 (AXI4 规则)
  axi_transaction                                           aw_queue                  [$];

  // 读通道：支持乱序，必须用 ID 索引
  // key = ID, value = 该 ID 下的 AR 请求队列
  axi_transaction                                           ar_map[int]                   [$];
  axi_transaction                                           pending_ar_q              [$];
  axi_transaction                                           pending_r_q               [$];

  // 统计计数器
  int                                                       match_count                        = 0;
  int                                                       mismatch_count                     = 0;

  // ----------------------------------------------------------------
  // 构造函数
  // ----------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_export = new("item_export", this);
  endfunction

  // ----------------------------------------------------------------
  // Build Phase: 初始化内存 (可选)
  // ----------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 初始化一些默认数据，防止读空地址报错
    ref_mem[0] = 8'h00;
  endfunction

  // ----------------------------------------------------------------
  // Write 方法: 当 Monitor 广播数据时，这里会被调用
  // ----------------------------------------------------------------
  virtual function void write(axi_transaction tr);
    if (tr.is_write) begin
      handle_write(tr);
    end
    else begin
      handle_read(tr);
    end
  endfunction

  // ----------------------------------------------------------------
  // 核心逻辑 1: 处理写操作
  // ----------------------------------------------------------------
  function void handle_write(axi_transaction tr);
    // Case A: 写地址包 (AW)
    if (tr.addr != 0 && tr.data.size() == 0) begin
      aw_queue.push_back(tr);
      `uvm_info("SCB_AW", $sformatf("Received AW: ID=%0h Addr=%0h", tr.id, tr.addr), UVM_HIGH)
    end
    // Case B: 写数据包 (W)
    else if (tr.data.size() > 0) begin
      axi_transaction aw_tr;

      // 检查是否有对应的地址包
      if (aw_queue.size() == 0) begin
        `uvm_error("SCB_ERR", "Received W Data but AW Queue is empty! (Or W came before AW)")
        return;
      end

      // 取出队首的 AW 请求
      aw_tr = aw_queue.pop_front();

      // 校验数据长度是否匹配 (Len+1)
      if (tr.data.size() != aw_tr.len + 1) begin
        `uvm_error("SCB_LEN", $sformatf("W Data size (%0d) mismatch AW Len (%0d+1)",
                                        tr.data.size(), aw_tr.len))
      end

      // 写入 Golden Memory
      update_memory(aw_tr, tr);
      process_pending_reads();
    end
    // Case C: 写响应包 (B)
    else if (tr.resp >= 0) begin
      // 可以在这里检查 B response 是否为 OKAY，或者验证写完成 ID
      if (tr.resp != `AXI_RESP_OKAY) begin
        `uvm_warning("SCB_BRESP", $sformatf("Received Error Response for ID=%0h", tr.id))
      end
    end
  endfunction

  // ----------------------------------------------------------------
  // 核心逻辑 2: 处理读操作
  // ----------------------------------------------------------------
  function void handle_read(axi_transaction tr);
    // Case A: 读地址包 (AR)
    if (tr.addr != 0 && tr.data.size() == 0) begin
      // 将 AR 请求存入对应 ID 的队列
      ar_map[tr.id].push_back(tr);
      `uvm_info("SCB_AR", $sformatf("Received AR: ID=%0h Addr=%0h", tr.id, tr.addr), UVM_HIGH)
    end
    // Case B: 读数据包 (R)
    else if (tr.data.size() > 0) begin
      axi_transaction ar_tr;

      // 检查该 ID 是否有未完成的请求
      if (!ar_map.exists(tr.id) || ar_map[tr.id].size() == 0) begin
        `uvm_error("SCB_ERR", $sformatf("Received R Data for ID=%0h but AR Queue is empty!", tr.id))
        return;
      end

      // 取出该 ID 下最早的一个 AR 请求
      ar_tr = ar_map[tr.id].pop_front();

      // 执行比对（若与 pending 写冲突，则延迟重试）
      if (compare_data_core(ar_tr, tr, 0)) begin
        match_count++;
        `uvm_info("SCB_PASS", $sformatf("Read Check PASSED! Addr=%0h ID=%0h", ar_tr.addr, ar_tr.id),
                  UVM_MEDIUM)
      end
      else if (has_overlap_with_pending_writes(ar_tr)) begin
        pending_ar_q.push_back(ar_tr);
        pending_r_q.push_back(tr);
        `uvm_warning("SCB_DEFER",
                     $sformatf("Defer read compare due to pending write overlap. Addr=%0h ID=%0h",
                               ar_tr.addr, ar_tr.id))
      end
      else begin
        void'(compare_data_core(ar_tr, tr, 1));
        mismatch_count++;
      end

      process_pending_reads();
    end
  endfunction

  // ----------------------------------------------------------------
  // 辅助函数: 更新内存 (支持 INCR 模式地址计算)
  // ----------------------------------------------------------------
  function automatic longint calc_next_addr(
      input longint curr_addr, input longint start_addr, input bit [`AXI_BURST_WIDTH-1:0] burst,
      input bit [`AXI_SIZE_WIDTH-1:0] size, input bit [`AXI_LEN_WIDTH-1:0] len);
    int     num_bytes;
    int     burst_len;
    longint wrap_size;
    longint wrap_base;
    longint next_addr;

    num_bytes = (1 << size);
    burst_len = len + 1;

    case (burst)
      `AXI_BURST_FIXED: calc_next_addr = curr_addr;

      `AXI_BURST_WRAP: begin
        wrap_size = num_bytes * burst_len;
        wrap_base = (start_addr / wrap_size) * wrap_size;
        next_addr = curr_addr + num_bytes;

        if (next_addr >= (wrap_base + wrap_size)) calc_next_addr = wrap_base;
        else calc_next_addr = next_addr;
      end

      default: calc_next_addr = curr_addr + num_bytes;  // INCR
    endcase
  endfunction

  function void update_memory(axi_transaction aw_tr, axi_transaction w_tr);
    longint addr;
    longint start_addr;
    int     num_bytes = 1 << aw_tr.size;  // 2^size

    addr       = aw_tr.addr;
    start_addr = aw_tr.addr;

    foreach (w_tr.data[i]) begin  // i 是 beat index
      // 处理每一个 Beat
      // 注意：w_tr.data[i] 是一个 Word (Data Width) 吗？
      // 不，在 axi_seq_item 里 data[] 是动态数组，看 Driver 怎么用。
      // 这里的 data[i] 应该是 32bit/64bit 的整块数据。

      // 我们需要根据 wstrb 把有效字节写进去
      for (int b = 0; b < num_bytes; b++) begin
        // 计算当前字节的绝对地址
        longint byte_addr = addr + b;

        // 检查 Strobe (假设 wstrb 也是按 beat 组织的)
        // 这里简化：假设 wstrb 全 1，或者 w_tr.wstrb[i] 的第 b 位有效
        if (w_tr.wstrb[i][b]) begin
          // 取出数据中对应的字节
          byte byte_val = (w_tr.data[i] >> (b * 8)) & 8'hFF;
          ref_mem[byte_addr] = byte_val;
          // `uvm_info("SCB_MEM", $sformatf("Write Mem[%0h] = %0h", byte_addr, byte_val), UVM_DEBUG)
        end
      end

      // 更新下一个 Beat 的地址
      addr = calc_next_addr(addr, start_addr, aw_tr.burst, aw_tr.size, aw_tr.len);
    end
    `uvm_info("SCB_WR", $sformatf(
              "Memory Updated for Addr=%0h (Burst Len=%0d)", aw_tr.addr, aw_tr.len + 1), UVM_MEDIUM)
  endfunction

  function void burst_addr_window(axi_transaction tr, output longint min_addr,
                                  output longint max_addr);
    int     num_bytes;
    int     burst_len;
    longint wrap_size;
    longint wrap_base;

    num_bytes = (1 << tr.size);
    burst_len = tr.len + 1;

    case (tr.burst)
      `AXI_BURST_FIXED: begin
        min_addr = tr.addr;
        max_addr = tr.addr + num_bytes - 1;
      end

      `AXI_BURST_WRAP: begin
        wrap_size = num_bytes * burst_len;
        wrap_base = (tr.addr / wrap_size) * wrap_size;
        min_addr  = wrap_base;
        max_addr  = wrap_base + wrap_size - 1;
      end

      default: begin
        min_addr = tr.addr;
        max_addr = tr.addr + (num_bytes * burst_len) - 1;
      end
    endcase
  endfunction

  function bit has_overlap_with_pending_writes(axi_transaction ar_tr);
    longint ar_min, ar_max;
    longint aw_min, aw_max;

    burst_addr_window(ar_tr, ar_min, ar_max);

    foreach (aw_queue[i]) begin
      burst_addr_window(aw_queue[i], aw_min, aw_max);
      if ((ar_min <= aw_max) && (aw_min <= ar_max)) begin
        return 1;
      end
    end

    return 0;
  endfunction

  function void process_pending_reads();
    int i;
    i = 0;
    while (i < pending_ar_q.size()) begin
      if (compare_data_core(pending_ar_q[i], pending_r_q[i], 0)) begin
        match_count++;
        `uvm_info("SCB_PASS", $sformatf("Deferred Read Check PASSED! Addr=%0h ID=%0h",
                                        pending_ar_q[i].addr, pending_ar_q[i].id), UVM_MEDIUM)
        pending_ar_q.delete(i);
        pending_r_q.delete(i);
      end
      else if (!has_overlap_with_pending_writes(pending_ar_q[i])) begin
        void'(compare_data_core(pending_ar_q[i], pending_r_q[i], 1));
        mismatch_count++;
        pending_ar_q.delete(i);
        pending_r_q.delete(i);
      end
      else begin
        i++;
      end
    end
  endfunction

  // ----------------------------------------------------------------
  // 辅助函数: 数据比对
  // ----------------------------------------------------------------
  function bit compare_data_core(axi_transaction ar_tr, axi_transaction r_tr, bit report_error);
    longint addr;
    longint start_addr;
    int     num_bytes = 1 << ar_tr.size;
    bit     match = 1;

    addr       = ar_tr.addr;
    start_addr = ar_tr.addr;

    // 校验 Burst 长度
    if (r_tr.data.size() != ar_tr.len + 1) begin
      if (report_error)
        `uvm_error("SCB_CMP", $sformatf(
                   "Read Burst Length Mismatch! Exp=%0d Act=%0d", ar_tr.len + 1, r_tr.data.size()))
      return 0;
    end

    foreach (r_tr.data[i]) begin
      bit [`AXI_DATA_WIDTH-1:0] exp_data = 0;
      bit [`AXI_DATA_WIDTH-1:0] act_data = r_tr.data[i];

      // 从 Golden Memory 拼凑期望数据
      for (int b = 0; b < num_bytes; b++) begin
        longint byte_addr = addr + b;
        if (ref_mem.exists(byte_addr)) begin
          exp_data |= (ref_mem[byte_addr] << (b * 8));
        end
        else begin
          // 读到了未初始化的地址，通常认为是 0 或 X
          // 这里默认为 0
          exp_data |= 0;
        end
      end

      // 比对当前 Beat
      if (act_data !== exp_data) begin
        if (report_error)
          `uvm_error("SCB_MISMATCH", $sformatf(
                     "Addr=%0h Beat=%0d Exp=%0h Act=%0h", addr, i, exp_data, act_data))
        match = 0;
      end

      // 更新地址
      addr = calc_next_addr(addr, start_addr, ar_tr.burst, ar_tr.size, ar_tr.len);
    end

    return match;
  endfunction

  // ----------------------------------------------------------------
  // Report Phase: 打印最终结果
  // ----------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    $display("\n------------------------------------------------");
    $display("       AXI SCOREBOARD REPORT                    ");
    $display("------------------------------------------------");
    $display(" Total Matches    : %0d", match_count);
    $display(" Total Mismatches : %0d", mismatch_count);
    $display("------------------------------------------------\n");

    if (mismatch_count == 0 && match_count > 0) $display(">>>> RESULT: [PASSED] <<<<");
    else $display(">>>> RESULT: [FAILED] <<<<");
  endfunction

endclass
