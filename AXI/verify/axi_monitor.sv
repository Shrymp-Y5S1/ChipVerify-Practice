`include "uvm_macros.svh"
`include "axi_define.v"

import uvm_pkg::*;

class axi_monitor extends uvm_monitor;

    // 1. 注册 Component
    `uvm_component_utils(axi_monitor)

    // 2. 虚拟接口句柄
    virtual axi_interface vif;

    // 3. Analysis Port (广播监测到的数据给 Scoreboard/Coverage)
    uvm_analysis_port #(axi_transaction) item_collected_port;

    // 4. 构造函数
    function new(string name, uvm_component parent);
        super.new(name, parent);
        // 实例化 Port
        item_collected_port = new("item_collected_port", this);
    endfunction

    // 5. Build Phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface must be set for: ", get_full_name(), ".vif");
        end
    endfunction

    // 6. Run Phase: 多线程并发监测
    virtual task run_phase(uvm_phase phase);
        // AXI 的通道是独立的，所以必须并行监测
        fork
            monitor_aw_channel(); // 监测写地址
            monitor_w_channel();  // 监测写数据 (核心难点)
            monitor_b_channel();  // 监测写响应
            monitor_ar_channel(); // 监测读地址
            monitor_r_channel();  // 监测读数据
        join
    endtask

    // ----------------------------------------------------------------
    // 任务 1: 监测 Write Address (AW) 通道
    // ----------------------------------------------------------------
    task monitor_aw_channel();
        axi_transaction tr;
        forever begin
            // 1. 等待时钟上升沿
            @(posedge vif.clk);

            // 2. 检查握手成功 (Valid & Ready 同时为高)
            if(vif.awvalid && vif.awready) begin
                tr = axi_transaction::type_id::create("tr");

                // 3. 采样信号
                tr.is_write = 1;
                tr.id    = vif.awid;
                tr.addr  = vif.awaddr;
                tr.len   = vif.awlen;
                tr.size  = vif.awsize;
                tr.burst = vif.awburst;

                // 标记这是一个“地址包”，数据为空
                tr.data = new[0];

                `uvm_info("MON_AW", $sformatf("Captured AW: ID=%0h Addr=%0h Len=%0d", tr.id, tr.addr, tr.len), UVM_HIGH)

                // 4. 广播出去
                item_collected_port.write(tr);
            end
        end
    endtask

    // ----------------------------------------------------------------
    // 任务 2: 监测 Write Data (W) 通道 (支持 Burst 重组)
    // ----------------------------------------------------------------
    task monitor_w_channel();
        axi_transaction tr;

        // 临时队列：用于缓存一个 Burst 的数据和 Strobe
        // 注意：这里简化处理，假设数据不交织 (No Interleaving)，或者我们只按顺序收集
        logic [`AXI_DATA_WIDTH-1:0]      data_q[$];
        logic [(`AXI_DATA_WIDTH/8)-1:0]  strb_q[$];

        forever begin
            @(posedge vif.clk);

            if(vif.wvalid && vif.wready) begin
                // 收集当前拍的数据
                data_q.push_back(vif.wdata);
                strb_q.push_back(vif.wstrb);

                // 如果是最后一拍 (WLAST)，说明一个 Burst 结束了
                if(vif.wlast) begin
                    tr = axi_transaction::type_id::create("tr");
                    tr.is_write = 1;

                    // W 通道没有 Address 信息，置 0
                    tr.addr = 0;
                    // W 通道没有 ID
                    // 为了简化，我们这里暂时留空，Scoreboard 可以靠顺序匹配

                    // 将队列里的数据搬运到 Transaction 的动态数组中
                    tr.data  = new[data_q.size()];
                    tr.wstrb = new[strb_q.size()];
                    tr.len   = data_q.size() - 1; // 恢复 len 定义

                    foreach(data_q[i]) begin
                        tr.data[i]  = data_q[i];
                        tr.wstrb[i] = strb_q[i];
                    end

                    `uvm_info("MON_W", $sformatf("Captured W Burst: Size=%0d Data[0]=%0h", tr.data.size(), tr.data[0]), UVM_HIGH)

                    // 广播数据包
                    item_collected_port.write(tr);

                    // 清空队列，准备下一次 Burst
                    data_q.delete();
                    strb_q.delete();
                end
            end
        end
    endtask

    // ----------------------------------------------------------------
    // 任务 3: 监测 Read Address (AR) 通道
    // ----------------------------------------------------------------
    task monitor_ar_channel();
        axi_transaction tr;
        forever begin
            @(posedge vif.clk);
            if(vif.arvalid && vif.arready) begin
                tr = axi_transaction::type_id::create("tr");
                tr.is_write = 0;
                tr.id    = vif.arid;
                tr.addr  = vif.araddr;
                tr.len   = vif.arlen;
                tr.size  = vif.arsize;
                tr.burst = vif.arburst;
                tr.data = new[0];

                `uvm_info("MON_AR", $sformatf("Captured AR: ID=%0h Addr=%0h", tr.id, tr.addr), UVM_HIGH)

                item_collected_port.write(tr);
            end
        end
    endtask

    // ----------------------------------------------------------------
    // 任务 4: 监测 Read Data (R) 通道
    // ----------------------------------------------------------------
    task monitor_r_channel();
        axi_transaction tr;
        // 使用关联数组支持读数据交织 (Interleaving)
        // key=RID, value=Queue of Data
        logic [`AXI_DATA_WIDTH-1:0] rdata_buffer[int][$];

        forever begin
            @(posedge vif.clk);
            if(vif.rvalid && vif.rready) begin
                int rid = vif.rid;

                // 存入对应 RID 的缓存
                rdata_buffer[rid].push_back(vif.rdata);

                // 如果是最后一拍
                if(vif.rlast) begin
                    tr = axi_transaction::type_id::create("tr");
                    tr.is_write = 0;
                    tr.id = rid;
                    tr.resp = vif.rresp; // 采样最后一拍的 Resp

                    // 搬运数据
                    tr.data = new[rdata_buffer[rid].size()];
                    foreach(rdata_buffer[rid][i]) begin
                        tr.data[i] = rdata_buffer[rid][i];
                    end

                    `uvm_info("MON_R", $sformatf("Captured R Burst: ID=%0h Size=%0d", tr.id, tr.data.size()), UVM_HIGH)

                    item_collected_port.write(tr);

                    // 清除该 ID 的缓存
                    rdata_buffer.delete(rid);
                end
            end
        end
    endtask

    // ----------------------------------------------------------------
    // 任务 5: 监测 Write Response (B) 通道
    // ----------------------------------------------------------------
    task monitor_b_channel();
        axi_transaction tr;
        forever begin
            // 等待时钟上升沿
            @(posedge vif.clk);

            // 检查握手 (BVALID & BREADY)
            if(vif.bvalid && vif.bready) begin
                tr = axi_transaction::type_id::create("tr");

                // 采样关键信息
                tr.is_write = 1;        // 标记为写相关
                tr.id       = vif.bid;  // 关键：用于匹配之前的 AW 请求
                tr.resp     = vif.bresp;// 关键：检查是否由 SLVERR/DECERR

                // B 通道不携带地址和数据，留空即可
                tr.addr = 0;
                tr.data = new[0];

                `uvm_info("MON_B", $sformatf("Captured B Resp: ID=%0h Resp=%0b", tr.id, tr.resp), UVM_HIGH)

                item_collected_port.write(tr);
            end
        end
    endtask

endclass
