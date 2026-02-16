`timescale 1ns / 1ps

`include "uvm_macros.svh"

module tb_axi_mst;

  import uvm_pkg::*;

  // ----------------------------------------------------------------
  // 1. Clock & Reset
  // ----------------------------------------------------------------
  reg clk;
  reg rst_n;

  initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50MHz
  end

  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end

  // ----------------------------------------------------------------
  // 2. Interface & DUT
  // ----------------------------------------------------------------
  axi_interface if0 (
    clk,
    rst_n
  );

  // 中间信号
  wire rd_ready_out;
  wire wr_ready_out;

  // DUT: Read Master
  axi_mst_rd #(
    .OST_DEPTH(16)
  ) u_rd (
    .clk            (clk),
    .rst_n          (rst_n),
    .rd_en          (1'b1),
    .user_req_valid (if0.user_req_valid && !if0.user_req_we),
    .user_req_ready (rd_ready_out),
    .user_req_id    (if0.user_req_id),
    .user_req_addr  (if0.user_req_addr),
    .user_req_len   (if0.user_req_len),
    .user_req_size  (if0.user_req_size),
    .user_req_burst (if0.user_req_burst),
    .axi_mst_arid   (if0.arid),
    .axi_mst_araddr (if0.araddr),
    .axi_mst_arlen  (if0.arlen),
    .axi_mst_arsize (if0.arsize),
    .axi_mst_arburst(if0.arburst),
    .axi_mst_arvalid(if0.arvalid),
    .axi_mst_arready(if0.arready),
    .axi_mst_rid    (if0.rid),
    .axi_mst_rdata  (if0.rdata),
    .axi_mst_rresp  (if0.rresp),
    .axi_mst_rlast  (if0.rlast),
    .axi_mst_rvalid (if0.rvalid),
    .axi_mst_rready (if0.rready),
    .axi_mst_aruser (),
    .axi_mst_ruser  (0)
  );

  // DUT: Write Master
  axi_mst_wr #(
    .OST_DEPTH    (16),
    .MAX_BURST_LEN(8)
  ) u_wr (
    .clk            (clk),
    .rst_n          (rst_n),
    .wr_en          (1'b1),
    .user_req_valid (if0.user_req_valid && if0.user_req_we),
    .user_req_ready (wr_ready_out),
    .user_req_id    (if0.user_req_id),
    .user_req_addr  (if0.user_req_addr),
    .user_req_len   (if0.user_req_len),
    .user_req_size  (if0.user_req_size),
    .user_req_burst (if0.user_req_burst),
    .user_req_wdata (if0.user_req_wdata),
    .user_req_wstrb (if0.user_req_wstrb),
    .axi_mst_awid   (if0.awid),
    .axi_mst_awaddr (if0.awaddr),
    .axi_mst_awlen  (if0.awlen),
    .axi_mst_awsize (if0.awsize),
    .axi_mst_awburst(if0.awburst),
    .axi_mst_awvalid(if0.awvalid),
    .axi_mst_awready(if0.awready),
    .axi_mst_wdata  (if0.wdata),
    .axi_mst_wstrb  (if0.wstrb),
    .axi_mst_wlast  (if0.wlast),
    .axi_mst_wvalid (if0.wvalid),
    .axi_mst_wready (if0.wready),
    .axi_mst_bid    (if0.bid),
    .axi_mst_bresp  (if0.bresp),
    .axi_mst_bvalid (if0.bvalid),
    .axi_mst_bready (if0.bready),
    .axi_mst_awuser (),
    .axi_mst_wuser  (),
    .axi_mst_buser  (0)
  );

  assign if0.user_req_ready = if0.user_req_we ? wr_ready_out : rd_ready_out;

  // ----------------------------------------------------------------
  // 3. SLAVE MEMORY MODEL
  // ----------------------------------------------------------------
  // Slave 存储所有写入的数据
  byte slave_mem             [longint];

  int  slave_slverr_pct;
  int  slave_decerr_pct;
  int  tb_err_resp_only_mode;
  int  tb_hs_timeout_cycles;
  int  b_wait_cycles;
  int  r_wait_cycles;

  function automatic logic [`AXI_RESP_WIDTH-1:0] gen_slave_resp(
      input logic [`AXI_ADDR_WIDTH-1:0] addr);
    int rnd;
    rnd = $urandom_range(0, 99);

    if (rnd < slave_decerr_pct) begin
      gen_slave_resp = `AXI_RESP_DECERR;
    end
    else if (rnd < (slave_decerr_pct + slave_slverr_pct)) begin
      gen_slave_resp = `AXI_RESP_SLVERR;
    end
    else begin
      gen_slave_resp = `AXI_RESP_OKAY;
    end
  endfunction

  function automatic longint calc_next_addr(
      input longint curr_addr, input longint start_addr, input logic [`AXI_BURST_WIDTH-1:0] burst,
      input logic [`AXI_SIZE_WIDTH-1:0] size, input logic [`AXI_LEN_WIDTH-1:0] len);
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

  // --- Write Channel Logic ---

  typedef struct {
    logic [`AXI_ID_WIDTH-1:0]    id;
    logic [`AXI_SIZE_WIDTH-1:0]  size;
    logic [`AXI_ADDR_WIDTH-1:0]  addr;
    logic [`AXI_ADDR_WIDTH-1:0]  start_addr;
    logic [`AXI_LEN_WIDTH-1:0]   len;
    logic [`AXI_BURST_WIDTH-1:0] burst;
  } aw_req_t;

  // W 通道数据结构
  typedef struct {
    logic [`AXI_DATA_WIDTH-1:0]     data;
    logic [(`AXI_DATA_WIDTH/8)-1:0] strb;
    logic                           last;
  } w_req_t;

  aw_req_t aw_fifo[$];
  w_req_t  w_fifo [$];

  typedef struct {
    logic [`AXI_ID_WIDTH-1:0]   id;
    logic [`AXI_RESP_WIDTH-1:0] resp;
  } b_rsp_t;

  b_rsp_t b_rsp_q    [$];
  int     b_rsp_sel;
  b_rsp_t b_rsp_curr;

  // 接收 AW 请求 -> 存入 AW FIFO
  initial begin
    forever begin
      @(posedge clk);
      if (if0.awvalid && if0.awready) begin
        aw_req_t req;
        req.id         = if0.awid;
        req.size       = if0.awsize;
        req.addr       = if0.awaddr;
        req.start_addr = if0.awaddr;
        req.len        = if0.awlen;
        req.burst      = if0.awburst;
        aw_fifo.push_back(req);
      end
    end
  end

  // 接收 W 数据 -> 存入 W FIFO
  initial begin
    forever begin
      @(posedge clk);
      if (if0.wvalid && if0.wready) begin
        w_req_t req;
        req.data = if0.wdata;
        req.strb = if0.wstrb;
        req.last = if0.wlast;
        w_fifo.push_back(req);
      end
    end
  end

  // 匹配 AW 和 W 并写入 Memory
  initial begin
    forever begin
      @(posedge clk);

      // 只有当 AW 和 W 都有数据时，才进行处理
      if (aw_fifo.size() > 0 && w_fifo.size() > 0) begin
        aw_req_t curr_aw;
        w_req_t  curr_w;
        int      beat_bytes;

        curr_aw    = aw_fifo[0];  // Peek AW (不要Pop，因为要处理多个Beat)
        curr_w     = w_fifo.pop_front();  // Pop W (消耗一个Beat)
        beat_bytes = (1 << curr_aw.size);

        // 写入内存
        for (int b = 0; b < beat_bytes; b++) begin
          if (curr_w.strb[b]) begin
            slave_mem[curr_aw.addr+b] = (curr_w.data >> (b * 8)) & 8'hFF;
            // 调试打印
            // $display("[TB_MEM_WR] Addr=%0h DataByte=%0h Time=%0t", curr_aw.addr + b, (curr_w.data >> (b*8)) & 8'hFF, $time);
          end
        end

        // 更新 AW 的地址 (支持 FIXED/INCR/WRAP)
        aw_fifo[0].addr = calc_next_addr(curr_aw.addr, curr_aw.start_addr, curr_aw.burst,
                                         curr_aw.size, curr_aw.len);

        // 如果是 Last Beat，说明这个 AW 处理完了
        if (curr_w.last) begin
          void'(aw_fifo.pop_front());  // 移除 AW

          // 入队写响应，后续可乱序发送
          b_rsp_curr.id   = curr_aw.id;
          b_rsp_curr.resp = gen_slave_resp(curr_aw.start_addr);
          b_rsp_q.push_back(b_rsp_curr);
        end
      end
    end
  end

  // 乱序发送 B 响应
  initial begin
    if0.bvalid = 0;
    if0.bid    = 0;
    if0.bresp  = 0;

    forever begin
      @(posedge clk);

      if (!rst_n) begin
        if0.bvalid <= 0;
      end
      else if (!if0.bvalid && b_rsp_q.size() > 0) begin
        b_rsp_sel  = $urandom_range(0, b_rsp_q.size() - 1);
        b_rsp_curr = b_rsp_q[b_rsp_sel];
        b_rsp_q.delete(b_rsp_sel);

        if0.bvalid <= 1;
        if0.bid    <= b_rsp_curr.id;
        if0.bresp  <= b_rsp_curr.resp;

        @(posedge clk);
        b_wait_cycles = 0;
        while (!if0.bready && b_wait_cycles < tb_hs_timeout_cycles) begin
          @(posedge clk);
          b_wait_cycles++;
        end
        if (!if0.bready) begin
          $error("[TB_B] Timeout waiting BREADY for ID=%0h after %0d cycles", b_rsp_curr.id,
                 tb_hs_timeout_cycles);
        end
        if0.bvalid <= 0;
      end
    end
  end

  // --- Read Channel Logic ---

  typedef struct {
    logic [`AXI_ID_WIDTH-1:0]    id;
    logic [`AXI_SIZE_WIDTH-1:0]  size;
    logic [`AXI_LEN_WIDTH-1:0]   len;
    logic [`AXI_ADDR_WIDTH-1:0]  addr;
    logic [`AXI_ADDR_WIDTH-1:0]  start_addr;
    logic [`AXI_BURST_WIDTH-1:0] burst;
  } ar_req_t;

  ar_req_t ar_queue[$];

  typedef struct {
    logic [`AXI_ID_WIDTH-1:0]    id;
    logic [`AXI_SIZE_WIDTH-1:0]  size;
    logic [`AXI_LEN_WIDTH-1:0]   len;
    logic [`AXI_ADDR_WIDTH-1:0]  addr;
    logic [`AXI_ADDR_WIDTH-1:0]  start_addr;
    logic [`AXI_BURST_WIDTH-1:0] burst;
    logic [`AXI_RESP_WIDTH-1:0]  resp;
    int                          beat_idx;
    int                          delay_cnt;
  } rd_ctx_t;

  rd_ctx_t rd_active_q[$];

  // 接收 AR 请求
  initial begin
    forever begin
      @(posedge clk);
      if (if0.arvalid && if0.arready) begin
        ar_req_t req;
        req.id         = if0.arid;
        req.size       = if0.arsize;
        req.len        = if0.arlen;
        req.addr       = if0.araddr;
        req.start_addr = if0.araddr;
        req.burst      = if0.arburst;
        ar_queue.push_back(req);
      end
    end
  end

  // 发送 R 数据 (支持 OoO + Beat-level Interleaving)
  initial begin
    if0.rvalid = 0;
    if0.rlast  = 0;
    if0.rid    = 0;
    if0.rdata  = 0;
    if0.rresp  = 0;

    forever begin
      @(posedge clk);
      if (!rst_n) begin
        if0.rvalid <= 0;
        if0.rlast  <= 0;
        rd_active_q.delete();
      end
      else begin
        // 持续吸收 AR 请求到 active context
        while (ar_queue.size() > 0) begin
          ar_req_t req;
          rd_ctx_t ctx;

          if (tb_err_resp_only_mode && (rd_active_q.size() > 0)) begin
            break;
          end

          req            = ar_queue.pop_front();

          ctx.id         = req.id;
          ctx.size       = req.size;
          ctx.len        = req.len;
          ctx.addr       = req.addr;
          ctx.start_addr = req.start_addr;
          ctx.burst      = req.burst;
          ctx.resp       = gen_slave_resp(req.addr);
          ctx.beat_idx   = 0;
          if (tb_err_resp_only_mode) ctx.delay_cnt = 0;
          else ctx.delay_cnt = $urandom_range(0, 2);

          rd_active_q.push_back(ctx);
        end

        // 延迟计数递减
        foreach (rd_active_q[i]) begin
          if (rd_active_q[i].delay_cnt > 0) rd_active_q[i].delay_cnt--;
        end

        // 从可发送 context 中随机挑一个，制造 OoO/Interleaving
        if (!if0.rvalid) begin
          int             eligible_idx_q[$];
          int             seen_id_q     [$];
          bit             id_seen;
          int             sel_list_idx;
          int             sel;
          rd_ctx_t        curr_ctx;
          int             beat_bytes;
          logic    [31:0] rdata_temp;

          foreach (rd_active_q[i]) begin
            if (rd_active_q[i].delay_cnt == 0) begin
              id_seen = 0;
              foreach (seen_id_q[j]) begin
                if (seen_id_q[j] == rd_active_q[i].id) begin
                  id_seen = 1;
                end
              end

              if (!id_seen) begin
                eligible_idx_q.push_back(i);
                seen_id_q.push_back(rd_active_q[i].id);
              end
            end
          end

          if (eligible_idx_q.size() > 0) begin
            if (tb_err_resp_only_mode) sel_list_idx = 0;
            else sel_list_idx = $urandom_range(0, eligible_idx_q.size() - 1);
            sel        = eligible_idx_q[sel_list_idx];
            curr_ctx   = rd_active_q[sel];
            beat_bytes = (1 << curr_ctx.size);
            rdata_temp = 0;

            for (int b = 0; b < beat_bytes; b++) begin
              if (slave_mem.exists(curr_ctx.addr + b))
                rdata_temp[b*8+:8] = slave_mem[curr_ctx.addr+b];
              else rdata_temp[b*8+:8] = 0;
            end

            if0.rvalid <= 1;
            if0.rid    <= curr_ctx.id;
            if0.rdata  <= rdata_temp;
            if0.rresp  <= curr_ctx.resp;
            if0.rlast  <= (curr_ctx.beat_idx == curr_ctx.len);

            @(posedge clk);
            r_wait_cycles = 0;
            while (!if0.rready && r_wait_cycles < tb_hs_timeout_cycles) begin
              @(posedge clk);
              r_wait_cycles++;
            end
            if (!if0.rready) begin
              $error("[TB_R] Timeout waiting RREADY for ID=%0h after %0d cycles", curr_ctx.id,
                     tb_hs_timeout_cycles);
            end

            if0.rvalid <= 0;
            if0.rlast  <= 0;

            curr_ctx.addr = calc_next_addr(curr_ctx.addr, curr_ctx.start_addr, curr_ctx.burst,
                                           curr_ctx.size, curr_ctx.len);
            curr_ctx.beat_idx++;

            if (curr_ctx.beat_idx > curr_ctx.len) begin
              rd_active_q.delete(sel);
            end
            else begin
              if (tb_err_resp_only_mode) curr_ctx.delay_cnt = 0;
              else curr_ctx.delay_cnt = $urandom_range(0, 1);
              rd_active_q[sel] = curr_ctx;
            end
          end
        end
      end
    end
  end

  // ----------------------------------------------------------------
  // 4. 驱动 Ready 信号 (随机反压)
  // ----------------------------------------------------------------
  // AW Ready 驱动 (随机反压)
  initial begin
    if0.awready = 0;
    forever begin
      @(posedge clk);
      if (rst_n) begin
        if (tb_err_resp_only_mode) begin
          if0.awready <= 1;
        end
        else begin
          // 30% 概率反压，70% 概率 Ready
          // std::randomize 也可以，但在模块层级用 randcase 更方便
          randcase
            70: if0.awready <= 1;
            30: if0.awready <= 0;
          endcase
        end
      end
    end
  end

  // AR Ready 驱动 (随机反压)
  initial begin
    if0.arready = 0;
    forever begin
      @(posedge clk);
      if (rst_n) begin
        if (tb_err_resp_only_mode) begin
          if0.arready <= 1;
        end
        else begin
          randcase
            70: if0.arready <= 1;
            30: if0.arready <= 0;
          endcase
        end
      end
    end
  end

  // W Ready 也可以加上，但目前的 assertion 只检查了 AR
  initial begin
    if0.wready = 0;
    forever begin
      @(posedge clk);
      if (rst_n) begin
        if (tb_err_resp_only_mode) begin
          if0.wready <= 1;
        end
        else begin
          randcase
            70: if0.wready <= 1;
            30: if0.wready <= 0;
          endcase
        end
      end
    end
  end

  // ----------------------------------------------------------------
  // 5. Config DB & Run
  // ----------------------------------------------------------------
  initial begin
    string uvm_testname;

    slave_slverr_pct      = 0;
    slave_decerr_pct      = 0;
    tb_err_resp_only_mode = 0;
    tb_hs_timeout_cycles  = 100000;

    if ($value$plusargs("UVM_TESTNAME=%s", uvm_testname)) begin
      if (uvm_testname == "axi_error_resp_test") begin
        slave_slverr_pct      = 20;
        slave_decerr_pct      = 5;
        tb_err_resp_only_mode = 1;
      end
    end

    void'($value$plusargs("SLV_ERR_PCT=%d", slave_slverr_pct));
    void'($value$plusargs("DEC_ERR_PCT=%d", slave_decerr_pct));
    void'($value$plusargs("ERR_RESP_ONLY_MODE=%d", tb_err_resp_only_mode));
    void'($value$plusargs("TB_HS_TIMEOUT=%d", tb_hs_timeout_cycles));

    if (slave_slverr_pct < 0) slave_slverr_pct = 0;
    if (slave_decerr_pct < 0) slave_decerr_pct = 0;
    if (slave_slverr_pct > 100) slave_slverr_pct = 100;
    if (slave_decerr_pct > 100) slave_decerr_pct = 100;
    if ((slave_slverr_pct + slave_decerr_pct) > 100) begin
      slave_decerr_pct = 100 - slave_slverr_pct;
      if (slave_decerr_pct < 0) slave_decerr_pct = 0;
    end

    if (tb_hs_timeout_cycles <= 0) tb_hs_timeout_cycles = 100000;

    $display("[TB_CFG] SLV_ERR_PCT=%0d DEC_ERR_PCT=%0d ERR_RESP_ONLY_MODE=%0d TB_HS_TIMEOUT=%0d",
             slave_slverr_pct, slave_decerr_pct, tb_err_resp_only_mode, tb_hs_timeout_cycles);

    uvm_config_db#(virtual axi_interface)::set(null, "*", "vif", if0);
    run_test();
  end

  initial begin
    $fsdbDumpfile("tb_axi_mst.fsdb");
    $fsdbDumpvars(0, tb_axi_mst, "+all");
  end

endmodule
