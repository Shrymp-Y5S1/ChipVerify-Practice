> [!warning]
>
> **Makefile 语法要求**：规则的命令行必须以 tab 开头，否则就会报 `missing separator`。
>
> VS Code 右下角切换为：`Indent Using Tabs`
>
> 并在 VS Code 中按 `Ctrl+Shift+P`。输入 `View: Toggle Render Whitespace` 回车
>
> > [!tip]
> >
> > Python 的语法要求严格缩进，混用 Tab 和空格会直接报错。
> >
> > PEP 8（Python 官方编码规范）明确推荐使用 **4 个空格** 作为缩进。

## 前提：命名规范

> [!tip]
>
> 不需要 **所有** 文件都命名统一，但需要 **每一个测试入口（Testcase）** 的三个点保持一致：
>
> 1. **命令行传入的 `TEST` 变量值**
> 2. **`.f` 文件的文件名（不含后缀）**
> 3. **Testbench 内部的 `module` 关键字后的名称**
>
> > [!note]
> >
> > 在设计的参数化 Makefile 中，存在一个 **链条**。假设输入 `make TEST=tb_fifo`：
> >
> > 1. **变量映射**：Makefile 得到变量 `TEST = tb_fifo`。
> > 2. **寻找文件清单**：Makefile 会去寻找 `FLIST = ./flist/tb_fifo.f`。
> >    - **要求**：`flist` 文件夹下的文件名必须是 `tb_fifo.f`。
> > 3. **指定顶层模块**：VCS 编译时会寻找 `-top tb_fifo`。
> >    - **要求**：测试平台文件（如 `tb_fifo.v`）内部定义的模块名必须是 `module tb_fifo;`。
>
> > [!caution]
> >
> > 参考命名规范：
> >
> > - **RTL 文件**：`<module_name>.v`
> > - **Testbench 文件**：`tb_<module_name>.v`
> > - **Filelist 文件**：
> >   - `flist/design_<subsystem>.f` （存放设计文件清单）
> >   - `flist/tb_<test_point>.f` （具体的测试入口清单）
> > - **输出目录**：`out/<test_name>/` （由 Makefile 自动创建，隔离不同测试的日志和波形）

### 1. 核心契约：测试标识符 (Test ID)

这是最需要统一的。如果你要测试 FIFO，那么这个测试的“ID”就是 `tb_fifo`。

- **Filelist 名**：`flist/tb_fifo.f`
- **TB 模块名**：`tb_fifo.v` 里的 `module tb_fifo`
- **命令输入**：`make TEST=tb_fifo`

### 2. 惯例契约：RTL 模块与文件名

虽然 Makefile 不直接强制要求，但为了不让自己在写 `.f` 文件时产生混乱，应遵循：

- **原则**：一个 `.v` 文件只写一个 `module`，且文件名与模块名完全一致。
- **示例**：`module uart_tx` 必须存放在 `uart_tx.v` 中。

### 3. 关联契约：分层 Filelist

正如你之前担心的，如果不想编译未完成的模块，你的分层清单命名也应有规律：

- **设计子清单**：`flist/design_uart.f`、`flist/design_fifo.f`。
- **使用方式**：在 `tb_fifo.f` 中只包含 `-f ./flist/design_fifo.f`。

## 参数化 Makefile 设计

> [!note]
>
> “参数化”的核心思想是 **“代码不动，通过变量控制行为”**。
>
> 在你的 `makefile` 中：
>
> - **`TEST ?= tb_uart_core`**：这里的 `?=` 是条件赋值。这意味着如果你直接运行 `make`，它用默认值；但如果你运行 `make TEST=tb_fifo`，命令行传入的值会覆盖默认值。
> - **`FLIST = ./flist/$(TEST).f`**：这实现了 **动态路径映射**。不同的测试名会自动寻找对应的文件列表。
> - **目录自动化**：通过 `$(OUT_DIR)` 将编译产物隔离，确保你运行 `tb_fifo` 时产生的文件不会覆盖 `tb_uart_core` 的日志。
>
> **这样做的好处：**
>
> 1. **环境一致性**：整个团队（或者你以后回看项目时）只需要记住一套命令。
> 2. **避免人为失误**：不需要频繁手动修改 `vcs` 命令后的文件名。

