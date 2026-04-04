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
#!/usr/bin/env bash
# run-os.sh — AIOS-Lite canonical OS launcher
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Derives AIOS_HOME and OS_ROOT from the script location, ensures all
# OS binaries are executable, then delegates to OS/sbin/init.
#
# Usage:
#   ./run-os.sh                        — full boot + interactive shell
#   ./run-os.sh --no-shell             — boot services only, then exit (CI / cron)
#   ./run-os.sh --shell os-real-shell  — boot + launch the specified shell

set -euo pipefail

AIOS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_ROOT="$AIOS_HOME/OS"
export AIOS_HOME OS_ROOT

# Make init and OS binaries executable
chmod +x "$OS_ROOT/sbin/init" 2>/dev/null || true
chmod +x "$OS_ROOT/bin/"* "$OS_ROOT/sbin/"* 2>/dev/null || true

# Extend PATH so OS tools and host tools are reachable immediately
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"

echo "[run-os] AIOS_HOME : $AIOS_HOME"
echo "[run-os] OS_ROOT   : $OS_ROOT"

exec "$OS_ROOT/sbin/init" "$@"
#!/bin/sh
# run-os.sh — AIOS-Lite canonical OS boot launcher (POSIX sh)
# © 2026 Chris Betts | AIOSCPU Official
#
# Sets OS_ROOT and PATH deterministically from the repository root,
# then execs OS/sbin/init.  All arguments are forwarded to init.
#
# Usage:
#   ./run-os.sh                       — full boot + login shell
#   ./run-os.sh --no-shell            — boot services only (headless)
#   ./run-os.sh --shell=os-real-shell — boot with alternate shell

REPO_ROOT="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

export OS_ROOT="$REPO_ROOT/OS"
export AIOS_HOME="$REPO_ROOT"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# Ensure init is executable before handing off
chmod +x "$OS_ROOT/sbin/init" 2>/dev/null || true

exec sh "$OS_ROOT/sbin/init" "$@"
