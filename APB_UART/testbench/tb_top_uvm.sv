// simulation top
`include "uvm_macros.svh"

import uvm_pkg::*;
import apb_pkg::*;

module tb_top_uvm();
    logic PCLK;
    logic PRESETn;
    logic [7:0] test_configs[] = '{8'h83, 8'h87, 8'h93, 8'ha3}; // 不同的 UART 配置
    // Control register, en_sys:[0], IE:[1], clk_freq_index:[3:2], baud_rate_index:[6:4], tx_en:[7]
    // 0:50MHz, 1:25MHz, 2:12.5MHz
    // 0:115200, 1:57600, 2:38400, 3:19200, 4:9600



    // instantiate interface
    // 实例化一个 APB 接口对象 intf，绑定时钟和复位。
    apb_inter intf(PCLK, PRESETn);

    // instantiate DUT
    // 实例化 DUT，并连接接口信号
    apb_if #(
        .ADDR_WIDTH  	(4      ),
        .DATA_WIDTH  	(8      ),
        .WAIT_STATES 	(1  ))
    u_apb_if(
        .PCLK       	(intf.PCLK        ),
        .PRESETn    	(intf.PRESETn     ),
        .PADDR      	(intf.PADDR       ),
        .PSELx      	(intf.PSELx       ),
        .PENABLE    	(intf.PENABLE     ),
        .PWRITE     	(intf.PWRITE      ),
        .PWDATA     	(intf.PWDATA      ),
        .rx         	(intf.rx          ),
        .PREADY     	(intf.PREADY      ),
        .PRDATA     	(intf.PRDATA      ),
        .PSLVERR    	(intf.PSLVERR     ),
        .tx         	(intf.tx          ),
        .rx_ready_out	(intf.rx_ready_out),
        .dma_tx_req 	(intf.dma_tx_req  ),
        .dma_rx_req 	(intf.dma_rx_req  )
    );

    // clock generation
    initial begin
        PCLK = 0;
        forever #10 PCLK = ~PCLK;
    end

    apb_driver drv;
    apb_trans tr;
    apb_scoreboard scb;
    apb_monitor mon;

    initial begin
        drv = new(intf.master); // 将物理接口传递给了 Driver 类，打通了软件控制硬件的通道。
        tr = new();
        scb = new();
        mon = new(intf.master, scb);

        // start monitor
        fork    // 并行启动 monitor
            mon.run();
        join_none

        // reset
        PRESETn = 0;
        #100 PRESETn = 1;

        // // UART configuration
        // tr.write = 1;
        // tr.addr = 4'h4;
        // tr.data = 8'h83;
        // drv.drive(tr);
        // `uvm_info("SETUP", "UART Enabled and Configured", UVM_LOW);

        // repeat(10)begin // 生成并驱动 10 个随机事务
        //     if(!tr.randomize() with {write == 1; addr == 4'h0;})
        //         $fatal("Randomization failed!");
        //     scb.push_expect(tr.data); // 将预期数据推送到 scoreboard
        //     drv.drive(tr);

        //     @(posedge intf.rx_ready_out); // 等待接收完成信号

        //     tr.write = 0; tr.addr = 4'h0;
        //     drv.drive(tr);
        // end

        foreach (test_configs[i])begin  // 遍历每个配置
            // 配置 UART
            tr.write = 1;
            tr.addr = 4'h4;
            tr.data = test_configs[i];
            drv.drive(tr);
            `uvm_info("SETUP", $sformatf("UART Configured with 0x%0h", test_configs[i]), UVM_LOW)

            repeat(5) begin
                // 发送数据
                if(!tr.randomize() with {write == 1; addr == 4'h0;})
                    $fatal("Randomization failed!");
                scb.push_expect(tr.data); // 将预期数据推送到 scoreboard
                drv.drive(tr);

                // 检查状态
                do begin
                    tr.write = 0;
                    tr.addr = 4'hc;
                    drv.drive(tr);
                end while (tr.data[1] == 0);
                // 读中断状态寄存器，等待 tx_done 标志置位
                `uvm_info("STATUS_CHECK", $sformatf("Status Register: 0x%0h", tr.data[1:0]), UVM_LOW)

                @(posedge intf.rx_ready_out); // 等待接收完成信号

                // 读取数据
                tr.write = 0; tr.addr = 4'h0;
                drv.drive(tr);

                // 检查状态
                tr.write = 0;
                tr.addr = 4'hc;
                drv.drive(tr);
                // 读中断状态寄存器，等待 rx_done 标志置位
                `uvm_info("STATUS_CHECK", $sformatf("Status Register: 0x%0h", tr.data[1:0]), UVM_LOW)

                // 清除中断
                tr.write = 1;
                tr.addr = 4'hc;
                tr.data = 8'h3;
                // tr.data = 8'h3; // 写 1 清除rx_done 和 tx_done 标志
                drv.drive(tr);
            end
        end

        // full FIFO test
        // 配置 UART 使能但不启动传输
        tr.write = 1;
        tr.addr = 4'h4;
        tr.data = 8'h01; // en_sys=1, tx_en=0
        drv.drive(tr);

        `uvm_info("FIFO_FULL_TEST", "Start FIFO Test: Filling...", UVM_LOW)
        repeat(16) begin
            tr.write = 1;
            tr.addr = 4'h0;
            tr. data = $urandom;
            drv.drive(tr);  // 连续写入
        end

        // 读取状态寄存器，检查 FIFO full 标志
        #100;
        tr.write = 0;
        tr.addr = 4'h8;
        drv.drive(tr);
        `uvm_info("FIFO_FULL_TEST", $sformatf("Status Register: 0x%0h", tr.data), UVM_LOW)
        if(tr.data[4]) `uvm_info("FIFO_FULL_TEST", "FIFO Full Flag Set as Expected", UVM_LOW)
        else          `uvm_error("FIFO_FULL_TEST", "FIFO Full Flag NOT Set!")
        // 启动传输
        tr.write = 1;
        tr.addr = 4'h4;
        tr.data = 8'h83; // en_sys=1, tx_en=1
        drv.drive(tr);

        #200000;
        scb.report();
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_top_uvm.fsdb");
        $fsdbDumpvars(0, tb_top_uvm);
    end

endmodule
