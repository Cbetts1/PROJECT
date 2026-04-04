#!/usr/bin/env bash
# tools/production-audit.sh — Comprehensive Production Readiness Check
# © 2026 Chris Betts | AIOSCPU Official
#
# Runs all available audit tools and produces a final readiness report:
#   - health_check.sh
#   - system_check.sh
#   - security-audit.sh
#   - offline-check.sh
#   - perms-audit.sh
#   - config-audit.sh
#
# Usage:
#   bash tools/production-audit.sh
#
# Exit codes:
#   0 — Production ready
#   1 — Warnings present
#   2 — Critical issues found

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="$OS_ROOT/var/log"
AUDIT_LOG="$LOG_DIR/audit-$TIMESTAMP.log"

mkdir -p "$LOG_DIR" 2>/dev/null

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0

# Results storage
declare -a RESULTS

_ts() { date '+%Y-%m-%dT%H:%M:%SZ'; }

log_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case "$status" in
        PASS)   PASSED_CHECKS=$((PASSED_CHECKS + 1)); icon="✓" ;;
        WARN)   WARNING_CHECKS=$((WARNING_CHECKS + 1)); icon="⚠" ;;
        FAIL)   FAILED_CHECKS=$((FAILED_CHECKS + 1)); icon="✗" ;;
    esac
    
    RESULTS+=("[$icon] $name: $message")
    echo "[$(_ts)] [$status] $name: $message" >> "$AUDIT_LOG"
}

run_check() {
    local name="$1"
    local script="$2"
    local args="${3:-}"
    
    echo "--- Running: $name ---"
    
    if [ ! -f "$script" ]; then
        log_result "$name" "WARN" "Script not found: $script"
        return
    fi
    
    local output
    local exit_code=0
    
    output=$(bash "$script" $args --quiet 2>&1) || exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_result "$name" "PASS" "Passed"
    elif [ $exit_code -eq 1 ]; then
        log_result "$name" "WARN" "Warnings found"
    else
        log_result "$name" "FAIL" "Failed (exit $exit_code)"
    fi
    
    # Log full output
    echo "=== $name output ===" >> "$AUDIT_LOG"
    echo "$output" >> "$AUDIT_LOG"
    echo "" >> "$AUDIT_LOG"
}

echo "=============================================="
echo "  AIOS Production Readiness Audit"
echo "  Started: $(_ts)"
echo "=============================================="
echo ""
echo "AIOS_ROOT: $AIOS_ROOT"
echo "OS_ROOT: $OS_ROOT"
echo "Log: $AUDIT_LOG"
echo ""

# Header in log
echo "AIOS Production Readiness Audit" > "$AUDIT_LOG"
echo "Started: $(_ts)" >> "$AUDIT_LOG"
echo "AIOS_ROOT: $AIOS_ROOT" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"

# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------

echo "=== Phase 1: Health Checks ==="
run_check "Health Check" "$AIOS_ROOT/tools/health_check.sh"
run_check "System Check" "$AIOS_ROOT/tools/system_check.sh"

echo ""
echo "=== Phase 2: Security Checks ==="
run_check "Security Audit" "$AIOS_ROOT/tools/security-audit.sh"
run_check "Permissions Audit" "$AIOS_ROOT/tools/perms-audit.sh"

echo ""
echo "=== Phase 3: Configuration Checks ==="
run_check "Config Audit" "$AIOS_ROOT/tools/config-audit.sh"
run_check "Offline Check" "$AIOS_ROOT/tools/offline-check.sh"

echo ""
echo "=== Phase 4: Module Verification ==="
if [ -f "$AIOS_ROOT/tools/module-ctl.sh" ]; then
    echo "--- Running: Module Verification ---"
    if bash "$AIOS_ROOT/tools/module-ctl.sh" check --quiet >> "$AUDIT_LOG" 2>&1; then
        log_result "Module Check" "PASS" "All modules present"
    else
        log_result "Module Check" "WARN" "Some modules missing"
    fi
else
    log_result "Module Check" "WARN" "module-ctl.sh not found"
fi

echo ""
echo "=== Phase 5: Service Verification ==="
if [ -f "$AIOS_ROOT/tools/service-ctl.sh" ]; then
    echo "--- Running: Service Verification ---"
    svc_output=$(bash "$AIOS_ROOT/tools/service-ctl.sh" list 2>&1)
    echo "$svc_output" >> "$AUDIT_LOG"
    
    # Check for dead services
    if echo "$svc_output" | grep -q "dead"; then
        log_result "Service Check" "WARN" "Dead services detected"
    else
        log_result "Service Check" "PASS" "All services OK"
    fi
else
    log_result "Service Check" "WARN" "service-ctl.sh not found"
fi

echo ""
echo "=== Phase 6: Manifest Verification ==="
MANIFEST="$OS_ROOT/proc/os.manifest"
if [ -f "$MANIFEST" ]; then
    echo "--- Running: Manifest Verification ---"
    manifest_errors=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        checksum=$(echo "$line" | awk '{print $1}')
        filepath=$(echo "$line" | awk '{print $2}')
        
        if [ -f "$AIOS_ROOT/$filepath" ]; then
            actual=$(sha256sum "$AIOS_ROOT/$filepath" 2>/dev/null | awk '{print $1}')
            if [ "$actual" != "$checksum" ]; then
                manifest_errors=$((manifest_errors + 1))
                echo "Checksum mismatch: $filepath" >> "$AUDIT_LOG"
            fi
        else
            manifest_errors=$((manifest_errors + 1))
            echo "File missing: $filepath" >> "$AUDIT_LOG"
        fi
    done < "$MANIFEST"
    
    if [ $manifest_errors -eq 0 ]; then
        log_result "Manifest Check" "PASS" "All checksums match"
    else
        log_result "Manifest Check" "WARN" "$manifest_errors files differ"
    fi
else
    log_result "Manifest Check" "WARN" "No manifest file (run generate-manifest.sh)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  PRODUCTION READINESS SUMMARY"
echo "=============================================="
echo ""

for result in "${RESULTS[@]}"; do
    echo "  $result"
done

echo ""
echo "----------------------------------------------"
echo "  Total Checks:   $TOTAL_CHECKS"
echo "  Passed:         $PASSED_CHECKS"
echo "  Warnings:       $WARNING_CHECKS"
echo "  Failed:         $FAILED_CHECKS"
echo "----------------------------------------------"

# Calculate score
if [ $TOTAL_CHECKS -gt 0 ]; then
    SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    SCORE=0
fi

echo ""
echo "  Readiness Score: $SCORE%"
echo ""

# Write summary to log
echo "" >> "$AUDIT_LOG"
echo "=== SUMMARY ===" >> "$AUDIT_LOG"
echo "Total: $TOTAL_CHECKS, Passed: $PASSED_CHECKS, Warnings: $WARNING_CHECKS, Failed: $FAILED_CHECKS" >> "$AUDIT_LOG"
echo "Score: $SCORE%" >> "$AUDIT_LOG"
echo "Completed: $(_ts)" >> "$AUDIT_LOG"

# Determine exit code and status
if [ $FAILED_CHECKS -gt 0 ]; then
    echo "Status: CRITICAL ISSUES FOUND"
    echo "Review $AUDIT_LOG for details."
    exit 2
elif [ $WARNING_CHECKS -gt 0 ]; then
    echo "Status: WARNINGS PRESENT"
    echo "System may be production-ready with caveats."
    echo "Review $AUDIT_LOG for details."
    exit 1
else
    echo "Status: PRODUCTION READY"
    echo "All checks passed!"
    exit 0
fi
