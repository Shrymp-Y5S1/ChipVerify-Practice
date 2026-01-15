`timescale 1ns/1ps

module tb_pre_encode;

    // 1. 信号定义
    reg  [3:0] a, b, c, d;
    reg  [3:0] sel;
    wire [3:0] out;

    // 用于自动化检查的预期值
    reg  [3:0] expected_out;

    // 2. 实例化被测设计 (DUT)
    pre_encode u_pre_encode (
        .a   (a),
        .b   (b),
        .c   (c),
        .d   (d),
        .sel (sel),
        .out (out)
    );

    // 3. 产生激励
    initial begin
        // 初始化数据源，赋予一些容易分辨的值
        a = 4'hA; b = 4'hB; c = 4'hC; d = 4'hD;
        sel = 4'd0;

        $display("-----------------------------------------------------");
        $display("Starting Priority Mux Simulation...");
        $display("Time\t Sel \t Out \t Expected \t Status");
        $display("-----------------------------------------------------");

        // --- 测试用例 1: 遍历定义的有效选择端 ---
        for (integer i = 0; i <= 3; i = i + 1) begin
            sel = i;
            #10;
            check_result();
        end

        // --- 测试用例 2: 边界值测试 (sel 超过范围) ---
        sel = 4'hF; // 15
        #10;
        check_result();

        // --- 测试用例 3: 随机压力测试 ---
        repeat(10) begin
            a = $random; b = $random; c = $random; d = $random;
            sel = $random % 16;
            #10;
            check_result();
        end

        $display("-----------------------------------------------------");
        $display("Simulation Finished!");
        $finish;
    end

    // 4. 自动化检查逻辑
    task check_result;
        begin
            // 模拟 RTL 逻辑计算预期值
            case (sel)
                4'd0:    expected_out = a;
                4'd1:    expected_out = b;
                4'd2:    expected_out = c;
                default: expected_out = d;
            endcase

            if (out === expected_out) begin
                $display("[%0tns]\t %d \t %h \t %h \t\t [PASS]", $time, sel, out, expected_out);
            end else begin
                $display("[%0tns]\t %d \t %h \t %h \t\t [FAIL!]", $time, sel, out, expected_out);
            end
        end
    endtask

    // 5. 波形导出
    initial begin
        $fsdbDumpfile("tb_pre_encode.fsdb");
        $fsdbDumpvars(0, tb_pre_encode);
    end

endmodule
