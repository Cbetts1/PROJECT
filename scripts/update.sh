#!/usr/bin/env bash
# scripts/update.sh — AIOS update wrapper
# Delegates to the root-level update.sh, which pulls the latest changes
# from the remote repository, re-runs install.sh, and optionally runs tests.
#
# Usage:
#   bash scripts/update.sh              — update + re-install
#   bash scripts/update.sh --check      — check for updates without applying
#   bash scripts/update.sh --self-test  — update + install + run full test suite

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "${REPO_ROOT}/update.sh" "$@"
