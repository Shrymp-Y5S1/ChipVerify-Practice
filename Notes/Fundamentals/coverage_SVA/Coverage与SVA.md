### 代码覆盖率 vs. 功能覆盖率

#### 1. 两者的区别

- **代码覆盖率 (Code Coverage):**
  - **定义:** 检查 RTL 代码中的行、分支、翻转（0变1, 1变0）是否都被执行过。
  - **来源:** 由仿真器（VCS）自动分析 RTL 代码生成。
  - **现状:** 你的 `makefile` 中定义了 `CM_OPTS = -cm line+cond+fsm+tgl+branch+assert`，这正是开启代码覆盖率的开关。
  - **局限性:** 代码覆盖率 100% **不代表** 功能没问题。例如：你可能从未发过 `WRAP` 类型的突发传输，但相关的 RTL 代码可能因为复位逻辑或与其他类型共享逻辑而被标记为“已覆盖”。
- **功能覆盖率 (Functional Coverage):**
  - **定义:** 检查验证计划中定义的**功能点**（Test Plan）是否都被测试过。例如：Burst Length 是否遍历了 1~16？地址是否出现过非对齐？
  - **来源:** 需要你编写 SystemVerilog 代码（`covergroup`, `coverpoint`）。
  - **现状:** 我们之前编写了 `verify/axi_coverage.sv`，其中定义的 `covergroup axi_cg` 就是用来收集功能覆盖率的。
  - **如何查看:** 当你运行 `make coverage` 生成 HTML 报告后，在报告的首页通常会有 **"Covergroups"** 或 **"Groups"** 这一栏。点进去，如果能看到 `axi_cg`，说明功能覆盖率已经被统计了。

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_coverage extends uvm_subscriber #(axi_transaction);

    `uvm_component_utils(axi_coverage)

    // ----------------------------------------------------------------
    // 定义 Covergroup
    // ----------------------------------------------------------------
    covergroup axi_cg;
        option.per_instance = 1;
        option.comment = "AXI Protocol Coverage";

        // 1. 读写类型覆盖
        cp_rw: coverpoint tr.is_write {
            bins write = {1};
            bins read  = {0};
        }

        // 2. 突发长度覆盖 (RTL MAX=8)
        cp_len: coverpoint tr.len {
            bins min_len = {0};       // 1 beat
            bins mid_len = {[1:6]};   // 2-7 beats
            bins max_len = {7};       // 8 beats (RTL 极限)
        }

        // 3. 突发大小覆盖
        cp_size: coverpoint tr.size {
            bins size_1b = {`AXI_SIZE_1_BYTE};
            bins size_2b = {`AXI_SIZE_2_BYTE};
            bins size_4b = {`AXI_SIZE_4_BYTE};
        }

        // 4. 突发类型 (目前主要测 INCR)
        cp_burst: coverpoint tr.burst {
            bins fixed = {`AXI_BURST_FIXED};
            bins incr  = {`AXI_BURST_INCR};
            bins wrap  = {`AXI_BURST_WRAP}; // 如果不支持可注释掉
        }

        // 5. 交叉覆盖：写操作 x 最大长度 (压力点)
        cross_wr_max_len: cross cp_rw, cp_len {
            bins wr_max = binsof(cp_rw.write) && binsof(cp_len.max_len);
            bins rd_max = binsof(cp_rw.read)  && binsof(cp_len.max_len);
        }

    endgroup

    // ----------------------------------------------------------------
    // Transaction 句柄
    // ----------------------------------------------------------------
    axi_transaction tr;

    // ----------------------------------------------------------------
    // 构造函数
    // ----------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        axi_cg = new(); // 实例化 covergroup
    endfunction

    // ----------------------------------------------------------------
    // 采样函数 (来自 uvm_subscriber)
    // ----------------------------------------------------------------
    virtual function void write(axi_transaction t);
        this.tr = t;
        axi_cg.sample(); // 触发采样
    endfunction

endclass
```

#### 2. 为什么必须两者结合？

- **代码覆盖率** 帮你看“有没有死代码”或“有没有漏测的逻辑分支”。
- **功能覆盖率** 帮你看“是不是所有业务场景都测到了”。
- **Sign-off 标准:** 通常要求 **Code Coverage > 99%** 且 **Functional Coverage = 100%**。

------

### 如何“不断提高”覆盖率（回归与合并）

你观察到“每次运行覆盖率都不一样”，这是完全正常的，因为我们使用了**随机种子 (Random Seed)**。

- **Seed A** 可能随机出了 `Length=3` 和 `Addr=0x1000`。
- **Seed B** 可能随机出了 `Length=8` 和 `Addr=0x2004`。

**我们提高覆盖率的方法，不是指望“某一次”仿真能跑完所有情况，而是通过“合并（Merge）”多次仿真的结果。**

#### 1. 覆盖率合并的原理

VCS 的覆盖率数据库（`.vdb` 文件夹）具有**累积（Accumulate）**特性。

根据你的 `makefile` 配置：

```
CM_DIR = $(COV_DB_DIR)/$(TEST).vdb
```

当你运行 `make sim` 时，VCS 默认的行为是：**读取现有的 `.vdb` -> 将本次仿真的新覆盖率数据加进去 -> 保存更新后的 `.vdb`**。

所以，你不需要修改工具，只需要**跑足够多的不同种子**。

#### 2. 实战操作：如何通过回归 (Regression) 提升覆盖率

请按照以下步骤操作，体验覆盖率从 50% -> 80% -> 100% 的攀升过程：

**第一步：准备一个回归脚本**

在 Linux 终端中，不要只运行一次 `make sim`，而是运行一个循环（或者写一个简单的 shell 脚本）：

```Bash
# 运行 50 次仿真，每次使用不同的随机种子
for i in {1..50}
do
   # 生成随机种子
   SEED=$(date +%s%N) 
   echo "Running regression run $i with seed $SEED..."
   
   # 运行仿真 (注意：不要运行 make clean，否则会删掉覆盖率库！)
   make sim UVM_TEST=axi_stress_test SEED=$SEED
done
```

**第二步：生成合并后的报告**

等那 50 次仿真跑完后，运行：

```Bash
make coverage
```

**第三步：分析报告 (Loop Closure)**

打开新生成的报告：

1. **看总分:** 此时的覆盖率应该比单次运行高得多。
2. **找漏洞 (Holes):**
   - 进入 `axi_cg` (功能覆盖率)。
   - 查看 `cp_len`：是不是 1~8 都变绿了？
   - 查看 `cross_wr_max_len`：是不是都覆盖到了？
3. **填补漏洞:**
   - 如果跑了 100 次，发现 `WRAP` 模式还是红的 -> 说明随机约束里权重太低，或者被关掉了。
   - **对策:** 修改 Sequence，增加 `WRAP` 的权重，或者写一个专门测 WRAP 的定向测试。

------

### 总结与建议

1. **确认功能覆盖率:** 请运行一次 `make coverage`，检查 HTML 报告中是否有 **Groups** 或 **Covergroups** 栏目。如果没有，我们需要检查 `axi_coverage.sv` 是否正确连接到了 Environment 中。
2. **不要每次都 `make clean`:** 在跑回归积累覆盖率时，只运行 `make sim`。只有当你修改了 RTL 代码需要重新编译时，才运行 `make comp` (你的 `make comp` 依赖 `prepare`，不会删除 `.vdb`，但 `make clean` 会删除 `out` 目录，需确认 `COV_DB_DIR` 是否在删除范围内。根据你的 makefile，`distclean` 才会删除 `coverage_db`，普通的 `clean` 不会删。**这是很好的设置！**)
3. **下一步:**
   - 先用上面的 `for` 循环跑一波“小回归”（比如 20 次）。
   - 生成报告，截个图，看看覆盖率是不是明显提升了。
   - 根据报告里的“红色部分”（未覆盖点），来决定我们下一阶段代码要写什么（比如增加 WRAP 支持）。

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

## SVA

理解 SVA（SystemVerilog Assertion）覆盖率报告

通常情况下，公式应该是这样的：
$$
\text{Total Clock Edges (Attempts)} = \underbrace{(\text{Real Success} + \text{Failure})}_{\text{前提条件满足 (干活了)}} + \underbrace{\text{Vacuous Success}}_{\text{前提条件不满足 (闲着)}}
$$
当出现SVA触发，但在得到结果前**仿真提前结束**就会有：
$$
\text{Attempts} = \underbrace{\text{Real Success} + \text{Failure}}_{\text{完成且触发}} + \underbrace{\text{Vacuous Success}}_{\text{完成但没触发}} + \underbrace{\textbf{Incomplete}}_{\text{触发了但没跑完}}
$$

### 详细解释：SVA 的三种状态

大多数 SVA 断言都是基于“蕴含操作符”（Implication Operator, `|->` 或 `|=>`）编写的。结构通常如下：

```systemverilog
// 格式： 前提条件 (Antecedent) |-> 检查结果 (Consequent)
assert property ( @(posedge clk) (VALID && !READY) |-> $stable(ADDR) );
```

在这种结构下，每次时钟上升沿都会触发一次 **Attempt（尝试）**，但根据前提条件是否满足，会有不同的结果：

1. **Vacuous Success (空成功 / 假成功)**
   - **情况**：前提条件 `(VALID && !READY)` **不成立**（为假）。
   - **结果**：断言直接视为“通过”。因为前提都没发生，断言不需要去检查后续的逻辑。
   - **现象**：在你的图 `image_e521a5.png` 中，这部分数据被隐藏了，但它们包含在 `Attempts` 的总数里。
2. **Real Success (真成功)**
   - **情况**：前提条件 **成立**（为真），**并且** 后续检查 `$stable(ADDR)` 也 **成立**。
   - **结果**：这是真正有意义的成功覆盖。
   - **现象**：对应图中 `Real Successes` 列。
3. **Failure (失败)**
   - **情况**：前提条件 **成立**，**但是** 后续检查 **失败**。
   - **结果**：这是 Bug。
   - **现象**：对应图中 `Failures` 列。

