# Building the AIOSCPU Disk Image

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

This guide walks through the complete process of building, booting, and
switching between modes on an AIOSCPU image.

---

## 1. Prerequisites

Ensure you have the required tools installed (see `docs/INSTALL.md`).

Quick install on Debian/Ubuntu:
```bash
sudo apt-get install -y debootstrap parted qemu-system-x86 qemu-utils \
    grub-pc-bin grub-common rsync util-linux
```

---

## 2. Running `build-image.sh`

The build script must be run as root:

```bash
cd aioscpu/build
sudo bash build-image.sh
```

Or via the Makefile:
```bash
sudo make image
```

### What the Script Does (Step by Step)

| Step | Action |
|------|--------|
| 1 | Prepares work directories (`aioscpu/build/work/`) |
| 2 | Runs `debootstrap` to create a minimal Debian Bookworm rootfs |
| 3 | Installs packages in a chroot (linux-image, grub, python3, ssh, etc.) |
| 4 | Creates users: `aios` (interactive) and `aura` (AI agent, locked) |
| 5 | Runs `chroot` configuration (locale, hostname, fstab, service enables) |
| 6 | Applies `aioscpu/rootfs-overlay/` via `rsync` |
| 7 | Copies `aura/` agent files to `/opt/aura/` |
| 8 | Copies `grub.cfg` to `/boot/grub/` |
| 9 | Creates a 6 GB raw disk image with `dd` |
| 10 | Partitions the image with `parted` (MBR, single ext4 partition) |
| 11 | Formats the partition with `mkfs.ext4` |
| 12 | Mounts the image via `losetup` and copies the rootfs with `rsync` |
| 13 | Runs `grub-install` and `grub-mkconfig` inside the image chroot |
| 14 | Enables `aura.service` and `aioscpu-mode-init.service` via `systemctl` |
| 15 | Unmounts everything and detaches the loop device |

### Expected Duration
- `debootstrap`: ~5–10 minutes (depends on mirror speed)
- Package installation in chroot: ~2–5 minutes
- Image creation and GRUB install: ~2–3 minutes
- **Total:** ~10–20 minutes

---

## 3. Build Output

After a successful build:
```
aioscpu/build/aioscpu-debian-amd64.img   # 6 GB raw disk image
```

The `aioscpu/build/work/` directory contains intermediate files and can be
removed with `sudo make clean`.

---

## 4. Booting in QEMU

### Basic (text console):
```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -nographic
```

### With KVM (hardware acceleration, much faster):
```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -enable-kvm \
    -nographic
```

### With networking (user-mode NAT):
```bash
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -enable-kvm \
    -netdev user,id=net0 -device virtio-net,netdev=net0 \
    -nographic
```

---

## 5. Booting in VirtualBox

1. Open VirtualBox → New Machine → Linux → Debian (64-bit)
2. Set RAM to 2048 MB
3. At the disk step, choose **"Use an existing virtual hard disk file"**
4. Click the folder icon → Add → select `aioscpu-debian-amd64.img`
5. **Important:** Convert the raw image to VDI first:
   ```bash
   VBoxManage convertfromraw aioscpu-debian-amd64.img aioscpu.vdi --format VDI
   ```
6. Start the machine — the GRUB menu will appear

---

## 6. Switching Between OS-AI and OS-SHELL Modes

At the GRUB menu (appears for 5 seconds at boot):

- **Arrow up/down** to select:
  - `AIOSCPU - OS-AI (AURA interface)` — AI mode
  - `AIOSCPU - OS-SHELL (standard shell)` — Shell mode
- **Enter** to boot the selected mode

To check the active mode from inside the running system:
```bash
cat /run/aioscpu/mode     # prints "ai" or "shell"
cat /proc/cmdline         # shows the full kernel cmdline
```

To manually invoke AI mode functions without rebooting:
```bash
sudo systemctl start aura.service
auractl interactive
```

---

## 7. Troubleshooting

### Build fails: "debootstrap not found"
```bash
sudo apt-get install debootstrap
```

### Build fails: "losetup: failed to find free device"
You may have stale loop devices. List them and detach:
```bash
losetup -l
sudo losetup -d /dev/loopN   # replace N with the stale device
```

### GRUB: "error: no such partition"
The image may be corrupt. Run `sudo make clean && sudo make image` to rebuild.

### QEMU: black screen / no output
Try adding `-serial stdio` or remove `-nographic` to use a graphical window.

### AURA service fails to start
Check journal:
```bash
journalctl -u aura.service -n 50
```
Ensure `/opt/aura/aura-agent.py` exists and is executable:
```bash
ls -l /opt/aura/
```
