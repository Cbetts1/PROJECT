#!/usr/bin/env bash
# tools/offline-check.sh — Offline-First Hardening Check
# © 2026 Chris Betts | AIOSCPU Official
#
# Scans the codebase for network-required operations:
#   - curl, wget, apt, pip install, npm install, git clone calls
#   - Hardcoded HTTP/HTTPS URLs
#   - DNS names suggesting cloud dependencies
#
# Reports: OFFLINE_SAFE | NETWORK_GATED | NETWORK_REQUIRED for each finding
#
# Usage:
#   bash tools/offline-check.sh [--verbose] [--path <dir>]
#
# Exit codes:
#   0 — No NETWORK_REQUIRED items found (offline-safe)
#   1 — NETWORK_REQUIRED items found

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

VERBOSE=0
SCAN_PATH="${AIOS_ROOT}"

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --path=*) SCAN_PATH="${arg#--path=}" ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--path <dir>]"
            echo "Scans codebase for network-required operations."
            echo ""
            echo "Options:"
            echo "  --verbose, -v   Show all findings including OFFLINE_SAFE"
            echo "  --path=<dir>    Directory to scan (default: AIOS_ROOT)"
            echo ""
            echo "Exit codes:"
            echo "  0  No NETWORK_REQUIRED items (offline-safe)"
            echo "  1  NETWORK_REQUIRED items found"
            exit 0
            ;;
    esac
done

# Counters
SAFE_COUNT=0
GATED_COUNT=0
REQUIRED_COUNT=0

# Findings arrays
declare -a FINDINGS

log_finding() {
    local status="$1"
    local file="$2"
    local line="$3"
    local desc="$4"
    
    case "$status" in
        OFFLINE_SAFE)     SAFE_COUNT=$((SAFE_COUNT + 1)) ;;
        NETWORK_GATED)    GATED_COUNT=$((GATED_COUNT + 1)) ;;
        NETWORK_REQUIRED) REQUIRED_COUNT=$((REQUIRED_COUNT + 1)) ;;
    esac
    
    FINDINGS+=("[$status] $file:$line - $desc")
}

echo "=== AIOS Offline-First Hardening Check ==="
echo "Scanning: $SCAN_PATH"
echo ""

# ---------------------------------------------------------------------------
# Check 1: Network commands (curl, wget, apt, pip install, npm install, git clone)
# ---------------------------------------------------------------------------
echo "--- Check 1: Network command usage ---"

# Patterns to search for network commands
NETWORK_CMDS="curl|wget|apt-get|apt |pip install|pip3 install|npm install|git clone"

while IFS=: read -r file lineno content; do
    [ -z "$file" ] && continue
    
    # Skip test files and documentation
    case "$file" in
        */tests/*|*test*.py|*test*.sh|*.md|*/docs/*|*/CHANGELOG*) continue ;;
    esac
    
    # Check if the command is behind an offline guard
    # Look for patterns like: if [ "$OFFLINE_MODE" != "1" ]; or if ! offline check
    if grep -B5 "^${lineno}:" "$file" 2>/dev/null | grep -qiE "OFFLINE_MODE|offline.*guard|if.*online|network.*check"; then
        log_finding "NETWORK_GATED" "$file" "$lineno" "Network command behind offline guard: ${content:0:60}..."
    else
        # Check if it's in a clearly optional/download function
        if echo "$content" | grep -qiE "download|fetch|update|install"; then
            log_finding "NETWORK_GATED" "$file" "$lineno" "Network command in optional function: ${content:0:60}..."
        else
            log_finding "NETWORK_REQUIRED" "$file" "$lineno" "Unguarded network command: ${content:0:60}..."
        fi
    fi
done < <(grep -rn --include="*.sh" --include="*.py" -E "$NETWORK_CMDS" "$SCAN_PATH" 2>/dev/null | grep -v "offline-check.sh" | head -100 || true)

# ---------------------------------------------------------------------------
# Check 2: Hardcoded HTTP/HTTPS URLs
# ---------------------------------------------------------------------------
echo "--- Check 2: Hardcoded URLs ---"

