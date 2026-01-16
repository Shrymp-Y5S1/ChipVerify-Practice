`timescale 1ns/1ps

module tb_traffic_button_ctrl();
    reg clk = 0;
    reg rst_n = 0;
    reg ped_btn = 0;
    wire [1:0] main_light;
    wire ped_light;

    traffic_button_ctrl u_dut(
        .clk(clk),
        .rst_n(rst_n),
        .ped_btn(ped_btn),
        .main_light(main_light),
        .ped_light(ped_light)
    );

    // 时钟生成：10ns 周期
    always #5 clk = ~clk;

    initial begin
        $display("Time\t Main\t Ped\t Btn\t State");
        $monitor("%0tns\t %b\t %b\t %b\t %d",
                 $time, main_light, ped_light, ped_btn, u_dut.state);
    end

    // 激励逻辑
    initial begin
        rst_n = 0; #10 rst_n = 1;

        // 场景：在红灯期间按下（不应触发提前变灯，但会进入冷却）
        #340;
        ped_btn = 1;
        #10;
        ped_btn = 0;

        // 场景：在绿灯期间按下（应立即触发变黄灯）
        #270;
        ped_btn = 1;
        #10;
        ped_btn = 0;

        // 场景：再次按下
        #150;
        ped_btn = 1;
        #10;
        ped_btn = 0;

        // 场景：连续按下，测试冷却保护
        #150;
        ped_btn = 1;
        #10;
        ped_btn = 0;

        #50;
        $display("Simulation Task Completed.");
        $finish;
    end

    // 波形记录
    initial begin
        $fsdbDumpfile("tb_traffic_button_ctrl.fsdb");
        $fsdbDumpvars(0, tb_traffic_button_ctrl);
    end

endmodule
