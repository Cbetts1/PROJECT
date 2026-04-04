#!/usr/bin/env bash
# tools/system_check.sh — Deep System Check Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Performs deep system scans without making changes:
# 1. All checks from health_check.sh
# 2. Orphaned PID files
# 3. Stale/oversized log files
# 4. Broken symlinks
# 5. Python syntax check
# 6. rc2.d script completeness
# 7. Config consistency
#
# Usage:
#   bash tools/system_check.sh [--quiet]
#
# Severity levels:
#   CRITICAL — System may not boot or function
#   WARNING  — Should be fixed but not blocking
#   INFO     — Informational, minor issues
#
# Exit codes:
#   0 — No critical issues
#   1 — Critical issues found

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

QUIET=0
CRITICAL=0
WARNING=0
INFO=0

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=1 ;;
        --help|-h)
            echo "Usage: $0 [--quiet]"
            echo "Performs deep system scans for issues (no changes made)."
            exit 0
            ;;
    esac
done

log() {
    [ "$QUIET" -eq 0 ] && echo "$*" || true
}

critical() {
    CRITICAL=$((CRITICAL + 1))
    log "[CRITICAL] $*"
}

warning() {
    WARNING=$((WARNING + 1))
    log "[WARNING] $*"
}

info() {
    INFO=$((INFO + 1))
    log "[INFO] $*"
}

ok() {
    [ "$QUIET" -eq 0 ] && log "[OK] $*" || true
}

log "=== AIOS Deep System Check ==="
log "AIOS_ROOT: $AIOS_ROOT"
log "OS_ROOT: $OS_ROOT"
log ""

# ---------------------------------------------------------------------------
# Run basic health check first
# ---------------------------------------------------------------------------
log "--- Running basic health checks ---"
if bash "$SCRIPT_DIR/health_check.sh" --quiet 2>/dev/null; then
    ok "Basic health checks passed"
else
    critical "Basic health checks failed — run tools/health_check.sh for details"
fi
log ""

# ---------------------------------------------------------------------------
# Check 1: Orphaned PID files
# ---------------------------------------------------------------------------
log "--- Check 1: Orphaned PID files ---"

