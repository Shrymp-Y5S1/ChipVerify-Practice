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

# 定义扫描的关键字符（需与 TB 中的 $display 匹配）
PASS_STR = "MATCHES: [1-9]\|TEST PASSED"
FAIL_STR = "UVM_ERROR : [1-9]\|UVM_FATAL : [1-9]\|MISMATCH"

# 覆盖率相关设置
CM_NAME  = $(TEST)
CM_DIR   = $(OUT_DIR)/coverage/$(TEST).vdb
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
	cd $(SIM_DIR) && ./simv \
	       -l ../logs/sim_$(TEST).log \
	       +fsdb+name=$(FSDB_FILE) \
	       $(CM_OPTS) -cm_dir ../../$(CM_DIR) -cm_name $(CM_NAME)

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

# 生成覆盖率报告
coverage:
	urg -dir $(OUT_DIR)/coverage/*.vdb -format both -report $(OUT_DIR)/coverage_report

# 结果检查
check:
	@echo "---------------------------------------------------"
	@echo "Checking Simulation Result for [$(TEST)]..."
	@# 1. 检查是否存在 UVM 错误
	@errors=$$(grep -E "UVM_ERROR|UVM_FATAL" $(LOG_DIR)/sim_$(TEST).log | grep -v ": 0" | wc -l); \
	if [ $$errors -gt 0 ]; then \
		echo ">>>> RESULT: [FAILED] (Found $$errors UVM Errors/Fatals) <<<<"; \
		exit 1; \
	fi; \
	# 2. 检查 Scoreboard 是否汇报了任何错误 [cite: 144]
	@scb_errs=$$(grep "ERRORS :" $(LOG_DIR)/sim_$(TEST).log | awk '{print $$3}'); \
	if [ "$$scb_errs" != "0" ] && [ -n "$$scb_errs" ]; then \
		echo ">>>> RESULT: [FAILED] (Scoreboard reported $$scb_errs errors) <<<<"; \
		exit 1; \
	fi; \
	# 3. 如果以上都没有，则判定为成功
	@echo ">>>> RESULT: [PASSED] <<<<";
	@echo "---------------------------------------------------"
