`timescale 1ns/1ps

module tb_pulse_sync_f2s();

    reg clk_f;
    reg clk_s;
    reg rst_n;
    reg pulse_f;
    wire pulse_s;

    // 实例化被测设计 (DUT)
    pulse_sync_f2s u_dut (
        .clk_f   (clk_f),
        .clk_s   (clk_s),
        .rst_n   (rst_n),
        .pulse_f (pulse_f),
        .pulse_s (pulse_s)
    );

    // --- 时钟生成 ---
    // 快时钟: 100MHz (周期 10ns)
    initial begin
        clk_f = 0;
        forever #5 clk_f = ~clk_f;
    end

    // 慢时钟: 20MHz (周期 50ns) - 模拟明显的频率差异
    initial begin
        clk_s = 0;
        forever #25 clk_s = ~clk_s;
    end

    // --- 激励逻辑 ---
    initial begin
        // 初始化
        rst_n = 0;
        pulse_f = 0;
        #105 rst_n = 1;
        #50;

        // 【测试案例 1：孤立脉冲测试】
        // 验证两种方法在慢时钟域都能成功检测到单次跳变
        $display("[%0t] Case 1: Single pulse testing...", $time);
        send_pulse(1);
        #200;

        // 【测试案例 2：疏脉冲测试 (间隔较大)】
        // 间隔 200ns (> 3个慢时钟周期)，两种方法都应该能成功检测到两个脉冲
        $display("[%0t] Case 2: Sparse pulses testing...", $time);
        send_pulse(1);
        #200;
        send_pulse(1);
        #300;

        // 【测试案例 3：密脉冲测试 (失效/忙碌验证)】
        // 间隔仅 20ns (< 1个慢时钟周期)
        // 电平翻转法：可能因为翻转太快导致慢时钟采样不到跳变（失效）
        // 带反馈握手法：由于 req_f 还在忙碌状态，第二个脉冲会被逻辑忽略（丢失）
        $display("[%0t] Case 3: Dense pulses testing (stress test)...", $time);
        send_pulse(1);
        #20; // 极短的间隔
        send_pulse(1);

        #1000;
        $display("[%0t] All test cases finished.", $time);
        $finish;
    end

    // 发送单周期脉冲的任务
    task send_pulse(input integer num);
        integer i;
        begin
            for(i=0; i<num; i=i+1) begin
                @(posedge clk_f);
                pulse_f <= 1'b1;
                @(posedge clk_f);
                pulse_f <= 1'b0;
            end
        end
    endtask

    // 波形导出
    initial begin
        $fsdbDumpfile("tb_pulse_sync_f2s.fsdb");
        $fsdbDumpvars(0, tb_pulse_sync_f2s);
    end

endmodule