PID_DIR="$OS_ROOT/var/service"
if [ -d "$PID_DIR" ]; then
    orphaned=0
    for pidfile in "$PID_DIR"/*.pid; do
        [ -f "$pidfile" ] || continue
        pid=$(cat "$pidfile" 2>/dev/null || echo "")
        
        if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
            if ! kill -0 "$pid" 2>/dev/null; then
                warning "Orphaned PID file: $pidfile (PID $pid not running)"
                orphaned=$((orphaned + 1))
            else
                ok "PID file valid: $pidfile (PID $pid running)"
            fi
        else
            info "Invalid PID in: $pidfile"
        fi
    done
    
    if [ "$orphaned" -eq 0 ]; then
        ok "No orphaned PID files"
    fi
else
    ok "No PID directory (service dir not created yet)"
fi
log ""

# ---------------------------------------------------------------------------
# Check 2: Stale/oversized log files
# ---------------------------------------------------------------------------
log "--- Check 2: Log file sizes ---"

MAX_LOG_SIZE=$((5 * 1024 * 1024))  # 5MB

LOG_DIRS=(
    "$OS_ROOT/var/log"
    "$AIOS_ROOT/var/log"
)

for log_dir in "${LOG_DIRS[@]}"; do
    [ -d "$log_dir" ] || continue
    
    for logfile in "$log_dir"/*.log; do
        [ -f "$logfile" ] || continue
        
        size=$(stat -c%s "$logfile" 2>/dev/null || stat -f%z "$logfile" 2>/dev/null || echo 0)
        
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            size_mb=$((size / 1024 / 1024))
            warning "Oversized log (${size_mb}MB): $logfile"
        else
            ok "Log size OK: $logfile"
        fi
    done
done
log ""

# ---------------------------------------------------------------------------
# Check 3: Broken symlinks in OS/bin
# ---------------------------------------------------------------------------
log "--- Check 3: Broken symlinks ---"

broken=0
for link in "$OS_ROOT/bin"/*; do
    [ -L "$link" ] || continue
    
    if [ ! -e "$link" ]; then
        warning "Broken symlink: $link"
        broken=$((broken + 1))
    fi
done

if [ "$broken" -eq 0 ]; then
    ok "No broken symlinks in OS/bin"
fi
log ""

# ---------------------------------------------------------------------------
# Check 4: Python syntax check
# ---------------------------------------------------------------------------
log "--- Check 4: Python syntax ---"

py_errors=0
for pyfile in "$AIOS_ROOT/ai/core"/*.py; do
    [ -f "$pyfile" ] || continue
    
    if python3 -m py_compile "$pyfile" 2>/dev/null; then
        ok "Syntax OK: $(basename "$pyfile")"
    else
        critical "Syntax error: $pyfile"
        py_errors=$((py_errors + 1))
    fi
done

if [ "$py_errors" -eq 0 ]; then
    ok "All Python files have valid syntax"
fi
log ""

# ---------------------------------------------------------------------------
# Check 5: rc2.d script completeness
# ---------------------------------------------------------------------------
log "--- Check 5: rc2.d script completeness ---"

for script in "$OS_ROOT/etc/init.d"/*; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    
    has_start=$(grep -q "start)" "$script" && echo "yes" || echo "no")
    has_stop=$(grep -q "stop)" "$script" && echo "yes" || echo "no")
    has_status=$(grep -q "status)" "$script" && echo "yes" || echo "no")
    
    if [ "$has_start" = "yes" ] && [ "$has_stop" = "yes" ]; then
        if [ "$has_status" = "yes" ]; then
            ok "Complete (start/stop/status): $name"
        else
            info "Missing status case: $name"
        fi
    else
        warning "Incomplete script (missing start or stop): $name"
    fi
done
log ""

# ---------------------------------------------------------------------------
# Check 6: Config consistency
# ---------------------------------------------------------------------------
log "--- Check 6: Config consistency ---"

os_conf="$AIOS_ROOT/config/aios.conf"
shell_conf="$AIOS_ROOT/etc/aios.conf"

if [ -f "$os_conf" ] && [ -f "$shell_conf" ]; then
    # Check both files are parseable
    if bash -n "$os_conf" 2>/dev/null && bash -n "$shell_conf" 2>/dev/null; then
        ok "Both config files have valid syntax"
    else
        critical "Config file syntax errors"
    fi
else
    if [ ! -f "$os_conf" ]; then
        critical "Missing: config/aios.conf"
    fi
    if [ ! -f "$shell_conf" ]; then
        critical "Missing: etc/aios.conf"
    fi
fi
log ""

# ---------------------------------------------------------------------------
# Check 7: Service health files
# ---------------------------------------------------------------------------
log "--- Check 7: Service health files ---"

HEALTH_DIR="$OS_ROOT/var/service"
if [ -d "$HEALTH_DIR" ]; then
    for health in "$HEALTH_DIR"/*.health; do
        [ -f "$health" ] || continue
        name=$(basename "$health" .health)
        
        status=$(grep "^status=" "$health" 2>/dev/null | cut -d= -f2 || echo "unknown")
        
        case "$status" in
            ok|running|stopped|disabled)
                ok "Service $name: $status"
                ;;
            *)
                info "Service $name has unusual status: $status"
                ;;
        esac
    done
else
    info "No service health directory (OS not booted yet)"
fi
log ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
log "Critical: $CRITICAL"
log "Warning:  $WARNING"
log "Info:     $INFO"

if [ "$CRITICAL" -gt 0 ]; then
    log ""
    log "Critical issues found! Run tools/system_autofix.sh to attempt repairs."
    exit 1
elif [ "$WARNING" -gt 0 ]; then
    log ""
    log "Warnings found. Consider running tools/system_autofix.sh --dry-run"
    exit 0
else
    log ""
    log "System check passed!"
    exit 0
fi