while IFS=: read -r file lineno content; do
    [ -z "$file" ] && continue
    
    # Skip test files, documentation, and license files
    case "$file" in
        */tests/*|*test*.py|*test*.sh|*.md|*/docs/*|*/LICENSE*|*/CHANGELOG*|*README*) continue ;;
    esac
    
    # Extract URL for classification
    url=$(echo "$content" | grep -oE 'https?://[^ "'"'"']+' | head -1)
    [ -z "$url" ] && continue
    
    # Classify by URL type
    case "$url" in
        *github.com*|*githubusercontent.com*)
            log_finding "NETWORK_GATED" "$file" "$lineno" "GitHub URL (optional download): $url"
            ;;
        *huggingface.co*|*ollama.com*|*llama.cpp*)
            log_finding "NETWORK_GATED" "$file" "$lineno" "Model download URL: $url"
            ;;
        *localhost*|*127.0.0.1*|*0.0.0.0*)
            log_finding "OFFLINE_SAFE" "$file" "$lineno" "Local URL: $url"
            ;;
        *example.com*|*example.org*|*test.*)
            log_finding "OFFLINE_SAFE" "$file" "$lineno" "Example/test URL: $url"
            ;;
        *)
            # Check context for offline guards
            if grep -B3 "$lineno" "$file" 2>/dev/null | grep -qiE "OFFLINE_MODE|if.*online"; then
                log_finding "NETWORK_GATED" "$file" "$lineno" "Guarded URL: $url"
            else
                log_finding "NETWORK_REQUIRED" "$file" "$lineno" "Hardcoded URL: $url"
            fi
            ;;
    esac
done < <(grep -rn --include="*.sh" --include="*.py" --include="*.conf" -E 'https?://' "$SCAN_PATH" 2>/dev/null | grep -v "offline-check.sh" | head -100 || true)

# ---------------------------------------------------------------------------
# Check 3: Cloud/DNS dependencies
# ---------------------------------------------------------------------------
echo "--- Check 3: Cloud service references ---"

CLOUD_PATTERNS="amazonaws\.com|azure\.com|googleapis\.com|cloudflare\.com|api\.openai\.com"

while IFS=: read -r file lineno content; do
    [ -z "$file" ] && continue
    
    # Skip test files and documentation
    case "$file" in
        */tests/*|*test*.py|*test*.sh|*.md|*/docs/*) continue ;;
    esac
    
    # Cloud services typically require network
    if echo "$content" | grep -qiE "OFFLINE_MODE|if.*offline"; then
        log_finding "NETWORK_GATED" "$file" "$lineno" "Cloud service (guarded): ${content:0:60}..."
    else
        log_finding "NETWORK_REQUIRED" "$file" "$lineno" "Cloud service dependency: ${content:0:60}..."
    fi
done < <(grep -rn --include="*.sh" --include="*.py" --include="*.conf" -iE "$CLOUD_PATTERNS" "$SCAN_PATH" 2>/dev/null | head -50 || true)

# ---------------------------------------------------------------------------
# Check 4: DNS lookups / hostname references
# ---------------------------------------------------------------------------
echo "--- Check 4: DNS/hostname references ---"

DNS_PATTERNS="getaddrinfo|gethostbyname|dns\.resolve|nslookup|dig |host "

while IFS=: read -r file lineno content; do
    [ -z "$file" ] && continue
    
    case "$file" in
        */tests/*|*test*.py|*test*.sh|*.md|*/docs/*) continue ;;
    esac
    
    log_finding "NETWORK_GATED" "$file" "$lineno" "DNS operation: ${content:0:60}..."
done < <(grep -rn --include="*.sh" --include="*.py" -E "$DNS_PATTERNS" "$SCAN_PATH" 2>/dev/null | head -50 || true)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Offline-First Audit Summary ==="
echo "OFFLINE_SAFE:     $SAFE_COUNT items (no network needed)"
echo "NETWORK_GATED:    $GATED_COUNT items (network optional, guarded)"
echo "NETWORK_REQUIRED: $REQUIRED_COUNT items (network required, REVIEW NEEDED)"
echo ""

# Print findings based on verbosity
if [ "$VERBOSE" -eq 1 ] || [ "$REQUIRED_COUNT" -gt 0 ]; then
    echo "=== Findings ==="
    for finding in "${FINDINGS[@]}"; do
        case "$finding" in
            "[NETWORK_REQUIRED]"*) echo "$finding" ;;
            "[NETWORK_GATED]"*)    [ "$VERBOSE" -eq 1 ] && echo "$finding" ;;
            "[OFFLINE_SAFE]"*)     [ "$VERBOSE" -eq 1 ] && echo "$finding" ;;
        esac
    done
    echo ""
fi

if [ "$REQUIRED_COUNT" -eq 0 ]; then
    echo "✓ System is OFFLINE-SAFE (no unguarded network requirements)"
    exit 0
else
    echo "⚠ System has $REQUIRED_COUNT NETWORK_REQUIRED items - review recommended"
    exit 1
fi
