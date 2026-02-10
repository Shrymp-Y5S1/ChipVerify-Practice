# Digital IC Design & Verification Lab

这是一个综合性的数字 IC 设计与验证演练库，内容涵盖从基础 Verilog 模块（逻辑、FSM、存储器）到 APB_UART、AXI 等较复杂总线设计，以及配套的 UVM 验证平台和相关理论笔记（AXI4、SV、UVM），并正在推进 RISC-V CPU 内核开发。本项目旨在通过从单元电路到系统级设计的实战，系统性地巩固数字 IC 设计与验证能力。

## 模块索引 (Module Index)

### Projects (工程练习)

- **APB UART** (基于 APB 总线的 UART):  [APB_UART](Project\APB_UART)
- **AXI**(AXI4 - Full):  [AXI](Project\AXI)
- **RISC-V**:  [RISC_V](Project\RISC_V)

### Notes (学习笔记)

- AXI4 Protocol: [Notes/AXI/AXI4.md](Notes/AXI/AXI4.md)
- SystemVerilog 验证测试平台编写指南（第二版）: [Notes/SV/HVL_SV.md](Notes/SV/HVL_SV.md)
- UVM实战: [Notes/UVM/UVM.md](Notes/UVM/UVM.md)

### Combinational (组合逻辑)

- **4x1 Multiplexer** (4选1多路选择器): [Combinational/4x1_Mux](Combinational/4x1_Mux)
- **Full Adder** (全加器): [Combinational/Full_Adder](Combinational/Full_Adder)
- **Priority Encoder** (优先编码器): [Combinational/Priority_Encoder](Combinational/Priority_Encoder)

### Sequential (时序逻辑)

- **D Flip-Flop** (D 触发器): [Sequentical/D_Flip_Flop](Sequentical/D_Flip_Flop)
- **Mod-N Counter** (模 N 计数器): [Sequentical/ModN_counter](Sequentical/ModN_counter)
- **N-bit Shift Register** (N 位移位寄存器): [Sequentical/n_shift_reg](Sequentical/n_shift_reg)

### FSM (有限状态机)

- **Sequence Detector** (序列检测器): [FSM/Seq_Detect](FSM/Seq_Detect)
- **Traffic Button Control** (交通灯控制): [FSM/Traffic_Button_Ctrl](FSM/Traffic_Button_Ctrl)

### Memory (存储器)

- **Async FIFO** (异步 FIFO): [Memory/Async_FIFO](Memory/Async_FIFO)
- **Single Port RAM** (单端口 RAM): [Memory/Single_Port_RAM](Memory/Single_Port_RAM)
- **Sync FIFO** (同步 FIFO): [Memory/Sync_FIFO](Memory/Sync_FIFO)

### Architecture (架构设计)

- **Async Reset Sync Release** (异步复位同步释放): [Architecture/Async_Rst_Sync_Rel](Architecture/Async_Rst_Sync_Rel)
- **Edge Detector** (边沿检测): [Architecture/Edge_Detector](Architecture/Edge_Detector)
- **Handshake Buffer** (握手缓冲): [Architecture/Handshake_Buffer](Architecture/Handshake_Buffer)
- **Pipeline Multiplier** (流水线乘法器): [Architecture/Pipeline_Mult](Architecture/Pipeline_Mult)
- **Pulse Synchronizer** (脉冲同步器): [Architecture/Pulse_Synchronizer](Architecture/Pulse_Synchronizer)
