#!/usr/bin/env bash
# build/reproducible.sh — Reproducible build helper for AIOS-Lite
#
# Records SOURCE_DATE_EPOCH, strips timestamps from build artifacts, and
# outputs a SHA-256 manifest of all tracked files.
#
# Usage:
#   bash build/reproducible.sh [--manifest-only] [--output <dir>]
#
# Options:
#   --manifest-only   Only write the SHA-256 manifest; skip strip operations
#   --output <dir>    Directory for manifest output (default: build/)
#   --help            Show this help
#
# Output files:
#   <output>/sha256-manifest.txt   — SHA-256 checksums for all tracked files
#   <output>/build-info.txt        — SOURCE_DATE_EPOCH and git commit

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { printf '[reproducible] %s\n' "$*"; }
die()  { printf '[reproducible] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MANIFEST_ONLY=0
OUTPUT_DIR="${REPO_ROOT}/build"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest-only) MANIFEST_ONLY=1; shift ;;
        --output)        OUTPUT_DIR="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,18p' "$0"; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

mkdir -p "${OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# SOURCE_DATE_EPOCH — use last git commit time for reproducibility
# ---------------------------------------------------------------------------
if command -v git &>/dev/null && [[ -d "${REPO_ROOT}/.git" ]]; then
    SOURCE_DATE_EPOCH="$(git log -1 --format='%ct' HEAD 2>/dev/null || date +%s)"
else
    SOURCE_DATE_EPOCH="$(date +%s)"
fi
export SOURCE_DATE_EPOCH
info "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}  ($(date -u -d "@${SOURCE_DATE_EPOCH}" 2>/dev/null || date -u -r "${SOURCE_DATE_EPOCH}" 2>/dev/null || echo 'N/A'))"

# ---------------------------------------------------------------------------
# Strip embedded timestamps from Python .pyc files (if any)
# ---------------------------------------------------------------------------
if [[ "${MANIFEST_ONLY}" -eq 0 ]]; then
    info "Stripping .pyc timestamp fields ..."
    find "${REPO_ROOT}" -name '*.pyc' -not -path '*/.git/*' | while IFS= read -r pyc; do
        # Python 3.8+: bytes 4–7 of .pyc are a 32-bit timestamp; zero them out
        if command -v python3 &>/dev/null; then
            python3 - "${pyc}" <<'PYEOF'
import sys, struct
path = sys.argv[1]
with open(path, 'rb') as f: data = bytearray(f.read())
if len(data) >= 8:
    # Zero the timestamp field (bytes 4-7) for source-hash or unchecked .pyc
    data[4:8] = b'\x00\x00\x00\x00'
    with open(path, 'wb') as f: f.write(data)
PYEOF
        fi
    done
fi

# ---------------------------------------------------------------------------
# Build info file
# ---------------------------------------------------------------------------
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
BUILD_INFO="${OUTPUT_DIR}/build-info.txt"
{
    echo "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
    echo "GIT_COMMIT=${GIT_COMMIT}"
    echo "BUILD_HOST=$(uname -n 2>/dev/null || echo unknown)"
    echo "BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "AIOS_VERSION=1.0.0"
} > "${BUILD_INFO}"
info "Build info written to ${BUILD_INFO}"

# ---------------------------------------------------------------------------
# SHA-256 manifest — cover all files tracked by git
# ---------------------------------------------------------------------------
MANIFEST="${OUTPUT_DIR}/sha256-manifest.txt"
info "Generating SHA-256 manifest ..."

if command -v sha256sum &>/dev/null; then
    HASH_CMD="sha256sum"
elif command -v shasum &>/dev/null; then
    HASH_CMD="shasum -a 256"
else
    die "sha256sum / shasum not found"
fi

# List all git-tracked files (excludes untracked and .gitignored files)
if command -v git &>/dev/null; then
    git ls-files --cached --others --exclude-standard | \
        sort | \
        xargs -d '\n' ${HASH_CMD} 2>/dev/null > "${MANIFEST}" || true
else
    find . -type f -not -path './.git/*' | sort | \
        xargs ${HASH_CMD} > "${MANIFEST}"
fi

LINE_COUNT="$(wc -l < "${MANIFEST}")"
info "Manifest written: ${MANIFEST} (${LINE_COUNT} files)"

echo ""
echo "  SOURCE_DATE_EPOCH : ${SOURCE_DATE_EPOCH}"
echo "  Git commit        : ${GIT_COMMIT}"
echo "  Manifest          : ${MANIFEST}"
echo "  Build info        : ${BUILD_INFO}"
echo ""
info "Reproducible build metadata complete."
