## makefile

```makefile
# 定义参数
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdb -lca -timescale=1ns/1ps -l comp.log
SIM_FLAGS = -l sim.log

# 默认目标
all: clean comp sim

# 编译
comp:
	vcs $(VCS_FLAGS) -f filelist.f -top tb_fxo_Mux -o simv

# 运行仿真
sim:
	./simv $(SIM_FLAGS)

# 查看波形
verdi:
	verdi -dbdir simv.daidir -ssf waveform.fsdb &

# 清理
clean:
	rm -rf simv* csrc verdiLog *.fsdb *.log ucli.key vc_hdrs.h novas*
```

这段内容其实是一个 **Makefile**，用来自动化 Verilog 仿真流程（基于 Synopsys VCS + Verdi）。我来逐行解释一下：

------

### 🛠 参数定义

```makefile
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdb -lca -timescale=1ns/1ps -l comp.log
SIM_FLAGS = -l sim.log
```

- **VCS_FLAGS**：编译时传给 VCS 的参数
  - `-full64`：启用 64 位编译
  - `-sverilog`：支持 SystemVerilog 语法
  - `-debug_access+all`：允许调试访问所有信号
  - `-kdb`：启用 kernel debug 数据库（配合 Verdi）
  - `-lca`：启用 license 兼容模式
  - `-timescale=1ns/1ps`：定义仿真时间单位和精度
  - `-l comp.log`：编译日志输出到 `comp.log`
- **SIM_FLAGS**：运行仿真时的参数
  - `-l sim.log`：仿真日志输出到 `sim.log`

------

### 📑 默认目标

```makefile
all: clean comp sim
```

- 默认执行顺序：先清理 → 编译 → 仿真。

------

### ⚙️ 编译

```makefile
comp:
    vcs $(VCS_FLAGS) -f filelist.f -top tb_fxo_Mux1 -o simv
```

- 调用 **VCS 编译器**
- `-f filelist.f`：指定文件列表（里面列出所有要编译的 Verilog 文件）
- `-top tb_fxo_Mux1`：指定顶层 testbench 模块
- `-o simv`：生成可执行仿真文件 `simv`

------

### ▶️ 运行仿真

```makefile
sim:
    ./simv $(SIM_FLAGS)
```

- 执行编译好的仿真程序 `simv`
- 日志写入 `sim.log`

------

### 👀 查看波形

```makefile
verdi:
    verdi -dbdir simv.daidir -ssf waveform.fsdb &
```

- 启动 **Verdi** 波形查看工具
- `-dbdir simv.daidir`：指定仿真数据库目录
- `-ssf waveform.fsdb`：加载波形文件 `waveform.fsdb`
- `&`：后台运行

------

### 🧹 清理

```makefile
clean:
    rm -rf simv* csrc verdiLog *.fsdb *.log ucli.key vc_hdrs.h novas*
```

- 删除仿真生成的临时文件和日志，保持目录整洁。

------

### 🎯 总结

这个 Makefile 就是一个 **标准的 VCS+Verdi 仿真流程脚本**：

1. **编译** → 生成仿真可执行文件
2. **运行** → 执行 testbench，生成日志和波形
3. **查看波形** → 用 Verdi 打开 FSDB 文件
4. **清理** → 删除中间文件

> [!tip]
>
> 默认执行：`make`
>
> 单独执行：`make comp` / `make sim` / `make verdi` / `make clean`
>
> > [!note]
> >
> > **最小流程**：`make → make verdi`
> >
> > **完整流程**：`make → make verdi → make clean`（清理步骤可根据需要决定是否执行）

## filelist.f

### 📘 基本结构

常见的 `filelist.f` 内容包括：

1. **源文件路径**

   - 每一行写一个 Verilog/SystemVerilog 文件的路径。
   - 可以是相对路径或绝对路径。

   ```text
   ./src/mux.v
   ./src/adder.v
   ./tb/tb_mux.v
   ```

2. **宏定义**

   - 用 `+define+宏名` 来定义编译宏。

   ```text
   +define+SIM
   +define+DEBUG
   ```

3. **包含目录**

   - 用 `+incdir+路径` 指定 `include` 文件的搜索路径。

   ```text
   +incdir+./include
   ```

4. **库文件**

   - 如果有库，可以直接写路径。

   ```text
   ./lib/std_cells.v
   ```

------

### ⚙️ 示例 filelist.f

假设你的工程目录结构如下：

```
project/
 ├── src/
 │    ├── mux.v
 │    ├── adder.v
 ├── tb/
 │    └── tb_mux.v
 ├── include/
 │    └── defines.vh
 └── filelist.f
```

那么 `filelist.f` 可以写成：

```text
# 宏定义
+define+SIM
+define+DEBUG

# include目录
+incdir+./include

# 源文件
./src/mux.v
./src/adder.v

# testbench文件
./tb/tb_mux.v
```

------

### 🎯 总结

- **每行一个编译项**：源文件路径、宏定义、include目录。
- **顺序很重要**：通常先写宏和 include，再写源文件，最后写 testbench。
- **灵活性**：你可以把所有文件都放在 filelist.f 里，然后在 Makefile 中用 `-f filelist.f` 调用。