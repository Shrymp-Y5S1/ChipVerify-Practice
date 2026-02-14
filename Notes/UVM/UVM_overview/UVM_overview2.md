# UVM overview2

## UVM 信息服务机制

UVM 的信息机制在打印追踪信息具有比 `$display` 更好的优势：

- 可显示打印信息在测试平台中的位置
- 可以通过层次、可视化等级和时间等选项对打印信息进行过滤

如``uvm_info`可打印报告类型、代码位置、仿真时间、打印信息来源对象全路径、信息 ID、打印信息

```systemverilog
`uvm_info("SCB_WR", $sformatf("Memory Updated for Addr=%0h (Burst Len=%0d)", aw_tr.addr, aw_tr.len+1), UVM_MEDIUM)
// 3个参数: ID、打印信息、可视化等级
```

```log
UVM_INFO ./verify/axi_scoreboard.sv(165) @ 310000: uvm_test_top.env.scb [SCB_WR] Memory Updated for Addr=85ec (Burst Len=7)
```

| **安全等级**    | **默认执行的行为**          | **行为描述**                                   |
| --------------- | --------------------------- | ---------------------------------------------- |
| **UVM_FATAL**   | `UVM_DISPLAY` + `UVM_EXIT`  | 打印信息并 **直接退出** 仿真。                   |
| **UVM_ERROR**   | `UVM_DISPLAY` + `UVM_COUNT` | 打印信息并 **累加错误计数**（计数达标则退出）。 |
| **UVM_WARNING** | `UVM_DISPLAY`               | 仅在终端 **打印相关信息**。                     |
| **UVM_INFO**    | `UVM_DISPLAY`               | 仅在终端 **打印相关信息**。                     |

```systemverilog
`uvm_fatal("ID", "Message")
`uvm_error("ID", "Message")
`uvm_warning("ID", "Message")
`uvm_info("ID", "Message", "verbosity")
// verbosity: UVM_LOW、UVM_MEDIUM、UVM_HIGH、UVM_FULL、UVM_DEBUG
// 从左到右等级越高，越易被屏蔽
```

`uvm_fatal`、`uvm_error` 和 `uvm_warning` 的打印信息 **总是会显示**，无可视化等级

`uvm_info` 的打印信息可根据 **可视化等级** 的不同显示或者不显示，在运行仿真时，需要指定信息可视等级，在仿真命令行中加入：

```systemverilog
+UVM_VERBOSITY = UVM_*
```

如果没有指定，则默认值为 `UVM_MEDIUM`。可视等级 **大于** 它的信息将会 **被过滤** 而不被显示

可以通过在仿真命令中加入 `UVM_VERBOSITY` 进行 **全局设定**，也可以通过函数来为单个 **component** 或者 **层次** 进行设置：

```systemverilog
set_report_verbosity_level(verbosity);
set_report_verbosity_level_hier(verbosity);
```

用户可以在 **test** 中更改信息机制的默认行为

在 `start_of_simulation phase` 中

```systemverilog
set_report_severity_action(severity, action)	// 覆盖最广，优先级最低
set_report_id_action(ID, action)
set_report_severity_id_action(severity, ID, action)//覆盖最小，优先级最高 
// example
set_report_severity_action(UVM_INFO, UVM_NO_ACTION)
set_report_id_action("DRV_RUN_PHASE", UVM_DISPLAY)
set_report_severity_id_action(UVM_INFO,"MON_RUN_PHASE", UVM_EXIT)
```

更复杂自定义信息设置不再赘述

在 log 的最后通常会根据 **安全等级与 ID** 进行总结报告，类似如下

```shell
--- UVM Report Summary ---

** Report counts by severity
UVM_INFO : 1005
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0
** Report counts by id
[RNTST]     1
[SCB_PASS]   476
[SCB_WR]   524
[SEQ]     2
[TEST_DONE]     1
[TOPO]     1
```

## UVM configuration 机制

### 基本概念

一个强大的属性配置工具：传递值、传递对象、传递 interface

如使用 **uvm_config** 机制配置 **agent_sequencer** 的 **default_sequence**

```systemverilog
uvm_config_db#(uvm_object_wrapper)::set(this, "*.my_seqr.run_phase", "default_sequence", my_sequence::get_type());
```

**特点**：

- **半个全局变量**，避免全局变量带来的风险
- 高层组件可以通过 configuration 机制实现在 **不改变代码的情况下更改它所包含子组件的变量**
- 在 **各个层次上都可以使用** configuration 机制
- 支持 **通配符和正则表达式** 对多个变量进行配置
- 支持 **用户自定义的数据类型**
- 可以在 **仿真运行的过程中** 进行配置

