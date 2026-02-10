`include "uvm_macros.svh"
import uvm_pkg::*;

// 声明时指定 Item 类型
class axi_driver extends uvm_driver #(axi_transaction);

    // 1. 注册 Component
    `uvm_component_utils(axi_driver)

    // 2. 虚拟接口句柄
    virtual axi_interface vif;

    // 3. 构造函数
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // 4. Build Phase: 获取 Interface
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
        end
    endfunction

    // 5. Run Phase: 驱动逻辑主循环
    virtual task run_phase(uvm_phase phase);
        // 复位期间清理信号
        drive_reset();

        forever begin
            // 等待复位释放
            while(vif.rst_n == 0) @(posedge vif.clk);

            // 获取下一个 Transaction
            seq_item_port.get_next_item(req);

            // 打印调试信息 (Optional)
            `uvm_info("DRV", $sformatf("Driving Item: Addr=%0h, Write=%0b", req.addr, req.is_write), UVM_HIGH)

            // 执行驱动任务
            drive_transfer(req);

            // 握手完成，通知 Sequencer
            seq_item_port.item_done();
        end
    endtask

    // ----------------------------------------------------------------
    // task: reset
    // ----------------------------------------------------------------
    virtual task drive_reset();
        vif.user_req_we <= 0;
        vif.user_req_valid <= 0;
        vif.user_req_id <= 0;
        vif.user_req_addr <= 0;
        vif.user_req_len <= 0;
        vif.user_req_size <= 0;
        vif.user_req_burst <= 0;
        vif.user_req_wdata <= 0;
        vif.user_req_wstrb <= 0;

    endtask

    // ----------------------------------------------------------------
    // task: single transfer drive (User Interface Handshake)
    // ----------------------------------------------------------------
    virtual task drive_transfer(axi_transaction tr);
        // 1. 驱动控制信号
        vif.user_req_we    <= tr.is_write;
        vif.user_req_id    <= tr.id;
        vif.user_req_addr  <= tr.addr;
        vif.user_req_len   <= tr.len;
        vif.user_req_size  <= tr.size;
        vif.user_req_burst <= tr.burst;

        // 2. 如果是写操作，进行数据打包 (Packing)
        if (tr.is_write) begin
            // 临时变量，用于拼接宽总线
            logic [8*`AXI_DATA_WIDTH-1:0] packed_data;
            logic [8*(`AXI_DATA_WIDTH/8)-1:0] packed_strb;

            packed_data = 0;
            packed_strb = 0;

            // 遍历动态数组，填入宽总线对应的 Slot
            foreach(tr.data[i]) begin
                // 确保不超过最大 Burst 长度 (RTL限制)
                if(i < 8) begin
                    packed_data[i*`AXI_DATA_WIDTH +: `AXI_DATA_WIDTH] = tr.data[i];
                    packed_strb[i*(`AXI_DATA_WIDTH/8) +: (`AXI_DATA_WIDTH/8)] = tr.wstrb[i];
                end
            end

            vif.user_req_wdata <= packed_data;
            vif.user_req_wstrb <= packed_strb;
        end else begin
            vif.user_req_wdata <= 0;
            vif.user_req_wstrb <= 0;
        end

        // 3. 拉高 Valid，发起请求
        vif.user_req_valid <= 1'b1;

        // 4. 等待握手 (Ready = 1)
        // 注意：要在时钟上升沿采样 Ready
        @(posedge vif.clk);
        while(vif.user_req_ready !== 1'b1) begin
            @(posedge vif.clk);
        end

        // 5. 握手成功，拉低 Valid
        vif.user_req_valid <= 1'b0;

        // Insert random idle cycles (Idle cycles)
        repeat($urandom_range(0, 5)) @(posedge vif.clk);

    endtask

endclass
