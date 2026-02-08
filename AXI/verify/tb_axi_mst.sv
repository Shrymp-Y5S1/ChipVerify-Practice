`timescale 1ns/1ps

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
        forever #10 clk = ~clk; // 50MHz
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // ----------------------------------------------------------------
    // 2. Interface & DUT
    // ----------------------------------------------------------------
    axi_interface if0(clk, rst_n);

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
        .OST_DEPTH(16),
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
    byte slave_mem [longint];

    // --- Write Channel Logic ---

    typedef struct {
        logic [`AXI_ID_WIDTH-1:0]   id;
        logic [`AXI_ADDR_WIDTH-1:0] addr;
        logic [`AXI_LEN_WIDTH-1:0]  len;
        logic [`AXI_BURST_WIDTH-1:0] burst;
    } aw_req_t;

    // W 通道数据结构
    typedef struct {
        logic [`AXI_DATA_WIDTH-1:0] data;
        logic [(`AXI_DATA_WIDTH/8)-1:0] strb;
        logic last;
    } w_req_t;

    aw_req_t aw_fifo[$];
    w_req_t  w_fifo[$];

    // 3.1 接收 AW 请求 -> 存入 AW FIFO
    initial begin
        if0.awready = 1;
        forever begin
            @(posedge clk);
            if(if0.awvalid && if0.awready) begin
                aw_req_t req;
                req.id    = if0.awid;
                req.addr  = if0.awaddr;
                req.len   = if0.awlen;
                req.burst = if0.awburst;
                aw_fifo.push_back(req);
            end
        end
    end

    // 3.2 接收 W 数据 -> 存入 W FIFO
    initial begin
        if0.wready = 1;
        forever begin
            @(posedge clk);
            if(if0.wvalid && if0.wready) begin
                w_req_t req;
                req.data = if0.wdata;
                req.strb = if0.wstrb;
                req.last = if0.wlast;
                w_fifo.push_back(req);
            end
        end
    end

    // 3.3 核心处理线程：匹配 AW 和 W 并写入 Memory
    initial begin
        if0.bvalid = 0;
        if0.bid    = 0;

        forever begin
            @(posedge clk);

            // 只有当 AW 和 W 都有数据时，才进行处理
            if(aw_fifo.size() > 0 && w_fifo.size() > 0) begin
                aw_req_t curr_aw;
                w_req_t  curr_w;

                curr_aw = aw_fifo[0]; // Peek AW (不要Pop，因为要处理多个Beat)
                curr_w  = w_fifo.pop_front(); // Pop W (消耗一个Beat)

                // 写入内存
                for(int b=0; b<4; b++) begin
                    if(curr_w.strb[b]) begin
                        slave_mem[curr_aw.addr + b] = (curr_w.data >> (b*8)) & 8'hFF;
                        // 调试打印
                        // $display("[TB_MEM_WR] Addr=%0h DataByte=%0h Time=%0t", curr_aw.addr + b, (curr_w.data >> (b*8)) & 8'hFF, $time);
                    end
                end

                // 更新 AW 的地址 (INCR模式)
                if(curr_aw.burst == `AXI_BURST_INCR) begin
                    aw_fifo[0].addr = curr_aw.addr + 4;
                end

                // 如果是 Last Beat，说明这个 AW 处理完了
                if(curr_w.last) begin
                    void'(aw_fifo.pop_front()); // 移除 AW

                    // 发送 B 响应
                    if0.bvalid <= 1;
                    if0.bid    <= curr_aw.id;
                    if0.bresp  <= 0; // OKAY

                    @(posedge clk);
                    while(!if0.bready) @(posedge clk);
                    if0.bvalid <= 0;
                end
            end
        end
    end

    // --- Read Channel Logic ---

    typedef struct {
        logic [`AXI_ID_WIDTH-1:0]   id;
        logic [`AXI_LEN_WIDTH-1:0]  len;
        logic [`AXI_ADDR_WIDTH-1:0] addr;
        logic [`AXI_BURST_WIDTH-1:0] burst;
    } ar_req_t;

    ar_req_t ar_queue[$];

    // 3.3 接收 AR 请求
    initial begin
        if0.arready = 1;
        forever begin
            @(posedge clk);
            if(if0.arvalid && if0.arready) begin
                ar_req_t req;
                req.id    = if0.arid;
                req.len   = if0.arlen;
                req.addr  = if0.araddr;
                req.burst = if0.arburst;
                ar_queue.push_back(req);
            end
        end
    end

    // 3.4 发送 R 数据 (从 Memory 读取)
    initial begin
        if0.rvalid = 0;
        if0.rlast  = 0;

        forever begin
            @(posedge clk);
            if (ar_queue.size() > 0) begin
                ar_req_t req;
                longint curr_addr;
                req = ar_queue.pop_front();
                curr_addr = req.addr;

                repeat(2) @(posedge clk); // Latency

                // Burst Loop
                for (int i = 0; i <= req.len; i++) begin
                    logic [31:0] rdata_temp;
                    rdata_temp = 0;

                    // 从 slave_mem 读取 4 字节
                    for(int b=0; b<4; b++) begin
                        if(slave_mem.exists(curr_addr + b))
                            rdata_temp[b*8 +: 8] = slave_mem[curr_addr + b];
                        else
                            rdata_temp[b*8 +: 8] = 0; // 默认 0
                    end

                    if0.rvalid <= 1;
                    if0.rid    <= req.id;
                    if0.rdata  <= rdata_temp;
                    if0.rresp  <= 0;
                    if0.rlast  <= (i == req.len);

                    @(posedge clk);
                    while(!if0.rready) @(posedge clk);

                    // 更新地址
                    if(req.burst == `AXI_BURST_INCR) curr_addr += 4;
                end

                if0.rvalid <= 0;
                if0.rlast  <= 0;
            end
        end
    end

    // ----------------------------------------------------------------
    // 4. Config DB & Run
    // ----------------------------------------------------------------
    initial begin
        uvm_config_db#(virtual axi_interface)::set(null, "*", "vif", if0);
        run_test();
    end

    initial begin
        $fsdbDumpfile("tb_axi_mst.fsdb");
        $fsdbDumpvars(0, tb_axi_mst, "+all");
    end

endmodule
