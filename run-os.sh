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
