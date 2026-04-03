#!/bin/bash
# tests/integration-tests.sh — AIOS-Lite Integration Tests
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Run from the repo root:
#   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
#
# Tests the os-shell, os-real-shell, os-kernel, aura-bridge, aura-agents,
# aura-tasks, LLM fallback, agent dispatch, task scheduling, and filesystem
# module — all end-to-end through the actual scripts.

REPO_ROOT="${AIOS_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$REPO_ROOT/OS}"
FS_PY="$OS_ROOT/lib/filesystem.py"

PASS=0
FAIL=0
ERRORS=""

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); ERRORS="$ERRORS\n  - $1"; }

section() { echo; echo "=== $1 ==="; }

export OS_ROOT

# ---------------------------------------------------------------------------
# os-shell: single command mode via echo pipe
# ---------------------------------------------------------------------------
section "os-shell — command dispatch"

_shell() { echo "$1" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null; }

out=$(_shell "help")
echo "$out" | grep -q "AI / LLM" \
    && pass "os-shell: help output contains AI / LLM section" \
    || fail "os-shell: help should contain AI / LLM section"

out=$(_shell "sysinfo")
echo "$out" | grep -qi "name\|version\|host" \
    && pass "os-shell: sysinfo shows system info" \
    || fail "os-shell: sysinfo should show system info"

out=$(_shell "uptime")
echo "$out" | grep -q "Uptime" \
    && pass "os-shell: uptime shows Uptime" \
    || fail "os-shell: uptime should show Uptime"

out=$(_shell "disk")
echo "$out" | grep -q "Disk Usage" \
    && pass "os-shell: disk shows Disk Usage" \
    || fail "os-shell: disk should show Disk Usage"

out=$(_shell "ls")
[ -n "$out" ] \
    && pass "os-shell: ls returns output" \
    || fail "os-shell: ls should return output"

# mem.set / mem.get roundtrip
_tmk="test.key.$$"
echo -e "mem.set $_tmk integration_value\nmem.get $_tmk\nexit" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null | grep -q "integration_value" \
    && pass "os-shell: mem.set/get roundtrip" \
    || fail "os-shell: mem.set/get roundtrip failed"

# sem.set / sem.search
_semk="sem.test.$$"
echo -e "sem.set $_semk hello semantic world\nsem.search hello\nexit" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null | grep -q "$_semk" \
    && pass "os-shell: sem.set/search roundtrip" \
    || fail "os-shell: sem.set/search failed"

# Fuzzy correction: typing "sysinf" should output sysinfo result
out=$(echo "sysinf" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null)
echo "$out" | grep -qi "auto-correcting\|name\|version\|host" \
    && pass "os-shell: fuzzy 'sysinf' corrects to sysinfo" \
    || fail "os-shell: fuzzy correction for 'sysinf' failed"

# AI fallback (no model — rule-based)
out=$(echo "ask hello" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null)
echo "$out" | grep -qi "hello\|AIOS\|assist" \
    && pass "os-shell: ask/AI fallback returns a response" \
    || fail "os-shell: ask/AI fallback should return a response"

# mode command
out=$(printf 'mode system\nmode operator\nexit' | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null)
echo "$out" | grep -q "system" \
    && pass "os-shell: mode command accepted" \
    || fail "os-shell: mode command should be accepted"

# write + read (via fs module)
out=$(printf 'write integration-test-file.txt hello_integration\nread integration-test-file.txt\nexit' | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null)
echo "$out" | grep -q "hello_integration" \
    && pass "os-shell: write/read roundtrip" \
    || fail "os-shell: write/read roundtrip failed"
rm -f "$OS_ROOT/integration-test-file.txt"

