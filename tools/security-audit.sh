#!/usr/bin/env bash
# tools/security-audit.sh — Security Hardening Audit
# © 2026 Chris Betts | AIOSCPU Official
#
# Performs security scans:
#   - World-writable files in OS/bin/ and tools/
#   - Scripts that eval user input directly
#   - Shell injection risks (unquoted variables)
#   - OS_ROOT jail enforcement
#   - Hardcoded secrets/passwords
#
# Usage:
#   bash tools/security-audit.sh [--verbose] [--fix]
#
# Exit codes:
#   0 — No critical/high issues
#   1 — Critical or high issues found

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

VERBOSE=0
FIX_MODE=0

# Counters
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --fix) FIX_MODE=1 ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--fix]"
            echo "Performs security audit on the AIOS installation."
            echo ""
            echo "Options:"
            echo "  --verbose, -v   Show all findings including low severity"
            echo "  --fix           Attempt to auto-fix some issues"
            echo ""
            echo "Severity levels:"
            echo "  CRITICAL  Immediate security risk"
            echo "  HIGH      Significant security concern"
            echo "  MEDIUM    Should be reviewed"
            echo "  LOW       Minor issue"
            exit 0
            ;;
    esac
done

log_finding() {
    local severity="$1"
    local file="$2"
    local desc="$3"
    
    case "$severity" in
        CRITICAL) CRITICAL=$((CRITICAL + 1)); echo "[CRITICAL] $file: $desc" ;;
        HIGH)     HIGH=$((HIGH + 1)); echo "[HIGH] $file: $desc" ;;
        MEDIUM)   MEDIUM=$((MEDIUM + 1)); [ "$VERBOSE" -eq 1 ] && echo "[MEDIUM] $file: $desc" ;;
        LOW)      LOW=$((LOW + 1)); [ "$VERBOSE" -eq 1 ] && echo "[LOW] $file: $desc" ;;
    esac
}

echo "=== AIOS Security Audit ==="
echo "AIOS_ROOT: $AIOS_ROOT"
echo "OS_ROOT: $OS_ROOT"
echo ""

# ---------------------------------------------------------------------------
# Check 1: World-writable files
# ---------------------------------------------------------------------------
echo "--- Check 1: World-writable files ---"

for dir in "$OS_ROOT/bin" "$AIOS_ROOT/tools" "$AIOS_ROOT/bin"; do
    [ -d "$dir" ] || continue
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ "$FIX_MODE" -eq 1 ]; then
            chmod o-w "$file" 2>/dev/null && echo "[FIXED] Removed world-write: $file"
        else
            log_finding "HIGH" "$file" "World-writable file"
        fi
    done < <(find "$dir" -type f -perm -002 2>/dev/null)
done

# ---------------------------------------------------------------------------
# Check 2: Eval usage with user input
# ---------------------------------------------------------------------------
echo "--- Check 2: Dangerous eval usage ---"

for dir in "$OS_ROOT/bin" "$AIOS_ROOT/tools" "$AIOS_ROOT/bin" "$AIOS_ROOT/lib"; do
    [ -d "$dir" ] || continue
    while IFS=: read -r file lineno content; do
        [ -z "$file" ] && continue
        # Check for eval with variables
        if echo "$content" | grep -qE 'eval.*\$'; then
            log_finding "HIGH" "$file:$lineno" "eval with variable: ${content:0:50}..."
        fi
    done < <(grep -rn --include="*.sh" -E 'eval ' "$dir" 2>/dev/null || true)
done

# ---------------------------------------------------------------------------
# Check 3: Shell injection risks
# ---------------------------------------------------------------------------
echo "--- Check 3: Shell injection risks ---"

