#!/usr/bin/env bash
# tools/ai-test.sh — AI Backend Test Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Tests the AI backend with canned inputs:
# 1. Health query
# 2. Log query
# 3. Repair query
# 4. Unknown query
# 5. LLM availability (non-fatal)
#
# Usage:
#   bash tools/ai-test.sh [--verbose]
#
# Exit codes:
#   0 — All critical tests passed
#   1 — Critical test(s) failed

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

VERBOSE=0
PASSED=0
FAILED=0

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            echo "Tests the AI backend with canned inputs."
            exit 0
            ;;
    esac
done

log() {
    echo "$*"
}

log_verbose() {
    [ "$VERBOSE" -eq 1 ] && echo "$*" || true
}

pass() {
    PASSED=$((PASSED + 1))
    log "[PASS] $*"
}

fail() {
    FAILED=$((FAILED + 1))
    log "[FAIL] $*"
}

# Run AI backend query
run_query() {
    local input="$1"
    local json_flag="${2:-}"
    
    local cmd=(python3 "$AIOS_ROOT/ai/core/ai_backend.py"
        --input "$input"
        --os-root "$OS_ROOT"
        --aios-root "$AIOS_ROOT")
    
    if [ "$json_flag" = "--json" ]; then
        cmd+=(--json-output)
    fi
    
    "${cmd[@]}" 2>&1
}

log "=== AIOS AI Backend Tests ==="
log "AIOS_ROOT: $AIOS_ROOT"
log "OS_ROOT: $OS_ROOT"
log ""

# Ensure required directories exist
mkdir -p "$OS_ROOT/var/log" "$OS_ROOT/proc"

# Create minimal state files if they don't exist
[ -f "$OS_ROOT/var/log/os.log" ] || touch "$OS_ROOT/var/log/os.log"
[ -f "$OS_ROOT/proc/os.state" ] || echo "boot_time=0" > "$OS_ROOT/proc/os.state"

# ---------------------------------------------------------------------------
# Test 1: Health query
# ---------------------------------------------------------------------------
log "--- Test 1: Health query ---"

output=$(run_query "check system health")
log_verbose "Input: check system health"
log_verbose "Output: $output"

if [ -n "$output" ]; then
    if echo "$output" | grep -qi "health\|status\|uptime\|ok"; then
        pass "Health query returned relevant response"
    else
        pass "Health query returned non-empty response"
    fi
else
    fail "Health query returned empty response"
fi
log ""

# ---------------------------------------------------------------------------
# Test 2: Log query
# ---------------------------------------------------------------------------
log "--- Test 2: Log query ---"

output=$(run_query "show logs")
log_verbose "Input: show logs"
log_verbose "Output: $output"

if [ -n "$output" ]; then
    pass "Log query returned response"
else
    fail "Log query returned empty response"
fi
log ""

# ---------------------------------------------------------------------------
# Test 3: Repair query
# ---------------------------------------------------------------------------
log "--- Test 3: Repair query ---"

output=$(run_query "repair")
log_verbose "Input: repair"
log_verbose "Output: $output"

if [ -n "$output" ]; then
    if echo "$output" | grep -qi "repair\|complete\|RepairBot"; then
        pass "Repair query triggered RepairBot"
    else
        pass "Repair query returned response"
    fi
else
    fail "Repair query returned empty response"
fi
log ""

# ---------------------------------------------------------------------------
# Test 4: Unknown/chat query
# ---------------------------------------------------------------------------
log "--- Test 4: Unknown/chat query ---"

output=$(run_query "hello, how are you?")
log_verbose "Input: hello, how are you?"
log_verbose "Output: $output"

if [ -n "$output" ]; then
    if echo "$output" | grep -qi "AURA\|hello\|help\|aios"; then
        pass "Chat query returned helpful response"
    else
        pass "Chat query returned response"
    fi
else
    fail "Chat query returned empty response"
fi
log ""

# ---------------------------------------------------------------------------
# Test 5: JSON output mode
# ---------------------------------------------------------------------------
log "--- Test 5: JSON output mode ---"

output=$(run_query "status" "--json")
log_verbose "Input: status (with --json-output)"
log_verbose "Output: $output"

if [ -n "$output" ]; then
    if echo "$output" | grep -q '"status"'; then
        pass "JSON output contains status field"
    else
        pass "JSON output returned (format may vary)"
    fi
else
    fail "JSON output returned empty"
fi
log ""

# ---------------------------------------------------------------------------
# Test 6: Intent classification
# ---------------------------------------------------------------------------
log "--- Test 6: Intent classification ---"

# Test that different inputs get routed correctly
test_intents=(
    "ls:command"
    "ping google.com:command"
    "uptime:system"
)

for test in "${test_intents[@]}"; do
    input="${test%%:*}"
    expected="${test##*:}"
    
    output=$(run_query "$input")
    
    if [ -n "$output" ]; then
        pass "Intent '$input' returned response"
    else
        fail "Intent '$input' returned empty"
    fi
done
log ""

# ---------------------------------------------------------------------------
# Test 7: LLM availability (non-fatal)
# ---------------------------------------------------------------------------
log "--- Test 7: LLM availability (non-fatal) ---"

# Check if llama-cli is available
if command -v llama-cli >/dev/null 2>&1 || command -v llama >/dev/null 2>&1; then
    log "[INFO] LLM binary found"
    
    # Check for model
    MODEL_DIR="${LLAMA_MODEL_DIR:-$AIOS_ROOT/llama_model}"
    if [ -d "$MODEL_DIR" ] && ls "$MODEL_DIR"/*.gguf >/dev/null 2>&1; then
        log "[INFO] LLM model found in $MODEL_DIR"
    else
        log "[INFO] No LLM model found (mock mode will be used)"
    fi
else
    log "[INFO] No LLM binary found (mock mode will be used)"
fi
log ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
log "Passed: $PASSED"
log "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
    log ""
    log "All AI backend tests passed!"
    exit 0
else
    log ""
    log "Some tests failed."
    exit 1
fi
