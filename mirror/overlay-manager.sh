#!/bin/bash
# overlay-manager.sh - Script to manage OverlayFS mount points and operations

# Function to mount OverlayFS
mount_overlay() {
    local lowerdir="$1"
    local upperdir="$2"
    local workdir="$3"
    local mountpoint="$4"
    
    mkdir -p "$mountpoint"
    mount -t overlay overlay -o lowerdir="$lowerdir",upperdir="$upperdir",workdir="$workdir" "$mountpoint"
}

# Function to unmount OverlayFS
unmount_overlay() {
    local mountpoint="$1"
    umount "$mountpoint"
}

# Check arguments
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <lowerdir> <upperdir> <workdir> <mountpoint>"
    exit 1
fi

# Call mount and unmount functions
echo "Mounting OverlayFS..."
mount_overlay "$1" "$2" "$3" "$4"
