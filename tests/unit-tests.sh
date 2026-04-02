#!/bin/bash
# tests/unit-tests.sh
# Unit tests for AIOS components.
# Tests are self-contained and do not require a model or root.
#
# Usage:
#   bash tests/unit-tests.sh

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS_ROOT="$AIOS_ROOT/OS"
PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

run_test() {
    local name="$1"
    shift
    if eval "$@" >/dev/null 2>&1; then
        pass "$name"
    else
        fail "$name"
    fi
}

echo "=== AIOS Unit Tests ==="

# ── File presence ─────────────────────────────────────────────────────────────
echo
echo "── Core files ──"
run_test "OS/sbin/init exists"    "[[ -f '$OS_ROOT/sbin/init' ]]"
run_test "OS/bin/os-shell exists" "[[ -f '$OS_ROOT/bin/os-shell' ]]"
run_test "OS/bin/sysinfo exists"  "[[ -f '$OS_ROOT/bin/sysinfo' ]]"
run_test "OS/etc/os-release"      "[[ -f '$OS_ROOT/etc/os-release' ]]"
run_test "config/aios.conf"       "[[ -f '$AIOS_ROOT/config/aios.conf' ]]"
run_test "config/llama-settings"  "[[ -f '$AIOS_ROOT/config/llama-settings.conf' ]]"
run_test "config/overlay.conf"    "[[ -f '$AIOS_ROOT/config/overlay.conf' ]]"
run_test "README.md"              "[[ -f '$AIOS_ROOT/README.md' ]]"
run_test "QUICKSTART.md"          "[[ -f '$AIOS_ROOT/QUICKSTART.md' ]]"

echo
echo "── Script executability ──"
for f in \
    "$AIOS_ROOT/deploy/container-installer.sh" \
    "$AIOS_ROOT/deploy/first-boot.sh" \
    "$AIOS_ROOT/deploy/phone-optimizations.sh" \
    "$AIOS_ROOT/mirror/overlay-manager.sh" \
    "$AIOS_ROOT/mirror/sync-daemon.sh" \
    "$AIOS_ROOT/scripts/health-check.sh" \
    "$AIOS_ROOT/scripts/benchmark.sh" \
    "$AIOS_ROOT/ai/shell-interface/ai-ask.sh" \
    "$AIOS_ROOT/ai/inference-engine/start-daemon.sh" \
    "$AIOS_ROOT/ai/model-quantizer/download-model.sh"
do
    name="$(basename "$f") is executable"
    run_test "$name" "[[ -x '$f' ]]"
done

echo
echo "── Config parsing ──"
run_test "aios.conf: AIOS_VERSION set" "grep -q 'AIOS_VERSION=' '$AIOS_ROOT/config/aios.conf'"
run_test "aios.conf: CPU affinity set" "grep -q 'LLAMA_CPU_AFFINITY=' '$AIOS_ROOT/config/aios.conf'"
run_test "llama-settings: MODEL_PATH"  "grep -q 'MODEL_PATH=' '$AIOS_ROOT/config/llama-settings.conf'"
run_test "llama-settings: THREADS"     "grep -q 'THREADS=' '$AIOS_ROOT/config/llama-settings.conf'"

echo
echo "── OS shell syntax ──"
run_test "os-shell sh syntax" "bash -n '$OS_ROOT/bin/os-shell'"
run_test "os-info sh syntax"  "bash -n '$OS_ROOT/bin/os-info'"
run_test "sysinfo sh syntax"  "bash -n '$OS_ROOT/bin/sysinfo'"

echo
echo "── Deploy script syntax ──"
for f in \
    "$AIOS_ROOT/deploy/container-installer.sh" \
    "$AIOS_ROOT/deploy/first-boot.sh" \
    "$AIOS_ROOT/deploy/phone-optimizations.sh" \
    "$AIOS_ROOT/mirror/overlay-manager.sh" \
    "$AIOS_ROOT/mirror/sync-daemon.sh"
do
    run_test "$(basename "$f") syntax" "bash -n '$f'"
done

echo
echo "── AI script syntax ──"
for f in \
    "$AIOS_ROOT/ai/shell-interface/ai-ask.sh" \
    "$AIOS_ROOT/ai/inference-engine/start-daemon.sh" \
    "$AIOS_ROOT/ai/inference-engine/stop-daemon.sh" \
    "$AIOS_ROOT/ai/model-quantizer/download-model.sh" \
    "$AIOS_ROOT/ai/model-quantizer/quantize.sh" \
    "$AIOS_ROOT/ai/llama-integration/build.sh"
do
    run_test "$(basename "$f") syntax" "bash -n '$f'"
done

echo
echo "── Script syntax (scripts/) ──"
for f in \
    "$AIOS_ROOT/scripts/optimize-for-phone.sh" \
    "$AIOS_ROOT/scripts/compress-rootfs.sh" \
    "$AIOS_ROOT/scripts/benchmark.sh" \
    "$AIOS_ROOT/scripts/health-check.sh"
do
    run_test "$(basename "$f") syntax" "bash -n '$f'"
done

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
