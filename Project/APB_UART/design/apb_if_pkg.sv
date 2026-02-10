// hardware interface
// 定义 APB 接口信号和时序

interface apb_inter(input logic PCLK, input logic PRESETn);
    // APB signals
    logic [3:0] PADDR;
    logic PSELx;
    logic PENABLE;
    logic PWRITE;
    logic [7:0] PWDATA;
    logic [7:0] PRDATA;
    logic PREADY;
    logic PSLVERR;

    // uart and dma signals
    logic rx;
    logic tx;
    logic rx_ready_out;
    logic dma_tx_req;
    logic dma_rx_req;

    // Clocking block for APB signals
    // clocking block: SV 的一种机制，用来在testbench中定义信号的采样和驱动时序
    clocking cb @(posedge PCLK);
        // 设置时序延迟，表示在时钟上升沿后1ns采样输入信号，1ns后驱动输出信号
        default input #1ns output #1ns;
        // master driven signals
        output rx;
        // master sampled signals
        input PRDATA, PREADY, PSLVERR, tx, rx_ready_out, dma_tx_req, dma_rx_req;
        inout PADDR, PSELx, PENABLE, PWRITE, PWDATA;
    endclocking

    // master modport
    // 定义接口的角色。这里定义 master 角色，说明它使用 clocking cb，并且需要 PCLK 和 PRESETn
    // 注意：确保类成员与实例化的modport类型统一，使接口间权限保持一致性
    modport master (clocking cb, input PCLK, PRESETn);

endinterface
