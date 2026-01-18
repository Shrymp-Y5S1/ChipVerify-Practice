`timescale 1ns/1ps

module tb_rst_bridge();

    reg clk;
    reg async_rst_n;
    wire sync_rst_n;

    // 实例化 DUT
    rst_bridge u_dut (
        .clk(clk),
        .async_rst_n(async_rst_n),
        .sync_rst_n(sync_rst_n)
    );

    // 产生 100MHz 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // 初始状态：复位激活
        async_rst_n = 0;
        #23; // 在非时钟沿释放复位

        // --- 测试点 1: 同步释放 ---
        async_rst_n = 1;
        $display("[%0tns] Async reset released. Waiting for sync release...", $time);

        // 等待 sync_rst_n 变高
        @(posedge sync_rst_n);
        $display("[%0tns] Sync reset released successfully!", $time);

        #50;

        // --- 测试点 2: 异步生效 ---
        // 在时钟中途突然拉低复位
        #3;
        async_rst_n = 0;
        #1; // 极短时间后检查
        if (sync_rst_n == 0)
            $display("[%0tns] PASS: Asynchronous reset activation is immediate.", $time);
        else
            $display("[%0tns] FAIL: Asynchronous reset activation delayed!", $time);

        #20;
        async_rst_n = 1; // 再次释放

        #100;
        $finish;
    end

    // 波形导出
    initial begin
        $fsdbDumpfile("tb_rst_bridge.fsdb");
        $fsdbDumpvars(0, tb_rst_bridge);
    end

endmodule
