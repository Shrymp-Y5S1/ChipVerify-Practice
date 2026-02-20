## 生成coverage report

### 1. 修改 Makefile 开启“代码覆盖率” (Code Coverage)

代码覆盖率是“白盒测试”的基础，只需在 `VCS` 和 `SIM` 选项中增加 `-cm` 关键字即可 。

```makefile
# --- 路径与参数定义 ---
# 默认仿真的测试名，可以通过 make TEST=tb_fifo 覆盖
TEST      ?= tb_uart_core
FLIST     ?= ./flist/$(TEST).f
TOP       ?= $(TEST)

# 目录定义
OUT_DIR    = ./out
LOG_DIR    = $(OUT_DIR)/logs
SIM_DIR    = $(OUT_DIR)/sim_$(TEST)
FSDB_FILE  = $(TEST).fsdb

# 工具链定义
VCS        = vcs -full64 -sverilog -ntb_opts uvm -debug_access+all -kdb -lca -timescale=1ns/1ps
SIM        = ./$(SIM_DIR)/simv
VERDI      = verdi -dbdir $(SIM_DIR)/simv.daidir

# 覆盖率相关设置
CM_NAME  = $(TEST)
CM_DIR   = $(OUT_DIR)/coverage/$(TEST).vdb
CM_OPTS  = -cm line+cond+fsm+tgl+branch+assert
CM_HIER  = -cm_hier ./flist/cm.hier

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
	cd $(SIM_DIR) && ./simv \
	       -l ../logs/sim_$(TEST).log \
	       +fsdb+name=$(FSDB_FILE) \
	       $(CM_OPTS) -cm_dir ../../$(CM_DIR) -cm_name $(CM_NAME)

# 生成覆盖率报告
coverage:
	urg -dir $(OUT_DIR)/coverage/*.vdb -format both -report $(OUT_DIR)/coverage_repor
```

### 2. 增加“功能覆盖率” (Functional Coverage)

在 `apb_pkg.sv` 的 `apb_monitor` 或单独定义一个类中增加如下代码，证明你的随机激励是有效的 ：

```systemverilog
covergroup uart_ctrl_cg @(posedge vif.cb);
    // 覆盖所有的寄存器地址
    ADDR: coverpoint vif.cb.PADDR {
        bins data_reg = {4'h0};
        bins ctrl_reg = {4'h4};
        bins stat_reg = {4'h8};
        bins int_reg  = {4'hc};
    }
    // 覆盖读和写操作
    RW_OP: coverpoint vif.cb.PWRITE {
        bins wr = {1};
        bins rd = {0};
    }
    // 交叉覆盖：确保每个寄存器都被读过且写过
    ADDR_X_RW: cross ADDR, RW_OP;
endgroup
```

---

## 查看coverage report

### 打开方式

   - 虚拟机/服务器支持图形界面：在终端执行 `firefox out/coverage_report/dashboard.html &`。
   - 纯命令行（通过 SSH 连接）：需要将 `out/coverage_report/` 整个文件夹下载到本地 Windows/Mac，然后用浏览器打开 **`dashboard.html`**。

### Dashboard（概览页）

- **Total Coverage Summary**：反映整个项目的平均水平。
- **tb_top_uvm 层次项**：这是你的核心战场。可以看到 **Line Coverage (87.50%)** 极高，说明绝大多数代码都被执行过。
- **FSM (55.56%)**：这是 UART 的核心指标。目前的得分说明你的状态机（如 `IDLE`, `SEND`, `WAIT`）只跑通了部分跳转路径。

### Hierarchy（层次页）

点击顶部的 `hierarchy` 链接，这是分析“谁没被测到”的关键：

- 你可以看到 `u_apb_if` 下的子模块（如 `fifo`, `uart_tx`）。
- **分析技巧**：点击具体的模块名，它会跳转到源代码。**红色（Red）** 的行表示从未执行过。
- **使用场景**：如果 `uart_rx` 的 `parity_error` 逻辑是红色的，说明你没构造过错误的奇偶校验激励。

### Modlist（定义页）

**定义统计 (Definition Summary)**：基于**代码定义（Module/Package Definition）**。

> 即使你例化了 10 个 FIFO，只要其中任意一个 FIFO 的某行代码被跑到了，那么在“定义统计”中，该模块的这一行就算覆盖。

**作用**：告诉你，写的每一个 `module` 模板是否在功能上已经“能够”跑通，而不关心它是哪个具体的实例在跑。

### 五大指标的分析

| **指标**           | **含义**                         |
| ------------------ | -------------------------------- |
| **Line**（行）     | 代码行是否执行                   |
| **Cond**（条件）   | 逻辑表达式的真假组合             |
| **Toggle**（翻转） | 信号是否完成了 0->1 和 1->0 跳变 |
| **FSM**（状态机）  | 状态机的状态和跳转是否完备       |
| **Branch**（分支） | `if/case` 的所有分支是否走过     |

> [!note]
>
> **Assert**：代码中编写的 **SystemVerilog Assertions (SVA)** 的执行情况。它不仅看断言是否“成功”，更重要的是看断言是否被“触发采样”过。

### uvm_custom_install_verdi_recording

- 这**不是**你的设计代码。它是 Synopsys 工具链在使用 **Verdi** 进行波形记录（FSDB dumping）时，自动注入的一段底层库代码或 PLI 接口。
- **分数低的原因**：这段代码是给仿真器调用的“工具插件”，你的测试激励（Testbench）主要是在测 UART 逻辑，根本不会去全面执行这些工具内部的函数。
- **工业界处理方式**：
  - **忽略它**：它是“噪声数据”。
  - **过滤它**：这也是为什么我们强调使用 `cm.hier` 的原因。在最终给导师的报告中，你应该只展示 `tb_top_uvm` 那一行的数据，因为它才是真实的设计验证质量。

### “清洗”报告

**使用 `Exclude` 移除干扰项**：在 `Dashboard` 或 `Hierarchy` 页面，你可以通过 `urg` 的过滤参数，或者在生成的 HTML 界面上手动选择并“Exclude”掉那个 `uvm_custom_install...` 项。