# service start/stop/status
out=$(printf 'services\nexit' | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-shell" 2>/dev/null)
echo "$out" | grep -q "Service Status" \
    && pass "os-shell: services command shows Service Status" \
    || fail "os-shell: services command should show Service Status"

# ---------------------------------------------------------------------------
# os-real-shell
# ---------------------------------------------------------------------------
section "os-real-shell — command dispatch"

_rshell() { echo "$1" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-real-shell" 2>/dev/null; }

out=$(_rshell "help")
echo "$out" | grep -q "AI / Memory" \
    && pass "os-real-shell: help shows AI / Memory" \
    || fail "os-real-shell: help should show AI / Memory"

out=$(_rshell "sysinfo")
echo "$out" | grep -qi "host\|cpu\|linux\|darwin\|arch" \
    && pass "os-real-shell: sysinfo shows host info" \
    || fail "os-real-shell: sysinfo should show host info"

out=$(_rshell "netinfo")
echo "$out" | grep -qi "network\|interface\|route\|addr" \
    && pass "os-real-shell: netinfo shows network info" \
    || fail "os-real-shell: netinfo should show network info"

out=$(_rshell "diskinfo")
echo "$out" | grep -qi "disk\|filesystem\|size" \
    && pass "os-real-shell: diskinfo shows disk info" \
    || fail "os-real-shell: diskinfo should show disk info"

out=$(_rshell "logread aura")
echo "$out" | grep -qi "log\|aura\|filesystem\|shell\|install" \
    && pass "os-real-shell: logread aura shows log content" \
    || fail "os-real-shell: logread aura should show log content"

# Real shell passthrough: test that 'echo test_passthrough' works
out=$(echo "echo test_passthrough_$$" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-real-shell" 2>/dev/null)
echo "$out" | grep -q "test_passthrough_$$" \
    && pass "os-real-shell: passthrough real shell command (echo)" \
    || fail "os-real-shell: passthrough should execute real shell commands"

# Fuzzy in real shell: "sysinf" -> sysinfo
out=$(echo "sysinf" | OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-real-shell" 2>/dev/null)
echo "$out" | grep -qi "auto-correcting\|host\|cpu\|linux" \
    && pass "os-real-shell: fuzzy 'sysinf' auto-corrects or falls through" \
    || fail "os-real-shell: fuzzy should auto-correct or pass 'sysinf' to real shell"

# ---------------------------------------------------------------------------
# os-kernel init.d service
# ---------------------------------------------------------------------------
section "os-kernel — init.d service"

# Start kernel
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/os-kernel" start >/dev/null 2>&1
sleep 2

# Check pidfile created
PIDFILE="$OS_ROOT/var/service/os-kernel.pid"
[ -f "$PIDFILE" ] \
    && pass "os-kernel: pid file created after start" \
    || fail "os-kernel: pid file should be created after start"

# Check process is running
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE")
    [ -d "/proc/$pid" ] \
        && pass "os-kernel: daemon process is alive" \
        || fail "os-kernel: daemon process should be alive"
fi

# Check health file
HEALTH="$OS_ROOT/var/service/os-kernel.health"
[ -f "$HEALTH" ] \
    && pass "os-kernel: health file exists" \
    || fail "os-kernel: health file should exist"

status_out=$(OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/os-kernel" status 2>/dev/null)
echo "$status_out" | grep -q "running" \
    && pass "os-kernel: status reports running" \
    || fail "os-kernel: status should report running"

# aura.log should have kernel entry
sleep 1
grep -q "kernel" "$OS_ROOT/var/log/aura.log" 2>/dev/null \
    && pass "os-kernel: audit log has kernel entries" \
    || fail "os-kernel: audit log should have kernel entries"

# Heartbeat written to os.log
[ -s "$OS_ROOT/var/log/os.log" ] \
    && pass "os-kernel: os.log has content after start" \
    || fail "os-kernel: os.log should have content"

# State file refreshed
state_hb=$(grep "last_heartbeat" "$OS_ROOT/proc/os.state" 2>/dev/null | head -1)
[ -n "$state_hb" ] \
    && pass "os-kernel: state file has last_heartbeat entry" \
    || fail "os-kernel: state file should have last_heartbeat"

# Stop kernel
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/os-kernel" stop >/dev/null 2>&1
sleep 1

[ ! -f "$PIDFILE" ] \
    && pass "os-kernel: pid file removed after stop" \
    || fail "os-kernel: pid file should be removed after stop"

# ---------------------------------------------------------------------------
# aura-bridge init.d service
# ---------------------------------------------------------------------------
section "aura-bridge — init.d service"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-bridge" start >/dev/null 2>&1
sleep 1

BRIDGE_HEALTH="$OS_ROOT/var/service/aura-bridge.health"
[ -f "$BRIDGE_HEALTH" ] \
    && pass "aura-bridge: health file created" \
    || fail "aura-bridge: health file should be created"

cat "$BRIDGE_HEALTH" 2>/dev/null | grep -q "running" \
    && pass "aura-bridge: health status is running" \
    || fail "aura-bridge: health status should be running"

BRIDGE_STATUS="$OS_ROOT/proc/aura/bridge/status"
[ -f "$BRIDGE_STATUS" ] \
    && pass "aura-bridge: bridge status file created" \
    || fail "aura-bridge: bridge status file should be created"

cat "$BRIDGE_STATUS" 2>/dev/null | grep -q "host_os" \
    && pass "aura-bridge: status file contains host_os" \
    || fail "aura-bridge: status file should contain host_os"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-bridge" stop >/dev/null 2>&1

# ---------------------------------------------------------------------------
# aura-agents init.d service
# ---------------------------------------------------------------------------
section "aura-agents — init.d service"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-agents" start >/dev/null 2>&1
sleep 2

AGENTS_PID="$OS_ROOT/var/service/aura-agents.pid"
[ -f "$AGENTS_PID" ] && [ -d "/proc/$(cat "$AGENTS_PID" 2>/dev/null)" ] \
    && pass "aura-agents: daemon is running" \
    || fail "aura-agents: daemon should be running"

# Send an event and check agents process it
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-event" "test:integration:event:$$" >/dev/null 2>&1
sleep 2

# Agents log should have entries after events
grep -q "agents" "$OS_ROOT/var/log/aura.log" 2>/dev/null \
    && pass "aura-agents: log has agent entries" \
    || fail "aura-agents: log should have agent entries"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-agents" stop >/dev/null 2>&1

# ---------------------------------------------------------------------------
# aura-tasks init.d service
# ---------------------------------------------------------------------------
section "aura-tasks — init.d service"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-tasks" start >/dev/null 2>&1
sleep 2

TASKS_PID="$OS_ROOT/var/service/aura-tasks.pid"
[ -f "$TASKS_PID" ] && [ -d "/proc/$(cat "$TASKS_PID" 2>/dev/null)" ] \
    && pass "aura-tasks: daemon is running" \
    || fail "aura-tasks: daemon should be running"

grep -q "tasks" "$OS_ROOT/var/log/aura.log" 2>/dev/null \
    && pass "aura-tasks: log has task entries" \
    || fail "aura-tasks: log should have task entries"

# logwatch task triggers on alert message
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-msg" "alert: integration test message $$" >/dev/null 2>&1
sleep 6  # wait for 5s polling cycle
grep -q "logwatch\|alert" "$OS_ROOT/var/log/aura.log" 2>/dev/null \
    && pass "aura-tasks: logwatch task fires on alert message" \
    || fail "aura-tasks: logwatch task should fire on alert message"

OS_ROOT="$OS_ROOT" sh "$OS_ROOT/etc/init.d/aura-tasks" stop >/dev/null 2>&1

# ---------------------------------------------------------------------------
# os-kernelctl
# ---------------------------------------------------------------------------
section "os-kernelctl"

out=$(OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-kernelctl" status 2>/dev/null)
[ -n "$out" ] && pass "os-kernelctl: status returns output" || fail "os-kernelctl: status should return output"

out=$(OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-kernelctl" info 2>/dev/null)
echo "$out" | grep -qi "kernel\|personality\|name\|version" \
    && pass "os-kernelctl: info shows personality" \
    || fail "os-kernelctl: info should show kernel personality"

# ---------------------------------------------------------------------------
# os-event + os-msg
# ---------------------------------------------------------------------------
section "os-event and os-msg"

TS=$(date +%s%N)
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-event" "unit:test:event:$TS" >/dev/null 2>&1

# Event file created in var/events/
ls "$OS_ROOT/var/events/"*.event 2>/dev/null | head -1 | grep -q ".event" \
    && pass "os-event: event file created" \
    || fail "os-event: event file should be created"

# Event log entry
grep -q "unit:test:event:$TS" "$OS_ROOT/var/log/events.log" 2>/dev/null \
    && pass "os-event: event appears in events.log" \
    || fail "os-event: event should appear in events.log"

# os-msg
OS_ROOT="$OS_ROOT" sh "$OS_ROOT/bin/os-msg" "integration-test-message-$TS" >/dev/null 2>&1
grep -q "integration-test-message-$TS" "$OS_ROOT/proc/os.messages" 2>/dev/null \
    && pass "os-msg: message written to os.messages" \
    || fail "os-msg: message should be written to os.messages"

# ---------------------------------------------------------------------------
# LLM module (rule-based fallback, no model needed)
# ---------------------------------------------------------------------------
section "LLM module — rule-based fallback"

out=$(OS_ROOT="$OS_ROOT" sh -c '. "$OS_ROOT/lib/aura-llm/llm.mod"; llm_fallback "hello there"' 2>/dev/null)
echo "$out" | grep -qi "hello\|AIOS\|assist" \
    && pass "llm_fallback: hello triggers greeting" \
    || fail "llm_fallback: hello should trigger greeting response"

out=$(OS_ROOT="$OS_ROOT" sh -c '. "$OS_ROOT/lib/aura-llm/llm.mod"; llm_fallback "what is the time"' 2>/dev/null)
echo "$out" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}:[0-9]{2}" \
    && pass "llm_fallback: time query returns a timestamp" \
    || fail "llm_fallback: time query should return a timestamp"

out=$(OS_ROOT="$OS_ROOT" sh -c '. "$OS_ROOT/lib/aura-llm/llm.mod"; llm_fallback "how is your status"' 2>/dev/null)
echo "$out" | grep -qi "status\|operational\|running" \
    && pass "llm_fallback: status query returns status response" \
    || fail "llm_fallback: status query should return a status response"

# llm_available returns non-zero when no binary present (rule-based path)
out=$(OS_ROOT="$OS_ROOT" sh -c '. "$OS_ROOT/lib/aura-llm/llm.mod"; llm_available 2>/dev/null; echo $?' 2>/dev/null | tail -1)
[ "$out" = "0" ] || [ "$out" = "1" ] \
    && pass "llm_available: returns 0 (found) or 1 (not found)" \
    || fail "llm_available: should return 0 or 1"

# ---------------------------------------------------------------------------
# Hybrid memory
# ---------------------------------------------------------------------------
section "Hybrid memory (symbolic + semantic + context)"

out=$(OS_ROOT="$OS_ROOT" sh -c '
. "$OS_ROOT/lib/aura-memory/engine.mod"
. "$OS_ROOT/lib/aura-semantic/embed.mod"
. "$OS_ROOT/lib/aura-semantic/engine.mod"
. "$OS_ROOT/lib/aura-hybrid/engine.mod"

mem_set "inttest.key" "integration_symbolic_value"
result=$(mem_get "inttest.key")
echo "$result"
' 2>/dev/null)
echo "$out" | grep -q "integration_symbolic_value" \
    && pass "hybrid: mem_set/get symbolic roundtrip" \
    || fail "hybrid: mem_set/get should work"

out=$(OS_ROOT="$OS_ROOT" sh -c '
. "$OS_ROOT/lib/aura-semantic/embed.mod"
. "$OS_ROOT/lib/aura-semantic/engine.mod"
semantic_store "inttest.sem" "quick brown fox jumps"
result=$(semantic_get "inttest.sem")
echo "$result"
' 2>/dev/null)
echo "$out" | grep -q "quick brown fox" \
    && pass "hybrid: semantic_store/get roundtrip" \
    || fail "hybrid: semantic_store/get should work"

# ---------------------------------------------------------------------------
# Filesystem module — Python API
# ---------------------------------------------------------------------------
section "filesystem.py — Python API"

# Write from Python API directly
python3 - << 'PYEOF' 2>/dev/null
import os, sys
sys.path.insert(0, os.environ.get('OS_ROOT', '') + '/lib')
os.chdir('/')
import importlib.util
spec = importlib.util.spec_from_file_location(
    "filesystem",
    os.path.join(os.environ.get('OS_ROOT', ''), 'lib', 'filesystem.py')
)
mod = importlib.util.load_from_spec = spec
PYEOF

# Use CLI instead (simpler)
_tmp="tmp/inttest-py-$$.txt"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" write "$_tmp" "py_api_value_$$" 2>/dev/null
result=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "$_tmp" 2>/dev/null)
echo "$result" | grep -q "py_api_value_$$" \
    && pass "filesystem.py: Python write/read via CLI" \
    || fail "filesystem.py: Python write/read should work"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" log var/log/aura.log "inttest log entry $$" 2>/dev/null
OS_ROOT="$OS_ROOT" python3 "$FS_PY" read var/log/aura.log 2>/dev/null | grep -q "inttest log entry $$" \
    && pass "filesystem.py: log entry appears in aura.log" \
    || fail "filesystem.py: log entry should appear in aura.log"
rm -f "$OS_ROOT/$_tmp"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "════════════════════════════════════════"
echo "Integration Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    printf "Failures:%b\n" "$ERRORS"
    exit 1
fi
echo "All integration tests passed."
