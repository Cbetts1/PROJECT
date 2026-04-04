#!/usr/bin/env bash
# scripts/run.sh — AIOS run wrapper
# Delegates to the root-level run.sh, which runs the full boot pipeline
# and then launches the interactive AI shell.
#
# Usage:
#   bash scripts/run.sh             — full boot + AI shell
#   bash scripts/run.sh --no-boot  — skip boot, go straight to shell

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "${REPO_ROOT}/run.sh" "$@"
