`timescale 1ns/1ps

module tb_fxo_Mux;
    // 1. 信号定义：输入用 reg，输出用 wire
    reg  [3:0] in;
    reg  [1:0] sel;
    wire       out;

    // 2. 实例化被测设计 (DUT)
    fxo_Mux u_mux (
        .in  (in),
        .sel (sel),
        .out (out)
    );

    // 3. 产生激励
    initial begin
        // 初始化
        in = 4'b0000;
        sel = 2'b00;

        // 打印表头，方便在终端查看
        $display("Time\t In \t Sel \t Out");
        $display("---------------------------------");

        // 使用循环遍历所有可能的 sel 和部分 in 的组合
        // 对于 4 选 1 Mux，我们可以进行“详尽测试”
        repeat(10) begin
            in = $random;      // 产生随机输入
            for (integer i=0; i<4; i=i+1) begin
                sel = i;
                #10; // 等待 10ns 观察结果

                // 自动化检查逻辑
                if (out !== in[sel]) begin
                    $display("[%0t] ERROR! in=%b, sel=%d, out=%b (Expected %b)",
                              $time, in, sel, out, in[sel]);
                end else begin
                    $display("[%0t] PASS   in=%b, sel=%d, out=%b",
                              $time, in, sel, out);
                end
            end
        end

        $display("---------------------------------");
        $display("Simulation Finished!");
        $finish; // 结束仿真
    end

    // 4. 波形导出 (配合你的 Makefile 参数)
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars(0, tb_fxo_Mux);
    end

endmodule
