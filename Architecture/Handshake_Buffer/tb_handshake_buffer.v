`timescale 1ns/1ps

module tb_handshake_buffer();
    parameter W = 8;
    reg clk, rst_n;
    reg s_valid;
    reg [W-1:0] s_data;
    wire s_ready;
    wire m_valid;
    reg m_ready;
    wire [W-1:0] m_data;

    handshake_buffer #(.WIDTH(W)) uut (.*);

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        // 初始化
        rst_n = 0; s_valid = 0; s_data = 0; m_ready = 1;
        #25 rst_n = 1;

        // --- 场景 1: 全速传输 ---
        repeat(3) begin
            @(posedge clk); #1;
            s_valid = 1; s_data = s_data + 1;
        end

        // --- 场景 2: 下游变忙 (Back-pressure) ---
        @(posedge clk); #1;
        m_ready = 0; // 下游关闸
        s_data = 8'hFF; // 上游想发一个新数据 FF
        s_valid = 1;
        $display("[%0t] Consumer is BUSY, m_ready=0", $time);

        // 观察：此时 s_ready 应该变低，FF 这个数据不应该进入 buffer
        // 而之前存的最后一个数据应该一直保持在 m_data 上
        #30;

        // --- 场景 3: 下游恢复 ---
        @(posedge clk); #1;
        m_ready = 1;
        $display("[%0t] Consumer is READY, m_ready=1", $time);

        #100;
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_handshake_buffer.fsdb");
        $fsdbDumpvars(0, tb_handshake_buffer);
    end
endmodule
