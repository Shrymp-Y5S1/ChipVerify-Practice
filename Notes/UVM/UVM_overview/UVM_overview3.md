# UVM overview3

## UVM analysis component

> [!note]
>
> - **Reference model**：**模拟 DUT 的行为**，并 **根据输入计算出相应输出** 的组件
>
> - **Scoreboard**：将 **DUT 的输出** 与从 **参考模型获取的期望值** 相比对，判断 DUT 是否正常工作的组件

- 构建 **slalve agent** 中的 **monitor**

  ```systemverilog
  class out_monitor extends uvm_monitor;
      // ...
      virtual dut_interface                   my_vif;
      uvm_blocking_put_port #(my_transaction) m2s_port;
      // ...
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          `uvm_info("TRACE", $sformat("%m"), UVM_MEDIUM)
          if (!uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
      endfunction
  
      virtual task run_phase(uvm_phase phase);
          my_transaction       tr;
          int                  active_port;
          logic          [7:0] temp;
          int                  count;
          forever begin
              active_port = -1;
              count       = 0;
              tr   = my_transaction::type_id::create("tr", this);
              // wait for bus active
              while (1) begin
                  @(my_vif.o_monitor_cb);
                  foreach (my_vif.o_monitor_cb.frameo_n[i]) begin
                      if (my_vif.o_monitor_cb.frameo_n[i] == 0) begin
                          active_port = i;
                      end
                  end
                  if (active_port != -1) begin
                      break;
                  end
              end
              // active port has been detected, get the source address
              tr.da = active_port;
              // get the payload
              forever begin
                  if (my_vif.o_monitor_cb.valido_n[tr.da] == 0) begin
                      temp[count] = my_vif.o_monitor_cb.dout[tr.da];
                      count++;
                      if (count == 8) begin
                          tr.payload.push_back(temp);
                          count = 0;
                      end
                  end
                  if (my_vif.o_monitor_cb.frameo_n[tr.da]) begin
                      if (count != 0) begin
                          tr.payload.push_back(temp);
                          `uvm_warning("PAYLOAD_WARNING", "...")
                      end
                      break;
                  end
                  @(my_vif.o_monitor_cb);
              end
              `uvm_info("OUT_MONITOR", {"...", tr.sprint()}, UVM_MEDIUM)
              `uvm_info("OUT_MONITOR", "...", UVM_MEDIUM)
              this.m2s_port.put(tr);
          end
      endtask
  endclass
  ```

- 构建 **slave agent**

  ```systemverilog
  class slave_agent extends uvm_agent;
      // ...
      out_monitor                               my_moni;
      agent_config                              my_agent_cfg;
      uvm_blocking_put_export #(my_transaction) s_a2s_export;
  
      function new(string name = "", uvm_component parent);
          super.new(name, parent);
          this.s_a2s_export = new("s_a2s_export", this);
      endfunction
  
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          if (!uvm_config_db#(agent_config)::get(this, "", "my_agent_cfg", my_agent_cfg)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
          uvm_config_db#(virtual dut_interface)::set(this, "my_moni", "vif", my_agent_cfg.my_vif);
          my_moni = out_monitor::type_id::create("my_moni", this);
      endfunction
  
      virtual function void connect_phase(uvm_phase phase);
          my_moni.m2s_port.connect(this.s_a2s_export);
      endfunction
  endclass
  ```

- 构建 **scoreboard**

  ```systemverilog
  class my_scoreboard extends uvm_scoreboard;
      // ...
      uvm_blocking_get_port #(my_transaction) r2s_port;
      uvm_blocking_get_port #(my_transaction) s_a2s_port;
      // ...
      virtual task run_phase(uvm_phase phase);
          my_transaction dut_output_tr;
          my_transaction expected_tr;
          forever begin
              `uvm_info("SCOREBOARD","...",UVM_MEDIUM)
              fork
                  r2s_port.get(expected_tr);
                  s_a2s_port.get(dut_output_tr);
              join
              `uvm_info("CHECK", "...", UVM_MEDIUM)
              if (expected_tr.compare(dut_output_tr)) begin
                  `uvm_info("CHECK", "...", UVM_MEDIUM)
              end
              else begin
                  `uvm_error("CHECK_ERROR", {"...",expected_tr.sprint(),,dut_output_tr.sprint()})
              end
          end
      endtask
  endclass
  ```

- 在 reference model 添加一个新的端口

  ```systemverilog
  class my_reference_model extends uvm_component;
      // ...
      uvm_blocking_put_imp #(my_transaction, my_reference_model) i_m2r_imp;
      uvm_blocking_put_port #(my_transaction)                    r2s_port;
  
      function new(string name = "", uvm_component parent);
          super.new(name, parent);
          this.i_m2r_imp = new("i_m2r_imp", this);
          this.r2s_port  = new("r2s_port", this);
      endfunction
  
      task put(my_transaction tr);
          `uvm_info("REF_REPORT", {"...", tr.sprint()}, UVM_MEDIUM)
          this.r2s_port.put(tr);
      endtask
  endclass
  ```

- 创建两个用于通信的 fifo

- 将组件与 fifo 相连接

  ```systemverilog
  class my_environment extends uvm_env;
      `uvm_component_utils(my_environment)
      master_agent                            my_agent;
      slave_agent                             my_slave_agent;
      env_config                              my_env_config;
      my_reference_model                      ref_model;
      my_scoreboard                           scb;
      uvm_tlm_analysis_fifo #(my_transaction) r2s_fifo;
      uvm_tlm_analysis_fifo #(my_transaction) s_a2s_fifo;
  
      function new(string name = "", uvm_component parent);
          super.new(name, parent);
          this.r2s_fifo   = new("r2s_fifo", this);
          this.s_a2s_fifo = new("s_a2s_fifo", this);
      endfunction
  
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          if (!uvm_config_db#(env_config)::get(this, "", "env_config", my_env_config)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
          uvm_config_db#(agent_config)::set(this, "my_agent", "my_agent_config", my_env_config.my_agent_config);
          uvm_config_db#(agent_config)::set(this, "my_slave_agent", "my_slave_agent_config", my_env_config.my_slave_agent_config);
  
          if (my_env_config.is_coverage) begin
              `uvm_info("COVERAGE_ENABLE", "...", UVM_LOW)
          end
          if (my_env_config.is_check) begin
              `uvm_info("CHECK_ENABLE", "...", UVM_LOW)
          end
  
          my_agent       = master_agent::type_id::create("my_agent", this);
          my_slave_agent = slave_agent::type_id::create("my_slave_agent", this);
          scb            = my_scoreboard::type_id::create("scb", this);
          ref_model      = my_reference_model::type_id::create("ref_model", this);
      endfunction
  
      virtual function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          `uvm_info("ENV", "...", UVM_MEDIUM)
          my_agent.m_a2r_export.connect(this.r2s_fifo.blocking_put_export);
          my_slave_agent.s_a2s_export.connect(this.s_a2s_fifo.blocking_put_export);
          ref_model.i_m2r_port.connect(this.r2s_fifo.blocking_get_export);
          if (my_env_config.is_check) begin
              scb.r2s_port.connect(this.r2s_fifo.blocking_get_export);
              scb.s_a2s_port.connect(this.s_a2s_fifo.blocking_get_export);
          end
      endfunction
  endclass
  ```

## UVM advanced sequence（后续补充）

### Virtual Sequence 与 Virtual Sequencer (全局“总指挥”)

> [!note]
>
> 在 SystemVerilog 中，`virtual interface` 里的 `virtual` 是一个 **真实的底层语法关键字**；但在 UVM 中，Virtual Sequence 和 Virtual Sequencer 里的 `Virtual` 仅仅是一个 **方法学上的概念命名**，在代码定义时确实不需要（也不能）加 `virtual` 前缀。

- **核心定位：** 它是真正用来协调全局验证环境的“总指挥”。
- **应用场景：** 当系统里有多个不同类型的接口时，比如一边通过 AXI 接口发送正常的数据报文，一边又需要发送控制指令或异常中断。
- **工作机制：** 你需要 Virtual Sequence 来跨越局部 Agent 的限制，**统一调度底层不同 Agent 的 sequence**，使它们能够按照特定的时间轴进行并发或串行执行。

  > [!tip]
  >
  > Virtual Sequencer **本身不直接与 Driver 连线发包**，它只负责 **给底层的 Sequencer 派发任务**。

```systemverilog
// 1. 定义 Virtual Sequencer (仅作为存放底层 Sequencer 句柄的容器)
class my_vsqr extends uvm_sequencer;
    `uvm_component_utils(my_vsqr)
    axi_sequencer  axi_sqr;  // AXI 总线序列器句柄
    intr_sequencer intr_sqr; // 中断序列器句柄
    // ... new() 函数省略 ...
endclass

// 2. 定义 Virtual Sequence
class global_sanity_vseq extends uvm_sequence;
    `uvm_object_utils(global_sanity_vseq)
    
    // 声明底层的具体 Sequence
    axi_burst_seq axi_seq;
    intr_err_seq  intr_seq;

    // 声明一个 Virtual Sequencer 的句柄，用于类型转换
    my_vsqr vsqr; 

    virtual task body();
        // 将通用的 m_sequencer 转换为具体的 Virtual Sequencer
        if (!$cast(vsqr, m_sequencer)) begin
            `uvm_fatal("VSEQ", "Cast to virtual sequencer failed!")
        end

        axi_seq  = axi_burst_seq::type_id::create("axi_seq");
        intr_seq = intr_err_seq::type_id::create("intr_seq");

        // 3. 使用 fork...join 并发调度不同接口的激励
        fork
            // AXI 序列挂载到 AXI sequencer 上
            axi_seq.start(vsqr.axi_sqr, this); 
            begin
                #1000ns; // 等待一段时间后触发中断
                // 中断序列挂载到中断 sequencer 上
                intr_seq.start(vsqr.intr_sqr, this); 
            end
        join
    endtask
endclass
```

### Sequence 的层级嵌套与 `start()` 方法 (场景构造器)

- **核心逻辑：** 在构建复杂的测试用例时，不要依赖隐式的、不可控的随机机制。
- **工作机制：** 学会在一个大的 Sequence 内部，手动实例化并调用 `start()` 方法来运行其他微小的、功能单一的 Sequence。
- **应用场景：** 像搭积木一样构造复杂的场景。比如在验证流水线处理器时，可以利用层级嵌套精准地构造并发送具有特定资源依赖关系的指令流，以此来测试流水线的停顿（Stall）或前递（Forwarding）机制。

```systemverilog
class riscv_complex_test_seq extends uvm_sequence;
    `uvm_object_utils(riscv_complex_test_seq)

    // 1. 声明底层的基础 Sequence 句柄
    riscv_alu_seq  alu_seq;
    riscv_mem_seq  mem_seq;

    virtual task body();
        // 2. 实例化并启动 ALU 测试序列
        alu_seq = riscv_alu_seq::type_id::create("alu_seq");
        // start() 的参数指明它挂载到哪个 Sequencer 上运行
        alu_seq.start(m_sequencer, this); 

        // 3. 实例化并启动 Memory 访存序列
        mem_seq = riscv_mem_seq::type_id::create("mem_seq");
        mem_seq.start(m_sequencer, this);
    endtask
endclass
```

### Sequence 的仲裁机制 `lock` / `grab` (资源与路权管理)

- **核心逻辑：** 学习和处理当多个 sequence 同时想占用同一个 Driver 时的资源冲突问题。
- **工作机制：** **仲裁 (Arbitration)** ：通过为不同的 Sequence 设置优先级，让底层 Sequencer 根据优先级高低来决定先发送谁的 Item。
  - **抢占 (`lock` / `grab`)：** 通过强制抢占机制（grab）直接打断正在执行的低优先级 Sequence。
- **应用场景：** 这种机制非常适合用来模拟硬件系统中的突发事件（例如总线报错、最高优先级的中断响应等）。

```systemverilog
class emergency_reset_seq extends uvm_sequence;
    `uvm_object_utils(emergency_reset_seq)
    
    axi_transaction rst_tr;

    virtual task body();
        rst_tr = axi_transaction::type_id::create("rst_tr");
        
        // 1. 强制抢占 Sequencer 的控制权 (无视其他正在排队的序列)
        m_sequencer.grab(this); 
        
        // 2. 发送紧急事务
        start_item(rst_tr);
        rst_tr.randomize() with { type == RESET; };
        finish_item(rst_tr);
        
        // 3. 必须释放控制权，否则系统死锁
        m_sequencer.ungrab(this); 
    endtask
endclass
```



## UVM RAL

### 基本概念

> RAL: register abstraction layer，寄存器抽象层

> [!note]
>
> | 特性         | 寄存器                                                       | 存储器                                           |
> | ------------ | ------------------------------------------------------------ | ------------------------------------------------ |
> | **位置**     | 位于处理器或硬件模块内部，紧贴逻辑电路                       | 独立的存储单元，如 RAM、ROM                       |
> | **容量**     | 数量少，容量 **小**                                           | 容量 **大**，可存储大量数据                       |
> | **速度**     | 访问速度极 **快**，通常一个时钟周期即可完成                   | 相对较 **慢**，需要总线访问                       |
> | **用途**     | 保存 **控制** 信息、**状态** 位、**配置** 参数                   | 保存程序 **数据**、**指令**、**运行时信息**       |
> | **抽象层**   | 在验证中常通过 **寄存器抽象层（RAL）** 建模，便于读写和覆盖率收集 | 存储器抽象更偏向 **整体数据块** 的读写与一致性验证 |
> | **验证重点** | 正确性、可读写性、复位值、**覆盖率**                         | 地址映射、**数据一致性**、容量边界、时序约束     |

Register Model 是验证环境中的一个 **软件抽象结构**。它在内存中创建了一份 DUT 内部硬件寄存器（register）和存储器（memory）的 **镜像**。通过这个模型，可以在不直接操作物理总线的情况下，在验证环境中随时查看和管理硬件的状态

<img src="./UVM_overview3.assets/ral_flow.png" alt="ral_flow" style="zoom: 25%;" />

### 工作原理及构成

#### 前门访问 (Frontdoor)

- **路径**：`Register model` $\rightarrow$ `Adapter` $\rightarrow$ `sequencer` $\rightarrow$ `driver` $\rightarrow$ `DUT`
- 前门访问是 **模拟真实的物理总线时序** 来读写寄存器
  - 当在 Sequence 中调用 `reg.write()` 或 `reg.read()` 时，RAL 会生成一个通用的寄存器操作
  - 这个操作必须 **经过总线协议**（如 APB, AHB, AXI 等）才能到达 DUT，因此需要 **消耗仿真时间**

#### 适配器 (Adapter)

- **向下转换：** 寄存器模型发出的是 **通用的** 抽象总线事务（`uvm_reg_bus_op`），Adapter 将其转换为 sequencer 能支持的 **特定总线协议** 的 `sequence_item`，然后交给 `sequencer`
- **向上转换：** 当总线完成读操作返回数据时，Adapter 将协议相关的 **响应**（response）转换回 **通用** 格式，交还给寄存器模型

#### 后门访问 (Backdoor)

- 直接从寄存器模型绕过 Agent 指向 DUT 内部
- 后门访问是 **绕过物理总线**，利用仿真器的特性（通过层次化路径 HDL path，底层基于 VPI/DPI）直接读取或修改 DUT 内部信号的值
  - **特点：** **不消耗仿真时间**，不占用总线带宽
  - **用途：** 常用于环境初始化、快速配置、或者在不影响总线状态的情况下“偷看”寄存器当前值

#### Scoreboard

- **状态获取：** Scoreboard 在比对数据包时，经常需要知道当前 DUT 的工作模式。它可以直接通过 RAL 模型（如调用 `reg.get()` 或 `read()`）获取配置状态
- **预期值计算：** Monitor 抓取到总线上的数据后，可以传递给 Scoreboard，Scoreboard 再去对比 Register Model 中保存的镜像值，以此验证寄存器读写的正确性

#### Sequence

在引入 RAL 之后，我们在编写测试用例（Sequence）时，可以直接实例化寄存器模型，然后调用面向对象的方法（如 `my_reg_model.ctrl_reg.write(status, value, UVM_FRONTDOOR)`）

> [!tip]
>
> 在 UVM 环境的 `connect_phase` 阶段，只需调用寄存器模型顶层默认地址映射表（`default_map`）的 `set_sequencer()` 方法，将物理总线的 `sequencer` 实例与协议转换器 `adapter` 实例作为参数同时传入，即可完成这 **三者的绑定连接**

#### Register Model 和 Adapter 内部结构

| **模块大类**              | **核心组件 / 方法**     | **结构定位与专业术语**                                       | **关键函数 / 属性与实际应用**                                |
| ------------------------- | ----------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Register Model (树状层级) | **`uvm_reg_block`**     | **根节点/枝干:** 封装整个子系统的寄存器、存储器、地址映射表以及子 block。 | `create()`: 实例化组件。 `build()`: 用户自定义的构建函数。 `lock_model()`: 构建完成后锁定结构防止修改 |
|                           | **`uvm_reg_map`**       | **路由与导航:** 负责地址偏移量计算。是连接模型与总线 Sequencer/Adapter 的物理桥梁。 | `add_reg()`: 将寄存器映射到指定偏移地址。 `set_sequencer()`: 在环境顶层绑定物理 Agent 的 Sequencer 和 Adapter。 |
|                           | **`uvm_reg`**           | **寄存器容器:** 对应物理硬件中特定地址的单个寄存器（如 32-bit），是位域的集合。 | 前门/后门操作接口：`read()`, `write()`, `update()` (同步期望值到 DUT), `mirror()` (读取 DUT 更新镜像值)。 |
|                           | **`uvm_reg_field`**     | **最底层原子位域:** 对应寄存器内部具有独立/相同功能的比特位集合（如 bit [2:0]）。 | 存储核心状态：**Desired Value (期望值)** 与 **Mirrored Value (镜像值)**。 `configure()`: 设置位宽、访问类型(RW/W1C/RO 等)、复位值。 `set()`, `get()`: 仅修改或获取模型内部的期望值（不发起总线操作）。 |
| Adapter (翻译引擎)        | **`reg2bus()`**         | **向下转换接口:** 纯虚函数。将 RAL 通用的抽象总线操作转换为具体的物理总线级事务。 | 输入：`const ref uvm_reg_bus_op rw` (包含地址、读写类型、数据)。 输出：`uvm_sequence_item` (如 `apb_item`, `axi_item`，直接发往 Sequencer)。 |
|                           | **`bus2reg()`**         | **向上转换接口:** 纯虚函数。将 Monitor 或 Driver 采到的物理总线事务，解析回 RAL 可识别的通用格式，用于更新内部镜像值。 | 输入：`uvm_sequence_item bus_item` (如抓取到的 `apb_item`)。 输出：`ref uvm_reg_bus_op rw` (将总线返回的 `rdata` 或 `status` 填入此结构体赋给模型)。 |
|                           | **Configuration Flags** | **总线特性配置标志:** 声明目标总线的硬件协议特性，指导 RAL 底层如何打包和发送事务。 | `provides_responses`: 设为 1 表示总线有独立响应通道（如 AXI）；设为 0 表示读写同周期完成（如 APB）。 `supports_byte_enable`: 设为 0 时，若模型只写部分位域，RAL 会自动执行 **Read-Modify-Write (读-改-写)**。 |

### 使用方法

> [!note]
>
> **基于以下 DUT 配置进行建模**
>
> **DUT 寄存器**
>
> | 名称       | 地址   | 域 field | 位位置 | 访问权限 |
> | ---------- | ------ | -------- | ------ | -------- |
> | config_reg | 0x001C | f4       | bit7   | WO       |
> |            |        | f3       | bit6   | RW       |
> |            |        | f2       | bit2   | RO       |
> |            |        | f1       | bit1~0 | RW       |
> | mode_reg   | 0x002D | data     | bit7~0 | RW       |
>
> **DUT 存储器**
>
> | 名称     | 起始地址 | 位宽  | 大小 |
> | -------- | -------- | ----- | ---- |
> | data_mem | 0x1000   | 16bit | 512  |

- **为 DUT 创建寄存器模型**（这里包括 config_reg, mode_reg, data_mem 以及顶层 reg_model）

  ```systemverilog
  class config_reg_c extends uvm_reg;
      // ...
      rand uvm_reg_field f1;
      // ...
      virtual function void build();
          f1 = uvm_reg_field::type_id::create("f1");
          // ...
          f1.configure(this, 1, 0, "RW", 0, 'h0, 1, 1, 1);
          // ...
      endfunction
      function new(string name = "config_reg_c");
          super.new(name, 8, UVM_NO_COVERAGE);
      endfunction
  endclass
  
  // ----------------------------------------
  class mode_reg_c extends uvm_reg;
      // ...
      rand uvm_reg_field data;
      virtual function void build();
          data = uvm_reg_field::type_id::create("data");
          data.configure(this, 8, 0, "RW", 0, 'h0, 1, 1, 1);
      endfunction
      function new(string name = "mode_reg_c");
          super.new(name, 8, UVM_NO_COVERAGE);
      endfunction
  endclass
  
  // ----------------------------------------
  class data_mem_c extends uvm_mem;
      // ...
      function new(string name = "data_mem_c");
          super.new(name, 512, 16);
      endfunction
  endclass
  
  // ----------------------------------------
  class reg_model_c extends uvm_reg_block;
      rand config_reg_c config_reg;
      // ...
      data_mem_c        data_mem;
  
      virtual function void build();
          config_reg = config_reg_c::type_id::create("config_reg");
          config_reg.configure(this, null, "config_reg");
          config_reg.build();
          // ...
          data_mem = data_mem_c::type_id::create("data_mem");
          data_mem.configure(this, "data_mem");
  
          default_map = create_map("default_map", 0, 1, UVM_LITTLE_ENDIAN);
          default_map.add_reg(config_reg, 'h001c, "RW");
          // ...
          default_map.add_mem(data_mem, 'h1000);
      endfunction
      function new(string name = "reg_model_c");
          super.new(name, UVM_NO_COVERAGE);
      endfunction
  endclass
  ```

- **为创建实现前门操作的转换器**

  ```systemverilog
  class my_adapter extends uvm_reg_adapter;
      // ...
      // 实现reg2bus函数，将寄存器访问转换为总线事务
      function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
          cpu_trans cpu_tr;
          cpu_tr      = cpu_trans::type_id::create("cpu_tr");
          // ...
          return cpu_tr;
      endfunction
  
      // 实现bus2reg函数，将总线事务转换为寄存器访问
      function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
          cpu_trans cpu_tr;
          if (!$cast(cpu_tr, bus_item)) begin
              `uvm_fatal("ADAPTER", "...")
              return;
          end
          rw.kind    = (cpu_tr.acc == CPU_R) ? UVM_READ : UVM_WRITE;
          // ...
      endfunction
  endclass
  
  // ----------------------------------------
  class cpu_trans extends uvm_sequence_item;
      typedef enum {CPU_R, CPU_W} BUS_ACC_e;
      rand bit       [15:0] addr;
      // ...
      rand BUS_ACC_e        acc;
      `uvm_object_utils_begin
      `uvm_field_int(addr, UVM_ALL_ON)
      // ...
      `uvm_field_enum(BUS_ACC_e, acc, UVM_ALL_ON)
      `uvm_object_utils_end
  endclass
  ```

  > [!tip]
  >
  > **UVM 内建结构体**: `uvm_reg_bus_op`
  >
  > ```systemverilog
  > typedef struct {
  >     uvm_access_e      kind;
  >     uvm_reg_addr_t    addr;
  >     uvm_reg_data_t    data;
  >     int               n_bits;
  >     uvm_reg_byte_en_t byte_en;
  >     uvm_status_e      status;
  > } uvm_reg_bus_op;
  > ```

- **在测试平台中实例化寄存器模型和转换器**

- **将转换器、sequencer 与寄存器模型的 map 建立关联**

  ```systemverilog
  class my_environment extends uvm_env;
      // ...
      reg_model_c reg_model;
      my_adapter  reg_adapter;
      // ...
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          // ...
          reg_model = reg_model_c::type_id::create("reg_model", this);
          reg_model.configure(null, "tb.dut");
          reg_model.build();
          reg_model.lock();
          reg_model.reset();
          reg_adapter = my_adapter::type_id::create("reg_adapter", this);
      endfunction
  
      virtual function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          // ...
          reg_model.default_map.set_sequencer(my_agent.sequencer, reg_adapter);
          reg_model.default_map.set_auto_predict(1);
      endfunction
  endclass
  ```

- **在需要进行寄存器读写的地方使用 API 访问寄存器**

  ```systemverilog
  class my_environment extends uvm_env;
      // ...
      my_scoreboard scb;
      // ...
      virtual function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          // ...
          scb.reg_model = reg_model;
      endfunction
  endclass
  
  // ----------------------------------------
  class my_scoreboard extends uvm_scoreboard;
      // ...
      reg_model_c reg_model;
      // ...
      virtual task run_phase(uvm_phase phase);
          // ...
          uvm_status_e   status;
          uvm_reg_data_t value;
          forever begin
              // ...
              reg_model.config_reg.write(status, value, UVM_FRONTDOOR);
              // ...
              reg_model.mode_reg.read(status, value, UVM_FRONTDOOR);
              // ...
          end
      endtask
  endclass
  ```


### 寄存器模型的基本数据结构

<img src="./UVM_overview3.assets/reg_model_data_structures.png" alt="reg_model_data_structures" style="zoom: 25%;" />

| **基类 (Base Class)** | **层级定位**   | **核心功能**                                                 | **扩展与使用说明**                                           |
| --------------------- | -------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **`uvm_reg_field`**   | 最底层数据单元 | **真正存储数据** 的位 **域**，包含 `value`（实际值）、`m_mirrored`（镜像值）、`m_desired`（期望值）等核心属性。 | 直接实例化使用，通常 **无需扩展**。                           |
| **`uvm_reg`**         | 寄存器模型     | 对硬件寄存器进行建模。**自身无存储能力**，本质是包含一个或多个 `uvm_reg_field` 的容器。 | 属于 **虚类**，**必须派生扩展** 后使用。                       |
| **`uvm_mem`**         | 存储器模型     | 对连续的存储空间（如 RAM、ROM 等连续地址段）进行建模。       | 一般 **需要派生扩展** 后使用。                                 |
| **`uvm_block`**       | 核心管理容器   | **RAL 树的主体**。包含 **reg**、**mem**、**map** 及 **子 block**；向外暴露供用户调用的寄存器访问 API。 | **需要派生扩展**，用于搭建完整的 RAL 结构。                  |
| **`uvm_map`**         | 寻址与通信桥梁 | 负责 **分配物理地址**；关联 `sequencer` 和 `adapter`，作为 RAL 模型与物理总线之间的转换枢纽。 | 供 UVM 内部底层机制使用，实现抽象读写到物理 transaction 的转换。 |

#### `uvm_reg_field` 核心状态属性解析

- **`value`（硬件实际值）**
  - **定义**：DUT 中物理寄存器 **当前真实的数值**
  - **说明**：它存在于真实的硬件代码（RTL）中，RAL 模型的终极目标就是去 **控制（写）和反映（读）** 这个真实值
- **`m_desired`（期望值）**
  - **定义**：验证环境 **希望** 该寄存器域被配置成的值
  - **操作流**：当在测试用例中调用 `set()` 方法时，仅仅是更新了 RAL 模型内部的 `m_desired` 值，**并不会立即触发对硬件的总线操作**
  - **作用**：它相当于一个“草稿”。你可以对多个 field 进行 `set()` 操作修改期望值，最后统一调用 `update()` 方法，RAL 会对比 `m_desired` 和 `m_mirrored`，只把那些发生了变化的值通过总线写入到真实的硬件 `value` 中
- **`m_mirrored`（镜像值）**
  - **定义**：RAL 模型对硬件实际值（`value`）的 **本地快照或预测**
  - **操作流**：当你对寄存器执行 `read()`、`write()` 或 `peek()`、`poke()` 操作成功后，UVM 机制会自动更新 `m_mirrored`，使其与硬件实际情况保持同步
  - **作用**：它代表了验证环境“认为”当前硬件处于什么状态。在很多 Check 中，我们可以直接读取镜像值来代替发起真实的硬件读操作，从而节省总线带宽

> [!tip] 
>
> 当调用 `write()` 时，流程大致是：**写入硬件的 `value` -> 同时更新 RAL 的 `m_desired` -> 同时更新 RAL 的 `m_mirrored`**。三者在写入成功后 **保持一致**。`read()` 同理

#### 寄存器的访问方式

针对实际中可能会存在的寄存器访问模式，UVM RAL 自定义了 **25 种** 的访问模式，包括 `RO`、`RW`、`WC` 等等

### RAL 的 API

#### 真实硬件读写（模拟行为）

> [!note]
>
> **模拟行为**：**操作是否会产生真实的硬件交互（即总线上的读写动作），并让 RAL 模型和硬件保持一致**。不仅仅是 **访问寄存器的方式**，而是区分“真实硬件交互” 与 “纯模型操作/后门直改”

这类操作会产生 **真实的存取动作**，常用于常规的验证流程。

- **`write` (写)**：通过前门或后门向 **DUT 写入值**。**会模拟寄存器的真实行为**，写完后会根据模拟结果同步更新 RAL 模型中的 **期望值** 和 **镜像值**。
- **`read` (读)**：通过前门或后门读取 **DUT 的值**。同样 **会模拟真实行为**，读完后用真实值更新模型里的 **期望值** 和 **镜像值**。

```systemverilog
// RAL write原型（read的参数列表与write完全相同），通常只配置前3个参数
virtual task write(
    output uvm_status_e        status,
    input  uvm_reg_data_t      value,
    input  uvm_path_e          path = UVM_DEFAULT_PATH,
    input  uvm_reg_map         map = null,
    input  uvm_sequence_base   parent = null,
    input  int                 prior = -1,
    input  uvm_object          extension = null,
    input  string              fname = "",
    input  int                 lineno = 0
);
```

```systemverilog
// case
class my_scoreboard extends uvm_scoreboard;
    // ...
    reg_model_c reg_model;
    // ...
    virtual task run_phase(uvm_phase phase);
        uvm_status_e   status;
        uvm_reg_data_t value;
        // ...
        forever begin
            // ...
            reg_model.config_reg.write(status, value, UVM_FRONTDOOR);
            // ...
            reg_model.mode_reg.read(status, value, UVM_FRONTDOOR);
            // ...
        end
        // ...
    endtask
endclass
```

#### 后门潜入读写（不模拟行为）

这类操作不会 **模拟行为**，速度 **快**，常用于快速初始化或隐蔽检查。

- **`poke` (潜入写)**：类似 `write` 的 **后门** 操作，但 **不模拟硬件行为**。直接把值写进 DUT，并顺便更新期望值和镜像值。
- **`peek` (潜入读)**：类似 `read` 的 **后门** 操作，**不模拟硬件行为**。直接读 DUT 里的值，并同步更新到期望值和镜像值。

```systemverilog
// RAL poke原型（peek的参数列表与poke完全相同），通常只配置前3个参数
virtual task poke(
    output uvm_status_e        status,
    input  uvm_reg_data_t      value,
    input  string              kind = "",
    input  uvm_sequence_base   parent = null,
    input  uvm_object          extension = null,
    input  string              fname = "",
    input  int                 lineno = 0
);
```

#### 本地模型操作（零总线消耗）

这类操作 **完全不会触碰 DUT 硬件**，仅仅在验证环境的软件模型（RAL Tree）内部打转。

- **`set` (设置)**：手动设定一个目标值，**只改变期望值 (desired)**。
- **`get` (获取)**：**仅获取期望值**。
- **`randomize` (随机化)**：针对寄存器生成一个随机值，并 **只赋给期望值**。

#### 模型与硬件同步（状态对齐）

这两者是用来在“软件模型”和“真实硬件”之间“对账”的。

- **`update` (模型 -> 硬件)**：**以期望值为准**。它会检查期望值和镜像值是否一致，如果不一致（说明模型里存了新配置还没发下去），就把 **期望值写入 DUT**，并把 **镜像值也更新** 了。
- **`mirror` (硬件 -> 模型)**：**以硬件真实值为准**。**强制从 DUT 读一次** 当前的真实内部值，然后拿这个真实值回来，把模型里的 **期望值和镜像值都刷新** 一遍。

```systemverilog
virtual task update(	// 通常只配置status参数
    output uvm_status_e        status,
    input  uvm_path_e          path = UVM_DEFAULT_PATH,
    input  uvm_reg_map         map = null,
    input  uvm_sequence_base   parent = null,
    input  int                 prior = -1,
    input  string              fname = "",
    input  int                 lineno = 0
);
```

```systemverilog
virtual task update(
    output uvm_status_e        status,
    input  uvm_check_e		   check = UVM_NO_CHECK,	// 默认不检查
    input  uvm_path_e          path = UVM_DEFAULT_PATH,
    input  uvm_reg_map         map = null,
    input  uvm_sequence_base   parent = null,
    input  int                 prior = -1,
    input  uvm_object          extension = null,
    input  string              fname = "",
    input  int                 lineno = 0
);
```

### 带 predictor 的 RAL 结构

![ral_flow2](./UVM_overview3.assets/ral_flow2.png)

```systemverilog
class my_environment extends uvm_env;
    // ...
    reg_model_c                             reg_model;
    my_adapter                              reg_adapter;
    my_adapter                              reg_adapter_m;
    uvm_reg_predictor #(cpu_trans)          reg_predictor;
    // ...
    virtual function void build_phase(uvm_phase phase);
        // ...
        ref_model = my_reference_model::type_id::create("ref_model", this);
        reg_model = reg_model_c::type_id::create("reg_model", this);
        reg_model.configure(null, "tb.dut");
        reg_model.build();
        reg_model.lock();
        reg_model.reset();

        reg_adapter = my_adapter::type_id::create("reg_adapter", this);
        reg_adapter_m = my_adapter::type_id::create("reg_adapter_m", this);
        reg_predictor = new("reg_predictor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        // ...
        reg_predictor.map     = reg_model.default_map;
        reg_predictor.adapter = reg_adapter_m;
        agent.monitor.analysis_port.connect(reg_predictor.bus_in);
    endfunction
endclass
```

### 内建寄存器 sequences 与 coverage

- **基于寄存器模型** 的自动测试的 **sequences 库**（`uvm_reg_hw_reset_seq`、`uvm_reg_single_bit bash_seq`、`uvm_reg_bit_bash_seq`...）
  - 这些 sequences 可以对 DUT 中的寄存器和存储器进行基本的测试
  - 包括检查寄存器的复位值是否正确、读写数据路径是否正常工作等（转换/检查每一位/前门和后门访问模式/存储器活动）
  
- RAL **内建的 coverage** 可实现寄存器测试的覆盖率统计，有三种方法为 RAL 添加 coverage 属性
  - 在 RAL 构造函数加入 coverage 选项
  
    ```systemverilog
    class mode_reg_c extends uvm_reg
        // ...
        function new(string name = "mode_reg_c")
            super.new(name, 8, UVM_CVR_ALL);
        endfunction
    endclass
    ```
  
  - 使用 `uvm_reg::include_coverage`(" 寄存器”，coverage 选项)
  
    ```systemverilog
    uvm_reg::include_coverage("*", UVM_CVR_REG_BITS + UVM_CVR_FIELD_VALS)
    ```
  
  - 使用 `uvm_reg_block/reg/mem.set_coverage`(coverage 选项)
  
    ```systemverilog
    uvm_reg_block.set_coverage(UVM_CVR_ALL)
    ```
  
  | UVM 选项              | 描述                                 |
  | -------------------- | ------------------------------------ |
  | `UVM_NO_COVERAGE`    | 不进行 coverage 统计                   |
  | `UVM_CVR_REG_BITS`   | 对寄存器的每一位进行读写统计         |
  | `UVM_CVR_ADDR_MAP`   | 对地址映射中的每一个地址进行读写统计 |
  | `UVM_CVR_FIELD_VALS` | 统计域的值                           |
  | `UVM_CVR_ALL`        | 统计所有的覆盖率                     |

## 覆盖率驱动验证 (CDV) 与 SVA（后续补充）

### 覆盖率驱动验证 (CDV) 与功能覆盖率

**理论核心：**

CDV（Coverage-Driven Verification）是一种闭环的验证思想：**制定验证计划 -> 随机发包跑测试 -> 收集覆盖率 -> 分析盲区 -> 修改约束再跑 -> 直到覆盖率达标。**

覆盖率主要分两种：

1. **代码覆盖率（Code Coverage）：** 仿真器自动收集的（比如行覆盖、翻转覆盖、状态机覆盖）。它只能证明代码被执行了，不能证明功能是对的。
2. **功能覆盖率（Functional Coverage）：** 验证工程师 **手写** 的。用来证明“特定的业务场景”是否被测试到了。

**实战用法（在 UVM 中收集功能覆盖率）：**

通常会单独写一个继承自 `uvm_subscriber` 的组件（类似于 Scoreboard，通过 Analysis Port 接收 Monitor 抓到的数据），专门负责采样覆盖率。

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;

// 定义一个专门收集 AXI 事务覆盖率的组件
class axi_cov_collector extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axi_cov_collector)

    // 声明一个事务句柄，用于在 covergroup 中被引用
    axi_transaction tr;

    // 1. 定义 Covergroup (覆盖率组)
    covergroup cg_axi_burst;
        // 覆盖点 1：检查 burst 类型是否都被测到
        cp_burst: coverpoint tr.burst {
            bins fixed = {2'b00};
            bins incr  = {2'b01};
            bins wrap  = {2'b10};
        }
        
        // 覆盖点 2：检查 burst 长度
        cp_len: coverpoint tr.len {
            bins short_burst = {[0:3]};
            bins long_burst  = {[4:15]};
            // 忽略非法的过长突发（假设当前不支持）
            ignore_bins invalid_len = {[16:255]}; 
        }

        // 交叉覆盖：只有当所有 burst 类型都以各种长度发送过，才算 100% 覆盖
        cross_burst_len: cross cp_burst, cp_len;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        // 2. 必须在 new 函数中实例化 covergroup
        cg_axi_burst = new();
    endfunction

    // 3. 实现 write 函数（通过 Analysis Port 自动被 Monitor 调用）
    virtual function void write(axi_transaction t);
        this.tr = t;
        // 4. 每次收到新的 transaction，调用 sample() 进行采样
        cg_axi_burst.sample();
    endfunction
endclass
```

### SystemVerilog Assertion (SVA) 与 UVM 的结合

**理论核心：**

- **Scoreboard 检查“数据”：** 算出来的结果对不对。
- **SVA 检查“时序”：** 信号跳变的顺序对不对。

在验证具有 outstanding、乱序特性的总线时，时序关系错综复杂。如果用传统的 Verilog 写状态机去检查握手协议，代码会极其臃肿。SVA 提供了一种声明式的语法，专门用来描述跨越多个时钟周期的复杂时序逻辑。

**实战用法（将 SVA 嵌入 Interface）：**

SVA 必须能够 **直接访问物理信号和时钟**，因此在 UVM 架构中，**SVA 几乎总是直接写在物理 `interface` 内部**，而不是写在 UVM 的 class 里。你可以利用 `import uvm_pkg::*;` 让 SVA 报错时直接调用 UVM 的信息服务机制。

```systemverilog
interface axi_if(input clk, input rst_n);
    import uvm_pkg::*; // 引入 UVM 宏，以便使用 `uvm_error

    logic awvalid;
    logic awready;
    logic [31:0] awaddr;

    // ---------------------------------------------------------
    // SVA 规则定义区
    // ---------------------------------------------------------

    // 规则 1：经典的握手保持原则
    // 如果 AWVALID 拉高，且 AWREADY 没拉高，那么在下一个时钟周期，AWVALID 必须保持为高
    property p_awvalid_hold;
        @(posedge clk) disable iff(!rst_n) // 指定时钟和复位条件
        (awvalid && !awready) |=> awvalid;  // |=> 表示“在下一个时钟周期”
    endproperty
    // 规则 2：AWVALID 保持期间，地址不允许改变
    property p_awaddr_stable;
        @(posedge clk) disable iff(!rst_n)
        (awvalid && !awready) |=> $stable(awaddr); // $stable 检查值是否未改变
    endproperty

    // ---------------------------------------------------------
    // SVA 断言执行区 (assert)
    // ---------------------------------------------------------
    
    // 断言属性，并在失败时通过 UVM 机制报错
    assert_awvalid_hold: assert property(p_awvalid_hold)
        else `uvm_error("SVA_ERR", "Protocol violation: AWVALID dropped before AWREADY!")
    assert_awaddr_stable: assert property(p_awaddr_stable)
        else `uvm_error("SVA_ERR", "Protocol violation: AWADDR changed while waiting for AWREADY!")

endinterface
```

## Reference Model 与 DPI-C（C/C++ 模型接入）

在面对复杂的算法 IP 或多级流水线的微处理器时，工业界的标准做法是：**硬件 RTL 由数字前端团队用 Verilog 写，而“标准答案”则由架构团队用 C/C++ 写（也就是指令集模拟器 ISS，例如 Spike 或 Whisper）**。验证工程师的任务就是用 **DPI-C** 把这两者缝合起来。

> [!tip]
>
> 引入 DPI-C 后，你的 UVM 环境就变成了：**SystemVerilog 负责在前面跟 RTL 拼时序、发激励、抓波形，而 C/C++ 在后面算核心算法。** 两者分工明确，是现代高端芯片验证的唯一解。
>
> 一旦涉及到 C 代码的加入，你原先使用 VCS 编译 `.sv` 文件的命令就需要加上 **编译 `.c` 文件** 的环节。

### DPI-C 理论核心总结

**DPI-C (Direct Programming Interface)** 是 SystemVerilog 提供的一种标准接口机制，让 SV 和 C/C++ 能够像在同一个语言里一样互相调用函数。

1. **核心方向：`import` 与 `export`**
   - **`import` (SV 调用 C)：** 最常用的场景。UVM 环境抓到了总线上的激励，把它传给 C 模型算出一个期望值，然后再拿回来给 Scoreboard 比对。
   - **`export` (C 调用 SV)：** 较少用。通常是 C 模型执行到某个特殊状态时，反向调用 SV 去触发一个硬件中断。
2. **数据类型映射（避坑指南）**
   - C 和 SV 的数据类型在底层内存排布上并不完全一致。
   - **工业界铁律：** 尽量只在 DPI 接口上传递最基本的数据类型！用 SV 的 `int` 对应 C 的 `int`，SV 的 `byte` 对应 C 的 `char`。
   - **坚决不要：** 试图直接在 DPI 接口上传递复杂的 SV `class` 或带时间概念的逻辑类型（四值逻辑 `logic` 传到 C 里处理起来非常繁琐，通常在 SV 侧强制转为 `bit` 或 `int` 再传）。

### 如何用 DPI-C 接入 C 语言 ISS

假设你现在需要给处理器写一个 Reference Model。UVM 已经通过 Monitor 抓到了输入的一条 32 位机器码（Instruction），现在我们要把它扔给 C 语言写的 ISS 去执行，并获取它期望写入的目标寄存器索引（reg_idx）和写入的数据（reg_data）。

#### C 语言侧：准备好“标准答案生成器” (iss_model.c)

用 C 写好业务逻辑，注意函数不需要特殊的修饰符，正常写即可。如果是指针参数，在 SV 侧会被映射为 `output` 或 `inout`。

```c
#include "svdpi.h" // 包含 DPI 标准头文件

// C 语言侧的 ISS 步进函数 (接收指令，输出期望的寄存器状态)
void c_iss_step(int inst, int* reg_idx, int* reg_data) {
    // 假设这里是极其复杂的 C++ 解码和执行逻辑...
    // 简单模拟：假设解码出需要将数据 0x12345678 写回 x1 寄存器
    
    *reg_idx = 1;               // 对应 RISC-V 的 x1 寄存器
    *reg_data = 0x12345678;     // 期望写回的数据
}
```

#### SystemVerilog 侧：导入 C 函数并在 UVM 中调用 (riscv_ref_model.sv)

在 UVM 的 Reference Model 中，使用 `import` 声明这个 C 函数，然后就可以像调用 SV 原生函数一样去调用它。

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;

// 1. 核心语法：导入 C 函数
// input 对应 C 的按值传递，output 对应 C 的指针传递
import "DPI-C" context function void c_iss_step(input int inst, output int reg_idx, output int reg_data);

class riscv_ref_model extends uvm_component;
    `uvm_component_utils(riscv_ref_model)

    // 定义接收 Monitor 数据的端口，以及发送给 Scoreboard 的端口
    uvm_blocking_get_port #(riscv_transaction) m2r_port;
    uvm_analysis_port #(riscv_transaction)     ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m2r_port = new("m2r_port", this);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        riscv_transaction tr_in, tr_exp;
        int expected_idx, expected_data;

        forever begin
            // 2. 从 Monitor 获取当前周期的输入指令
            m2r_port.get(tr_in);
            
            // 3. 【DPI-C 魔法时刻】调用 C 模型！
            // 把 SV 抓到的机器码 tr_in.inst 传给 C 函数，C 函数把结果填入后面两个变量
            c_iss_step(tr_in.inst, expected_idx, expected_data);
            
            // 4. 将 C 模型算出的期望值，打包成 Transaction 准备送给 Scoreboard
            tr_exp = riscv_transaction::type_id::create("tr_exp");
            tr_exp.reg_idx  = expected_idx;
            tr_exp.reg_data = expected_data;
            
            // 5. 通过 Analysis Port 发送给 Scoreboard 进行比对
            ap.write(tr_exp);
        end
    endtask
endclass
```

## UVM callback（后续补充）

> **实际应用场景：** 一般在开发通用的验证 IP (VIP) 时用得最多。如果你只是 **使用** 环境，可能不常去定义 Callback；但如果你要 **维护或二次开发**一个大型的成熟平台，理解 Callback 机制能让你在不破坏底层架构的前提下“见缝插针”地注入错误（Error Injection）或修改数据。建议初期先理解概念，知道怎么调即可。