# Look for unquoted variable expansions in dangerous positions
for dir in "$OS_ROOT/bin" "$AIOS_ROOT/tools" "$AIOS_ROOT/bin" "$AIOS_ROOT/lib"; do
    [ -d "$dir" ] || continue
    while IFS=: read -r file lineno content; do
        [ -z "$file" ] && continue
        # Skip comments
        [[ "$content" =~ ^[[:space:]]*# ]] && continue
        
        # Check for unquoted $1, $2, $@, $* in exec positions
        if echo "$content" | grep -qE '(^|[;&|])[\t ]*[a-zA-Z_][a-zA-Z0-9_-]*[\t ]+\$[0-9@*]([^"]|$)'; then
            log_finding "MEDIUM" "$file:$lineno" "Potentially unquoted variable in command: ${content:0:50}..."
        fi
    done < <(grep -rn --include="*.sh" -E '\$[0-9@*]' "$dir" 2>/dev/null || true)
done

# ---------------------------------------------------------------------------
# Check 4: OS_ROOT jail enforcement
# ---------------------------------------------------------------------------
echo "--- Check 4: OS_ROOT jail enforcement ---"

# Check for symlinks that could escape the jail
while IFS= read -r link; do
    [ -z "$link" ] && continue
    target=$(readlink -f "$link" 2>/dev/null || true)
    if [ -n "$target" ] && [[ ! "$target" =~ ^"$OS_ROOT" ]] && [[ ! "$target" =~ ^"$AIOS_ROOT" ]]; then
        log_finding "HIGH" "$link" "Symlink escapes OS_ROOT: -> $target"
    fi
done < <(find "$OS_ROOT" -type l 2>/dev/null)

# Check that osroot_resolve is used in fs operations
for file in "$AIOS_ROOT/lib"/aura-fs.sh; do
    [ -f "$file" ] || continue
    if ! grep -q "osroot_resolve" "$file"; then
        log_finding "CRITICAL" "$file" "Missing osroot_resolve() jail enforcement"
    fi
done

# ---------------------------------------------------------------------------
# Check 5: Hardcoded secrets
# ---------------------------------------------------------------------------
echo "--- Check 5: Hardcoded secrets ---"

SECRET_PATTERNS="password=|passwd=|secret=|api_key=|apikey=|token=|credential|private_key"

for dir in "$AIOS_ROOT/config" "$AIOS_ROOT/etc" "$OS_ROOT/etc"; do
    [ -d "$dir" ] || continue
    while IFS=: read -r file lineno content; do
        [ -z "$file" ] && continue
        # Skip if it's just a placeholder or empty
        if echo "$content" | grep -qiE '(password=["'"'"']?$|password=["'"'"']?\$|password=["'"'"']{2}|password=.*CHANGE_ME|password=.*example)'; then
            log_finding "LOW" "$file:$lineno" "Empty/placeholder credential (OK)"
        elif echo "$content" | grep -qiE "password=|secret=|api_key="; then
            # Check if it looks like a real secret
            value=$(echo "$content" | grep -oE '(password|secret|api_key)=[^ ]+' | cut -d= -f2)
            if [ -n "$value" ] && [ ${#value} -gt 5 ] && [[ ! "$value" =~ ^\$ ]]; then
                log_finding "CRITICAL" "$file:$lineno" "Potential hardcoded secret"
            fi
        fi
    done < <(grep -rn --include="*.conf" --include="*.sh" -iE "$SECRET_PATTERNS" "$dir" 2>/dev/null || true)
done

# ---------------------------------------------------------------------------
# Check 6: Script permissions
# ---------------------------------------------------------------------------
echo "--- Check 6: Script permissions ---"

# Ensure scripts are not world-writable and have proper ownership
for dir in "$OS_ROOT/bin" "$OS_ROOT/sbin" "$AIOS_ROOT/bin" "$AIOS_ROOT/tools"; do
    [ -d "$dir" ] || continue
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        
        # Check if executable
        if [ ! -x "$file" ]; then
            if [ "$FIX_MODE" -eq 1 ]; then
                chmod +x "$file" && echo "[FIXED] Made executable: $file"
            else
                log_finding "LOW" "$file" "Script not executable"
            fi
        fi
    done
done

# ---------------------------------------------------------------------------
# Check 7: Input validation in bin/aios
# ---------------------------------------------------------------------------
echo "--- Check 7: Input validation ---"

AIOS_SCRIPT="$AIOS_ROOT/bin/aios"
if [ -f "$AIOS_SCRIPT" ]; then
    if grep -q "sanitize_input" "$AIOS_SCRIPT"; then
        echo "[OK] bin/aios uses sanitize_input()"
    else
        log_finding "MEDIUM" "$AIOS_SCRIPT" "Should use sanitize_input() for AI backend path"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Security Audit Summary ==="
echo "CRITICAL: $CRITICAL"
echo "HIGH:     $HIGH"
echo "MEDIUM:   $MEDIUM"
echo "LOW:      $LOW"
echo ""

if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo "⚠ Security issues found - review required"
    exit 1
else
    echo "✓ No critical or high severity issues"
    exit 0
fi
