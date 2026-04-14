#!/bin/bash
# overlay-manager.sh - Script to manage OverlayFS mount points and operations
#
# Usage:
#   overlay-manager.sh mount   <lowerdir> <upperdir> <workdir> <mountpoint>
#   overlay-manager.sh umount  <mountpoint>

set -euo pipefail

# Mount an OverlayFS at <mountpoint>
mount_overlay() {
    local lowerdir="$1"
    local upperdir="$2"
    local workdir="$3"
    local mountpoint="$4"

    mkdir -p "$upperdir" "$workdir" "$mountpoint"
    mount -t overlay overlay \
        -o lowerdir="$lowerdir",upperdir="$upperdir",workdir="$workdir" \
        "$mountpoint"
    echo "Mounted OverlayFS at $mountpoint"
}

# Unmount an OverlayFS at <mountpoint>
unmount_overlay() {
    local mountpoint="$1"
    umount "$mountpoint"
    echo "Unmounted OverlayFS at $mountpoint"
}

# Dispatch on subcommand
case "${1:-}" in
    mount)
        if [[ $# -ne 5 ]]; then
            echo "Usage: $0 mount <lowerdir> <upperdir> <workdir> <mountpoint>" >&2
            exit 1
        fi
        mount_overlay "$2" "$3" "$4" "$5"
        ;;
    umount|unmount)
        if [[ $# -ne 2 ]]; then
            echo "Usage: $0 umount <mountpoint>" >&2
            exit 1
        fi
        unmount_overlay "$2"
        ;;
    *)
        echo "Usage: $0 {mount|umount} ..." >&2
        echo "  mount  <lowerdir> <upperdir> <workdir> <mountpoint>" >&2
        echo "  umount <mountpoint>" >&2
        exit 1
        ;;
esac
