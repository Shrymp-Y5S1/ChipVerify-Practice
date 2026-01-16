`timescale 1ns/1ps

module tb_ModN_counter;

    // 1. 参数与信号定义
    parameter TEST_N     = 10; // 测试模 10
    parameter TEST_WIDTH = 4;

    reg clk;
    reg rst_n;
    wire [TEST_WIDTH-1:0] cout;

    // 2. 实例化 DUT (使用参数重载)
    ModN_counter #(
        .N(TEST_N),
        .WIDTH(TEST_WIDTH)
    ) u_counter (
        .clk   (clk),
        .rst_n (rst_n),
        .cout  (cout)
    );

    // 3. 产生 100MHz 时钟 (10ns 周期)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. 产生刺激激励
    initial begin
        // 初始化
        rst_n = 0;

        $display("-----------------------------------------------------");
        $display("Starting ModN Counter Simulation (N = %0d)", TEST_N);
        $display("-----------------------------------------------------");

        // --- 1. 复位测试 ---
        #15;
        rst_n = 1; // 释放复位
        $display("[%0tns] Reset released.", $time);

        // --- 2. 观察计数过程 ---
        // 运行足够长的时间，至少观察 2-3 个完整的计数周期
        repeat (TEST_N * 3) begin
            @(posedge clk);
            // 可以在每个上升沿采样并打印，检查是否跳回 0
            #1; // 延迟 1ns 采样，避开竞争冒险
            if (cout == TEST_N - 1) begin
                $display("[%0tns] Counter reached MAX (%0d), checking next cycle...", $time, cout);
            end
        end

        // --- 3. 运行中复位测试 (Robustness Check) ---
        #3;
        rst_n = 0;
        $display("[%0tns] Applying mid-run reset...", $time);
        #10;
        if (cout === 0)
            $display("[%0tns] PASS: Mid-run reset successful.", $time);
        else
            $display("[%0tns] FAIL: Mid-run reset failed!", $time);

        rst_n = 1;
        #50;

        $display("-----------------------------------------------------");
        $display("Simulation Finished!");
        $finish;
    end

    // 5. 波形导出
    initial begin
        $fsdbDumpfile("tb_ModN_counter.fsdb");
        $fsdbDumpvars(0, tb_ModN_counter);
    end

endmodule