### 参考

```makefile
# --- 路径与参数定义 ---
# 默认仿真的测试名，可以通过 make TEST=tb_xxx 覆盖
TEST      ?= tb_uart_core
# 随机数种子，可以通过 make SEED=12345 进行覆盖
SEED      := $(shell date +%s)
FLIST     ?= ./flist/$(TEST).f
TOP       ?= $(TEST)

# 目录定义
OUT_DIR    = ./out
COV_DB_DIR = ./coverage_db
LOG_DIR    = $(OUT_DIR)/logs
SIM_DIR    = $(OUT_DIR)/sim_$(TEST)
FSDB_FILE  = $(TEST).fsdb
# 确保 sim 和 check 操作的是同一个文件
CURRENT_LOG = $(LOG_DIR)/sim_$(TEST)_$(SEED).log

# 工具链定义
VCS        = vcs -full64 -sverilog -ntb_opts uvm -debug_access+all -kdb -lca -timescale=1ns/1ps \
             -assert enable_debug \
             +define+SVA_ENABLE
SIM        = ./$(SIM_DIR)/simv
VERDI      = verdi -dbdir $(SIM_DIR)/simv.daidir

# 定义扫描的关键字符（需与 TB 中的 $display 匹配）
PASS_STR = "MATCHES: [1-9]\|TEST PASSED"
FAIL_STR = "UVM_ERROR : [1-9]\|UVM_FATAL : [1-9]\|MISMATCH"

# 覆盖率相关设置
CM_NAME  = $(TEST)
CM_DIR   = $(COV_DB_DIR)/$(TEST).vdb
CM_OPTS  = -cm line+cond+fsm+tgl+branch+assert
CM_HIER  = -cm_hier ./flist/cm.hier

# --- 主要目标 ---

all: clean comp sim check coverage

# 创建必要的目录
prepare:
	mkdir -p $(LOG_DIR)
	mkdir -p $(SIM_DIR)

# 编译
comp: prepare
	$(VCS) -f $(FLIST) \
	       -top $(TOP) \
	       -o $(SIM_DIR)/simv \
	       -l $(LOG_DIR)/comp_$(TEST).log \
	       $(CM_OPTS) $(CM_HIER)\
           -cm_dir $(CM_DIR) -cm_name $(CM_NAME)

# 仿真
sim:
	@echo "Running Test: $(TEST) with Seed: $(SEED)"
	mkdir -p $(LOG_DIR)
	cd $(SIM_DIR) && ./simv \
	       -l $(abspath $(CURRENT_LOG)) \
	       +fsdb+name=$(FSDB_FILE) \
	       +ntb_random_seed=$(SEED) \
	       $(CM_OPTS) -cm_dir $(abspath $(CM_DIR)) -cm_name $(CM_NAME)

# 打开波形 (Verdi)
verdi:
	$(VERDI) -ssf $(SIM_DIR)/$(FSDB_FILE) &

# 清理
clean:
	@echo "Cleaning up simulation artifacts (Keeping Coverage)..."
	rm -rf $(OUT_DIR)
	rm -rf csrc simv* *.fsdb *.log ucli.key vc_hdrs.h vdCovLog

distclean: clean
	@echo "WARNING: Deleting Coverage Database..."
	rm -rf $(COV_DB_DIR)
	rm -rf verdiLog vfastLog

# 生成覆盖率报告
coverage:
	urg -full64 -dir $(COV_DB_DIR)/*.vdb \
		-format both \
		-report $(OUT_DIR)/coverage_report \
		-show tests

# 查看覆盖率代码着色（如果有这个license，否则HTML）
cov_gui:
	$(VERDI) -cov -covdir $(CM_DIR) &

# 结果检查
check:
	@echo "---------------------------------------------------"
	@echo "Checking Simulation Result for [$(TEST)] Seed [$(SEED)]..."
	@echo "Log file: $(CURRENT_LOG)"
	@# 0. 先检查 Log 文件是否存在 (防止 simv 根本没跑起来)
	@if [ ! -f $(CURRENT_LOG) ]; then \
		echo ">>>> RESULT: [FATAL] Log file not found! Simulation failed to start? <<<<"; \
		exit 1; \
	fi; \
	# 1. 检查 UVM 错误 + SVA 断言错误 (针对当前具体的 Log 文件)
	@errors=$$(grep -E "UVM_ERROR|UVM_FATAL|Error:|Offending" $(CURRENT_LOG) | grep -v ": 0" | wc -l); \
	if [ $$errors -gt 0 ]; then \
		echo ">>>> RESULT: [FAILED] (Found $$errors Errors/Fatals/Assertion Failures) <<<<"; \
		exit 1; \
	fi; \
	# 2. 检查 Scoreboard (针对当前具体的 Log 文件)
	@scb_errs=$$(grep "ERRORS :" $(CURRENT_LOG) | awk '{print $$3}'); \
	if [ "$$scb_errs" != "0" ] && [ -n "$$scb_errs" ]; then \
		echo ">>>> RESULT: [FAILED] (Scoreboard reported $$scb_errs errors) <<<<"; \
		exit 1; \
	fi; \
	# 3. 成功
	@echo ">>>> RESULT: [PASSED] <<<<";
	@echo "---------------------------------------------------"
```

