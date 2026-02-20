> [!note]
>
> `cm.hier`： **指定层次化路径**，告诉工具在哪些模块下采集覆盖率。

#### 工业界标准 `cm.hier` 模板

代码覆盖率必须且只能关注 **DUT**。假设你的 Testbench 结构如下：

```systemverilog
module tb_top_uvm;
    // ... 时钟复位 ...
    apb_if      u_apb_if(clk, rst_n); // 接口
    apb_uart_sv u_dut (               // 你的 RTL 实例名，通常叫 u_dut 或 u_rtl
        .pclk(u_apb_if.pclk),
        .psel(u_apb_if.psel),
        ...
    );
endmodule
```

**正确的 `cm.hier` 应该这样写：**

```Plaintext
// 1. 全局排除：先把 Testbench、Interface、VIP 全部排除
-tree tb_top_uvm 0

// 2. 精准包含：只把 DUT 加回来
// 格式：+tree {TB顶层名}.{RTL实例名} {层级深度}
// "0" 表示包含该层级及其下属所有子模块（递归）
+tree tb_top_uvm.u_dut 0
```

#### 3. 进阶技巧：黑盒 IP 处理

如果你的设计里调用了一个第三方的 IP（比如你是做 SoC 的，调用了别人做好的 SRAM 或 PLL），你不需要看它的内部代码覆盖率，否则会拉低你的总分。

```Plaintext
// 3. 排除特定子模块（黑盒处理）
-tree tb_top_uvm.u_dut.u_ram_4k 0
```

> [!tip]
>
> - 打开你的 `tb_top.sv` 或 `tb_uart_core.sv`。
>
> - 找到你的 RTL 模块实例化时的名字（是 `u_dut`？`u_top`？还是 `uart_inst`？）。
> - 假设是 `u_top`，则将 `cm.hier` 中的 `+tree tb_top_uvm.u_dut 0`，改写为 `+tree tb_top_uvm.u_top 0`

