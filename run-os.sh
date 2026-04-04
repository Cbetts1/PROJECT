#!/bin/sh
# run-os.sh — AIOS-Lite canonical launcher
# © 2026 Chris Betts | AIOSCPU Official
#
# POSIX sh — no bashisms.
# Detects the repo root from the script's own location, sets OS_ROOT,
# creates the minimum required runtime directories, then execs OS/sbin/init.
#
# Usage:
#   ./run-os.sh              — normal boot (drops into os-shell)
#   ./run-os.sh --no-shell   — boot services only, no interactive shell
#   ./run-os.sh --shell=NAME — override the login shell

# ---------------------------------------------------------------------------
# Detect repo root (directory that contains this script)
# ---------------------------------------------------------------------------
AIOS_HOME="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -z "$AIOS_HOME" ]; then
    echo "[run-os.sh] ERROR: Cannot determine repo root from script path." >&2
    exit 1
fi

export AIOS_HOME
export OS_ROOT="$AIOS_HOME/OS"

# ---------------------------------------------------------------------------
# Extend PATH so OS/bin and OS/sbin are first
# ---------------------------------------------------------------------------
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# ---------------------------------------------------------------------------
# Create minimum runtime directories (idempotent)
# ---------------------------------------------------------------------------
mkdir -p \
    "$OS_ROOT/proc" \
    "$OS_ROOT/var/log" \
    "$OS_ROOT/var/service" \
    "$OS_ROOT/mirror" \
    2>/dev/null

# ---------------------------------------------------------------------------
# Exec into init (passes through any arguments, e.g. --no-shell)
# ---------------------------------------------------------------------------
exec sh "$OS_ROOT/sbin/init" "$@"
