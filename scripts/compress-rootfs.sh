#!/bin/bash
# scripts/compress-rootfs.sh
# Compresses the AIOS OS/ directory to a squashfs image.
# Wrapper around build/rootfs-builder.sh with additional size reporting.
#
# Usage:
#   bash scripts/compress-rootfs.sh [--output FILE]

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$AIOS_ROOT/build/aios-rootfs.squashfs}"

log() { echo "[compress] $*"; }

log "Compressing AIOS rootfs -> $OUTPUT"

BEFORE=$(du -sh "$AIOS_ROOT/OS" 2>/dev/null | cut -f1)
log "Source size: $BEFORE"

bash "$AIOS_ROOT/build/rootfs-builder.sh" --output "$OUTPUT"

AFTER=$(du -sh "$OUTPUT" 2>/dev/null | cut -f1)
log "Compressed: $AFTER"
log "Done: $OUTPUT"
