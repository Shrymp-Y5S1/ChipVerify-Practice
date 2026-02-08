`include "uvm_macros.svh"
`include "axi_define.v"

import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    parameter ID_WIDTH    = `AXI_ID_WIDTH;
    parameter ADDR_WIDTH  = `AXI_ADDR_WIDTH;
    parameter DATA_WIDTH  = `AXI_DATA_WIDTH;
    parameter LEN_WIDTH   = `AXI_LEN_WIDTH;
    parameter SIZE_WIDTH  = `AXI_SIZE_WIDTH;
    parameter BURST_WIDTH = `AXI_BURST_WIDTH;

    // ----------------------------------------------------------------
    // Request Fields (需要随机化)
    // ----------------------------------------------------------------
    rand bit [ID_WIDTH-1:0]    id;
    rand bit [ADDR_WIDTH-1:0]  addr;
    rand bit [LEN_WIDTH-1:0]   len;
    rand bit [SIZE_WIDTH-1:0]  size;   // 0=1Byte, 1=2Bytes, 2=4Bytes...
    rand bit [BURST_WIDTH-1:0] burst;  // 0=FIXED, 1=INCR, 2=WRAP

    // 读写类型控制 (用于 Driver 判断)
    rand bit                   is_write; // 1 = Write, 0 = Read

    // Data Payload (动态数组)
    rand bit [DATA_WIDTH-1:0]  data[];
    rand bit [(DATA_WIDTH/8)-1:0] wstrb[];

    // ----------------------------------------------------------------
    // Response Fields (由 Monitor/Driver 回填，不需要随机化)
    // ----------------------------------------------------------------
    bit [1:0]                  resp;   // RRESP or BRESP
    bit                        id_matched; // 用于 Scoreboard 标记

    // ----------------------------------------------------------------
    // UVM Macros (用于 Print, Copy, Compare 等自动化)
    // ----------------------------------------------------------------
    `uvm_object_utils_begin(axi_transaction)
        `uvm_field_int(id,       UVM_ALL_ON)
        `uvm_field_int(addr,     UVM_ALL_ON)
        `uvm_field_int(len,      UVM_ALL_ON)
        `uvm_field_int(size,     UVM_ALL_ON)
        `uvm_field_int(burst,    UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_array_int(data, UVM_ALL_ON)
        `uvm_field_array_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(resp,     UVM_ALL_ON)
    `uvm_object_utils_end

    // ----------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------
    function new(string name = "axi_transaction");
        super.new(name);
    endfunction

    // ----------------------------------------------------------------
    // Constraints (核心验证逻辑)
    // ----------------------------------------------------------------

    // 1. 基础一致性约束：数据数组大小必须等于 (len + 1)
    constraint c_data_size {
        data.size() == len + 1;
        wstrb.size() == len + 1;
    }

    // 2. 数据位宽约束：AxSIZE 不能超过总线的数据位宽
    // 例如：32位总线(4 Bytes)，size 最大只能是 2 (2^2=4)
    constraint c_size_limit {
        (1 << size) * 8 <= DATA_WIDTH;
    }

    // 3. 突发类型约束
    constraint c_burst_type {
        burst inside { `AXI_BURST_FIXED, `AXI_BURST_INCR, `AXI_BURST_WRAP };
    }

    // 4. WRAP 模式的特殊约束 (长度必须是 2, 4, 8, 16)
    constraint c_wrap_len {
        if (burst == `AXI_BURST_WRAP) {
            (len + 1) inside {2, 4, 8, 16};
            // WRAP 模式下必须地址对齐
            addr % (1 << size) == 0;
        }
    }

    // 5. 4K 边界约束 (4K Boundary Constraint)
    // AXI 协议规定：一个 Burst 不能跨越 4K 地址边界。
    // 原理：(起始地址 / 4096) 必须等于 (结束地址 / 4096)
    constraint c_4k_boundary {
        // 结束地址 = 起始地址 + (字节数 * 拍数) - 1
        (addr / 4096) == ((addr + ((len + 1) * (1 << size)) - 1) / 4096);
    }

    // 6. 地址对齐约束 (虽然 AXI 支持非对齐，但先简化约束为对齐)
    // 可以通过 `constraint_mode(0)` 在高级测试用例中关闭它
    constraint c_aligned_addr {
        solve size before addr; // 先随机 size，再随机 addr
        addr % (1 << size) == 0;
    }

    // ----------------------------------------------------------------
    // Post Randomize (自动填充 wstrb)
    // ----------------------------------------------------------------
    function void post_randomize();
        if (is_write) begin
            foreach(wstrb[i]) begin
                if (wstrb[i] == 0) wstrb[i] = '1; // 默认所有 Byte 有效
            end
        end
    endfunction

endclass
