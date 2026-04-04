#!/usr/bin/env bash
# scripts/install.sh — AIOS installer wrapper
# Delegates to the root-level install.sh, which handles all dependency
# installation, permission setup, and environment preparation.
#
# Usage:
#   bash scripts/install.sh [options]
#   bash scripts/install.sh --help

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "${REPO_ROOT}/install.sh" "$@"
