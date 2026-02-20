## AXI验证中的makefile优化

```makefile
# --- 路径与参数定义 ---
# 默认仿真的测试名，可以通过 make TEST=tb_xxx 覆盖
TEST      ?= tb_axi_mst
UVM_TEST  ?= axi_base_test
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
CURRENT_LOG = $(LOG_DIR)/sim_$(TEST)_$(UVM_TEST)_$(SEED).log

# 工具链定义
VCS        = vcs -full64 -sverilog -ntb_opts uvm -debug_access+all -kdb -lca -timescale=1ns/1ps \
             -assert enable_debug \
             +define+SVA_ENABLE \
             +incdir+./design +incdir+./verify
SIM        = ./$(SIM_DIR)/simv
VERDI      = verdi -dbdir $(SIM_DIR)/simv.daidir

# 定义扫描的关键字符（需与 TB 中的 $display 匹配）
PASS_STR = "MATCHES: [1-9]\|TEST PASSED"
FAIL_STR = "UVM_ERROR : [1-9]\|UVM_FATAL : [1-9]\|MISMATCH"

# 覆盖率相关设置
CM_NAME  = $(TEST)_$(SEED)
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
	@echo "Running Test: $(TEST) with UVM Case: $(UVM_TEST) Seed: $(SEED)"
	mkdir -p $(LOG_DIR)
	cd $(SIM_DIR) && ./simv \
	       -l $(abspath $(CURRENT_LOG)) \
	       +fsdb+name=$(FSDB_FILE) \
	       +ntb_random_seed=$(SEED) \
	       +UVM_TESTNAME=$(UVM_TEST) \
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
	@errors=$$(grep -E "UVM_ERROR|UVM_FATAL|Error:|Offending" $(CURRENT_LOG) | grep -v ": 0" | wc -l); \
	if [ $$errors -gt 0 ]; then \
		echo ">>>> RESULT: [FAILED] (Found $$errors Errors/Fatals/Assertion Failures) <<<<"; \
		exit 1; \
	fi; \
	@scb_errs=$$(grep "ERRORS :" $(CURRENT_LOG) | awk '{print $$3}'); \
	if [ "$$scb_errs" != "0" ] && [ -n "$$scb_errs" ]; then \
		echo ">>>> RESULT: [FAILED] (Scoreboard reported $$scb_errs errors) <<<<"; \
		exit 1; \
	fi; \
	@echo ">>>> RESULT: [PASSED] <<<<";
	@echo "---------------------------------------------------"
```

在引入 UVM 之后，你的验证环境实际上分成了两个维度：

1. **硬件/架构维度 (`TEST`)**：决定了编译哪些 RTL 文件、哪个 Interface、哪个 Top TB（即 `tb_axi_mst.sv`）。这由 `TEST` 变量控制。
2. **软件/激励维度 (`UVM_TEST`)**：决定了在仿真运行时，UVM Factory 实例化哪个具体的 Test Class（例如 `axi_base_test` 还是 `axi_stress_test`）。这由 `UVM_TEST` 变量控制。

#### 场景 A：运行默认测试（回归检查）

直接输入 `make` 即可。

- **命令**：`make`
- **效果**：编译 `tb_axi_mst`，运行 `axi_base_test`。

#### 场景 B：运行不同的 UVM 用例（最常用的场景）

当你做完 `axi_base_test`，想要跑 `axi_stress_test` 或其他新写的测试时，保持 `TEST` 不变，只改变 `UVM_TEST`。

- **命令**：

  ```Bash
  make UVM_TEST=axi_stress_test
  ```

- **效果**：编译 `tb_axi_mst`（如果已编译过可跳过），然后仿真时传递 `+UVM_TESTNAME=axi_stress_test`。

#### 场景 C：更改随机种子（复现 Bug）

- **命令**：

  ```Bash
  make UVM_TEST=axi_stress_test SEED=123456
  ```

#### 场景 D：切换到完全不同的项目（例如 tb_uart）

如果你有另一个设计 `tb_uart`，它有自己的 filelist 和 UVM Test，你需要同时指定两者。

- **命令**：

  ```Bash
  make TEST=tb_uart UVM_TEST=uart_data_test
  ```

### 总结速查表

| **你的目的**       | **以前的命令**     | **现在的命令 (UVM)**                      |
| ------------------ | ------------------ | ----------------------------------------- |
| **跑默认测试**     | `make`             | `make`                                    |
| **跑特定 TB**      | `make TEST=tb_xxx` | `make TEST=tb_xxx UVM_TEST=xxx_base_test` |
| **跑压力测试**     | (无)               | **`make UVM_TEST=axi_stress_test`**       |
| **带种子跑**       | `make SEED=123`    | `make UVM_TEST=axi_stress_test SEED=123`  |
| **只仿真(不编译)** | `make sim`         | `make sim UVM_TEST=axi_stress_test`       |

### 回归测试/覆盖率合并

```shell
#!/bin/bash

# --- 配置 ---
LOOP_NUM=50                  # 运行次数
TEST_CASE="tb_axi_mst"       # 你的 TEST 名字
UVM_CASE="axi_stress_test"   # 你的 UVM_TEST 名字 (这里可以用 stress test)

# 1. 清理旧的 Log 和输出 (注意：不要误删 coverage_db，除非你想重来)
echo "Cleaning simulation artifacts..."
make clean
# 如果你想彻底重跑覆盖率，取消下面这行的注释：
# rm -rf coverage_db

# 2. 编译一次 (Compile ONCE)
echo "Compiling design..."
make comp TEST=$TEST_CASE
if [ $? -ne 0 ]; then
    echo "Compilation Failed! Exiting."
    exit 1
fi

# 3. 循环运行 (Run MANY times)
echo "Starting Regression Loop ($LOOP_NUM runs)..."

for i in $(seq 1 $LOOP_NUM)
do
    # 生成随机种子
    SEED=$(date +%s%N) 
    
    echo -n "[Run $i/$LOOP_NUM] Seed: $SEED ... "
    
    # 运行仿真 (静默运行，只看结果)
    # 注意：这里我们覆盖了 Makefile 中的变量
    make sim check TEST=$TEST_CASE UVM_TEST=$UVM_CASE SEED=$SEED > /dev/null 2>&1
    
    # 检查刚刚生成的 Log 状态 (利用 make check 的返回值或 grep)
    # 因为上面把 stdout 重定向了，这里我们直接去 grep log 文件
    LOG_FILE="./out/logs/sim_${TEST_CASE}_${UVM_CASE}_${SEED}.log"
    
    if grep -q "UVM_ERROR : *0" "$LOG_FILE" && grep -q "UVM_FATAL : *0" "$LOG_FILE"; then
        echo "PASS"
    else
        echo "FAIL (Check $LOG_FILE)"
    fi
done

# 4. 合并并生成报告
echo "Generating Coverage Report..."
make coverage

echo "Done! Report is in out/coverage_report/dashboard.html"
```

