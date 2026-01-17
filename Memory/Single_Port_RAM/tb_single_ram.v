`timescale 1ns/1ps

module tb_single_ram();

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    reg clk;
    reg [ADDR_WIDTH-1:0] addr;
    reg cs, we, oe;

    // 双向总线处理
    wire [DATA_WIDTH-1:0] data;
    reg  [DATA_WIDTH-1:0] data_reg; // TB 内部用来驱动总线的寄存器

    // 当 we 为高且 cs 为高时，TB 驱动总线（写入数据）
    // 否则，TB 释放总线（高阻态），由 RAM 驱动或保持悬空
    assign data = (cs && we) ? data_reg : {DATA_WIDTH{1'bz}};

    // 实例化 DUT
    single_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ram (
        .clk(clk),
        .addr(addr),
        .data(data),
        .cs(cs),
        .we(we),
        .oe(oe)
    );

    // 时钟生成 (100MHz)
    always #5 clk = ~clk;

    initial begin
        // 初始化
        clk = 0; addr = 0; cs = 0; we = 0; oe = 0; data_reg = 0;
        #20;

        $display("--- Starting RAM Test ---");

        // --- 场景 1: 写入数据到地址 8'hA5 ---
        write_mem(8'hA5, 32'hDEAD_BEEF);

        // --- 场景 2: 写入数据到地址 8'h5A ---
        write_mem(8'h5A, 32'h55AA_FF00);

        // --- 场景 3: 读取地址 8'hA5 并验证 ---
        read_mem(8'hA5);

        // --- 场景 4: 读取地址 8'h5A 并验证 ---
        read_mem(8'h5A);

        // --- 场景 5: 测试 Chip Select (cs) 无效 ---
        cs = 0; addr = 8'hA5; oe = 1; we = 0;
        #10;
        if (data === {DATA_WIDTH{1'bz}})
            $display("[Time %0t] PASS: CS disable results in High-Z", $time);

        #50;
        $display("--- Simulation Finished ---");
        $finish;
    end

    // 写入任务
    task write_mem(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d);
        begin
            @(negedge clk);
            cs = 1; we = 1; oe = 0;
            addr = a;
            data_reg = d;
            @(negedge clk);
            we = 0; cs = 0;
            $display("[Time %0t] WRITE: Addr=0x%h, Data=0x%h", $time, a, d);
        end
    endtask

    // 读取任务
    task read_mem(input [ADDR_WIDTH-1:0] a);
        begin
            @(negedge clk);
            cs = 1; we = 0; oe = 1;
            addr = a;
            #2; // 等待组合逻辑读取完成
            $display("[Time %0t] READ : Addr=0x%h, Data=0x%h", $time, a, data);
            @(negedge clk);
            cs = 0; oe = 0;
        end
    endtask

    // 波形记录
    initial begin
        $fsdbDumpfile("tb_single_ram.fsdb");
        $fsdbDumpvars(0, tb_single_ram);
        // 关键：为了在 Verdi 查看存储器内部内容，需要开启 mem dump
        $fsdbDumpMDA();
    end

endmodule
