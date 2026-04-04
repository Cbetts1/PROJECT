#!/usr/bin/env bash
# tools/config-audit.sh — Configuration Audit Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Audits configuration files for:
# 1. Variables defined in one config but not the other
# 2. Hard-coded absolute paths in scripts
# 3. Conflicts between config files
#
# Usage:
#   bash tools/config-audit.sh [--verbose]
#
# Exit codes:
#   0 — No issues found
#   1 — Issues found (for information only)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

OS_CONF="$AIOS_ROOT/config/aios.conf"
SHELL_CONF="$AIOS_ROOT/etc/aios.conf"

VERBOSE=0
ISSUES=0
WARNINGS=0

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            echo "Audits configuration files for inconsistencies and hard-coded paths."
            exit 0
            ;;
    esac
done

log() {
    echo "[config-audit] $*"
}

log_verbose() {
    [ "$VERBOSE" -eq 1 ] && echo "[config-audit] $*" || true
}

issue() {
    echo "[ISSUE] $*"
    ISSUES=$((ISSUES + 1))
}

warning() {
    echo "[WARNING] $*"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo "[INFO] $*"
}

# Extract variable names from a shell config file
extract_vars() {
    local file="$1"
    grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$file" 2>/dev/null | cut -d= -f1 | sort -u
}

log "Starting configuration audit..."
log "OS-level config: $OS_CONF"
log "Shell-level config: $SHELL_CONF"
echo ""

# ---------------------------------------------------------------------------
# Check 1: Config files exist
# ---------------------------------------------------------------------------
log "=== Check 1: Config files exist ==="

if [ ! -f "$OS_CONF" ]; then
    issue "OS-level config not found: $OS_CONF"
else
    log_verbose "Found $OS_CONF"
fi

if [ ! -f "$SHELL_CONF" ]; then
    issue "Shell-level config not found: $SHELL_CONF"
else
    log_verbose "Found $SHELL_CONF"
fi

if [ ! -f "$OS_CONF" ] || [ ! -f "$SHELL_CONF" ]; then
    log "Cannot continue audit without both config files."
    exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# Check 2: Variables defined in one but not the other
# ---------------------------------------------------------------------------
log "=== Check 2: Variable coverage ==="

OS_VARS=$(extract_vars "$OS_CONF")
SHELL_VARS=$(extract_vars "$SHELL_CONF")

# Find variables unique to each config
ONLY_IN_OS=""
ONLY_IN_SHELL=""

for var in $OS_VARS; do
    if ! echo "$SHELL_VARS" | grep -qx "$var"; then
        ONLY_IN_OS="$ONLY_IN_OS $var"
    fi
done

for var in $SHELL_VARS; do
    if ! echo "$OS_VARS" | grep -qx "$var"; then
        ONLY_IN_SHELL="$ONLY_IN_SHELL $var"
    fi
done

if [ -n "$ONLY_IN_OS" ]; then
    info "Variables in config/aios.conf but not in etc/aios.conf:"
    for var in $ONLY_IN_OS; do
        echo "  - $var"
    done
fi

if [ -n "$ONLY_IN_SHELL" ]; then
    info "Variables in etc/aios.conf but not in config/aios.conf:"
    for var in $ONLY_IN_SHELL; do
        echo "  - $var"
    done
fi

if [ -z "$ONLY_IN_OS" ] && [ -z "$ONLY_IN_SHELL" ]; then
    log_verbose "All variables are defined in both configs"
fi
echo ""

# ---------------------------------------------------------------------------
# Check 3: Hard-coded absolute paths in scripts
# ---------------------------------------------------------------------------
log "=== Check 3: Hard-coded absolute paths ==="

HARDCODED_PATHS=()

# Patterns to look for (should be guarded by variables)
PATTERNS="/home/|/usr/local/|/opt/|/var/log/[^$]|/etc/[^$]"

# Directories to scan
SCAN_DIRS=(
    "$AIOS_ROOT/bin"
    "$AIOS_ROOT/lib"
    "$AIOS_ROOT/tools"
    "$OS_ROOT/bin"
    "$OS_ROOT/sbin"
    "$OS_ROOT/etc/init.d"
)

for dir in "${SCAN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        [ -L "$file" ] && continue
        
        # Skip binary files
        file_type=$(file -b "$file" 2>/dev/null || echo "unknown")
        case "$file_type" in
            *executable*|*ELF*|*binary*) continue ;;
        esac
        
        # Look for hard-coded paths
        matches=$(grep -nE "$PATTERNS" "$file" 2>/dev/null | grep -v "^#" | head -3 || true)
        if [ -n "$matches" ]; then
            warning "Possible hard-coded paths in $file:"
            echo "$matches" | while read -r line; do
                echo "    $line"
            done
        fi
    done
done
echo ""

# ---------------------------------------------------------------------------
# Check 4: Conflicts between config files
# ---------------------------------------------------------------------------
log "=== Check 4: Config conflicts ==="

# Check for variables that are defined in both but have different values
conflicts_found=0

# Get intersection of variables
for var in $OS_VARS; do
    if echo "$SHELL_VARS" | grep -qx "$var"; then
        # Variable exists in both - compare values
        os_val=$(grep "^${var}=" "$OS_CONF" | cut -d= -f2- | tr -d '"' | tr -d "'")
        shell_val=$(grep "^${var}=" "$SHELL_CONF" | cut -d= -f2- | tr -d '"' | tr -d "'")
        
        # Skip if either contains variable references (can't easily compare)
        case "$os_val$shell_val" in
            *'$'*) continue ;;
        esac
        
        if [ "$os_val" != "$shell_val" ]; then
            warning "Conflicting values for $var:"
            echo "    config/aios.conf: $os_val"
            echo "    etc/aios.conf:    $shell_val"
            conflicts_found=1
        fi
    fi
done

if [ "$conflicts_found" -eq 0 ]; then
    log_verbose "No conflicting values found"
fi
echo ""

# ---------------------------------------------------------------------------
# Check 5: Config file syntax
# ---------------------------------------------------------------------------
log "=== Check 5: Config syntax ==="

# Try to source each file in a subshell to check for syntax errors
if bash -n "$OS_CONF" 2>/dev/null; then
    log_verbose "$OS_CONF: syntax OK"
else
    issue "$OS_CONF has syntax errors"
fi

if bash -n "$SHELL_CONF" 2>/dev/null; then
    log_verbose "$SHELL_CONF: syntax OK"
else
    issue "$SHELL_CONF has syntax errors"
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
log "Issues: $ISSUES"
log "Warnings: $WARNINGS"

if [ "$ISSUES" -gt 0 ]; then
    log "Some issues require attention."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "Audit complete with warnings (informational only)."
    exit 0
else
    log "All checks passed."
    exit 0
fi
