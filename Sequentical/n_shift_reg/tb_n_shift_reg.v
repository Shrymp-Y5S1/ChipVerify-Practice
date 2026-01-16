`timescale 1ns/1ps

module tb_n_shift_reg;

    // 1. 参数与信号定义
    parameter TEST_N = 8;

    reg clk;
    reg rst_n;
    reg dir;
    reg in_bit;
    wire [TEST_N-1:0] out_bits;

    // 2. 实例化 DUT
    n_shift_reg #(
        .N(TEST_N)
    ) u_shift_reg (
        .clk      (clk),
        .rst_n    (rst_n),
        .dir      (dir),
        .in_bit   (in_bit),
        .out_bits (out_bits)
    );

    // 3. 产生 100MHz 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. 产生测试激励
    initial begin
        // 初始化
        rst_n = 0;
        dir = 0;
        in_bit = 0;

        $display("-----------------------------------------------------");
        $display("Starting N-bit Shift Register Simulation (N = %0d)", TEST_N);
        $display("-----------------------------------------------------");

        // --- 1. 复位测试 ---
        #15 rst_n = 1;

        // --- 2. 测试左移 (dir = 0) ---
        // 目标：将 1011 从右端移入
        dir = 0;
        $display("[%0tns] Testing LEFT Shift...", $time);
        push_bit(1); push_bit(0); push_bit(1); push_bit(1);
        #20;

        // --- 3. 测试右移 (dir = 1) ---
        // 目标：将 1100 从左端移入
        dir = 1;
        $display("[%0tns] Testing RIGHT Shift...", $time);
        push_bit(1); push_bit(1); push_bit(0); push_bit(0);

        #50;
        $display("-----------------------------------------------------");
        $display("Simulation Finished!");
        $finish;
    end

    // 自动压入位的辅助任务
    task push_bit(input bit b);
        begin
            @(negedge clk); // 在下降沿给数据，确保上升沿稳定采样
            in_bit = b;
            $display("[%0tns] Pushing bit: %b", $time, b);
        end
    endtask

    // 5. 波形导出
    initial begin
        $fsdbDumpfile("tb_n_shift_reg.fsdb");
        $fsdbDumpvars(0, tb_n_shift_reg);
    end

endmodule
