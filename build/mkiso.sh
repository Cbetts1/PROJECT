#!/usr/bin/env bash
# build/mkiso.sh — Build a hybrid bootable ISO for AIOS-Lite
#
# Produces a hybrid ISO (boots from USB stick and optical drive) that:
#   - Contains the AIOS-Lite repository tree at /opt/aios/
#   - Has GRUB as bootloader using build/grub/grub.cfg
#   - Can be written to a USB stick with: dd if=aios-lite.iso of=/dev/sdX bs=4M
#
# Usage:
#   bash build/mkiso.sh [--output <file>] [--label <label>]
#
# Dependencies: xorriso, grub-mkimage or grub2-mkimage, mksquashfs (optional)
# Requires: xorriso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { printf '[mkiso] %s\n' "$*"; }
die()  { printf '[mkiso] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
OUTPUT_ISO="${SCRIPT_DIR}/aios-lite.iso"
VOLUME_LABEL="AIOS-LITE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT_ISO="$2"; shift 2 ;;
        --label)  VOLUME_LABEL="$2"; shift 2 ;;
        --help|-h) sed -n '3,15p' "$0"; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
command -v xorriso >/dev/null 2>&1 || die "xorriso not found — install xorriso"

GRUB_MKIMAGE=""
for _cmd in grub-mkimage grub2-mkimage; do
    command -v "${_cmd}" &>/dev/null && GRUB_MKIMAGE="${_cmd}" && break
done

# ---------------------------------------------------------------------------
# Work directory
# ---------------------------------------------------------------------------
WORK_DIR="${SCRIPT_DIR}/iso-work"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/iso/opt/aios" \
         "${WORK_DIR}/iso/boot/grub"

info "Staging AIOS-Lite tree ..."
rsync -a --exclude='.git' \
         --exclude='build/iso-work' \
         --exclude='build/*.iso' \
         --exclude='build/*.img' \
         --exclude='aioscpu/build/work' \
         "${REPO_ROOT}/" "${WORK_DIR}/iso/opt/aios/"

# ---------------------------------------------------------------------------
# GRUB configuration
# ---------------------------------------------------------------------------
info "Installing GRUB configuration ..."
cp "${SCRIPT_DIR}/grub/grub.cfg" "${WORK_DIR}/iso/boot/grub/grub.cfg"

# ---------------------------------------------------------------------------
# GRUB eltorito image (EFI + BIOS hybrid)
# ---------------------------------------------------------------------------
GRUB_ELTORITO=""
GRUB_EFI_IMG=""

if [[ -n "${GRUB_MKIMAGE}" ]]; then
    info "Building GRUB eltorito image ..."

    # BIOS (i386-pc)
    BIOS_IMG="${WORK_DIR}/boot.img"
    "${GRUB_MKIMAGE}" \
        -O i386-pc-eltorito \
        -p '/boot/grub' \
        -o "${BIOS_IMG}" \
        boot linux ext2 fat iso9660 part_msdos part_gpt normal echo 2>/dev/null || true

    # EFI (x86_64-efi) — best effort; non-fatal if GRUB EFI modules missing
    GRUB_EFI_IMG="${WORK_DIR}/iso/boot/grub/efiboot.img"
    mkdir -p "${WORK_DIR}/iso/EFI/BOOT"
    "${GRUB_MKIMAGE}" \
        -O x86_64-efi \
        -p '/boot/grub' \
        -o "${WORK_DIR}/iso/EFI/BOOT/BOOTX64.EFI" \
        boot linux ext2 fat iso9660 part_msdos part_gpt normal echo 2>/dev/null || \
        { GRUB_EFI_IMG=""; info "EFI GRUB modules not available — BIOS-only ISO"; }

    GRUB_ELTORITO="${BIOS_IMG}"
else
    info "grub-mkimage not found — ISO will not be directly bootable (data-only layout)"
fi

# ---------------------------------------------------------------------------
# Assemble ISO with xorriso
# ---------------------------------------------------------------------------
info "Building ISO image: ${OUTPUT_ISO} ..."

XORRISO_ARGS=(
    xorriso -as mkisofs
    -V "${VOLUME_LABEL}"
    -J -joliet-long
    -r
    -o "${OUTPUT_ISO}"
)

if [[ -n "${GRUB_ELTORITO}" && -f "${GRUB_ELTORITO}" ]]; then
    XORRISO_ARGS+=(
        -b boot.img
        -no-emul-boot
        -boot-load-size 4
        -boot-info-table
        --grub2-boot-info
        --grub2-mbr "${GRUB_ELTORITO}"
    )
    cp "${GRUB_ELTORITO}" "${WORK_DIR}/iso/boot.img"
fi

if [[ -n "${GRUB_EFI_IMG}" && -f "${WORK_DIR}/iso/EFI/BOOT/BOOTX64.EFI" ]]; then
    XORRISO_ARGS+=(
        -eltorito-alt-boot
        -e EFI/BOOT/BOOTX64.EFI
        -no-emul-boot
    )
fi

XORRISO_ARGS+=("${WORK_DIR}/iso")

"${XORRISO_ARGS[@]}"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ISO_SIZE="$(du -sh "${OUTPUT_ISO}" 2>/dev/null | cut -f1)"
info "ISO image built: ${OUTPUT_ISO} (${ISO_SIZE})"
echo ""
echo "  Write to USB: dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress"
echo "  Boot in QEMU: qemu-system-x86_64 -m 2048 -cdrom ${OUTPUT_ISO} -boot d"
echo ""
rm -rf "${WORK_DIR}"
info "Done."
