`timescale 1ns/1ps

module tb_edge_detect();

    reg clk;
    reg rst_n;
    reg sig_in;
    wire pos_edge;
    wire neg_edge;

    // 实例化 DUT
    edge_detect u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .sig_in(sig_in),
        .pos_edge(pos_edge),
        .neg_edge(neg_edge)
    );

    // 100MHz 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // 初始化
        rst_n = 0;
        sig_in = 0;
        #15 rst_n = 1;

        // --- 场景 1: 正常的上升沿和下降沿 ---
        #20;
        @(negedge clk) sig_in = 1; // 在下降沿给输入，确保同步采样稳定
        #40;
        @(negedge clk) sig_in = 0;

        // --- 场景 2: 异步随机信号 ---
        // 模拟信号在时钟上升沿附近抖动（这是最容易产生亚稳态的时刻）
        #33;
        sig_in = 1;
        #2;
        sig_in = 0; // 这个脉冲太窄，观察是否会被漏掉

        #50;
        sig_in = 1;
        #100;

        $display("Simulation Finished!");
        $finish;
    end

    // 波形导出
    initial begin
        $fsdbDumpfile("tb_edge_detect.fsdb");
        $fsdbDumpvars(0, tb_edge_detect);
    end

endmodule