> [!note]
>
> ```makefile
> $(abspath filenames)
> ```
>
> **作用**：
>
> - 将相对路径或混合路径规范化为绝对路径。
> - 不会检查文件是否真实存在，只是做字符串路径转换。
>
> **举例**：
>
> ```makefile
> SRC = ./src/main.c
> ABS = $(abspath $(SRC))
> ```
>
> 如果当前目录是 `/home/user/project`，那么 `ABS` 的值就是：
>
> ```makefile
> /home/user/project/src/main.c
> ```


> [!caution]
>
> #### `check` 注意事项
>
> 1. 在 `FAIL_STR` 中应尽可能使用更精确的正则。例如，使用 `"UVM_ERROR : [1-9]"` 来确保只有当错误计数不为 0 时才报错。
> 2. `check` 脚本 **强依赖于重定向的 `.log` 文件**。如果仿真因为超时或环境崩溃（如 License 失败）而提前退出，日志可能不完整。
>    - **建议**：在 `check` 逻辑中增加对 `VCS Simulation Report` 结尾标志的检查，确保仿真是“正常结束”而非“半路夭折”。
> 3. 专业的 `Makefile` 除了扫描文本，更应关注仿真命令的退出状态 `$?`。
>    - 如果仿真中途触发了 ``uvm_fatal`，VCS 应该**返回非零值**。结合文本扫描与状态码判断，才是最稳健的工程实践。
>
>  `$display` 像在代码里随手贴“便利贴”，而 UVM 宏（``uvm_info/error/fatal`）则是一个**全自动化的日志管理系统**。
>
> | **特性**       | **$display (Verilog)** | **UVM 宏 (UVM_INFO/ERROR/FATAL)**                            |
> | -------------- | ---------------------- | ------------------------------------------------------------ |
> | **层级溯源**   | 仅打印内容             | 自动包含 **文件名、行号、产生该日志的类名**                   |
> | **冗余度过滤** | 全量打印               | 支持 **Verbosity**（如 `UVM_LOW` 到 `UVM_DEBUG`）。可以一键关闭调试信息，只看关键报告 |
> | **严重性分级** | 无                     | 明确定义 **Severity**。`uvm_error` 会自动增加错误计数，`uvm_fatal` 会直接终止仿真 |
>
> ------
>
> #### `cm.hier` 编写规范
>
> > [!tip]
> >
> > `cm.hier` 采用树状结构控制指令。最常用的指令如下：
> >
> > - **`+tree instance_path [depth]`**：统计指定路径及其子层次的覆盖率。`0` 表示不限深度。
> > - **`-tree instance_path`**：排除指定路径及其子层次。
> > - **`+module module_name`**：统计该类型模块的所有实例。
>
> 根据你提供的 APB_UART 的 `tb_top_uvm.sv` 和其中的实例名 `u_apb_if` ，你的文件应编写如下：
>
> ```Plaintext
> // 文件名: flist/cm.hier
> -tree tb_top_uvm         // 1. 先排除顶层所有内容（包括 TB） 
> +tree tb_top_uvm.u_apb_if 0 // 2. 再精准包含你的设计实例及其所有子模块 
> ```
>
> > [!note]
> >
> > 1. **路径准确性**：`instance_path` 必须是 **实例名** 而非模块名。例如你是 `u_apb_if` 而不是 `apb_if` 。
> > 2. **编译与仿真同步**：如果在编译时使用了 `-cm_hier`，仿真命令（`simv`）也必须带上同样的 `-cm` 选项，否则无法生成正确的 `.vdb` 数据库。
> > 3. **结果验证**：生成 `urg` 报告后，打开 `index.html`，检查 **Hierarchy** 页面。如果你只看到了 `u_apb_if` 及其子模块（如 `u_uart_rx`, `u_fifo`），说明配置成功。

