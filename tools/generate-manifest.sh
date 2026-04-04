#!/usr/bin/env bash
# tools/generate-manifest.sh — Generate OS Manifest
# © 2026 Chris Betts | AIOSCPU Official
#
# Generates checksums for stable files in the AIOS installation.
# The manifest is used by system_check.sh to detect tampering.
#
# Usage:
#   bash tools/generate-manifest.sh
#
# Output:
#   OS/proc/os.manifest

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

MANIFEST="$OS_ROOT/proc/os.manifest"

mkdir -p "$(dirname "$MANIFEST")" 2>/dev/null

echo "=== AIOS Manifest Generator ==="
echo "AIOS_ROOT: $AIOS_ROOT"
echo "Output: $MANIFEST"
echo ""

# Temporary file for building manifest
TEMP_MANIFEST="${MANIFEST}.tmp"

# Header
cat > "$TEMP_MANIFEST" << EOF
# AIOS File Manifest
# Generated: $(date '+%Y-%m-%dT%H:%M:%SZ')
# Format: sha256sum  path (relative to AIOS_ROOT)
#
# This manifest is used by system_check.sh to verify file integrity.
# Regenerate after updates: bash tools/generate-manifest.sh
#

EOF

# Counter
count=0

# Function to add files to manifest
add_to_manifest() {
    local dir="$1"
    local pattern="${2:-*}"
    
    [ -d "$AIOS_ROOT/$dir" ] || return 0
    
    while IFS= read -r -d '' file; do
        [ -f "$file" ] || continue
        
        # Get relative path
        local relpath="${file#$AIOS_ROOT/}"
        
        # Calculate checksum
        local checksum=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
        
        if [ -n "$checksum" ]; then
            echo "$checksum  $relpath" >> "$TEMP_MANIFEST"
            count=$((count + 1))
        fi
    done < <(find "$AIOS_ROOT/$dir" -name "$pattern" -type f -print0 2>/dev/null)
}

echo "Scanning directories..."

# Stable directories to include
echo "  - bin/"
add_to_manifest "bin"

echo "  - lib/"
add_to_manifest "lib" "*.sh"

echo "  - tools/"
add_to_manifest "tools" "*.sh"

echo "  - config/"
add_to_manifest "config" "*.conf"

echo "  - etc/"
add_to_manifest "etc" "*.conf"

echo "  - OS/bin/"
add_to_manifest "OS/bin"

echo "  - OS/sbin/"
add_to_manifest "OS/sbin"

echo "  - OS/etc/init.d/"
add_to_manifest "OS/etc/init.d"

echo "  - OS/etc/security.conf"
if [ -f "$AIOS_ROOT/OS/etc/security.conf" ]; then
    checksum=$(sha256sum "$AIOS_ROOT/OS/etc/security.conf" | awk '{print $1}')
    echo "$checksum  OS/etc/security.conf" >> "$TEMP_MANIFEST"
    count=$((count + 1))
fi

echo "  - ai/core/*.py"
add_to_manifest "ai/core" "*.py"

# Move temp to final
mv "$TEMP_MANIFEST" "$MANIFEST"

echo ""
echo "=== Manifest Generated ==="
echo "Files: $count"
echo "Output: $MANIFEST"
echo ""
echo "To verify: bash tools/system_check.sh"
