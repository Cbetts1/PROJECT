#!/usr/bin/env bash
# tools/log-viewer.sh — Log Viewer Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Shows recent entries from all AIOS log files with optional filtering.
#
# Usage:
#   bash tools/log-viewer.sh [options]
#
# Options:
#   --tail N       Show last N lines (default: 20)
#   --log <name>   Show specific log (os, aura, events, heartbeat, ai-queries)
#   --follow       Follow log output (like tail -f)
#   --summary      Show summary with counts by level
#   --all          Show all logs combined
#   --help         Show this help
#
# Exit codes:
#   0 — Success

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

TAIL_LINES=20
SPECIFIC_LOG=""
FOLLOW=0
SUMMARY=0
SHOW_ALL=0

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --tail)
            shift
            TAIL_LINES="${1:-20}"
            ;;
        --tail=*)
            TAIL_LINES="${1#--tail=}"
            ;;
        --log)
            shift
            SPECIFIC_LOG="$1"
            ;;
        --log=*)
            SPECIFIC_LOG="${1#--log=}"
            ;;
        --follow|-f)
            FOLLOW=1
            ;;
        --summary|-s)
            SUMMARY=1
            ;;
        --all|-a)
            SHOW_ALL=1
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --tail N       Show last N lines (default: 20)"
            echo "  --log <name>   Show specific log (os, aura, events, heartbeat, ai-queries)"
            echo "  --follow       Follow log output (like tail -f)"
            echo "  --summary      Show summary with counts by level"
            echo "  --all          Show all logs combined"
            echo "  --help         Show this help"
            exit 0
            ;;
    esac
    shift
done

# Define log files
declare -A LOG_FILES
LOG_FILES["os"]="$OS_ROOT/var/log/os.log"
LOG_FILES["aura"]="$OS_ROOT/var/log/aura.log"
LOG_FILES["events"]="$OS_ROOT/var/log/events.log"
LOG_FILES["heartbeat"]="$AIOS_ROOT/var/log/heartbeat.log"
LOG_FILES["aios"]="$AIOS_ROOT/var/log/aios.log"
LOG_FILES["ai-queries"]="$OS_ROOT/var/log/ai-queries.log"
LOG_FILES["bridge"]="$OS_ROOT/var/log/bridge.log"
LOG_FILES["recover"]="$OS_ROOT/var/log/recover.log"
LOG_FILES["autofix"]="$OS_ROOT/var/log/autofix.log"

# Get log path by name
get_log_path() {
    local name="$1"
    case "$name" in
        os|os.log) echo "${LOG_FILES[os]}" ;;
        aura|aura.log) echo "${LOG_FILES[aura]}" ;;
        events|events.log) echo "${LOG_FILES[events]}" ;;
        heartbeat|heartbeat.log) echo "${LOG_FILES[heartbeat]}" ;;
        aios|aios.log) echo "${LOG_FILES[aios]}" ;;
        ai|ai-queries|ai-queries.log) echo "${LOG_FILES[ai-queries]}" ;;
        bridge|bridge.log) echo "${LOG_FILES[bridge]}" ;;
        recover|recover.log) echo "${LOG_FILES[recover]}" ;;
        autofix|autofix.log) echo "${LOG_FILES[autofix]}" ;;
        *) echo "$name" ;;  # Assume it's a path
    esac
}

# Show summary of a log file
show_summary() {
    local file="$1"
    local name="$2"
    
    if [ ! -f "$file" ]; then
        echo "$name: (not found)"
        return
    fi
    
    local total=$(wc -l < "$file" 2>/dev/null || echo 0)
    local info=$(grep -ci "\[INFO\]" "$file" 2>/dev/null || echo 0)
    local warn=$(grep -ci "\[WARN\]\|\[WARNING\]" "$file" 2>/dev/null || echo 0)
    local error=$(grep -ci "\[ERROR\]" "$file" 2>/dev/null || echo 0)
    local size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
    
    printf "%-20s %6d lines  INFO: %4d  WARN: %4d  ERROR: %4d  Size: %s\n" \
           "$name:" "$total" "$info" "$warn" "$error" "$size"
}

# Show tail of a log file
show_log() {
    local file="$1"
    local name="$2"
    
    if [ ! -f "$file" ]; then
        echo "--- $name ---"
        echo "(log file not found: $file)"
        echo ""
        return
    fi
    
    echo "--- $name ---"
    tail -n "$TAIL_LINES" "$file" 2>/dev/null || echo "(empty)"
    echo ""
}

# Follow a log file
follow_log() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "Log file not found: $file"
        exit 1
    fi
    
    echo "Following: $file (Ctrl+C to stop)"
    echo "---"
    tail -f "$file"
}

# Summary mode
if [ "$SUMMARY" -eq 1 ]; then
    echo "=== Log Summary ==="
    echo ""
    
    for name in os aura events aios heartbeat ai-queries; do
        file="${LOG_FILES[$name]}"
        show_summary "$file" "$name"
    done
    
    echo ""
    echo "Optional logs:"
    for name in bridge recover autofix; do
        file="${LOG_FILES[$name]}"
        [ -f "$file" ] && show_summary "$file" "$name"
    done
    
    exit 0
fi

# Specific log mode
if [ -n "$SPECIFIC_LOG" ]; then
    log_path=$(get_log_path "$SPECIFIC_LOG")
    
    if [ "$FOLLOW" -eq 1 ]; then
        follow_log "$log_path"
    else
        show_log "$log_path" "$SPECIFIC_LOG"
    fi
    
    exit 0
fi

# Follow mode (requires specific log)
if [ "$FOLLOW" -eq 1 ]; then
    echo "Error: --follow requires --log <name>"
    echo "Example: $0 --follow --log aura"
    exit 1
fi

# All logs mode
if [ "$SHOW_ALL" -eq 1 ]; then
    echo "=== All Logs (last $TAIL_LINES lines each) ==="
    echo ""
    
    for name in os aura events aios heartbeat; do
        file="${LOG_FILES[$name]}"
        show_log "$file" "$name"
    done
    
    exit 0
fi

# Default: show main logs
echo "=== Recent Log Entries (last $TAIL_LINES lines) ==="
echo ""
echo "Use --log <name> to see a specific log, --summary for counts, --all for everything"
echo ""

for name in aura os; do
    file="${LOG_FILES[$name]}"
    show_log "$file" "$name"
done