### 使用

| **操作指令**                       | **实际行为**                                       |
| ---------------------------------- | -------------------------------------------------- |
| **`make、make TEST=tb_fifo`**      | 默认运行 `tb_uart_core` 、`tb_fifo` 的编译与仿真。 |
| **`make comp TEST=tb_fifo`**       | 仅编译 FIFO 的仿真组 。                            |
| **`make sim TEST=tb_fifo`**        | 运行 FIFO 的仿真并生成日志 。                      |
| **`make verdi TEST=tb_uart_core`** | 打开 UART 核心回环的波形图 。                      |

## 分层 filelist 设计

> [!tip]
>
> 在编写 `filelist.f` 时，规范主要集中在 **路径统一、顺序正确、分组清晰、可维护性强**：
>
> - 用相对路径（`./` 开头），避免绝对路径。
>
>   - **统一使用相对路径**
>
>     推荐写成 `./design/module.v` 或 `../testbench/module.v`，避免绝对路径（如 `/home/user/project/...`），这样在不同机器或环境下更容易移植。
>
>   - **保持路径一致性**
>
>     所有文件路径应从项目根目录出发，保持统一风格。
>
>     不要混用 `./` 和不带前缀的写法，避免编译器解析混乱。
>
> - 底层模块在前，顶层 testbench 在后。
>
> - 使用 `-f` 引用子 filelist，分设计与验证。
>
>   - `design.f` → 设计文件
>   - `tb.f` → testbench 文件
>   - `sim.f` → 仿真文件（包含 design.f + tb.f）
>
> - 保持风格一致，适当加注释。

### 1. 核心设计清单：`flist/design.f`

此文件仅包含经过验证的 RTL 源码。

```Plaintext
// RTL Source Files
./design/baud_generate.v
./design/uart_tx.v
./design/uart_rx.v
./design/fifo.v
./design/reg_map.v
./design/APB_interface.v
```

