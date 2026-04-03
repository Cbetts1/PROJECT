#!/usr/bin/env bash
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# build-image.sh - AIOSCPU Debian-based disk image builder
#
# This script:
#   1. Creates a minimal Debian rootfs via debootstrap
#   2. Installs required packages inside the chroot
#   3. Creates AIOSCPU users (aios, aura)
#   4. Overlays rootfs-overlay/ and the aura/ agent
#   5. Builds a 6GB ext4 disk image
#   6. Installs GRUB into the image
#   7. Outputs aioscpu-debian-amd64.img
#
# Usage: sudo ./build-image.sh
# Must be run as root (requires debootstrap, chroot, losetup, etc.)
#
# Dependencies: debootstrap, parted, losetup, grub-pc-bin, rsync, qemu-utils

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ROOTFS_OVERLAY="${SCRIPT_DIR}/../rootfs-overlay"
AURA_SRC="${REPO_ROOT}/aura"

OUTPUT_IMG="${SCRIPT_DIR}/aioscpu-debian-amd64.img"
WORK_DIR="${SCRIPT_DIR}/work"
ROOTFS_DIR="${WORK_DIR}/rootfs"
MOUNT_DIR="${WORK_DIR}/mnt"

DEBIAN_MIRROR="http://deb.debian.org/debian"
DEBIAN_SUITE="bookworm"

IMAGE_SIZE_MB=6144   # 6 GB
PARTITION_OFFSET=1   # MiB – space before first partition (for GRUB embedding)

PACKAGES=(
    linux-image-amd64
    grub-pc
    sudo
    vim
    net-tools
    iproute2
    openssh-server
    python3
    python3-pip
    curl
    wget
    git
    bluez
    network-manager
)

# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------
log()  { echo "[BUILD] $*"; }
err()  { echo "[ERROR] $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "Required tool not found: $1"; }

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || err "This script must be run as root."

for tool in debootstrap parted losetup mkfs.ext4 rsync grub-install; do
    need "$tool"
done

# ---------------------------------------------------------------------------
# Prepare work directories
# ---------------------------------------------------------------------------
log "Preparing work directories..."
rm -rf "${WORK_DIR}"
mkdir -p "${ROOTFS_DIR}" "${MOUNT_DIR}"

# ---------------------------------------------------------------------------
# Step 1: Bootstrap minimal Debian rootfs
# ---------------------------------------------------------------------------
log "Running debootstrap (suite=${DEBIAN_SUITE}) – this may take several minutes..."
debootstrap \
    --arch=amd64 \
    --include="$(IFS=,; echo "${PACKAGES[*]}")" \
    "${DEBIAN_SUITE}" \
    "${ROOTFS_DIR}" \
    "${DEBIAN_MIRROR}"

# ---------------------------------------------------------------------------
# Step 2: Configure the rootfs inside chroot
# ---------------------------------------------------------------------------
log "Configuring rootfs in chroot..."

# Mount proc/sys/dev for chroot operations
mount --bind /proc "${ROOTFS_DIR}/proc"
mount --bind /sys  "${ROOTFS_DIR}/sys"
mount --bind /dev  "${ROOTFS_DIR}/dev"
mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

# Cleanup mounts on exit
cleanup_mounts() {
    log "Cleaning up bind mounts..."
    umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/dev"     2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/sys"     2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/proc"    2>/dev/null || true
}
trap cleanup_mounts EXIT

# Write chroot configuration script
cat > "${ROOTFS_DIR}/tmp/chroot-setup.sh" <<'CHROOT_EOF'
#!/bin/bash
set -euo pipefail

# --- Locale & timezone ---
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# --- Hostname / hosts ---
echo "aioscpu" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   aioscpu
::1         localhost ip6-localhost ip6-loopback
HOSTS

# --- Create users ---
# aios: interactive user, sudo capable
useradd -m -s /bin/bash -c "AIOSCPU Interactive User" aios
echo "aios:aios" | chpasswd
usermod -aG sudo aios

# aura: AI agent service account, locked, no interactive login
useradd -r -s /usr/sbin/nologin -d /opt/aura -c "AURA AI Agent" aura
passwd -l aura   # lock password (no direct login)
mkdir -p /opt/aura /var/lib/aura /var/log
chown aura:aura /opt/aura /var/lib/aura

# --- sudoers for aura (will be overlaid, but ensure dir exists) ---
install -d -m 0750 /etc/sudoers.d

# --- Enable services ---
systemctl enable ssh
systemctl enable NetworkManager
systemctl enable bluetooth

# --- GRUB configuration (placeholder; grub-install done outside chroot) ---
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub || true

# --- Clean up apt cache ---
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[chroot] Setup complete."
CHROOT_EOF

chmod +x "${ROOTFS_DIR}/tmp/chroot-setup.sh"
chroot "${ROOTFS_DIR}" /tmp/chroot-setup.sh
rm -f "${ROOTFS_DIR}/tmp/chroot-setup.sh"

cleanup_mounts
trap - EXIT

# ---------------------------------------------------------------------------
# Step 3: Overlay rootfs-overlay/ into the rootfs
# ---------------------------------------------------------------------------
log "Applying rootfs-overlay..."
if [[ -d "${ROOTFS_OVERLAY}" ]]; then
    rsync -a --chown=root:root "${ROOTFS_OVERLAY}/" "${ROOTFS_DIR}/"
    # Move systemd unit files to the correct path
    if [[ -d "${ROOTFS_DIR}/systemd/system" ]]; then
        mkdir -p "${ROOTFS_DIR}/etc/systemd/system"
        cp -r "${ROOTFS_DIR}/systemd/system/." "${ROOTFS_DIR}/etc/systemd/system/"
        rm -rf "${ROOTFS_DIR}/systemd"
    fi
    # Move sudoers.d entries
    if [[ -d "${ROOTFS_DIR}/sudoers.d" ]]; then
        mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
        cp -r "${ROOTFS_DIR}/sudoers.d/." "${ROOTFS_DIR}/etc/sudoers.d/"
        chmod 0440 "${ROOTFS_DIR}/etc/sudoers.d/"*
        rm -rf "${ROOTFS_DIR}/sudoers.d"
    fi
    # Mark usr/local/bin scripts executable
    find "${ROOTFS_DIR}/usr/local/bin" -type f -exec chmod 0755 {} \;
else
    log "WARNING: rootfs-overlay not found at ${ROOTFS_OVERLAY}"
fi

# ---------------------------------------------------------------------------
# Step 4: Copy AURA agent into /opt/aura
# ---------------------------------------------------------------------------
log "Installing AURA agent..."
if [[ -d "${AURA_SRC}" ]]; then
    mkdir -p "${ROOTFS_DIR}/opt/aura"
    rsync -a "${AURA_SRC}/" "${ROOTFS_DIR}/opt/aura/"
    chown -R root:root "${ROOTFS_DIR}/opt/aura"
    chmod 0755 "${ROOTFS_DIR}/opt/aura/aura-agent.py" 2>/dev/null || true
else
    log "WARNING: aura/ source directory not found at ${AURA_SRC}"
fi

# ---------------------------------------------------------------------------
# Step 5: Copy GRUB config into rootfs
# ---------------------------------------------------------------------------
log "Installing GRUB config..."
mkdir -p "${ROOTFS_DIR}/boot/grub"
cp "${SCRIPT_DIR}/grub.cfg" "${ROOTFS_DIR}/boot/grub/grub.cfg"

# ---------------------------------------------------------------------------
# Step 6: Create the disk image
# ---------------------------------------------------------------------------
log "Creating ${IMAGE_SIZE_MB}MB disk image at ${OUTPUT_IMG}..."
dd if=/dev/zero of="${OUTPUT_IMG}" bs=1M count="${IMAGE_SIZE_MB}" status=progress

# Partition: single primary ext4 spanning the disk (after 1MiB GRUB gap)
parted -s "${OUTPUT_IMG}" \
    mklabel msdos \
    mkpart primary ext4 "${PARTITION_OFFSET}MiB" 100% \
    set 1 boot on

# ---------------------------------------------------------------------------
# Step 7: Format the partition and populate it
# ---------------------------------------------------------------------------
log "Setting up loop device and formatting partition..."
LOOP_DEV=$(losetup --find --show --partscan "${OUTPUT_IMG}")
PART_DEV="${LOOP_DEV}p1"

# Give the kernel a moment to register the partition device
sleep 1
partprobe "${LOOP_DEV}" 2>/dev/null || true
sleep 1

mkfs.ext4 -L "aioscpu-root" "${PART_DEV}"

log "Mounting partition and copying rootfs..."
mount "${PART_DEV}" "${MOUNT_DIR}"

# Use rsync to copy rootfs into the image (preserve permissions, no xattr issues)
rsync -aHAX --numeric-ids "${ROOTFS_DIR}/" "${MOUNT_DIR}/"

# ---------------------------------------------------------------------------
# Step 8: Install GRUB into the image MBR
# ---------------------------------------------------------------------------
log "Installing GRUB into image MBR..."

# Bind-mount /dev /proc /sys for grub-install inside the chroot on the image
mount --bind /dev  "${MOUNT_DIR}/dev"
mount --bind /proc "${MOUNT_DIR}/proc"
mount --bind /sys  "${MOUNT_DIR}/sys"

# Update /etc/fstab in the image
PART_UUID=$(blkid -s UUID -o value "${PART_DEV}")
cat > "${MOUNT_DIR}/etc/fstab" <<FSTAB
# AIOSCPU fstab
UUID=${PART_UUID}  /  ext4  errors=remount-ro  0  1
tmpfs              /run  tmpfs  defaults  0  0
FSTAB

chroot "${MOUNT_DIR}" grub-install \
    --target=i386-pc \
    --recheck \
    --boot-directory=/boot \
    "${LOOP_DEV}"

chroot "${MOUNT_DIR}" grub-mkconfig -o /boot/grub/grub.cfg

# Enable AIOSCPU systemd services inside image chroot
chroot "${MOUNT_DIR}" systemctl enable aura.service             2>/dev/null || true
chroot "${MOUNT_DIR}" systemctl enable aioscpu-mode-init.service 2>/dev/null || true

# Cleanup image mounts
umount -lf "${MOUNT_DIR}/sys"  2>/dev/null || true
umount -lf "${MOUNT_DIR}/proc" 2>/dev/null || true
umount -lf "${MOUNT_DIR}/dev"  2>/dev/null || true
umount -lf "${MOUNT_DIR}"      2>/dev/null || true
losetup -d "${LOOP_DEV}"       2>/dev/null || true

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "============================================================"
log "  Build complete!"
log "  Output: ${OUTPUT_IMG}"
log "  Size:   ${IMAGE_SIZE_MB}MiB"
log ""
log "  Boot with QEMU:"
log "    qemu-system-x86_64 -m 2048 -hda ${OUTPUT_IMG} -nographic"
log "============================================================"
