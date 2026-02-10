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