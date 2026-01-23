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
VCS        = vcs -full64 -sverilog -debug_access+all -kdb -lca -timescale=1ns/1ps
SIM        = ./$(SIM_DIR)/simv
VERDI      = verdi -dbdir $(SIM_DIR)/simv.daidir

# 定义扫描的关键字符（需与 TB 中的 $display 匹配）
PASS_STR = "SUCCESS\|Simulation finished"
FAIL_STR = "ERROR\|FAIL\|MISMATCH"

# --- 主要目标 ---

all: clean comp sim check

# 创建必要的目录
prepare:
	mkdir -p $(LOG_DIR)
	mkdir -p $(SIM_DIR)

# 编译
comp: prepare
	$(VCS) -f $(FLIST) \
	       -top $(TOP) \
	       -o $(SIM_DIR)/simv \
	       -l $(LOG_DIR)/comp_$(TEST).log

# 仿真
sim:
	cd $(SIM_DIR) && ./simv -l ../logs/sim_$(TEST).log +fsdb+name=$(FSDB_FILE)

# 打开波形 (Verdi)
verdi:
	$(VERDI) -ssf $(SIM_DIR)/$(FSDB_FILE) &

# 清理
clean:
	@echo "Cleaning up all simulation and tool artifacts..."
	rm -rf $(OUT_DIR)
	rm -rf csrc simv*
	rm -rf verdiLog vfastLog
	rm -rf *.fsdb *.log
	rm -rf ucli.key novas*
	rm -rf vc_hdrs.h

check:
	@echo "---------------------------------------------------"
	@echo "Checking Simulation Result for [$(TEST)]..."
	@if grep -iq $(FAIL_STR) $(LOG_DIR)/sim_$(TEST).log; then \
		echo ">>>> RESULT: [FAILED] <<<<"; \
		echo "Found error keywords in $(LOG_DIR)/sim_$(TEST).log"; \
	elif grep -iq $(PASS_STR) $(LOG_DIR)/sim_$(TEST).log; then \
		echo ">>>> RESULT: [PASSED] <<<<"; \
	else \
		echo ">>>> RESULT: [UNKNOWN] <<<<"; \
		echo "No status keywords found. Check log manually."; \
	fi
	@echo "---------------------------------------------------"
