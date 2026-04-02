#!/bin/bash
# deploy/usb-image-builder.sh
# Builds a bootable USB image for AIOS standalone mode.
#
# Usage:
#   bash deploy/usb-image-builder.sh [--output FILE] [--size SIZE] [--device s21fe]
#
# Requirements: mksquashfs, grub-mkstandalone (or u-boot-tools), dd, losetup

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$AIOS_ROOT/aios-s21fe.img"
IMAGE_SIZE="8G"
DEVICE_TARGET="s21fe"

log() { echo "[usb-image] $*"; }
die() { echo "[usb-image] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        --size)   IMAGE_SIZE="$2"; shift 2 ;;
        --device) DEVICE_TARGET="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

command -v dd        >/dev/null 2>&1 || die "dd not found"
command -v losetup   >/dev/null 2>&1 || die "losetup not found"
command -v mkfs.ext4 >/dev/null 2>&1 || die "mkfs.ext4 not found (install e2fsprogs)"

log "Building bootable AIOS image"
log "Output : $OUTPUT"
log "Size   : $IMAGE_SIZE"
log "Device : $DEVICE_TARGET"

# ── Build rootfs squashfs ─────────────────────────────────────────────────────
ROOTFS_IMG="$AIOS_ROOT/build/aios-rootfs.squashfs"
if [[ ! -f "$ROOTFS_IMG" ]]; then
    log "Building rootfs first..."
    bash "$AIOS_ROOT/build/rootfs-builder.sh" --output "$ROOTFS_IMG"
fi

# ── Create raw disk image ─────────────────────────────────────────────────────
log "Creating raw image ($IMAGE_SIZE)..."
dd if=/dev/zero of="$OUTPUT" bs=1M count=0 seek="$(echo "$IMAGE_SIZE" | sed 's/G/000/')" status=none

# ── Partition the image (GPT: 1MB gap + EFI + root) ──────────────────────────
if command -v sgdisk >/dev/null 2>&1; then
    log "Partitioning with GPT..."
    sgdisk -Z "$OUTPUT"
    sgdisk -n 1:2048:+100M -t 1:EF00 -c 1:"EFI" "$OUTPUT"
    sgdisk -n 2:0:0        -t 2:8300 -c 2:"AIOS Root" "$OUTPUT"
elif command -v parted >/dev/null 2>&1; then
    log "Partitioning with parted..."
    parted -s "$OUTPUT" mklabel gpt
    parted -s "$OUTPUT" mkpart EFI fat32 1MiB 101MiB
    parted -s "$OUTPUT" set 1 esp on
    parted -s "$OUTPUT" mkpart primary ext4 101MiB 100%
else
    die "Neither sgdisk nor parted found. Install gdisk or parted."
fi

# ── Mount and populate ────────────────────────────────────────────────────────
LOOP=$(losetup -f)
losetup -P "$LOOP" "$OUTPUT"

log "Formatting partitions..."
mkfs.fat -F32 "${LOOP}p1" -n AIOS_EFI   >/dev/null
mkfs.ext4 -q  "${LOOP}p2" -L AIOS_ROOT

MOUNT_DIR=$(mktemp -d)
mount "${LOOP}p2" "$MOUNT_DIR"
mkdir -p "$MOUNT_DIR/boot/efi"
mount "${LOOP}p1" "$MOUNT_DIR/boot/efi"

log "Copying rootfs..."
unsquashfs -d "$MOUNT_DIR" -f "$ROOTFS_IMG" >/dev/null

# ── Install bootloader ────────────────────────────────────────────────────────
if command -v grub-install >/dev/null 2>&1; then
    log "Installing GRUB..."
    grub-install \
        --target=arm64-efi \
        --efi-directory="$MOUNT_DIR/boot/efi" \
        --boot-directory="$MOUNT_DIR/boot" \
        --removable \
        "$LOOP" 2>/dev/null || log "GRUB install requires running on ARM64 host"
fi

# Write a minimal GRUB config
mkdir -p "$MOUNT_DIR/boot/grub"
cat > "$MOUNT_DIR/boot/grub/grub.cfg" << 'GRUB_CFG'
set default=0
set timeout=3

menuentry "AIOS — Portable AI OS" {
    linux /boot/vmlinuz-aios root=/dev/disk/by-label/AIOS_ROOT ro quiet
    initrd /boot/initrd-aios.img
}
GRUB_CFG

# ── Cleanup ───────────────────────────────────────────────────────────────────
sync
umount "$MOUNT_DIR/boot/efi"
umount "$MOUNT_DIR"
losetup -d "$LOOP"
rmdir "$MOUNT_DIR"

SIZE=$(du -sh "$OUTPUT" | cut -f1)
log "Image ready: $OUTPUT ($SIZE)"
log "Flash with: dd if=$OUTPUT of=/dev/sdX bs=4M status=progress"
