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

## UVM callback（后续补充）

> **实际应用场景：** * 一般在开发通用的验证 IP (VIP) 时用得最多。如果你只是* *使用* *环境，可能不常去定义 Callback；但如果你要* *维护或二次开发**一个大型的成熟平台，理解 Callback 机制能让你在不破坏底层架构的前提下“见缝插针”地注入错误（Error Injection）或修改数据。建议初期先理解概念，知道怎么调即可。

## UVM advanced sequence（后续补充）

**Virtual Sequence 与 Virtual Sequencer：**

- 这是真正用来协调全局环境的“总指挥”。当系统里有多个不同类型的接口时（比如一边发正常数据，一边发控制指令或异常中断），你需要 Virtual Sequence 来调度底层不同 Agent 的 sequence 按照特定时间轴并发或串行执行。

**Sequence 的层级嵌套与 `start()` 方法：**

- 不要依赖隐式的随机，而是要学会在一个大的 Sequence 里面，手动实例化并 `start()` 其他小的 Sequence，像搭积木一样构造复杂的场景（比如针对流水线处理器发送特定依赖关系的指令流）。

**Sequence 的仲裁机制 (`lock` / `grab`)：**

- 学习当多个 sequence 同时想占用驱动器（Driver）时，如何通过设置优先级或强制抢占（grab）来模拟突发事件。

> 你的笔记已经构建了基础环境，但要应对真实复杂的数字 IC 验证项目（如完整的微处理器或复杂总线节点），以下理论是必须要补齐的：
>
> **1. RAL（寄存器抽象层）**
>
> - **现状：** 你目前的笔记中还没有包含 RAL 的内容。
> - **重要性：** 正如我们之前讨论的，面对海量的控制寄存器，必须掌握通过前门/后门访问的 RAL 模型。这是接轨企业级项目的基础设施。
>
> **2. Virtual Sequence 的代码落地**
>
> - **你的笔记：** 在 `UVM_overview3.md` 中以文字形式记录了 Virtual Sequence 是“总指挥”的概念。
> - **补充方向：** 理论上你需要知道，Virtual Sequence 本身是不产生数据包的，它里面包含的是各个底层 Agent 的 Sequencer 句柄（即 Virtual Sequencer）。你需要学习如何在一个大的 Virtual Sequence 的 `body()` 任务里，去分发、嵌套、协调底层的 Sequence。
>
> **3. Reference Model 与 DPI-C（C/C++ 模型接入）**
>
> - **你的笔记：** 记录了使用 SystemVerilog 编写 Reference Model 并通过 TLM 通信的逻辑。
> - **补充方向：** 在验证复杂的算法模块或 RISC-V 等处理器架构时，参考模型通常是 C/C++ 写的（比如指令集模拟器 ISS）。你需要补充 **DPI-C (Direct Programming Interface)** 的知识，学习如何让 UVM 环境（SystemVerilog）调用 C 语言的函数，实现联合仿真。
>
> **4. 覆盖率驱动验证 (CDV) 与 SVA**
>
> - **补充方向：** UVM 是一个平台，验证的最终验收标准是“覆盖率”。你需要补充如何在UVM中收集功能覆盖率（`covergroup`, `coverpoint`），以及如何将 SVA（SystemVerilog Assertions，断言）与 UVM 环境结合，去监控复杂的时序协议（比如 AXI4 的握手规则）。

