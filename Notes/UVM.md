# UVM 实战（卷 I）

[TOC]

验证的目的：**保证 DUT 的功能符合 Spec 要求**

<img src="./UVM.assets/frontend_process.png" alt="frontend_process" style="zoom: 50%;" />

## 一个简单的 UVM 验证平台

通过 Spec 要求：

- **设计**：DUT，硬件思维
- **验证**：reference model（模拟 DUT 的行为），软件思维


<img src="./UVM.assets/uvm_platform.png" alt="uvm_platform" style="zoom: 50%;" />


> [!tip]
>
> 数据对象 → 场景组织 → 调度执行
>
> - **transaction**：子弹
> - **sequence**：弹匣
> - **sequencer**：手枪
>
> > [!note]
> >
> > $\text{sequencer}\rightarrow\text{driver}\rightarrow\text{DUT}\rightarrow\text{monitor}\rightarrow\text{out-agent}\rightarrow\text{expect value}$
> >
> > $\text{sequencer}\rightarrow\text{driver}\rightarrow\text{monitor}\rightarrow\text{in-agent}\rightarrow\text{reference model}\rightarrow\text{real value}$
> >
> > $\text{scoreboard}=(expect value==real value)$

### 一个简单的 driver 示例

所有派生自 `uvm_driver` 的类的 `new` 函数有两个参数，一个是 `string` 类型的 `name`，一个是 `uvm_component` 类型的 `parent`。

这两个参数是由 ==`uvm_component`== 要求的，每一个派生自 `uvm_component` 或其派生类的类在其 `new` 函数中要指明两个参数：`name` 和 `parent`，这是 `uvm_component` 类的一大特征。

`uvm_driver` 是一个派生自 `uvm_component` 的类，所以也会有这两个参数。

> [!note]
>
> `driver` 所做的事情几乎都在 `main_phase` 中完成。UVM 由 `phase` 来管理验证平台的运行，这些 phase 统一以 `xxxx_phase` 来命名，且都有一个类型为 `uvm_phase`、名字为 `phase` 的参数。
>
> `main_phase` 是 `uvm_driver` 中 **预先定义好** 的一个任务。可以简单地认为，**实现一个 driver 等于实现其 main_phase**。

```systemverilog
class my_driver extends uvm_driver;	// my_driver 是一个自定义的 UVM 驱动类，继承自 uvm_driver
	
    // 构造函数调用 super.new，完成 UVM 组件的标准初始化。
    function new(string name = "my_driver", uvm_component parent = null);   
        super.new(name, parent);
    endfunction
    
    // main_phase 是一个执行阶段任务，通常用于驱动 DUT 的输入信号。
    extern virtual task main_phase(uvm_phase phase);
endclass

task my_driver::main_phase(uvm_phase phase);
    top_tb.rxd <= 8'b0;
    top_tb.rx_dv <= 1'b0;
    while(!top_tb.rst_n)
        @(posedge top_tb.clk);
    for(int i = 0; i < 256; i++)begin
        @(posedge top_tb.clk);
        top_tb.rxd <= $urandom_range(0, 255);	// 每个时钟周期，把一个 0~255 的随机数赋值到 rxd 信号
        top_tb.rx_dv <= 1'b1;
        `uvm_info("my_driver", "data is drived", UVM_LOW)
    end
    @(posedge top_tb.clk);
    top_tb.rx_dv <= 1'b0;
endtask
```

``uvm_info(" my_driver ", " data is drived ", UVM_LOW)`

- `"my_driver"` → 消息来源标签（方便定位）。
- `"data is drived"` → 打印的内容。
- `UVM_LOW` → 日志等级，表示低优先级信息。

> UVM_INFO my_driver.sv(20) @ 48500000: drv [my_driver] data is drived

- `20` → 代码行号
- `48500000` → 仿真时间戳

