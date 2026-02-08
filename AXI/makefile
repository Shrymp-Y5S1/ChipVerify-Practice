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