**原理**： **先存后取**

- **存**：把配置项放入 **资源池**
- **取**：通过 **路径和 ID** 在资源池中检索并应用

- **UVM 资源池** 存放了配置资源，每条配置包含以下信息：

  - **资源源**：配置的来源对象（如 `uvm_top`、`uvm_test_top`、`m_env` 等）

  - **配置路径**：资源在层次结构中的路径（如 `.m_seq`、`.m_agent`）

  - **资源类型**：可以是 `int`、`string`、`uvm_object`、`uvm_component` 等

  - **资源 ID**：资源的标识符（如 `"num"`、`"massage"`、`"m_config"`）

  - **资源值**：具体的配置值（如 `20`、`"config"`、`m_config`、`m_comp`）

### 使用方法

配置平台 **步骤**：

- **定义** 控制变量或控制对象
- 在使用这些控制变量或对象前，使用 `uvm_config_db#(type)::get` 从高层获取配置
- 使用这些控制变量或对象 **配置平台或控制行为**
- 在高层使用 `uvm_config_db#(type):set` 配置这些控制变量或对象

```systemverilog
// set() 设置配置资源
uvm_config_db#(type)::set(				// 资源类型
        uvm_component cntxt,			// 设置该配置资源的源平台组件
    	string        instance_name,	// 该配置资源的目标对象所属组件(路径)
        string        field_name,		// 该配置资源的ID
        T             value				// 资源值
                        );

// get() 获取配置资源
uvm_config_db#(type)::get(
        uvm_component cntxt,			// 获取配置资源的源组件
    	string        instance_name,	// 该配置资源的目标对象所属组件(路径)
        string        field_name,		// 该配置资源的ID
        inout T       variable			// 目标变量或对象
                        );
```

**例 1**：配置 sequence 产生 transaction 的数量

```systemverilog
class my_test extends uvm_test;
    // ...
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // ...
        // 在build_phase中设置配置项，使用uvm_config_db将item_num的值设置为20，这样在my_sequence的pre_randomize方法中就会从uvm_config_db获取这个值，并使用它来控制生成事务的数量
        uvm_config_db#(int)::set(this, "*.my_seqr", "item_num", 20);
    endfunction
    // ...
endclass

// ----------------------------------------

class my_sequence extends uvm_sequence #(my_transaction);
    int item_num = 10;

    function void pre_randomize();
        // 通过前3个参数查找资源，找到则赋值给item_num，否则语句无效
        uvm_config_db#(int)::get(my_seqr, "", "item_num", item_num);
    endfunction

    virtual task body();
        // ...
        repeat (item_num) begin
            // ...
        end
        // ...
    endtask
endclass
```

**例 2**：配置 interface

- 首先需要根据 DUT 构建 **interface**

  ```systemverilog
  interface dut_interface (
      input bit clk
  );
      logic        rst_n;
      // ...
      clocking driver_cb @(posedge clk);
          default input #1 output #0;// 默认输入延迟为1周期，输出无延迟
          output rst_n;  // 方向：Driver -> 输出 -> DUT
          // ...
          input busy_n;  // 方向：DUT -> 输入 -> Driver (Driver 只能读取/等待这个信号)
      endclocking
      // ...
      // 驱动modport，指定driver_cb时钟域中的rst_n信号为输出
      modport driver(clocking driver_cb, output rst_n);
          // ...
  endinterface
  ```

- 为 my_driver 添加 **virtual interface** 和驱动 DUT

  ```systemverilog
  class my_driver extends uvm_driver #(my_transaction);
      // ...
      virtual dut_interface my_vif;
  	// ...
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif);
      endfunction
  
      virtual task reset_phase(uvm_phase phase);
          super.reset_phase(phase);
          phase.raise_objection(this);
          my_vif.driver_cb.frame_n <= '1;
          // ...
          repeat (5) @(my_vif.driver_cb);
          my_vif.driver_cb.rst_n <= '0;
          // ...
          phase.drop_objection(this);
      endtask
  
      virtual task run_phase(uvm_phase phase);
          logic [7:0] temp;
          repeat (15) @(my_vif.driver_cb);
          forever begin
              seq_item_port.get_next_item(req);
              // ...
              foreach (req.payload[index]) begin
                  temp = req.payload[index];
                  for (int i = 0; i < 8; i++) begin
                      // ...
                      my_vif.driver_cb.frame_n[req.sa] <= ((req.payload.size() - 1) == index) && (i == 7);
                      @(my_vif.driver_cb);
                  end
              end
              my_vif.driver_cb.valid_n[req.sa] <= 1'b1;
              seq_item_port.item_done();
          end
      endtask
  endclass
  ```

