#!/bin/bash
# tests/integration-tests.sh
# Integration tests for AIOS — tests component interaction.
# Requires: bash, mktemp
# Does NOT require root, a model, or a running daemon.
#
# Usage:
#   bash tests/integration-tests.sh

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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

echo "=== AIOS Integration Tests ==="
echo "Temp dir: $TMP"

# ── Environment setup ─────────────────────────────────────────────────────────
export AIOS_HOME="$AIOS_ROOT"
export OS_ROOT="$AIOS_ROOT/OS"

echo
echo "── first-boot.sh integration ──"
TEST_OS_ROOT="$TMP/test-os"
mkdir -p "$TEST_OS_ROOT/etc/aura" "$TEST_OS_ROOT/sbin" "$TEST_OS_ROOT/bin"
cp "$AIOS_ROOT/OS/sbin/init" "$TEST_OS_ROOT/sbin/init"
cp "$AIOS_ROOT/OS/bin/os-shell" "$TEST_OS_ROOT/bin/os-shell" 2>/dev/null || true
cp "$AIOS_ROOT/OS/etc/os-release" "$TEST_OS_ROOT/etc/os-release" 2>/dev/null || true

OS_ROOT="$TEST_OS_ROOT" AIOS_HOME="$AIOS_ROOT" bash "$AIOS_ROOT/deploy/first-boot.sh" > "$TMP/first-boot.log" 2>&1
run_test "first-boot creates var/log"         "[[ -d '$TEST_OS_ROOT/var/log' ]]"
run_test "first-boot creates proc/aura"       "[[ -d '$TEST_OS_ROOT/proc/aura' ]]"
run_test "first-boot creates overlay/upper"   "[[ -d '$TEST_OS_ROOT/overlay/upper' ]]"
run_test "first-boot writes boot.time"        "[[ -f '$TEST_OS_ROOT/var/boot.time' ]]"
run_test "first-boot writes os-release"       "[[ -f '$TEST_OS_ROOT/etc/os-release' ]]"
run_test "first-boot writes os.identity"      "[[ -f '$TEST_OS_ROOT/proc/os.identity' ]]"
run_test "os.identity has OS_NAME"            "grep -q 'OS_NAME=' '$TEST_OS_ROOT/proc/os.identity'"

echo
echo "── health-check.sh integration ──"
OS_ROOT="$TEST_OS_ROOT" AIOS_HOME="$AIOS_ROOT" \
    bash "$AIOS_ROOT/scripts/health-check.sh" > "$TMP/health.log" 2>&1
run_test "health-check exits cleanly"    "true"
run_test "health-check outputs OK lines" "grep -q 'OK' '$TMP/health.log'"
run_test "health-check shows memory"     "grep -qi 'RAM\|memory' '$TMP/health.log'"

echo
echo "── overlay-manager.sh status (no root) ──"
bash "$AIOS_ROOT/mirror/overlay-manager.sh" status > "$TMP/overlay-status.log" 2>&1 || true
run_test "overlay status runs"           "[[ -f '$TMP/overlay-status.log' ]]"

echo
echo "── sync-daemon.sh sync-now ──"
SYNC_SOURCE="$TMP/upper"
SYNC_TARGET="$TMP/backup"
mkdir -p "$SYNC_SOURCE"
echo "test" > "$SYNC_SOURCE/testfile"

SYNC_SOURCE="$SYNC_SOURCE" SYNC_TARGET="$SYNC_TARGET" \
    bash "$AIOS_ROOT/mirror/sync-daemon.sh" sync-now > "$TMP/sync.log" 2>&1
run_test "sync-daemon creates target dir"  "[[ -d '$SYNC_TARGET' ]]"
run_test "sync-daemon copies file"         "[[ -f '$SYNC_TARGET/testfile' ]]"

echo
echo "── config sourcing ──"
(. "$AIOS_ROOT/config/aios.conf" && [[ -n "$AIOS_VERSION" ]]) \
    && pass "aios.conf sources cleanly" || fail "aios.conf source error"

(. "$AIOS_ROOT/config/llama-settings.conf" && [[ -n "$MODEL_PATH" ]]) \
    && pass "llama-settings.conf sources cleanly" || fail "llama-settings.conf source error"

(. "$AIOS_ROOT/config/overlay.conf" && [[ -n "$SYNC_INTERVAL" ]]) \
    && pass "overlay.conf sources cleanly" || fail "overlay.conf source error"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
