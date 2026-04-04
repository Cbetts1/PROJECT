#!/bin/sh
# launch.sh — Canonical AIOS-Lite OS launcher
# © 2026 Chris Betts | AIOSCPU Official
#
# Requirements (POSIX sh — no bashisms):
#   1. Detect repo root from script location
#   2. Set OS_ROOT to <repo_root>/OS
#   3. Prepend PATH with OS/bin and OS/sbin
#   4. Create required runtime dirs: proc, var/log, var/service, mirror
#   5. Exec OS/sbin/init (passes all arguments through)
#
# Usage:
#   ./launch.sh               — boot AIOS-Lite (drops into os-shell)
#   ./launch.sh --no-shell    — boot services only, no interactive shell
#   ./launch.sh --shell=<bin> — boot and launch alternate shell binary

set -eu

# ---------------------------------------------------------------------------
# Detect repo root (POSIX: cd to dirname and resolve with pwd -P)
# pwd -P follows symlinks in path components; sufficient for typical usage.
# ---------------------------------------------------------------------------
REPO_ROOT=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)

if [ -z "$REPO_ROOT" ]; then
    echo "[launch] ERROR: Cannot determine repo root from \$0='$0'" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Set OS_ROOT
# ---------------------------------------------------------------------------
OS_ROOT="$REPO_ROOT/OS"
export OS_ROOT

if [ ! -d "$OS_ROOT" ]; then
    echo "[launch] ERROR: OS directory not found at $OS_ROOT" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Prepend PATH with OS/bin and OS/sbin
# ---------------------------------------------------------------------------
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# ---------------------------------------------------------------------------
# Create required runtime directories
# ---------------------------------------------------------------------------
mkdir -p \
    "$OS_ROOT/proc" \
    "$OS_ROOT/var/log" \
    "$OS_ROOT/var/service" \
    "$OS_ROOT/mirror"

# ---------------------------------------------------------------------------
# Exec OS/sbin/init (replaces this process; passes all arguments through)
# ---------------------------------------------------------------------------
INIT="$OS_ROOT/sbin/init"

if [ ! -f "$INIT" ]; then
    echo "[launch] ERROR: init not found at $INIT" >&2
    exit 1
fi

if [ ! -x "$INIT" ]; then
    echo "[launch] ERROR: $INIT is not executable. Run: chmod +x $INIT" >&2
    exit 1
fi

exec "$INIT" "$@"