- **实例化 DUT**

  ```systemverilog
  module tb_top;
      bit sys_clk;
      dut_interface if0 (sys_clk);
      router dut (
          .clk     (if0.clk),
          .rst_n   (if0.rst_n),
          .din     (if0.din),
          // ...
      );
      // ...
      initial begin
          uvm_config_db#(virtual dut_interface)::set(null, "*.my_agent.*", "vif");
          run_test();
      end
  endmodule
  ```

**例 3**：配置用户 **自定义的 config 类**

> [!tip]
>
> **使用 class** 将需要配置的变量与接口 **打包在一起**，通过配置对象快速准确配置

- 可配置属性是平台重用性实现一种方法
- 将对同一个组件的所有配置项打包成一个配置对象(class)
- 将配置对象作为一个整体进行配置

<img src="./UVM_overview2.assets/config_class_flow.png" alt="config_class_flow" style="zoom: 22%;" />

```systemverilog
// 从顶至底，配置对象不断被分解，并被使用在需要的地方
module tb_top
    uvm_config_db#(virtual dut_interface)::set(null, "uvm_test_top", "top_if", if0);
endmodule

// ----------------------------------------
class my_test extends uvm_test;
    uvm_config_db#(virtual dut_interface)::get(this, "", "top_if", my_env_config.my_agent_config.my_vif);

    uvm_config_db#(env_config)::set(this, "my_env", "env_config", my_env_config);
endclass

// ----------------------------------------
class my_environment extends uvm_env;
    uvm_config_db#(agent_config)::set(this, "my_agent", "my_agent_config", my_env_config.my_agent_config);
endclass

// ----------------------------------------
class master_agent extends uvm_agent;
    uvm_config_db#(agent_config)::get(this, "", "my_agent_config", my_agent_config);

    uvm_config_db#(int unsigned)::set(this, "my_driv", "pad_cycles", my_agent_config.pad_cycles);
    uvm_config_db#(virtual dut_interface)::set(this, "my_driv", "vif", my_agent_config.my_vif);
    uvm_config_db#(virtual dut_interface)::set(this, "my_moni", "vif", my_agent_config.my_vif);

endclass

// ----------------------------------------
class my_driver extends uvm_driver #(my_transaction);
    virtual dut_interface my_vif;
    uvm_config_db#(int unsigned)::get(this, "", "pad_cycles", pad_cycles);
    uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif);
endclass


class my_monitor extends uvm_monitor;
    virtual dut_interface my_vif;
    uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif);
endclass
```

> [!note]
>
> **1.顶层 test 设置配置对象**
>
> - 在 test 中创建并初始化 `m_env_cfg`（环境配置对象），其中包含一些全局开关和子配置对象，例如：
>   - `is_coverage=0`
>   - `is_check=0`
>   - `m_agent_cfg`（代理配置对象）
>
> **2.环境层 env 使用配置对象**
>
> - **m_env** 接收并持有 `m_env_cfg`，作为环境的统一配置入口
> - `env_config` 中包含了对 agent 的配置对象 `m_agent_cfg`，用于进一步传递
>
> **3.agent 层配置传递**
>
> - m_agent 内部持有 `m_agent_cfg`，其中定义了：
>   - `is_active=UVM_ACTIVE`（代理是否激活）
>   - `pad_cycles=5`（驱动器的等待周期）
>   - `virtual dut_interface m_vif`（虚拟接口句柄）
>
> **4.子组件获取配置**
>
> - **m_driver**：通过 `m_agent_cfg` 获取 `pad_cycles` 和 `m_vif`
> - **m_monitor**：通过 `m_agent_cfg` 获取 `m_vif`
> - **m_sequencer**：同样由 agent 配置驱动
>
> **5.配置传递逻辑**
>
> - 配置对象在 **test → env → agent → driver/monitor/sequencer** 的层次结构中逐级传递
> - 每个组件通过 `uvm_config_db` 或资源池机制获取对应的配置对象
> - 这样保证了配置的集中管理与灵活传递，避免硬编码

