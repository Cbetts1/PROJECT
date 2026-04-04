#!/usr/bin/env bash
# tools/perms-audit.sh — Permission and Shebang Audit Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Verifies:
# 1. All executable files in bin/, sbin/, tools/, OS/bin/ have proper shebangs
# 2. All files with shebangs that should be executable are marked as such
# 3. All rc2.d and init.d scripts are executable
#
# Usage:
#   bash tools/perms-audit.sh [--verbose]
#
# Exit codes:
#   0 — No issues found
#   1 — Issues found (reported but not fixed)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

VERBOSE=0
ISSUES=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
    esac
done

log() {
    echo "[perms-audit] $*"
}

log_verbose() {
    [ "$VERBOSE" -eq 1 ] && echo "[perms-audit] $*" || true
}

issue() {
    echo "[ISSUE] $*"
    ISSUES=$((ISSUES + 1))
}

ok() {
    log_verbose "[OK] $*"
}

# Check if a file has a valid shebang
has_shebang() {
    local file="$1"
    [ -f "$file" ] || return 1
    head -c 2 "$file" 2>/dev/null | grep -q '^#!' && return 0
    return 1
}

# Get the shebang line
get_shebang() {
    local file="$1"
    head -n1 "$file" 2>/dev/null | grep '^#!' || echo ""
}

# Check if shebang is valid
is_valid_shebang() {
    local shebang="$1"
    case "$shebang" in
        '#!/bin/sh'*) return 0 ;;
        '#!/bin/bash'*) return 0 ;;
        '#!/usr/bin/env bash'*) return 0 ;;
        '#!/usr/bin/env sh'*) return 0 ;;
        '#!/usr/bin/env python'*) return 0 ;;
        '#!/usr/bin/python'*) return 0 ;;
        '#!/usr/bin/env node'*) return 0 ;;
        '#!/usr/bin/env perl'*) return 0 ;;
        *) return 1 ;;
    esac
}

log "Starting permission and shebang audit..."
log "AIOS_ROOT: $AIOS_ROOT"
log "OS_ROOT: $OS_ROOT"
echo ""

# ---------------------------------------------------------------------------
# Check 1: Executable files should have shebangs
# ---------------------------------------------------------------------------
log "=== Check 1: Executable files should have shebangs ==="

EXEC_DIRS=(
    "$AIOS_ROOT/bin"
    "$AIOS_ROOT/tools"
    "$OS_ROOT/bin"
    "$OS_ROOT/sbin"
)

for dir in "${EXEC_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    log_verbose "Scanning $dir..."
    
    for file in "$dir"/*; do
        # Check for symlinks first (e.g., busybox applets)
        if [ -L "$file" ]; then
            ok "$file is a symlink"
            continue
        fi
        
        [ -f "$file" ] || continue
        
        # Skip non-executable files
        if [ ! -x "$file" ]; then
            continue
        fi
        
        # Check for shebang
        if has_shebang "$file"; then
            shebang=$(get_shebang "$file")
            if is_valid_shebang "$shebang"; then
                ok "$file has valid shebang"
            else
                issue "$file is executable but has unusual shebang: $shebang"
            fi
        else
            # Check if it's a binary (ELF, etc.)
            file_type=$(file -b "$file" 2>/dev/null || echo "unknown")
            case "$file_type" in
                *executable*|*ELF*|*binary*)
                    ok "$file is a binary executable"
                    ;;
                *)
                    issue "$file is executable but has no shebang"
                    ;;
            esac
        fi
    done
done
echo ""

# ---------------------------------------------------------------------------
# Check 2: Files with shebangs should be executable
# ---------------------------------------------------------------------------
log "=== Check 2: Files with shebangs should be executable ==="

SCRIPT_DIRS=(
    "$AIOS_ROOT/bin"
    "$AIOS_ROOT/tools"
    "$OS_ROOT/bin"
    "$OS_ROOT/sbin"
    "$OS_ROOT/etc/init.d"
)

# Note: lib/*.sh files are excluded because they're meant to be sourced, not executed

for dir in "${SCRIPT_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    log_verbose "Scanning $dir..."
    
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        
        if has_shebang "$file"; then
            if [ -x "$file" ]; then
                ok "$file has shebang and is executable"
            else
                issue "$file has shebang but is NOT executable"
            fi
        fi
    done
done
echo ""

# ---------------------------------------------------------------------------
# Check 3: rc2.d and init.d scripts should be executable
# ---------------------------------------------------------------------------
log "=== Check 3: Service scripts should be executable ==="

# Check init.d
if [ -d "$OS_ROOT/etc/init.d" ]; then
    for script in "$OS_ROOT/etc/init.d"/*; do
        [ -f "$script" ] || continue
        if [ -x "$script" ]; then
            ok "$script is executable"
        else
            issue "$script is NOT executable (init.d service)"
        fi
    done
fi

# Check rc2.d (symlinks should point to executable targets)
if [ -d "$OS_ROOT/etc/rc2.d" ]; then
    for link in "$OS_ROOT/etc/rc2.d"/S*; do
        [ -L "$link" ] || [ -f "$link" ] || continue
        
        if [ -L "$link" ]; then
            target=$(readlink -f "$link" 2>/dev/null || echo "")
            if [ -n "$target" ] && [ -f "$target" ]; then
                if [ -x "$target" ]; then
                    ok "$link -> $target is executable"
                else
                    issue "$link -> $target is NOT executable (rc2.d service)"
                fi
            else
                issue "$link is a broken symlink"
            fi
        elif [ -f "$link" ]; then
            if [ -x "$link" ]; then
                ok "$link is executable"
            else
                issue "$link is NOT executable (rc2.d service)"
            fi
        fi
    done
fi
echo ""

# ---------------------------------------------------------------------------
# Check 4: OS/init.d/startup.sh and OS/sbin/init should be executable
# ---------------------------------------------------------------------------
log "=== Check 4: Critical boot scripts ==="

critical_scripts=(
    "$OS_ROOT/init.d/startup.sh"
    "$OS_ROOT/sbin/init"
)

for script in "${critical_scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            ok "$script is executable"
        else
            issue "$script is NOT executable (critical boot script)"
        fi
    else
        issue "$script not found (critical boot script)"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
if [ "$ISSUES" -eq 0 ]; then
    log "All checks passed. No issues found."
    exit 0
else
    log "Found $ISSUES issue(s). Run 'tools/system_autofix.sh' to fix."
    exit 1
fi