> [!note]
>
> - **作用**：在 UVM 日志系统中打印一条信息。（强于 verilog 中的 `$display`）
> - UVM 默认只显示 `UVM_MEDIUM` 或者 `UVM_LOW` 的信息，关键信息设置为 `UVM_LOW`
> - `UVM_INFO` 关键字：表明这是一个 `uvm_info` 宏打印的结果。除了 `uvm_info` 宏外，还有 `uvm_error` 宏、`uvm_warning` 宏

```systemverilog
// top_tb.sv
`timescale 1ns/1ps
`include "uvm_macros.svh"	// UVM中的一个文件，里面包含了众多的宏定义，只需要包含一次

import uvm_pkg::*;
`include "my_driver.sv"		// 只有导入了这个库，编译器在编译.sv文件时才会认识其中的 uvm_driver等类名

module top_tb;

    reg clk;
    reg rst_n;
    reg[7:0] rxd;
    reg rx_dv;
    wire[7:0] txd;
    wire tx_en;

    dut my_dut(.clk(clk),
               .rst_n(rst_n), 
               .rxd(rxd),
               .rx_dv(rx_dv),
               .txd(txd),
               .tx_en(tx_en));

    initial begin
        my_driver drv;
        drv = new("drv", null);
        drv.main_phase(null);
        $finish();
    end

    initial begin
        clk = 0;
        forever begin
            #100 clk = ~clk;
        end
    end

    initial begin
        rst_n = 1'b0;
        #1000;
        rst_n = 1'b1;
    end

endmodule
```

### factory 机制

> 功能：**自动** 创建一个类的 **实例** 并调用其中的函数（**function**）和任务（**task**）。

> [!note]
>
> **factory 机制** 的实现被集成在了一个宏中：`uvm_component_utils`。
>
> 这个宏所做的事情非常多，其中之一就是将 my_driver 登记在 UVM 内部的一张表中，这张表是 factory 功能实现的基础。只要在定义一个新的类时使用这个宏，就相当于 **把这个类 ==注册== 到了这张表中**。

```systemverilog
// my_driver.sv
class my_driver extends uvm_driver;

    `uvm_component_utils(my_driver)
    function new(string name = "my_driver", uvm_component parent = null);
        super.new(name, parent);
        `uvm_info("my_driver", "new is called", UVM_LOW);
    endfunction
    extern virtual task main_phase(uvm_phase phase);
endclass

task my_driver::main_phase(uvm_phase phase);
    `uvm_info("my_driver", "main_phase is called", UVM_LOW);
    top_tb.rxd <= 8'b0;
    top_tb.rx_dv <= 1'b0;
    while(!top_tb.rst_n)
        @(posedge top_tb.clk);
    for(int i = 0; i < 256; i++)begin
        @(posedge top_tb.clk);
        top_tb.rxd <= $urandom_range(0, 255);
        top_tb.rx_dv <= 1'b1;
        `uvm_info("my_driver", "data is drived", UVM_LOW);
    end
    @(posedge top_tb.clk);
    top_tb.rx_dv <= 1'b0;
endtask
```

在给 `driver` 中加人 factory 机制后，还需要对 top_tb 做一些 **改动**：

```systemverilog
module top_tb;
// ...
    initial begin
        run_test("my_driver");	// 使用run_test替换了top_tb中第23到28行的my_driver实例化及main_phase的显式调用
        // initial begin
        //     my_driver drv;
        //     drv = new("drv", null);
        //     drv.main_phase(null);
        //     $finish();
    	// end
    end

