#!/usr/bin/env bash
# run.sh — AIOS launcher
# © 2026 Chris Betts | AIOSCPU Official
#
# Runs the full boot pipeline then launches the interactive AI shell.
#
# Usage:
#   ./run.sh          — normal boot + AI shell
#   ./run.sh --no-boot — skip boot sequence, drop straight into AI shell

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure required runtime directories exist (first-run bootstrap)
if [[ ! -d "${REPO_ROOT}/var/log" ]]; then
    echo "[run.sh] First run detected — setting up environment..."
    bash "${REPO_ROOT}/install.sh" 2>&1
fi

# Make key binaries executable
chmod +x \
    "${REPO_ROOT}/bin/aios" \
    "${REPO_ROOT}/bin/aios-sys" \
    "${REPO_ROOT}/bin/aios-heartbeat" \
    "${REPO_ROOT}/boot/bootloader.sh" \
    2>/dev/null || true

# Parse flags
SKIP_BOOT=0
for arg in "$@"; do
    [[ "${arg}" == "--no-boot" ]] && SKIP_BOOT=1
done

if (( SKIP_BOOT == 0 )); then
    # Run the visual boot sequence
    bash "${REPO_ROOT}/boot/bootloader.sh"
fi

exec "${REPO_ROOT}/bin/aios"