> [!note]
>
> 分层设计的真正精髓在于 **“按需包含”**，而不是把所有东西都塞进一个 `design.f`。
>
> 你可以根据模块的依赖关系，将 `design` 拆分为多个小包：
>
> - **`rtl_core.f`**：基础组件（如 `fifo.v`, `baud_generate.v`）。这些通常是最先验证完的。
> - **`rtl_uart.f`**：串口协议逻辑（包含 `uart_tx.v`, `uart_rx.v` ）。
> - **`rtl_system.f`**：顶层总线逻辑（包含 `reg_map.v`, `APB_interface.v`）。
>
> 如果你现在只想验证 `fifo`，而 `reg_map.v` 还是乱码或未完成状态，你的 `tb_fifo.f` 应该这样写：
>
> ```Plaintext
> // flist/tb_fifo.f 
> ./design/fifo.v        // 只包含正在测试的模块
> ./testbench/tb_fifo.v  // 对应的激励
> ```
>
> **此时：**
>
> - **编译不会报错**：因为 `vcs` 根本没有看到 `reg_map.v`。
> - **编译速度最快**：只处理必要的文件。
> - **解耦验证**：当你确定 `fifo.v` 完美通过后，再在 `rtl_system.f` 中引用它。

### 2. 测试专用清单：`flist/tb_uart_core.f`

每个仿真组对应一个文件，内部包含设计清单。

```fortran
// Include Design Files
-f ./flist/design.f

// Testbench for UART Core Loopback
./testbench/tb_uart_core.v
```

> **注**：你可以依此类推创建 `flist/tb_fifo.f` 和 `flist/tb_apb_sys.f`。

> [!note]
>
> 如果你正在验证 `APB_interface`，但底层的 `uart_rx` 还没写好，导致顶层编译不过，这时候有两套方案：
>
> 1. **排除法**：在 `.f` 文件里不写那个没写好的 `.v`。但在顶层 `APB_interface` 里已经例化了它，不读入文件会报 `Module not defined` 错误。
> 2. **黑盒/桩模块**：写一个只有端口声明、内部逻辑为空的 `uart_rx_stub.v`。
>    - 这样 `vcs` 能找到这个模块名，编译能通过。
>    - 你可以先专注于测试总线对寄存器的读写，而不管串口是否真的收到了数。
>
> 对于你现在的工程，我建议的 `flist` 结构如下：
>
> | **文件**         | **内容建议**                                    | **适用场景**            |
> | ---------------- | ----------------------------------------------- | ----------------------- |
> | **`rtl_base.f`** | `fifo.v`, `baud_generate.v`                     | 基础模块验证            |
> | **`rtl_uart.f`** | `-f rtl_base.f`, `uart_tx.v`, `uart_rx.v`       | 核心回环验证 (Loopback) |
> | **`rtl_all.f`**  | `-f rtl_uart.f`, `reg_map.v`, `APB_interface.v` | 全系统验证              |
>
> 1. **初期**：`make TEST=tb_fifo`（对应的 `.f` 只写 `fifo.v`）。
> 2. **中期**：`make TEST=tb_uart_core`（对应的 `.f` 包含 `rtl_uart.f`）。
> 3. **后期**：`make TEST=tb_apb_sys`（对应的 `.f` 包含 `rtl_all.f`）。

### 3. 语法

```fortran
// 顺序很重要，Package 必须在 Top 之前编译

+incdir+./design
+incdir+./testbench

./design/apb_if_pkg.sv
./testbench/apb_pkg.sv
-f ./flist/design_apb_sys.f

./testbench/tb_top_uvm.sv
```

| 指令            | 作用               | 例子                    | 解释                                                         |
| --------------- | ------------------ | ----------------------- | ------------------------------------------------------------ |
| **Direct Path** | 编译指定文件       | `./design/apb_if.sv`    | 明确告诉编译器编译这个具体的 `.sv` 文件。                    |
| **-f / -F**     | 包含另一个文件列表 | `-f ./flist/sub_list.f` | 把 `sub_list.f` 里的内容展开贴到这里，相当于嵌套列表。       |
| **+incdir+**    | **添加搜索路径**   | `+incdir+./design`      | **不直接编译文件**。它只是把这个目录加入“白名单”，当代码里遇到 ``include` 时才去这里搜。 |

> [!tip]
>
> ```
> /design
>   ├── apb_slave.sv   <-- 这里面用到了 `include "apb_params.svh"
>   └── apb_params.svh
> /testbench
>   └── tb_top.sv
> ```
