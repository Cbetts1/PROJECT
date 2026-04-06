#!/usr/bin/env bash
# scripts/ota-verify.sh — Verify a GPG-signed AIOS-Lite OTA bundle
#
# Usage:
#   bash scripts/ota-verify.sh <bundle.tar.gz>
#
# Expects <bundle>.sha256 and <bundle>.sha256.asc to exist alongside the bundle.
# Exits 0 on success, non-zero on any verification failure.
#
# Environment variables:
#   OTA_KEYRING   — path to a GPG keyring file to use for verification
#                   (default: caller's default keyring)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '[ota-verify] %s\n' "$*"; }
ok()    { printf '[ota-verify] ✓ %s\n' "$*"; }
fail()  { printf '[ota-verify] ✗ FAIL: %s\n' "$*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage: bash scripts/ota-verify.sh <bundle.tar.gz>

Verifies an OTA bundle before applying it to AIOS-Lite.
Requires <bundle>.sha256 and <bundle>.sha256.asc alongside the bundle.

Environment:
  OTA_KEYRING   Path to GPG keyring file (optional)
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
[[ $# -lt 1 ]] && usage

BUNDLE="$1"
[[ -f "${BUNDLE}" ]] || fail "Bundle file not found: ${BUNDLE}"

MANIFEST="${BUNDLE}.sha256"
SIG_FILE="${BUNDLE}.sha256.asc"

[[ -f "${MANIFEST}" ]] || fail "Manifest not found: ${MANIFEST}"
[[ -f "${SIG_FILE}"  ]] || fail "Signature not found: ${SIG_FILE}"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
command -v gpg >/dev/null 2>&1 || fail "gpg not found — install GnuPG"
command -v sha256sum >/dev/null 2>&1 || \
command -v shasum    >/dev/null 2>&1 || fail "sha256sum / shasum not found"

# ---------------------------------------------------------------------------
# Step 1: Checksum verification
# ---------------------------------------------------------------------------
info "Verifying SHA-256 checksum ..."

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum --check "${MANIFEST}" || fail "SHA-256 checksum mismatch"
else
    shasum -a 256 --check "${MANIFEST}" || fail "SHA-256 checksum mismatch"
fi

ok "Checksum verified"

# ---------------------------------------------------------------------------
# Step 2: GPG signature verification
# ---------------------------------------------------------------------------
info "Verifying GPG signature ..."

GPG_ARGS=(--verify)
if [[ -n "${OTA_KEYRING:-}" ]]; then
    [[ -f "${OTA_KEYRING}" ]] || fail "Keyring not found: ${OTA_KEYRING}"
    GPG_ARGS+=(--keyring "${OTA_KEYRING}" --no-default-keyring)
fi
GPG_ARGS+=("${SIG_FILE}" "${MANIFEST}")

if gpg "${GPG_ARGS[@]}" 2>&1; then
    ok "GPG signature valid"
else
    fail "GPG signature verification failed"
fi

ok "OTA bundle verified — safe to apply."
