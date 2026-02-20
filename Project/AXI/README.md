# AXI4 UVM 验证平台功能点总结（当前版本）

本文档基于 `Project/AXI/verify` 现有 UVM 代码与测试集合，汇总**当前已验证功能点**和**暂不支持/部分支持功能点**。

## 1. 当前验证平台范围

- 验证对象：`axi_mst_rd` + `axi_mst_wr`（在 `tb_axi_mst.sv` 中组装）
- 协议类型：AXI4（基础读写通道）
- 当前参数：
  - `AXI_ID_WIDTH = 4`
  - `AXI_ADDR_WIDTH = 16`
  - `AXI_DATA_WIDTH = 32`
  - `MAX_BURST_LEN = 8`（即 `len <= 7`）
- 平台组件：`agent + driver + monitor + scoreboard + coverage + SVA`

---

## 2. 已验证功能点（Supported）

### 2.1 基础读写与突发功能

- 支持读写请求生成与驱动（`axi_base_test` / `axi_full_test` / `axi_stress_test`）
- 支持 burst 类型覆盖：`FIXED / INCR / WRAP`
- 支持 burst 长度范围：1~8 beats（受 RTL 约束）
- 支持 `size` 覆盖：1/2/4 Byte（32-bit 总线下）

### 2.2 协议规则与断言检查（SVA）

在 `axi_interface.sv` 中已启用并检查：

- AR/AW 在 `VALID && !READY` 时控制信号稳定
- W 在 `VALID && !READY` 时 `WDATA/WSTRB/WLAST` 稳定
- VALID 信号无 X 态
- AW/AR 单次 burst 不跨 4KB 边界

### 2.3 Scoreboard 数据一致性校验

- Byte-level Golden Memory（按 `WSTRB` 写入）
- 读数据按 `ID` 匹配 AR/R 并进行 beat-by-beat 比对
- 支持 `FIXED/INCR/WRAP` 地址推进模型
- 支持 BRESP/RRESP 严格检查（非 `OKAY` 计为错误）
- 支持“读写重叠地址”场景的延迟比对（pending read defer）

### 2.4 压力与并发行为

在 `tb_axi_mst.sv` 中已实现并用于验证：

- AW/AR/W 随机反压（Ready 随机拉低）
- 多 outstanding 事务（读写 OST 深度场景）
- B/R 响应乱序返回（OoO）
- R 通道 beat-level interleaving 场景

### 2.5 错误响应注入与校验

- `axi_error_resp_test` 支持注入 `SLVERR/DECERR`
- 可通过 plusargs 配置错误比例：
  - `+SLV_ERR_PCT=<0~100>`
  - `+DEC_ERR_PCT=<0~100>`
  - `+ERR_RESP_ONLY_MODE=1`
- Scoreboard 可检测并统计 BRESP/RRESP 错误

### 2.6 特殊场景测试

- 4KB 边界 crossing 定向场景（`axi_4k_boundary_test`）
  - 通过关闭 transaction 的 `c_4k_boundary` 约束，主动构造跨界请求
  - 用于验证断言/错误检测能力
- 非对齐地址 + 部分 strobe 场景（`axi_unaligned_strobe_test`）
  - 当前默认回归指向 must-pass 子集
- `size × 对齐方式 × strobe` 组合矩阵（`axi_size_align_strobe_matrix_test`）
  - 系统遍历 `size={1B,2B,4B}` × `对齐/非对齐` × `wstrb=0~15`
  - 每个组合执行单拍 WR/RD 对，并由现有 scoreboard 自动校验

---

## 3. 暂不支持 / 部分支持功能点（Not Supported Yet）

### 3.1 AXI4 高级属性未建模

以下信号/语义当前平台未完整建模到 transaction/检查链路：

- `AxPROT / AxCACHE / AxQOS / AxREGION / AxLOCK / USER`
- 因此对应协议语义（保护属性、缓存属性、锁访问、QoS 等）当前不可验证

### 3.2 Exclusive/Atomic 语义

- 不支持 exclusive access（`EXOKAY` 语义未建立完整激励与检查）
- 不支持原子类扩展行为验证

### 3.3 窄传输与非对齐全矩阵覆盖不足

- 已支持单拍矩阵：`size={1B,2B,4B} × 对齐/非对齐 × wstrb=0~15`
- 但多拍 burst 下 `wstrb[beat0..beatN]` 的组合矩阵尚未完整覆盖
- `axi_unaligned_strobe_expected_fail_test` 仍用于暴露已知限制边界

### 3.4 多主多从/互连级验证未覆盖

- 当前 testbench 为单主侧 DUT + 单内存模型
- 未覆盖多 master 仲裁、公平性、跨端口流量竞争等 SoC 级场景

### 3.5 性能与长期稳态指标未纳入签核

- 当前重点是功能正确性与协议合法性
- 未形成系统化性能签核（吞吐、延迟分布、极限背压下 QoS）

### 3.6 参数化覆盖范围有限

- 当前主要在固定配置下验证：16-bit 地址、32-bit 数据、burst<=8
- 更大数据位宽/地址空间配置未形成常态回归矩阵

---

## 4. 当前测试与功能点映射

- `axi_base_test`：基础随机 + 定向 R/W
- `axi_full_test`：大样本随机覆盖（burst/size/对齐约束）
- `axi_stress_test`：高压随机、并发与反压场景
- `axi_error_resp_test`：错误响应注入与检测
- `axi_4k_boundary_test`：跨 4KB 边界违规请求检测
- `axi_unaligned_strobe_must_pass_test`：当前可通过的非对齐+strobe 子集
- `axi_unaligned_strobe_expected_fail_test`：已知限制场景（用于暴露能力边界）
- `axi_size_align_strobe_matrix_test`：全矩阵组合遍历（size × 对齐方式 × strobe）

---

## 5. 结论（现阶段能力边界）

当前 AXI4 UVM 平台已经具备：

- 较完整的基础功能验证能力（R/W、burst、响应、一致性）
- 面向并发与异常返回的压力验证能力（OoO、interleave、error inject）
- 协议关键规则断言能力（稳定性、4KB 边界）

但对 AXI4 完整协议生态而言，仍需补齐：

- 高级属性语义（PROT/CACHE/QOS/LOCK/USER）
- Exclusive/Atomic 语义
- 多拍 burst 下窄传输与非对齐全矩阵
- 多主多从互连级与性能签核

这份文档可作为当前版本回归签核的“能力边界说明”。

---

## 6. 一键完整回归与覆盖率报告

新增脚本：`run_axi_regression.sh`（CentOS7/Linux 推荐）

兼容脚本：`run_axi_regression.ps1`（Windows/PowerShell）

能力说明：

- 一次编译（`make comp`）后批量执行多个 `UVM_TEST`
- 每个测试自动执行 `sim + check`
- 全部测试结束后自动执行 `make coverage`
- 自动生成汇总结果：
  - `out/logs/regression_summary_*.txt`
  - `out/logs/regression_summary_*.csv`
  - 覆盖率报告：`out/coverage_report`

常用命令：

- CentOS7 首次使用请先赋执行权限：
  - `chmod +x ./run_axi_regression.sh`
- 默认完整回归（推荐）：
  - `./run_axi_regression.sh`
- 指定起始种子与步进：
  - `./run_axi_regression.sh --seed-start 10001 --seed-step 7`
- 失败即停：
  - `./run_axi_regression.sh --stop-on-fail`
- 包含 expected-fail 场景：
  - `./run_axi_regression.sh --include-expected-fail`
- 强制重编译：
  - `./run_axi_regression.sh --rebuild`