endmodule
```

一个 `run_test` 语句会创建一个 `my_driver` 的 **实例（`new()`）**，并且会 **自动调用** `my_driver` 的 `main_phase`

运行新的验证平台, 输出如下信息：

```shell
new is called
main_phased is called
```

> [!caution]
>
> 上面的例子中，只输出到“`main_phase is called`”。但没有输出“`data is drived`”，按照预期，它应该输出 256 次。关于这个问题，牵涉 UVM 的 ==**objection**== 机制。


> [!important]
>
> 根据类名创建一个类的实例，这是 `uvm_component_utils` 宏所带来的效果，同时也是 `factory` 机制给读者的最初印象。
>
> **只有在类定义时声明了这个宏，才能使用这个功能**。所以从某种程度上来说，==这个宏起到了注册的作用==。只有经过注册的类，才能使用这个功能。
>
> 记住一点：==所有派生自 `uvm_component` 及其派生类的类（`driver`、`monitor`、`sequencer`...）都应该使用 `uvm_component_utils` 宏注册。==

### objection 机制

> 功能：**控制验证平台的关闭**。（在 UVM 中 objection 机制取代了 `$finish`）

**在每个 phase 中**，UVM 会检查 **是否有 objection 被提起**（`raise_objection`），如果有，那么 **等待这个 objection 被撤销**（`drop_objection`）后停止仿真；如果没有，则 **马上结束当前 phase**

- 简单地将 `drop_objection` 语句当成是 `$finish` 函数的替代者
  - `raise_objection` 和 `drop_objection` 总是成对出现


> [!caution]
>
> `raise_objection` 语句必须在 main_phase 中 **第一个消耗仿真时间** 的语句之前，如 `@(posedge top.clk)` 等语句
>
> 如 `$display` 语句是不消耗仿真时间，可以放在 `raise_objection` 之前

```systemverilog
task my_driver::main_phase(uvm_phase phase);
    phase.raise_objection(this);	// objection机制
    `uvm_info("my_driver", "main_phase is called", UVM_LOW);
    top_tb.rxd <= 8'b0;
    top_tb.rx_dv <= 1'b0;
    while(!top_tb.rst_n)
        @(posedge top_tb.clk);
    for(int i = 0; i < 256; i++)begin
        @(posedge top_tb.clk);
        top_tb.rxd <= $urandom_range(0, 255);
        top_tb.rx_dv <= 1'b1;
        `uvm_info("my_driver", "data is drived", UVM_LOW);
    end
    @(posedge top_tb.clk);
    top_tb.rx_dv <= 1'b0;
    phase.drop_objection(this);		// objection机制
