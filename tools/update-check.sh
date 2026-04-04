#!/usr/bin/env bash
# tools/update-check.sh — AIOS Update Checker
# © 2026 Chris Betts | AIOSCPU Official
#
# Checks for available updates:
#   - Checks git status (clean/dirty working tree)
#   - Reports current version
#   - In offline mode, skips remote checks
#   - If online, checks for remote changes
#
# Usage:
#   bash tools/update-check.sh
#
# Exit codes:
#   0 — UP_TO_DATE or OFFLINE
#   1 — UPDATES_AVAILABLE or LOCAL_CHANGES

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Load config for version and offline mode
AIOS_CONF="$AIOS_ROOT/config/aios.conf"
[ -f "$AIOS_CONF" ] && . "$AIOS_CONF" 2>/dev/null

AIOS_VERSION="${AIOS_VERSION:-0.1}"
OFFLINE_MODE="${OFFLINE_MODE:-0}"

echo "=== AIOS Update Check ==="
echo "Current Version: $AIOS_VERSION"
echo "AIOS_ROOT: $AIOS_ROOT"
echo ""

# ---------------------------------------------------------------------------
# Check if we're in a git repository
# ---------------------------------------------------------------------------
cd "$AIOS_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Status: NOT_GIT_REPO"
    echo "This installation is not a git repository."
    echo "Manual updates required."
    exit 0
fi

# ---------------------------------------------------------------------------
# Check for local changes
# ---------------------------------------------------------------------------
echo "--- Local State ---"

LOCAL_CHANGES=0
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)

if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "Local changes: YES ($UNCOMMITTED files modified)"
    LOCAL_CHANGES=1
    git status --short 2>/dev/null | head -10
    [ "$UNCOMMITTED" -gt 10 ] && echo "... and $((UNCOMMITTED - 10)) more"
else
    echo "Local changes: NO (working tree clean)"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "Branch: $CURRENT_BRANCH"
echo "Commit: $CURRENT_COMMIT"
echo ""

# ---------------------------------------------------------------------------
# Check offline mode
# ---------------------------------------------------------------------------
if [ "$OFFLINE_MODE" = "1" ]; then
    echo "--- Remote Check ---"
    echo "Status: OFFLINE"
    echo "Offline mode enabled. Remote checks skipped."
    echo ""
    echo "To check for updates, disable offline mode:"
    echo "  export OFFLINE_MODE=0"
    echo "  bash tools/update-check.sh"
    exit 0
fi

# ---------------------------------------------------------------------------
# Check for remote updates
# ---------------------------------------------------------------------------
echo "--- Remote Check ---"

# Try to fetch (dry run)
FETCH_OUTPUT=$(git fetch --dry-run 2>&1 || echo "FETCH_FAILED")

if echo "$FETCH_OUTPUT" | grep -q "FETCH_FAILED"; then
    echo "Remote check: FAILED (network unavailable or no remote)"
    echo ""
    if [ "$LOCAL_CHANGES" -eq 1 ]; then
        echo "Status: LOCAL_CHANGES"
        exit 1
    else
        echo "Status: UNKNOWN (cannot reach remote)"
        exit 0
    fi
fi

# Check if there are updates
REMOTE_BRANCH="origin/$CURRENT_BRANCH"
git fetch origin "$CURRENT_BRANCH" 2>/dev/null || true

LOCAL_HEAD=$(git rev-parse HEAD 2>/dev/null)
REMOTE_HEAD=$(git rev-parse "$REMOTE_BRANCH" 2>/dev/null || echo "")

if [ -z "$REMOTE_HEAD" ]; then
    echo "Remote: No tracking branch found"
    echo ""
    if [ "$LOCAL_CHANGES" -eq 1 ]; then
        echo "Status: LOCAL_CHANGES"
        exit 1
    else
        echo "Status: UP_TO_DATE"
        exit 0
    fi
fi

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
    echo "Remote: Up to date with $REMOTE_BRANCH"
    UPDATES_AVAILABLE=0
else
    # Count commits behind
    BEHIND=$(git rev-list --count HEAD.."$REMOTE_BRANCH" 2>/dev/null || echo "?")
    AHEAD=$(git rev-list --count "$REMOTE_BRANCH"..HEAD 2>/dev/null || echo "?")
    echo "Remote: $BEHIND commits behind, $AHEAD commits ahead of $REMOTE_BRANCH"
    UPDATES_AVAILABLE=1
fi

echo ""

# ---------------------------------------------------------------------------
# Final status
# ---------------------------------------------------------------------------
if [ "$LOCAL_CHANGES" -eq 1 ]; then
    echo "Status: LOCAL_CHANGES"
    echo "You have uncommitted local changes."
    echo "Commit or stash them before updating."
    exit 1
elif [ "$UPDATES_AVAILABLE" -eq 1 ]; then
    echo "Status: UPDATES_AVAILABLE"
    echo "Updates are available. Run:"
    echo "  bash tools/apply-update.sh"
    exit 1
else
    echo "Status: UP_TO_DATE"
    echo "Your installation is up to date."
    exit 0
fi
