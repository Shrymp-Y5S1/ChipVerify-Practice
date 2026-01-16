`timescale 1ns/1ps

module tb_D_Flip_Flop;

    // 1. 信号定义
    reg  clk;
    reg  rst_n;
    reg  D;
    wire Q;

    // 2. 实例化 DUT
    D_Flip_Flop u_dff (
        .clk   (clk),
        .rst_n (rst_n),
        .D     (D),
        .Q     (Q)
    );

    // 3. 产生时钟 (100MHz, 周期为 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. 产生测试激励
    initial begin
        // 初始化信号
        rst_n = 0;
        D = 0;

        $display("-----------------------------------------------------");
        $display("Starting DFF Simulation...");

        // --- 测试 1: 异步复位 ---
        #12;           // 在非时钟沿释放复位
        rst_n = 1;
        #3;

        // --- 测试 2: 正常数据采样 ---
        // 注意：在时序逻辑 TB 中，尽量在时钟下降沿给激励，
        // 这样可以模拟真实的时序（避开上升沿的 Setup/Hold 风险）
        @(negedge clk);
        D = 1'b1;
        $display("[%0tns] D set to 1, waiting for posedge clk...", $time);

        @(posedge clk);
        #1; // 等待 1ns 让逻辑生效
        if (Q === 1'b1)
            $display("[%0tns] PASS: Q captured D = 1", $time);
        else
            $display("[%0tns] FAIL: Q is %b", $time, Q);

        @(negedge clk);
        D = 1'b0;

        // --- 测试 3: 异步复位的即时性 ---
        #2;
        D = 1'b1;      // 先给 D 赋值
        #2;
        rst_n = 0;     // 在时钟中途突然复位
        #1;
        if (Q === 1'b0)
            $display("[%0tns] PASS: Asynchronous reset worked immediately!", $time);
        else
            $display("[%0tns] FAIL: Reset failed!", $time);

        #10;
        rst_n = 1;
        #20;

        $display("-----------------------------------------------------");
        $display("Simulation Finished!");
        $finish;
    end

    // 5. 波形导出
    initial begin
        $fsdbDumpfile("tb_D_Flip_Flop.fsdb");
        $fsdbDumpvars(0, tb_D_Flip_Flop);
    end

endmodule
