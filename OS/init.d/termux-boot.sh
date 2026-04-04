#!/data/data/com.termux/files/usr/bin/bash
# OS/init.d/termux-boot.sh — AIOS-Lite Termux Boot Helper
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Designed for Termux on Android.  Install this file as a Termux boot script:
#
#   mkdir -p ~/.termux/boot
#   cp OS/init.d/termux-boot.sh ~/.termux/boot/aios-boot.sh
#   chmod +x ~/.termux/boot/aios-boot.sh
#
# Termux will execute it automatically on device boot when
# the "Termux:Boot" add-on is installed.
#
# Manual launch:
#   bash OS/init.d/termux-boot.sh
#   bash OS/init.d/termux-boot.sh --no-shell   (services only, no interactive shell)

# ---------------------------------------------------------------------------
# Locate AIOS_HOME (repo root) from the script's own path
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
AIOS_HOME="${AIOS_HOME:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_HOME/OS}"

export AIOS_HOME OS_ROOT

# ---------------------------------------------------------------------------
# Termux environment sanity
# ---------------------------------------------------------------------------
if [ -z "${TERMUX_VERSION:-}" ] && [ ! -d "/data/data/com.termux" ]; then
    echo "[termux-boot] WARNING: Not running inside Termux. Proceeding anyway..."
fi

# Use Termux prefix for tools when available
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"

# Acquire a partial wakelock so the boot daemon keeps running
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>/dev/null &
fi

echo "[termux-boot] AIOS_HOME : $AIOS_HOME"
echo "[termux-boot] OS_ROOT   : $OS_ROOT"
echo "[termux-boot] PREFIX    : $PREFIX"

# ---------------------------------------------------------------------------
# Delegate to the full init sequence
# ---------------------------------------------------------------------------
exec bash "$OS_ROOT/sbin/init" "$@"
