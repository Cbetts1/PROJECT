#!/usr/bin/env bash
# scripts/ota-sign.sh — GPG-sign an AIOS-Lite OTA update bundle
#
# Usage:
#   bash scripts/ota-sign.sh <bundle.tar.gz> [<gpg-key-id>]
#
# What it does:
#   1. Computes a SHA256 manifest of every file in the bundle
#   2. GPG-signs the manifest with the supplied (or default) key
#   3. Writes <bundle>.sha256 and <bundle>.sha256.asc alongside the bundle
#
# Consumers use scripts/ota-verify.sh to verify before applying.
#
# Environment variables:
#   OTA_GPG_KEY   — override key ID (default: first signing-capable key)
#   OTA_SIGN_DIR  — directory to write .sha256 / .asc files (default: alongside bundle)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '[ota-sign] %s\n' "$*"; }
die()   { printf '[ota-sign] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage: bash scripts/ota-sign.sh <bundle.tar.gz> [<gpg-key-id>]

Signs an OTA bundle for AIOS-Lite.
Writes <bundle>.sha256 and <bundle>.sha256.asc next to the bundle.

Environment:
  OTA_GPG_KEY   GPG key ID / fingerprint (optional)
  OTA_SIGN_DIR  Output directory for signature files (default: same dir as bundle)
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
[[ $# -lt 1 ]] && usage

BUNDLE="$1"
[[ -f "${BUNDLE}" ]] || die "Bundle file not found: ${BUNDLE}"

GPG_KEY="${2:-${OTA_GPG_KEY:-}}"
SIGN_DIR="${OTA_SIGN_DIR:-$(dirname "${BUNDLE}")}"
BUNDLE_BASE="$(basename "${BUNDLE}")"
MANIFEST="${SIGN_DIR}/${BUNDLE_BASE}.sha256"
SIG_FILE="${SIGN_DIR}/${BUNDLE_BASE}.sha256.asc"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
command -v gpg  >/dev/null 2>&1 || die "gpg not found — install GnuPG"
command -v sha256sum >/dev/null 2>&1 || \
command -v shasum    >/dev/null 2>&1 || die "sha256sum / shasum not found"

mkdir -p "${SIGN_DIR}"

# ---------------------------------------------------------------------------
# Step 1: SHA-256 manifest
# ---------------------------------------------------------------------------
info "Computing SHA-256 checksum for ${BUNDLE_BASE} ..."

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${BUNDLE}" > "${MANIFEST}"
else
    # macOS / BSD fallback
    shasum -a 256 "${BUNDLE}" > "${MANIFEST}"
fi

info "Manifest written to ${MANIFEST}"

# ---------------------------------------------------------------------------
# Step 2: GPG sign the manifest
# ---------------------------------------------------------------------------
GPG_ARGS=(--armor --detach-sign --output "${SIG_FILE}")
if [[ -n "${GPG_KEY}" ]]; then
    GPG_ARGS+=(--local-user "${GPG_KEY}")
fi

info "Signing manifest${GPG_KEY:+ with key ${GPG_KEY}} ..."
gpg "${GPG_ARGS[@]}" "${MANIFEST}"

info "Signature written to ${SIG_FILE}"
info "OTA bundle signed successfully."
echo ""
echo "  Bundle   : ${BUNDLE}"
echo "  Manifest : ${MANIFEST}"
echo "  Signature: ${SIG_FILE}"
