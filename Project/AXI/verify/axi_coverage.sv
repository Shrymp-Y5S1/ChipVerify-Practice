`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_coverage extends uvm_subscriber #(axi_transaction);

    `uvm_component_utils(axi_coverage)

    // ----------------------------------------------------------------
    // 定义 Covergroup
    // ----------------------------------------------------------------
    covergroup axi_cg;
        option.per_instance = 1;
        option.comment = "AXI Protocol Coverage";

        // 1. 读写类型覆盖
        cp_rw: coverpoint tr.is_write {
            bins write = {1};
            bins read  = {0};
        }

        // 2. 突发长度覆盖 (RTL MAX=8)
        cp_len: coverpoint tr.len {
            bins min_len = {0};       // 1 beat
            bins mid_len = {[1:6]};   // 2-7 beats
            bins max_len = {7};       // 8 beats (RTL 极限)
        }

        // 3. 突发大小覆盖
        cp_size: coverpoint tr.size {
            bins size_1b = {`AXI_SIZE_1_BYTE};
            bins size_2b = {`AXI_SIZE_2_BYTE};
            bins size_4b = {`AXI_SIZE_4_BYTE};
        }

        // 4. 突发类型 (目前主要测 INCR)
        cp_burst: coverpoint tr.burst {
            bins fixed = {`AXI_BURST_FIXED};
            bins incr  = {`AXI_BURST_INCR};
            bins wrap  = {`AXI_BURST_WRAP}; // 如果不支持可注释掉
        }

        // 5. 交叉覆盖：写操作 x 最大长度 (压力点)
        cross_wr_max_len: cross cp_rw, cp_len {
            bins wr_max = binsof(cp_rw.write) && binsof(cp_len.max_len);
            bins rd_max = binsof(cp_rw.read)  && binsof(cp_len.max_len);
        }

    endgroup

    // ----------------------------------------------------------------
    // Transaction 句柄
    // ----------------------------------------------------------------
    axi_transaction tr;

    // ----------------------------------------------------------------
    // 构造函数
    // ----------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        axi_cg = new(); // 实例化 covergroup
    endfunction

    // ----------------------------------------------------------------
    // 采样函数 (来自 uvm_subscriber)
    // ----------------------------------------------------------------
    virtual function void write(axi_transaction t);
        this.tr = t;
        axi_cg.sample(); // 触发采样
    endfunction

endclass
