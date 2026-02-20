## `axi_define.v` 的写法（Verilog 宏定义）

```verilog
`define ADDR_WIDTH 32
`define DATA_WIDTH 64
`define ID_WIDTH   4

`define BURST_FIXED 2'b00
`define BURST_INCR  2'b01
`define BURST_WRAP  2'b10
```

- 使用 **宏定义 (**`define`**)**。
- 在编译预处理阶段替换文本，相当于 C 语言里的 `#define`。
- 没有类型检查，容易出现拼写错误或宏污染。
- 作用域是全局的，所有文件只要 `include` 了这个头文件，就能用这些宏。

## `axi_pkg.sv` 的写法（SystemVerilog Package）


```systemverilog
package axi_pkg;

  parameter int ADDR_WIDTH = 32;
  parameter int DATA_WIDTH = 64;
  parameter int ID_WIDTH   = 4;

  typedef enum logic [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10
  } burst_t;

endpackage
```

- 使用 **parameter** 定义参数，带有类型信息（如 `int`）。

- 使用 **typedef enum** 定义枚举类型，语义更清晰。

- 作用域是 **包级别**，需要 `import axi_pkg::*;` 才能使用。

- 有编译器检查，避免拼写错误和宏污染。

- 更符合 **SystemVerilog 面向对象/模块化设计**理念。

| 场景                       | `axi_define.v`     | `axi_pkg.sv`         |
| -------------------------- | ------------------ | -------------------- |
| **RTL 小规模设计**         | 可用，简单直接     | 可用，更模块化       |
| **RTL 大规模设计**         | 不推荐，宏污染严重 | 推荐，作用域清晰     |
| **传统 Verilog Testbench** | 常见，简单         | 可用，但需 SV 支持   |
| **SystemVerilog/UVM 验证** | 不推荐             | 推荐，几乎是标准做法 |

- **两者都能用**，在设计和验证中都能实现相同功能。

- **推荐选择**：如果项目是 **SystemVerilog**，最好用 `axi_pkg.sv`；如果是老的 **Verilog-only** 项目，可以继续用 `axi_define.v`。

- 在现代 SoC 设计与验证流程中，`axi_pkg.sv` 更符合最佳实践。
