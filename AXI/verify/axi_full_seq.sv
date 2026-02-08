`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_full_seq extends uvm_sequence #(axi_transaction);
    `uvm_object_utils(axi_full_seq)

    function new(string name = "axi_full_seq");
        super.new(name);
    endfunction

    virtual task body();
        axi_transaction tr;

        `uvm_info("SEQ", "Starting AXI Full Coverage Sequence...", UVM_NONE)

        // 发送 2000 笔交易，确保覆盖各种组合
        repeat(2000) begin
            `uvm_do_with(tr, {
                // ------------------------------------------------
                // 1. 基础限制 (RTL Constraint)
                // ------------------------------------------------
                len <= 7; // RTL MAX_BURST_LEN = 8

                // ------------------------------------------------
                // 2. 覆盖率目标分布 (Target Distribution)
                // ------------------------------------------------
                // 填补 burst 类型缺口
                burst dist {
                    `AXI_BURST_INCR  := 60, // 60% 概率
                    `AXI_BURST_WRAP  := 30, // 30% 概率
                    `AXI_BURST_FIXED := 10  // 10% 概率
                };

                // 填补 size 大小缺口 (窄传输)
                size dist {
                    `AXI_SIZE_4_BYTE := 60,
                    `AXI_SIZE_2_BYTE := 20,
                    `AXI_SIZE_1_BYTE := 20
                };

                // ------------------------------------------------
                // 3. 协议严格约束 (Protocol Rules)
                // ------------------------------------------------
                // AXI 规定：传输地址必须对齐到 size
                // (例如 size=4字节时，addr 低2位必须为0)
                // 尤其是 WRAP 模式，必须对齐，否则回环边界计算会错
                solve size before addr;
                (addr % (1 << size)) == 0;

                // WRAP 模式的特殊约束
                if (burst == `AXI_BURST_WRAP) {
                    // WRAP 长度只能是 2, 4, 8, 16 beats
                    // 对应 len = 1, 3, 7, 15
                    // 但 RTL 限制最大 8 beats，所以只能取 1, 3, 7
                    len inside {1, 3, 7};
                }

                // ------------------------------------------------
                // 4. 数据完整性约束
                // ------------------------------------------------
                // 尽量保证 strobe 有效，防止稀疏写干扰验证
                // 注意：对于窄传输，我们不强制 wstrb 全 F，而是让它自然随机
                // 只要地址对齐，通常 valid strobe 是连续的
            })
        end

        `uvm_info("SEQ", "AXI Full Coverage Sequence Finished!", UVM_NONE)
    endtask
endclass
