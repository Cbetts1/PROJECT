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
