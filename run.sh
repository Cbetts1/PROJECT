#!/usr/bin/env bash
# run.sh — AIOS launcher
# © 2026 Chris Betts | AIOSCPU Official
#
# Cleanly launches the AIOS AI shell.
# Equivalent to: bash bin/aios
#
# Usage:
#   bash run.sh
#   ./run.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure required directories and permissions are in place
if [[ ! -d "${REPO_ROOT}/var/log" ]]; then
    echo "[run.sh] First run detected — setting up environment..."
    bash "${REPO_ROOT}/install.sh" 2>&1
fi

# Make bin/aios executable if needed
chmod +x "${REPO_ROOT}/bin/aios" 2>/dev/null || true
chmod +x "${REPO_ROOT}/bin/aios-sys" 2>/dev/null || true
chmod +x "${REPO_ROOT}/bin/aios-heartbeat" 2>/dev/null || true

exec "${REPO_ROOT}/bin/aios" "$@"
