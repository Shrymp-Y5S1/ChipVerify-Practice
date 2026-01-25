// verification logic
// 定义 APB 事务类（数据抽象）和驱动类（行为抽象）。
// 依赖于接口（apb_if_pkg.sv），因为 Driver 内部需要操作接口句柄。
// 被顶层（tb_top_uvm.sv）调用。

// 将 Transaction、Driver 和 Monitor 封装在一个 Package 里。
// 通过 import apb_pkg::*; 使用这些类，避免重复定义。
package apb_pkg;

    // 1. 必须在 package 内部包含 UVM 宏
    `include "uvm_macros.svh"

    // 2. 必须在 package 内部导入 UVM 包
    import uvm_pkg::*;

    //transaction class: data abstraction
    class apb_trans;
        // rand 表示可以随机生成，用于覆盖率驱动的验证。
        rand logic [3:0] addr;
        rand logic [7:0] data;
        rand logic write; // 1: write, 0: read

        // random constraint
        // addr 只能是 0x0, 0x4, 0x8, 0xc 中的一个
        constraint c_addr {addr inside {4'h0, 4'h4, 4'h8, 4'hc};}
    endclass

    // driver class: behavior abstraction
    // apb_trans 的抽象数据通过 virtual interface 连接到 DUT 的接口
    class apb_driver;
        virtual apb_inter.master vif;  // 绑定到接口的 master modport

        function new(virtual apb_inter.master v);
            this.vif = v;
        endfunction

        task drive(apb_trans tr);   // 按照 APB 协议时序驱动信号
            @(vif.cb);  // 等待（clocking block 的下一个时钟）事件发生
            vif.cb.PSELx <= 1;
            vif.cb.PWRITE <= tr.write;
            vif.cb.PADDR <= tr.addr;
            vif.cb.PWDATA <= tr.data;
            vif.cb.PENABLE <= 0;

            @(vif.cb);
            vif.cb.PENABLE <= 1;

            wait(vif.cb.PREADY == 1);
            @(vif.cb);
            vif.cb.PSELx <= 0;
            vif.cb.PENABLE <= 0;
        endtask
    endclass

    // scoreboard class: behavior abstraction
    class apb_scoreboard;
        logic [7:0] expected_queue[$]; // 使用SV队列存储预期数据
        int match_cnt = 0;
        int error_cnt = 0;

        // 添加预期数据到队列
        function void push_expect(logic [7:0] data);
            expected_queue.push_back(data);
        endfunction

        // 比对实际数据与预期数据
        function void check_data(logic [7:0] actual_data);
            logic [7:0] expected;
            if(expected_queue.size() > 0)begin
                expected = expected_queue.pop_front();
                if(actual_data == expected)begin
                    match_cnt++;
                    `uvm_info("SCB",$sformatf("Match: expected=%0h, actual=%0h", expected, actual_data), UVM_LOW);
                end else begin
                    error_cnt++;
                    `uvm_error("SCB",$sformatf("Mismatch: expected=%0h, actual=%0h", expected, actual_data));
                end
            end else begin
                    `uvm_error("SCB","No expected data available (Queue is empty)");
            end
        endfunction

        function void report();
            $display("\n--- SCOREBOARD REPORT ---");
            $display("  MATCHES: %0d", match_cnt);
            $display("  ERRORS : %0d", error_cnt);
            $display("--------------------------\n");
        endfunction
    endclass

    // monitor class: behavior abstraction
    class apb_monitor;
        virtual apb_inter.master vif;
        apb_scoreboard scb; // 关联到 scoreboard

        function new(virtual apb_inter.master v, apb_scoreboard s);
            this.vif = v;
            this.scb = s;
        endfunction

        task run();
            forever begin
                @(vif.cb); // 每个时钟沿巡视
                // 如果 PSEL, PENABLE 为高，且是读操作 (PWRITE=0)，且地址是 DATA 寄存器 (0x0)
                if (vif.cb.PSELx && vif.cb.PENABLE && !vif.cb.PWRITE && (vif.cb.PADDR == 4'h0)) begin
                wait(vif.cb.PREADY == 1); // 等待从机数据准备好
                #1ns; // 稍微偏移避开沿
                scb.check_data(vif.cb.PRDATA); // 此时 PRDATA 上的才是读出的数据
            end
            end
        endtask
    endclass
endpackage
