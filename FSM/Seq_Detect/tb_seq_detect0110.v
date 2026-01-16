`timescale 1ns/1ps

module tb_seq_detect0110;
    reg clk;
    reg rst_n;
    reg in;
    wire out;

    // 实例化 DUT
    seq_detect0110 u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .in(in),
        .out(out)
    );

    // 时钟生成 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试激励
    initial begin
        rst_n = 0; in = 0;
        #15 rst_n = 1;

        // 构造序列: 0110 (成功) -> 11 (干扰) -> 0110 (成功) -> 110 (重叠检测)
        // 期望序列输入: 0 -> 1 -> 1 -> 0 -> 1 -> 1 -> 0 -> 1 -> 1 -> 0 (重叠)

        feed_bit(0); feed_bit(1); feed_bit(1); feed_bit(0); // 第1次匹配
        feed_bit(1); feed_bit(1);                           // 干扰
        feed_bit(0); feed_bit(1); feed_bit(1); feed_bit(0); // 第2次匹配
        feed_bit(1); feed_bit(1); feed_bit(0);             // 干扰后再尝试

        #50;
        $display("Simulation Finished!");
        $finish;
    end

    // 辅助任务：在下降沿驱动数据，模拟真实时序
    task feed_bit(input b);
        begin
            @(negedge clk);
            in = b;
            $display("[%0tns] Input Bit: %b, Detect Out: %b", $time, b, out);
        end
    endtask

    // 波形记录
    initial begin
        $fsdbDumpfile("tb_seq_detect0110.fsdb");
        $fsdbDumpvars(0, tb_seq_detect0110);
    end
endmodule
