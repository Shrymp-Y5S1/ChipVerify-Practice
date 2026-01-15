`timescale 1ns/1ps

module tb_full_adder;

    // 1. 声明信号：输入用 reg，输出用 wire
    reg  [3:0] a;
    reg  [3:0] b;
    reg        cin;
    wire [3:0] sum;
    wire       cout;

    // 定义一个变量用于存放预期的结果，用来做自动化比对
    reg  [4:0] expected_res;

    // 2. 实例化被测设计 (DUT)
    full_adder u_full_adder (
        .a    (a),
        .b    (b),
        .cin  (cin),
        .sum  (sum),
        .cout (cout)
    );

    // 3. 产生刺激激励 (Stimulus)
    initial begin
        // 初始化信号
        a = 0; b = 0; cin = 0;

        $display("-----------------------------------------------------");
        $display("Starting Full Adder Simulation...");
        $display("Time\t a \t b \t cin \t sum \t cout \t Status");
        $display("-----------------------------------------------------");

        // --- 测试用例 1: 简单加法 ---
        a = 4'd2; b = 4'd3; cin = 1'b0;
        #10; check_result();

        // --- 测试用例 2: 产生进位 ---
        a = 4'd8; b = 4'd8; cin = 1'b0;
        #10; check_result();

        // --- 测试用例 3: 边界值测试 (全 1 加进位) ---
        a = 4'hf; b = 4'hf; cin = 1'b1;
        #10; check_result();

        // --- 测试用例 4: 随机压力测试 ---
        repeat(20) begin
            a = $random;
            b = $random;
            cin = $random % 2; // 只取 0 或 1
            #10;
            check_result();
        end

        $display("-----------------------------------------------------");
        $display("Simulation Finished!");
        $finish;
    end

    // 4. 自动化检查任务 (Task)
    // 这个任务会计算“正确答案”并与模块输出进行比对
    task check_result;
        begin
            expected_res = a + b + cin;
            if ({cout, sum} === expected_res) begin
                $display("[%0tns]\t %h \t %h \t %b \t %h \t %b \t [PASS]",
                          $time, a, b, cin, sum, cout);
            end else begin
                $display("[%0tns]\t %h \t %h \t %b \t %h \t %b \t [FAIL! Expected: %h]",
                          $time, a, b, cin, sum, cout, expected_res);
            end
        end
    endtask

    // 5. 波形导出 (用于 Verdi 查看)
    initial begin
        $fsdbDumpfile("tb_full_adder.fsdb");
        $fsdbDumpvars(0, tb_full_adder);
    end

endmodule