endtask 
```

加入 objection 机制后再运行验证平台，可以发现“`data isdrived`”按照预期输出了 256 次

### virtual interface

> `interface`：UVM（软件）与 DUT（硬件）进行数据传输需要的 **接口**
>
> `virtual interface`：**接口的指针**
>
> - **类比**：使用 **class 类**，需要先定义 **句柄**，再通过 `new()` 进行 **实例化**

> [!caution]
>
> 在前几节的例子中，`driver` 中等待时钟事件（`@posedge top.clk`）、给 DUT 中输入端口赋值（`top.rx_dv<=1‘b1`）都是使用 ==绝对路径==，绝对路径的使用大大减弱了验证平台的 ==可移植性==。
>
> 避免绝对路径的一个方法是 **使用宏**：

```systemverilog
`define TOP top_tb	// 使用宏定义统一修改变量名
task my_driver::main_phase(uvm_phase phase);    
    phase.raise_objection(this);
    `uvm_info("my_driver", "main_phase is called", UVM_LOW);
    `TOP.rxd <= 8'b0;    
    `TOP.rx_dv <= 1'b0;    
    while(!`TOP.rst_n)       
        @(posedge `TOP.clk);
    for(int i = 0; i < 256; i++)begin
        @(posedge `TOP.clk);
        `TOP.rxd <= $urandom_range(0, 255);
        `TOP.rx_dv <= 1'b1;
        `uvm_info("my_driver", "data is drived", UVM_LOW);    
    end
    @(posedge `TOP.clk);    
    `TOP.rx_dv <= 1'b0;    
    phase.drop_objection(this); 
endtask
```

但是假如 `clk` 的路径变为了 `top_tb.clk_inst.clk`，而 `rst_n` 的路径变为了 `top_tb.rst_inst.rst_n`，那么单纯地修改宏定义是无效的。

所以有避免绝对路径的另外一种方式：**使用 `interface`**

在 SystemVerilog 中使用 `interface` 来连接 **验证平台** 与 **DUT 的端口**。

```systemverilog
// interface 定义
interface my_if(input clk, input rst_n);
    logic [7:0] data;
    logic valid;
endinterface
```

定义了 `interface后`，在 `top_tb` 中实例化 DUT 时，可以直接使用

```systemverilog
// interface 实例化
my_if input_if(clk, rst_n);
my_if output_if(clk, rst_n);

dut my_dut(.clk(clk),
           .rst_n(rst_n),
           .rxd(input_if.data),
           .rx_dv(input_if.valid),
           .txd(output_if.data),
           .tx_en(output_if.valid));
```

如何在 `driver` 中使用 `interface`

```systemverilog
class my_driver extends uvm_driver;
    my_if  drv_if;
	// ...
endclass
```

> [!caution]
>
> 因为 `my_driver` 是一个 **calss 类**（**软件世界**），在类中不能使用上述方式声明一个 **interface（硬件世界）**，只有在类似 `top_tb` 这样的模块（`module`）中才可以。

在 **类** 中使用的是 ==`virtual interface`==

```systemverilog
class my_driver extends uvm_driver;
	virtual my_if vif;
    // ...
endclass
```

在声明了 `vif` 后，就可以在 `main_phase` 中使用如下方式驱动其中的信号：

```systemverilog
task my_driver::main_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("my_driver", "main_phase is called", UVM_LOW);
    vif.data <= 8'b0;
    vif.valid <= 1'b0;
    while(!vif.rst_n)
        @(posedge vif.clk);
    for(int i = 0; i < 256; i++)begin
        @(posedge vif.clk);
        vif.data <= $urandom_range(0, 255);
        vif.valid <= 1'b1;
        `uvm_info("my_driver", "data is drived", UVM_LOW);
    end
    @(posedge vif.clk);
    vif.valid <= 1'b0;
    phase.drop_objection(this);
endtask
```

> [!caution]
>
> **最后一个问题**：如何把 `top_tb` 中的 `input_if` 和 `my_driver` 中的 `vif` 对应起来
>
> 对于这种 **脱离了 `top_tb` 层次结构**，同时又 **期望在 `top_tb` 中对其进行某些操作的实例**，UVM 引进了 ==config_db== 机制

### config_db 机制

> 分为 `set` 和 `get` 两步操作。
>
> **`set`**：可以简单理解成是“**寄信**”
>
> **`get`**：相当于是“**收信**”

在 `top_tb` 中执行 **`set` 操作**

```systemverilog
initial begin
	uvm_config_db#(virtual my_if)::set(null, "uvm_test_top", "vif", input_if);
end
```

在 `my_driver` 中，执行 **`get` 操作**

```systemverilog
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("my_driver", "build_phase is called", UVM_LOW);
    if(!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
        `uvm_fatal("my_driver", "virtual interface must be set for vif!!!")
endfunction
```

- 引入了 `build_phase`。与 `main_phase` 一样，`build_phase` 也是 UVM 中 **内建** 的一个 `phase`。

- 当 UVM 启动后，会自动执行 `build_phase`。`build_phase` 在 `new` 函数之后 `main_phase` 之前执行。在 `build_phase` 中主要通过 `config_db` 的 `set` 和 `get` 操作来传递一些数据，以及实例化成员变量等。

- 注意，这里需要加入 `super.build_phase` 语句，因为在其 `父类的build_phase` 中执行了一些必要的操作，这里必须显式地调用并执行它。

- `build_phase` 与 `main_phased` 的 **不同点** 在于，**`build_phase` 是一个 `function phase`，而 `main_phase` 是一个 `task phase`**

  `build_phase` 不消耗仿真时间，**build_phase 总是在仿真时间（`$time` 函数打印出的时间）为 0 时执行**。
