#!/usr/bin/env bash
set -euo pipefail

TESTBENCH="tb_axi_mst"
SEED_START="$(date +%s)"
SEED_STEP=1
REBUILD=0
DISTCLEAN=0
INCLUDE_EXPECTED_FAIL=0
STOP_ON_FAIL=0
UVM_TIMEOUT=2000000000
UVM_MAX_QUIT_COUNT=50
TB_HS_TIMEOUT=100000
DRV_REQ_TIMEOUT=100000

TESTS=()
DEFAULT_TESTS=(
  "axi_base_test"
  "axi_full_test"
  "axi_stress_test"
  "axi_error_resp_test"
  "axi_4k_boundary_test"
  "axi_unaligned_strobe_must_pass_test"
  "axi_size_align_strobe_matrix_test"
)
EXPECTED_FAIL_TESTS=(
  "axi_unaligned_strobe_expected_fail_test"
)

usage() {
  cat <<'EOF'
Usage: ./run_axi_regression.sh [options]

Options:
  --testbench <name>            Testbench top (default: tb_axi_mst)
  --seed-start <num>            Start seed (default: current unix time)
  --seed-step <num>             Seed increment per test (default: 1)
  --rebuild                     Run make clean before compile
  --distclean                   Run make distclean before compile
  --include-expected-fail       Add expected-fail test into regression
  --stop-on-fail                Stop regression on first test failure
  --uvm-timeout <num>           +UVM_TIMEOUT value (default: 2000000000)
  --uvm-max-quit-count <num>    +UVM_MAX_QUIT_COUNT value (default: 50)
  --tb-hs-timeout <num>         +TB_HS_TIMEOUT cycles (default: 100000)
  --drv-req-timeout <num>       +DRV_REQ_TIMEOUT cycles (default: 100000)
  --test <uvm_test_name>        Add one test (can be repeated)
  --help                        Show this help

Examples:
  ./run_axi_regression.sh
  ./run_axi_regression.sh --seed-start 10001 --seed-step 7
  ./run_axi_regression.sh --rebuild --stop-on-fail
  ./run_axi_regression.sh --uvm-timeout 500000000 --uvm-max-quit-count 20
  ./run_axi_regression.sh --test axi_full_test --test axi_stress_test
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --testbench)
      TESTBENCH="$2"
      shift 2
      ;;
    --seed-start)
      SEED_START="$2"
      shift 2
      ;;
    --seed-step)
      SEED_STEP="$2"
      shift 2
      ;;
    --rebuild)
      REBUILD=1
      shift
      ;;
    --distclean)
      DISTCLEAN=1
      shift
      ;;
    --include-expected-fail)
      INCLUDE_EXPECTED_FAIL=1
      shift
      ;;
    --stop-on-fail)
      STOP_ON_FAIL=1
      shift
      ;;
    --uvm-timeout)
      UVM_TIMEOUT="$2"
      shift 2
      ;;
    --uvm-max-quit-count)
      UVM_MAX_QUIT_COUNT="$2"
      shift 2
      ;;
    --tb-hs-timeout)
      TB_HS_TIMEOUT="$2"
      shift 2
      ;;
    --drv-req-timeout)
      DRV_REQ_TIMEOUT="$2"
      shift 2
      ;;
    --test)
      TESTS+=("$2")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! command -v make >/dev/null 2>&1; then
  echo "[ERR] 'make' not found in PATH" >&2
  exit 2
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  TESTS=("${DEFAULT_TESTS[@]}")
  if [[ $INCLUDE_EXPECTED_FAIL -eq 1 ]]; then
    TESTS+=("${EXPECTED_FAIL_TESTS[@]}")
  fi
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "[ERR] No tests selected" >&2
  exit 2
fi

run_make() {
  echo "[RUN] make $*"
  make "$@"
}

echo "============================================================"
echo "AXI UVM Regression Start"
echo "Project     : $(pwd)"
echo "Testbench   : ${TESTBENCH}"
echo "SeedStart   : ${SEED_START}"
echo "SeedStep    : ${SEED_STEP}"
echo "UVM_TIMEOUT : ${UVM_TIMEOUT}"
echo "UVM_MAX_QUIT_COUNT : ${UVM_MAX_QUIT_COUNT}"
echo "TB_HS_TIMEOUT : ${TB_HS_TIMEOUT}"
echo "DRV_REQ_TIMEOUT : ${DRV_REQ_TIMEOUT}"
echo "Tests       : ${TESTS[*]}"
echo "============================================================"

if [[ $DISTCLEAN -eq 1 ]]; then
  run_make distclean
elif [[ $REBUILD -eq 1 ]]; then
  run_make clean
fi

COMPILE_SEED="$SEED_START"
run_make comp "TEST=${TESTBENCH}" "SEED=${COMPILE_SEED}"

mkdir -p out/logs
STAMP="$(date +%Y%m%d_%H%M%S)"
CSV_PATH="out/logs/regression_summary_${STAMP}.csv"
TXT_PATH="out/logs/regression_summary_${STAMP}.txt"

echo "Test,Seed,Status,Note" > "$CSV_PATH"

ANY_FAIL=0
PASS_COUNT=0
FAIL_COUNT=0

for i in "${!TESTS[@]}"; do
  test_name="${TESTS[$i]}"
  seed=$((SEED_START + i * SEED_STEP))

  echo "------------------------------------------------------------"
  echo "[TEST] ${test_name} (SEED=${seed})"

  status="PASS"
  note=""

  if ! run_make sim "TEST=${TESTBENCH}" "UVM_TEST=${test_name}" "SEED=${seed}" \
    "UVM_TIMEOUT=${UVM_TIMEOUT}" "UVM_MAX_QUIT_COUNT=${UVM_MAX_QUIT_COUNT}" \
    "TB_HS_TIMEOUT=${TB_HS_TIMEOUT}" "DRV_REQ_TIMEOUT=${DRV_REQ_TIMEOUT}"; then
    status="FAIL"
    note="sim failed"
  elif ! run_make check "TEST=${TESTBENCH}" "UVM_TEST=${test_name}" "SEED=${seed}"; then
    status="FAIL"
    note="check failed"
  fi

  if [[ "$status" == "PASS" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    ANY_FAIL=1
  fi

  echo "${test_name},${seed},${status},${note}" >> "$CSV_PATH"

  if [[ "$status" == "FAIL" && $STOP_ON_FAIL -eq 1 ]]; then
    echo "[STOP] stop-on-fail is enabled"
    break
  fi
done

if ! run_make coverage "TEST=${TESTBENCH}"; then
  echo "[FAIL] coverage generation failed"
  ANY_FAIL=1
fi

{
  echo "AXI UVM Regression Summary"
  echo "Time        : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Testbench   : ${TESTBENCH}"
  echo "Total       : $((PASS_COUNT + FAIL_COUNT))"
  echo "PASS        : ${PASS_COUNT}"
  echo "FAIL        : ${FAIL_COUNT}"
  echo "Coverage    : out/coverage_report"
  echo "CSV         : ${CSV_PATH}"
} > "$TXT_PATH"

echo "============================================================"
echo "Regression finished"
echo "Summary TXT : ${TXT_PATH}"
echo "Summary CSV : ${CSV_PATH}"
echo "Coverage    : out/coverage_report"
echo "============================================================"

if [[ $ANY_FAIL -ne 0 ]]; then
  exit 1
fi

exit 0
