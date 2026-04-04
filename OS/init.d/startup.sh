#!/bin/bash
# OS/init.d/startup.sh — AIOS-Lite Startup Helper
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Called by external boot environments (e.g. Termux $PREFIX/etc/boot.d,
# systemd ExecStart, or Docker ENTRYPOINT) to launch AIOS-Lite.
#
# Usage:
#   bash OS/init.d/startup.sh [--shell os-shell|os-real-shell] [--no-shell]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_HOME="${AIOS_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_HOME/OS}"

export OS_ROOT AIOS_HOME

echo "[startup] AIOS_HOME: $AIOS_HOME"
echo "[startup] OS_ROOT  : $OS_ROOT"

# Verify that sbin/init is executable before exec'ing
INIT_SCRIPT="$OS_ROOT/sbin/init"
if [ ! -f "$INIT_SCRIPT" ]; then
    echo "[startup] ERROR: $INIT_SCRIPT not found" >&2
    exit 1
fi
if [ ! -x "$INIT_SCRIPT" ]; then
    echo "[startup] ERROR: $INIT_SCRIPT is not executable" >&2
    echo "[startup] Try running: chmod +x $INIT_SCRIPT" >&2
    exit 1
fi

# Delegate to sbin/init for the full boot sequence
exec "$OS_ROOT/sbin/init" "$@"
