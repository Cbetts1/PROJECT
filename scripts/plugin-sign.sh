#!/usr/bin/env bash
# scripts/plugin-sign.sh — GPG-sign an AIOS-Lite plugin manifest
#
# Usage:
#   bash scripts/plugin-sign.sh <plugin-dir> [<gpg-key-id>]
#
# Signs OS/var/pkg/plugins/<plugin-name>/plugin.json and writes
# plugin.json.asc alongside it.

set -euo pipefail

info() { printf '[plugin-sign] %s\n' "$*"; }
die()  { printf '[plugin-sign] ERROR: %s\n' "$*" >&2; exit 1; }

[[ $# -lt 1 ]] && { echo "Usage: bash scripts/plugin-sign.sh <plugin-dir> [<gpg-key-id>]" >&2; exit 1; }

PLUGIN_DIR="$1"
GPG_KEY="${2:-${PLUGIN_GPG_KEY:-}}"

MANIFEST="${PLUGIN_DIR}/plugin.json"
SIG_FILE="${PLUGIN_DIR}/plugin.json.asc"

[[ -f "${MANIFEST}" ]] || die "plugin.json not found: ${MANIFEST}"
command -v gpg >/dev/null 2>&1 || die "gpg not found — install GnuPG"

GPG_ARGS=(--armor --detach-sign --output "${SIG_FILE}")
[[ -n "${GPG_KEY}" ]] && GPG_ARGS+=(--local-user "${GPG_KEY}")

info "Signing ${MANIFEST}${GPG_KEY:+ with key ${GPG_KEY}} ..."
gpg "${GPG_ARGS[@]}" "${MANIFEST}"
info "Signature written: ${SIG_FILE}"
