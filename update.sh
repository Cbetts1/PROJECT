#!/usr/bin/env bash
# update.sh — AIOS update and patch system
# © 2026 Chris Betts | AIOSCPU Official
#
# Pulls the latest changes from the remote repository, re-runs install.sh,
# and optionally runs the self-test suite.
#
# Usage:
#   bash update.sh              — update + re-install
#   bash update.sh --check      — check for updates without applying
#   bash update.sh --self-test  — update + install + run full test suite
#   bash update.sh --help       — show this help

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${REPO_ROOT}/var/log/aios.log"

# Ensure log directory exists
mkdir -p "${REPO_ROOT}/var/log"

info()    { echo "[update] $*"; printf '[%s] [UPDATE] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" >> "${LOG_FILE}"; }
success() { echo "[update] ✓ $*"; }
warn()    { echo "[update] ⚠ $*" >&2; }
die()     { echo "[update] ✗ $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CHECK_ONLY=0
RUN_TESTS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)     CHECK_ONLY=1; shift ;;
        --self-test) RUN_TESTS=1; shift ;;
        --help|-h)
            sed -n '3,14p' "$0"
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
done

echo "════════════════════════════════════════"
echo "  AIOS Update System"
echo "  Repo root : ${REPO_ROOT}"
echo "════════════════════════════════════════"
echo ""

# ---------------------------------------------------------------------------
# Verify git is available
# ---------------------------------------------------------------------------
if ! command -v git &>/dev/null; then
    die "git not found — cannot pull updates. Install git and retry."
fi

# ---------------------------------------------------------------------------
# Check remote for updates
# ---------------------------------------------------------------------------
info "Checking for remote updates..."
cd "${REPO_ROOT}"

# Fetch without merging
if ! git fetch origin 2>&1; then
    warn "Could not reach remote — continuing with local files."
    if [[ "${CHECK_ONLY}" -eq 1 ]]; then exit 0; fi
else
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse FETCH_HEAD 2>/dev/null || echo "${LOCAL}")
    BASE=$(git merge-base HEAD FETCH_HEAD 2>/dev/null || echo "${LOCAL}")

    if [[ "${LOCAL}" == "${REMOTE}" ]]; then
        success "Already up to date ($(git rev-parse --short HEAD))."
        if [[ "${CHECK_ONLY}" -eq 1 ]]; then exit 0; fi
    elif [[ "${LOCAL}" == "${BASE}" ]]; then
        COMMITS_BEHIND=$(git rev-list HEAD..FETCH_HEAD --count 2>/dev/null || echo "?")
        info "Updates available: ${COMMITS_BEHIND} new commit(s) on remote."
        if [[ "${CHECK_ONLY}" -eq 1 ]]; then
            echo ""
            git log --oneline HEAD..FETCH_HEAD 2>/dev/null | head -20 || true
            exit 0
        fi
    else
        warn "Local branch has diverged from remote — manual merge may be needed."
        if [[ "${CHECK_ONLY}" -eq 1 ]]; then exit 1; fi
    fi
fi

# ---------------------------------------------------------------------------
# Apply updates (git pull)
# ---------------------------------------------------------------------------
if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    info "Pulling latest changes..."
    if git pull --ff-only origin 2>&1; then
        success "Pull complete (now at $(git rev-parse --short HEAD))."
        info "$(git log -1 --pretty='%h %s' HEAD)"
    else
        warn "Fast-forward pull failed — trying merge..."
        if git pull origin 2>&1; then
            success "Merge pull complete."
        else
            die "git pull failed. Resolve conflicts manually and re-run update.sh."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Re-run installer to pick up any new dependencies / permissions
# ---------------------------------------------------------------------------
info "Re-running installer..."
if bash "${REPO_ROOT}/install.sh" 2>&1; then
    success "Install complete."
else
    warn "Install step had warnings — check output above."
fi

# ---------------------------------------------------------------------------
# Optional: run full test suite
# ---------------------------------------------------------------------------
if [[ "${RUN_TESTS}" -eq 1 ]]; then
    info "Running test suite..."
    echo ""
    if AIOS_HOME="${REPO_ROOT}" OS_ROOT="${REPO_ROOT}/OS" \
       bash "${REPO_ROOT}/tests/unit-tests.sh" 2>&1; then
        success "All unit tests passed."
    else
        warn "Some unit tests failed — see output above."
    fi

    if [[ -f "${REPO_ROOT}/tests/integration-tests.sh" ]]; then
        if AIOS_HOME="${REPO_ROOT}" OS_ROOT="${REPO_ROOT}/OS" \
           bash "${REPO_ROOT}/tests/integration-tests.sh" 2>&1; then
            success "All integration tests passed."
        else
            warn "Some integration tests failed."
        fi
    fi
fi

echo ""
echo "════════════════════════════════════════"
success "Update complete!"
echo ""
echo "  Launch AIOS : ./run.sh"
echo "  View log    : tail -f var/log/aios.log"
echo "════════════════════════════════════════"

info "Update finished at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
