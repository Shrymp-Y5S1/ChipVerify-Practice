`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_axi_mst;

    import uvm_pkg::*;

    // ----------------------------------------------------------------
    // 1. Clock & Reset Generation
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
    // 2. Interface Instantiation
    // ----------------------------------------------------------------
    axi_interface if0(clk, rst_n);
    // 用来接收 RD 和 WR 模块的 Ready 输出
    wire rd_ready_out;
    wire wr_ready_out;
    // ----------------------------------------------------------------
    // 3. DUT Connection (Bridge Logic)
    // ----------------------------------------------------------------
    // 这里的逻辑是 TB 的核心：它负责把 Interface 的信号“分发”给读写两个模块

    assign if0.user_req_ready = if0.user_req_we ? wr_ready_out : rd_ready_out;

    // 3.1 读通道连接 (axi_mst_rd)
    axi_mst_rd #(
        .OST_DEPTH(16)
    ) u_rd (
        .clk            (clk),
        .rst_n          (rst_n),
        .rd_en          (1'b1), // Global Enable

        // User Interface Connect (Demux Logic)
        // 只有当 valid=1 且 we=0 (读) 时，才把 Valid 传给读模块
        .user_req_valid (if0.user_req_valid && !if0.user_req_we),
        .user_req_ready (rd_ready_out), // 假设读写 Ready 逻辑相同，或需做仲裁
        .user_req_id    (if0.user_req_id),
        .user_req_addr  (if0.user_req_addr),
        .user_req_len   (if0.user_req_len),
        .user_req_size  (if0.user_req_size),
        .user_req_burst (if0.user_req_burst),

        // AXI Master Read Channels (Connect to Interface)
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

        // Unused User ports (Master Read only)
        .axi_mst_aruser (),
        .axi_mst_ruser  (0)
    );

    // 3.2 写通道连接 (axi_mst_wr)
    axi_mst_wr #(
        .OST_DEPTH(16)
    ) u_wr (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_en          (1'b1),

        // User Interface Connect (Demux Logic)
        // 只有当 valid=1 且 we=1 (写) 时，才把 Valid 传给写模块
        .user_req_valid (if0.user_req_valid && if0.user_req_we),
        .user_req_ready (wr_ready_out), // 注意：这里有冲突，实际上需要一个 OR 逻辑或仲裁
        .user_req_id    (if0.user_req_id),
        .user_req_addr  (if0.user_req_addr),
        .user_req_len   (if0.user_req_len),
        .user_req_size  (if0.user_req_size),
        .user_req_burst (if0.user_req_burst),
        .user_req_wdata (if0.user_req_wdata),
        .user_req_wstrb (if0.user_req_wstrb),

        // AXI Master Write Channels
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

        // Unused
        .axi_mst_awuser (),
        .axi_mst_wuser  (),
        .axi_mst_buser  (0)
    );

    // ----------------------------------------------------------------
    // 4. Dummy Slave Behavior (临时模拟，防挂死)
    // ----------------------------------------------------------------
    // 如果没有 Slave Agent，Master 发出请求后会一直等待 Ready。
    // 这里我们简单地拉高 Ready，并且在收到请求后伪造一个响应。

    // 4.1 Always Ready
    assign if0.arready = 1'b1;
    assign if0.awready = 1'b1;
    assign if0.wready  = 1'b1;

    // 4.2 Auto Read Response (收到 AR 后，过几拍回数据)
    initial begin
        if0.rvalid = 0;
        forever begin
            @(posedge clk);
            if(if0.arvalid && if0.arready) begin
                // 模拟延时
                repeat(2) @(posedge clk);

                // 发送数据 (简单模拟一个beat)
                if0.rvalid <= 1;
                if0.rid    <= if0.arid; // 回传 ID
                if0.rdata  <= 32'hDEAD_BEEF;
                if0.rlast  <= 1; // 假设只发一个 Beat 用于测试
                if0.rresp  <= 0; // OKAY

                @(posedge clk);
                while(!if0.rready) @(posedge clk); // 等待 Master 接收
                if0.rvalid <= 0;
            end
        end
    end

    // 4.3 Auto Write Response (收到 WLAST 后，回 BVALID)

    // 只要收到写地址，就把 ID 存进来
    logic [`AXI_ID_WIDTH-1:0] slave_awid_queue[$];

    // 线程 1: 负责接收 AWID 并存入队列
    initial begin
        forever begin
            @(posedge clk);
            if(if0.awvalid && if0.awready) begin
                slave_awid_queue.push_back(if0.awid);
                $display("TB_SLAVE: Received AWID = %0h", if0.awid);
            end
        end
    end

    // 线程 2: 负责在数据写完后，取出 ID 并发送 B 响应
    initial begin
        if0.bvalid = 0;
        if0.bid    = 0;
        forever begin
            @(posedge clk);

            // 当收到 WLAST (且握手成功) 时，准备回响应
            if(if0.wvalid && if0.wready && if0.wlast) begin

                // 模拟 Slave 处理延时 (2拍)
                repeat(2) @(posedge clk);

                // 准备发送 BVALID
                if0.bvalid <= 1;
                if0.bresp  <= 0; // OKAY

                // 从队列头部取出一个 ID 作为 BID
                if(slave_awid_queue.size() > 0) begin
                    if0.bid <= slave_awid_queue.pop_front();
                end else begin
                    // 如果队列空了，说明 W 比 AW 先到，或者逻辑有误，暂时回 0
                    if0.bid <= 0;
                    $warning("TB_SLAVE: WLAST received but AWID queue is empty!");
                end

                // 等待 Master 接收 B 响应
                @(posedge clk);
                while(!if0.bready) @(posedge clk);
                if0.bvalid <= 0;
            end
        end
    end

    // ----------------------------------------------------------------
    // 5. UVM Config DB & Run
    // ----------------------------------------------------------------
    initial begin
        // 把 Interface 句柄存入 Config DB，供 Driver/Monitor 使用
        uvm_config_db#(virtual axi_interface)::set(null, "*", "vif", if0);

        $display("------------------------------------------------");
        $display("       AXI Master Bridge TB Started             ");
        $display("------------------------------------------------");

        // 启动 Test (需要创建一个 Test Case，或者这里先留空)
        run_test();
    end

    // Dump Waves
    initial begin
        $fsdbDumpfile("tb_axi_mst.fsdb");
        $fsdbDumpvars(0, tb_axi_mst);
    end

endmodule