- 创建 **agent_config** 类

  ```systemverilog
  class agent_config extends uvm_object;
      uvm_active_passive_enum is_active = UVM_ACTIVE;
      int unsigned pad_cycles = 5;
      virtual dut_interface my_vif;
  
      `uvm_object_utils_begin(agent_config)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
      `uvm_field_int(pad_cycles, UVM_ALL_ON)
      `uvm_object_utils_end
  
      function new(string name = "agent_config");
          super.new(name);
      endfunction
  endclass
  ```

- 创建 **env_config** 类

  ```systemverilog
  class env_config extends uvm_object;
    int is_coverage = 0;
    int is_check = 0;
    agent_config my_agent_config;
  
    `uvm_object_utils_begin(env_config)
      `uvm_field_int(is_coverage, UVM_ALL_ON)
      `uvm_field_int(is_check, UVM_ALL_ON)
      `uvm_field_object(my_agent_config, UVM_ALL_ON)
    `uvm_object_utils_end
  
    function new(string name = "env_config");
      super.new(name);
      my_agent_config = agent_config::type_id::create("my_agent_config");
    endfunction
  endclass
  ```

- **向 my_test 中添加 env_config**，并将该配置对象配置给 env

  ```systemverilog
  class my_test extends uvm_test;
    // ...
    env_config my_env_config;
  
    function new(string name = "my_test", uvm_component parent);
      super.new(name, parent);
      my_env_config = env_config::type_id::create("my_env_config");
    endfunction
  
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      //...
      my_env_config.is_coverage                = 1;
      my_env_config.is_check                   = 1;
      my_env_config.my_agent_config.is_active  = UVM_ACTIVE;
      my_env_config.my_agent_config.pad_cycles = 10;
      if (!uvm_config_db#(virtual dut_interface)::get(this, "", "top_if", my_env_config.my_agent_config.my_vif)) begin
        `uvm_fatal("CONFIG_ERROR", "...")
      end
  
      uvm_config_db#(env_config)::set(this, "my_env", "env_config", my_env_config);
    endfunction
  endclass
  ```

- **在 env 添加配置项，从 testcase 获取配置**，再将 **使用该对象配置 agent**

  ```systemverilog
  class my_environment extends uvm_env;
      // ...
      master_agent my_agent;
      env_config   my_env_config;
      // ...
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          if (!uvm_config_db#(env_config)::get(this, "", "env_config", my_env_config)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
          uvm_config_db#(agent_config)::set(this, "my_agent", "my_agent_config", my_env_config.my_agent_config);
  
          if (my_env_config.is_coverage) begin
              `uvm_info("COVERAGE_ENABLE", "...", UVM_LOW)
          end
          if (my_env_config.is_check) begin
              `uvm_info("CHECK_ENABLE", "...", UVM_LOW)
          end
          // ...
      endfunction
  endclass
  ```

- **在 agent 中添加配置项**，**从 env 获取配置**，并且 **使用该配置项配置 driver**

  ```systemverilog
  class master_agent extends uvm_agent;
      // ...
      agent_config my_agent_config;
      // ...
      virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          if (!uvm_config_db#(agent_config)::get(this, "", "my_agent_config", my_agent_config)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
          is_active = my_agent_config.is_active;
  
          uvm_config_db#(int unsigned)::set(this, "my_driv", "pad_cycles", my_agent_config.pad_cycles);
          uvm_config_db#(virtual dut_interface)::set(this, "my_driv", "vif", my_agent_config.my_vif);
          if (is_active == UVM_ACTIVE) begin
              // ...
          end
          // ...
      endfunction
      // ...
  endclass
  ```

- **driver 从上层获取配置信息**

  ```systemverilog
  class my_driver extends uvm_driver #(my_transaction);
      // ...
      virtual dut_interface my_vif;
      int unsigned pad_cycles;
      // ...
      virtual function void build_phase(uvm_phase phase);
          if (!uvm_config_db#(int unsigned)::get(this, "", "pad_cycles", pad_cycles)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
          if (!uvm_config_db#(virtual dut_interface)::get(this, "", "vif", my_vif)) begin
              `uvm_fatal("CONFIG_FATAL", "...")
          end
      endfunction
      // ...
      virtual task run_phase(uvm_phase phase);
          // ...
          repeat (pad_cycles) @(my_vif.driver_cb);
          // ...    
      endtask
      // ...
  endclass
  ```

- 在 **顶层配置 virtual interface**

  ```systemverilog
  module tb_top;
    dut_interface if0 (sys_clk);
    router dut (
        .clk     (if0.clk),
        .rst_n   (if0.rst_n),
        .din     (if0.din),
        // ...
    );
    initial begin
        uvm_config_db#(virtual dut_interface)::set(null, "uvm_test_top", "top_if", if0);
      run_test();
    end
  endmodule
  ```

## UVM sequence 机制

