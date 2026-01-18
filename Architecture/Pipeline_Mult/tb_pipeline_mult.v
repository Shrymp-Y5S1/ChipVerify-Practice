`timescale 1ns/1ps

module tb_pipeline_mult();

    reg clk;
    reg rst_n;
    reg [7:0] a, b, c;
    wire [16:0] result; // 修改为 17 位

    // 实例化 DUT
    pipeline_mult u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .c(c),
        .result(result)
    );

    // 时钟生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; a = 0; b = 0; c = 0;
        #25; rst_n = 1; // 1. 异步释放复位，避开时钟沿
        @(posedge clk); // 2. 等待一个稳定的时钟沿

        repeat(10) begin
            @(posedge clk);
            #1;
            a = $urandom_range(0, 100);
            b = $urandom_range(0, 100);
            c = $urandom_range(0, 10);
        end

        @(posedge clk); // 3. 多等一个沿，让最后一组数据被采样进去
        #1;
        a = 0; b = 0; c = 0;

        #100; // 4. 继续跑 10 拍，观察“流水线排空”过程
        $finish;
    end
    // 自动监控输出
    initial begin
        #30; // 跳过复位
        forever begin
            @(posedge clk);
            #2; // 在计算完成后的稳定时刻采样
            if (result !== 0)
                $display("[%0tns] Output Captured: %0d", $time, result);
        end
    end

    // 波形导出
    initial begin
        $fsdbDumpfile("tb_pipeline_mult.fsdb");
        $fsdbDumpvars(0, tb_pipeline_mult);
    end

endmodule
