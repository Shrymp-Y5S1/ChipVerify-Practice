`timescale 1ns/1ps

module tb_async_fifo();
    parameter DW = 8;
    parameter AW = 4;

    reg wr_clk, rd_clk, rst_n;
    reg wr_en, rd_en;
    reg [DW-1:0] wr_data;
    wire [DW-1:0] rd_data;
    wire full, empty;

    async_fifo #(.DATA_WIDTH(DW), .ADDR_WIDTH(AW)) uut (.*);

    // 产生异步时钟：写快读慢
    initial begin wr_clk = 0; forever #3 wr_clk = ~wr_clk; end // ~166MHz
    initial begin rd_clk = 0; forever #13 rd_clk = ~rd_clk; end // ~38MHz

    initial begin
        rst_n = 0; wr_en = 0; rd_en = 0; wr_data = 0;
        #50 rst_n = 1;

        // 1. 写满
        @(posedge wr_clk);
        while (!full) begin
            wr_en = 1;
            wr_data = wr_data + 1;
            @(posedge wr_clk);
        end
        wr_en = 0;
        $display("[%0t] FIFO FULL!", $time);

        // 2. 读空
        @(posedge rd_clk);
        while (!empty) begin
            rd_en = 1;
            @(posedge rd_clk);
        end
        rd_en = 0;
        $display("[%0t] FIFO EMPTY!", $time);

        #100 $finish;
    end

    initial begin
        $fsdbDumpfile("tb_async_fifo.fsdb");
        $fsdbDumpvars(0, tb_async_fifo);
    end
endmodule
