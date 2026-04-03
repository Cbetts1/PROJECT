# AIOSCPU Installation Guide

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Prerequisites

### Host System Requirements

- Linux host (Debian/Ubuntu recommended for `debootstrap` compatibility)
- At least **10 GB** free disk space (6 GB image + working directory)
- At least **2 GB** RAM
- Root / sudo access

### Required Tools

Install all dependencies on a Debian/Ubuntu host:

```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap \
    parted \
    qemu-system-x86 \
    qemu-utils \
    grub-pc-bin \
    grub-common \
    xorriso \
    rsync \
    util-linux
```

---

## Clone the Repository

```bash
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
```

---

## Build the Disk Image

```bash
cd aioscpu/build
sudo make image
# or directly:
sudo bash build-image.sh
```

The build process will:
1. Run `debootstrap` to create a minimal Debian rootfs (~5 min)
2. Install all required packages inside a chroot
3. Create the `aios` and `aura` users
4. Apply the `rootfs-overlay/` directory tree
5. Copy the AURA agent to `/opt/aura/`
6. Create a 6 GB disk image with an ext4 root partition
7. Install GRUB into the image MBR

Output: `aioscpu/build/aioscpu-debian-amd64.img`

---

## Boot in QEMU

### Text-only (fastest, for testing):

```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -nographic \
    -serial mon:stdio
```

### With graphical console:

```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -vga std
```

### With KVM acceleration (much faster):

```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -enable-kvm \
    -nographic
```

---

## Default Login Credentials

| User | Password | Notes |
|------|----------|-------|
| `aios` | `aios` | Interactive user, in `sudo` group |
| `root` | (none set) | Direct root login disabled by default |

**Change the `aios` password immediately after first boot:**

```bash
passwd aios
```

---

## Switching Between Modes

AIOSCPU supports two boot modes, selected via the GRUB menu:

### OS-AI Mode (`aioscpu_mode=ai`)
- GRUB menu entry: **"AIOSCPU - OS-AI (AURA interface)"**
- Autologs in as `aios` on tty1
- Launches the AURA AI agent interface (`auractl interactive`)
- AURA service is enabled and started automatically

### OS-SHELL Mode (`aioscpu_mode=shell`)
- GRUB menu entry: **"AIOSCPU - OS-SHELL (standard shell)"**
- Standard multi-user login prompt on tty1
- AURA service is stopped and disabled

You can also switch manually from within a running system:

```bash
# Check current mode
cat /run/aioscpu/mode

# Switch to AI mode for this session
sudo aioscpu-mode-init  # after editing /proc/cmdline simulation is not possible;
                         # reboot and select from GRUB menu instead

# Start AURA manually
sudo systemctl start aura.service
auractl interactive
```

---

## Post-Installation Steps

1. Change the default `aios` password
2. Configure SSH keys (`~/.ssh/authorized_keys`)
3. Review `/etc/sudoers.d/aura-commands` to ensure it matches your security policy
4. Read `docs/LEGAL.md` and `docs/SECURITY.md`
