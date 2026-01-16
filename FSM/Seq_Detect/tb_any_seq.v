`timescale 1ns/1ps

module tb_any_seq;
    parameter W = 5;
    parameter S = 5'b10010;

    reg clk, rst_n, in;
    wire out;

    any_seq #(.WIDTH(W), .SEQ(S)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .in(in),
        .out(out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; in = 0;
        #15 rst_n = 1;

        // 发送序列：1 -> 0 -> 0 -> 1 -> 0 (成功)
        send_bit(1); send_bit(0); send_bit(0); send_bit(1); send_bit(0);

        // 干扰
        send_bit(1); send_bit(1);

        // 测试重叠/连续序列：10010010 (应该触发两次 out)
        send_bit(1); send_bit(0); send_bit(0); send_bit(1); send_bit(0);
        send_bit(0); send_bit(1); send_bit(0);

        #50;
        $finish;
    end

    task send_bit(input b);
        begin
            @(negedge clk);
            in = b;
        end
    endtask

    initial begin
        $fsdbDumpfile("tb_any_seq.fsdb");
        $fsdbDumpvars(0, tb_any_seq);
    end
endmodule
