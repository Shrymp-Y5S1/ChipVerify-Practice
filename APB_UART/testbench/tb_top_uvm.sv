// simulation top
`include "uvm_macros.svh"

import uvm_pkg::*;
import apb_pkg::*;

module tb_top_uvm();
    logic PCLK;
    logic PRESETn;

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
        fork
            mon.run();
        join_none

        // reset
        PRESETn = 0;
        #100 PRESETn = 1;

        // UART configuration
        tr.write = 1;
        tr.addr = 4'h4;
        tr.data = 8'h83;
        drv.drive(tr);
        `uvm_info("SETUP", "UART Enabled and Configured", UVM_LOW);

        repeat(10)begin // 生成并驱动 10 个随机事务
            if(!tr.randomize() with {write == 1; addr == 4'h0;})
                $fatal("Randomization failed!");
            scb.push_expect(tr.data); // 将预期数据推送到 scoreboard
            drv.drive(tr);

            @(posedge intf.rx_ready_out); // 等待接收完成信号

            tr.write = 0; tr.addr = 4'h0;
            drv.drive(tr);
        end
        #200000;
        scb.report();
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_top_uvm.fsdb");
        $fsdbDumpvars(0, tb_top_uvm);
    end

endmodule
