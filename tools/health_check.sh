#!/usr/bin/env bash
# tools/health_check.sh — Comprehensive Health Check Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Performs comprehensive health checks on the AIOS installation:
# 1. Directory structure verification
# 2. Key files present
# 3. Permission checks
# 4. Boot dry-run
# 5. Python AI core import test
#
# Usage:
#   bash tools/health_check.sh [--quiet]
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

QUIET=0
PASSED=0
FAILED=0

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=1 ;;
        --help|-h)
            echo "Usage: $0 [--quiet]"
            echo "Runs comprehensive health checks on the AIOS installation."
            exit 0
            ;;
    esac
done

log() {
    [ "$QUIET" -eq 0 ] && echo "$*" || true
}

pass() {
    PASSED=$((PASSED + 1))
    log "[PASS] $*"
}

fail() {
    FAILED=$((FAILED + 1))
    log "[FAIL] $*"
}

log "=== AIOS Health Check ==="
log "AIOS_ROOT: $AIOS_ROOT"
log "OS_ROOT: $OS_ROOT"
log ""

# ---------------------------------------------------------------------------
# Check 1: Directory structure
# ---------------------------------------------------------------------------
log "--- Check 1: Directory structure ---"

REQUIRED_DIRS=(
    "$AIOS_ROOT/bin"
    "$AIOS_ROOT/lib"
    "$AIOS_ROOT/etc"
    "$AIOS_ROOT/config"
    "$AIOS_ROOT/ai/core"
    "$AIOS_ROOT/tools"
    "$OS_ROOT/bin"
    "$OS_ROOT/sbin"
    "$OS_ROOT/etc/init.d"
    "$OS_ROOT/etc/rc2.d"
    "$OS_ROOT/var/log"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        pass "Directory exists: $dir"
    else
        fail "Directory missing: $dir"
    fi
done
log ""

# ---------------------------------------------------------------------------
# Check 2: Key files present
# ---------------------------------------------------------------------------
log "--- Check 2: Key files present ---"

REQUIRED_FILES=(
    "$OS_ROOT/sbin/init"
    "$AIOS_ROOT/bin/aios"
    "$AIOS_ROOT/etc/aios.conf"
    "$AIOS_ROOT/config/aios.conf"
    "$AIOS_ROOT/lib/aura-core.sh"
    "$AIOS_ROOT/ai/core/ai_backend.py"
    "$AIOS_ROOT/ai/core/intent_engine.py"
    "$AIOS_ROOT/ai/core/router.py"
    "$AIOS_ROOT/ai/core/bots.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        pass "File exists: $file"
    else
        fail "File missing: $file"
    fi
done
log ""

# ---------------------------------------------------------------------------
# Check 3: Permissions
# ---------------------------------------------------------------------------
log "--- Check 3: Permissions ---"

# Check bin/ files are executable
for file in "$AIOS_ROOT/bin"/*; do
    [ -f "$file" ] || continue
    if [ -x "$file" ]; then
        pass "Executable: $file"
    else
        fail "Not executable: $file"
    fi
done

# Check init scripts
if [ -x "$OS_ROOT/sbin/init" ]; then
    pass "Executable: OS/sbin/init"
else
    fail "Not executable: OS/sbin/init"
fi

# Check rc2.d services (via symlinks or direct files)
for link in "$OS_ROOT/etc/rc2.d"/S*; do
    [ -e "$link" ] || continue
    name=$(basename "$link")
    
    if [ -L "$link" ]; then
        target=$(readlink -f "$link" 2>/dev/null || echo "")
        if [ -n "$target" ] && [ -x "$target" ]; then
            pass "Service executable: $name"
        else
            fail "Service not executable: $name"
        fi
    elif [ -x "$link" ]; then
        pass "Service executable: $name"
    else
        fail "Service not executable: $name"
    fi
done
log ""

# ---------------------------------------------------------------------------
# Check 4: Boot dry-run
# ---------------------------------------------------------------------------
log "--- Check 4: Boot dry-run ---"

# Create a temporary OS_ROOT for the dry run
TEMP_OS_ROOT=$(mktemp -d "${AIOS_ROOT}/OS/tmp/health-check-XXXXXX" 2>/dev/null || mktemp -d)
mkdir -p "$TEMP_OS_ROOT/etc/rc2.d" "$TEMP_OS_ROOT/var/log" "$TEMP_OS_ROOT/sbin"

# Copy init script
cp "$OS_ROOT/sbin/init" "$TEMP_OS_ROOT/sbin/init"

# Create empty rc2.d to test empty-check warning
boot_output=$(OS_ROOT="$TEMP_OS_ROOT" AIOS_HOME="$AIOS_ROOT" sh "$TEMP_OS_ROOT/sbin/init" --no-shell 2>&1 || true)

if echo "$boot_output" | grep -q "AIOS-Lite boot complete"; then
    pass "Boot dry-run completed successfully"
else
    fail "Boot dry-run did not complete"
    [ "$QUIET" -eq 0 ] && echo "Output: $boot_output" | head -10
fi

# Cleanup
rm -rf "$TEMP_OS_ROOT"
log ""

# ---------------------------------------------------------------------------
# Check 5: Python AI core imports
# ---------------------------------------------------------------------------
log "--- Check 5: Python AI core imports ---"

PYTHON_CHECK='
import sys
sys.path.insert(0, "ai/core")
try:
    import ai_backend
    import intent_engine
    import router
    import bots
    import commands
    import fuzzy
    import llama_client
    print("OK")
except ImportError as e:
    print(f"FAIL: {e}")
    sys.exit(1)
'

cd "$AIOS_ROOT"
python_result=$(python3 -c "$PYTHON_CHECK" 2>&1)

if [ "$python_result" = "OK" ]; then
    pass "Python AI core modules import successfully"
else
    fail "Python AI core import failed: $python_result"
fi
log ""

# ---------------------------------------------------------------------------
# Check 6: Config files parseable
# ---------------------------------------------------------------------------
log "--- Check 6: Config files ---"

if bash -n "$AIOS_ROOT/config/aios.conf" 2>/dev/null; then
    pass "config/aios.conf is valid shell syntax"
else
    fail "config/aios.conf has syntax errors"
fi

if bash -n "$AIOS_ROOT/etc/aios.conf" 2>/dev/null; then
    pass "etc/aios.conf is valid shell syntax"
else
    fail "etc/aios.conf has syntax errors"
fi
log ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
log "Passed: $PASSED"
log "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
    log "All health checks passed!"
    exit 0
else
    log "Some health checks failed."
    exit 1
fi
