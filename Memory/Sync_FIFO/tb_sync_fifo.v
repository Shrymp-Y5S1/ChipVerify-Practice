`timescale 1ns/1ps

module tb_sync_fifo();

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH = 1 << ADDR_WIDTH;

    reg clk;
    reg rst_n;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1 : 0] din;
    wire [DATA_WIDTH-1 : 0] dout;
    wire full;
    wire empty;

    // 实例化 DUT
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    // 时钟生成 (100MHz)
    always #5 clk = ~clk;

    initial begin
        // 初始化
        clk = 0; rst_n = 0; wr_en = 0; rd_en = 0; din = 0;
        #20 rst_n = 1;

        $display("--- Starting FIFO Test ---");

        // 1. 写满测试
        repeat (DEPTH) begin
            @(negedge clk);
            if (!full) begin
                wr_en = 1;
                din = $random;
            end
        end
        @(negedge clk) wr_en = 0;
        if (full) $display("[Time %0t] PASS: FIFO is FULL", $time);

        // 2. 满后再写测试 (数据不应改变)
        @(negedge clk) begin
            wr_en = 1; din = 8'hFF;
        end
        @(negedge clk) wr_en = 0;

        // 3. 读空测试
        repeat (DEPTH) begin
            @(negedge clk);
            if (!empty) rd_en = 1;
        end
        @(negedge clk) rd_en = 0;
        if (empty) $display("[Time %0t] PASS: FIFO is EMPTY", $time);

        // 4. 同时读写测试 (保持平衡)
        #20;
        @(negedge clk) begin
            wr_en = 1; rd_en = 1; din = 8'h55;
        end
        repeat (5) @(negedge clk) din = din + 1;
        @(negedge clk) begin
            wr_en = 0; rd_en = 0;
        end

        #100;
        $display("--- Simulation Finished ---");
        $finish;
    end

    // 波形导出
    initial begin
        $fsdbDumpfile("tb_sync_fifo.fsdb");
        $fsdbDumpvars(0, tb_sync_fifo);
        // 关键：在 Verdi 中查看存储器内容
        $fsdbDumpMDA();
    end

endmodule
