# Deployment Guide — Installation & Boot Procedures

## Deployment Modes

### Mode 1: Hosted Mode (Recommended for S21 FE)

Runs AIOS as a shell application inside Termux on Android.

**Requirements:** Termux, root access (Magisk)

```bash
bash deploy/container-installer.sh
```

### Mode 2: Standalone Mode (USB Boot)

Boots AIOS as a standalone OS from a USB drive or internal storage partition.

**Requirements:** Custom recovery (TWRP), or boot from `fastboot`

```bash
bash deploy/usb-image-builder.sh --output aios-s21fe.img
```

---

## Hosted Mode Installation

### 1. Prepare Termux

```bash
pkg update -y && pkg upgrade -y
pkg install -y git bash python clang make cmake proot
termux-setup-storage
```

### 2. Run the Installer

```bash
git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios
bash deploy/container-installer.sh
```

The installer performs:

1. Detects device model and RAM
2. Sets `OS_ROOT=$HOME/aios/OS` in `~/.bashrc` / `~/.profile`
3. Compiles `llama.cpp` (or downloads prebuilt binary)
4. Downloads the appropriate quantized model
5. Configures OverlayFS mount points (root required)
6. Runs `deploy/first-boot.sh` to initialize state
7. Runs `deploy/phone-optimizations.sh` to tune the device

### 3. Launch

```bash
bash ~/aios/OS/sbin/init
```

Or add to `~/.bashrc`:

```bash
alias aios='bash ~/aios/OS/sbin/init'
```

---

## USB Standalone Boot

### Build the Image

```bash
bash deploy/usb-image-builder.sh \
  --output /sdcard/aios-s21fe.img \
  --size 8G \
  --device s21fe
```

The image contains:
- Minimal Linux kernel (aarch64, 5.15 LTS)
- BusyBox userland
- AIOS root filesystem
- GRUB/U-Boot bootloader config
- Llama model (optional, increases image size)

### Flash to USB

```bash
dd if=/sdcard/aios-s21fe.img of=/dev/sda bs=4M status=progress sync
```

### Boot

Reboot into Fastboot mode (`Vol Down + Power`), then:

```bash
fastboot boot aios-s21fe.img
```

---

## First Boot Initialization

`deploy/first-boot.sh` runs automatically after install. It:

1. Generates a unique OS identity
2. Initializes Aura memory databases
3. Creates OverlayFS work directories
4. Sets CPU affinity and governor
5. Verifies model checksum

Run manually:

```bash
bash deploy/first-boot.sh
```

---

## Phone Optimizations

`deploy/phone-optimizations.sh` applies S21 FE specific tuning:

```bash
bash deploy/phone-optimizations.sh
```

Applied optimizations:
- CPU governor: `schedutil` (or `performance` when charging)
- CPU affinity: big cores (1–3) for inference
- Disable battery optimization for Termux
- zram setup (4 GB swap)
- vm.overcommit = 1
- Wakelock for sustained inference

---

## Graceful Shutdown

```bash
# From the Aura shell
exit

# Or from the OS
bash OS/bin/shutdown
```

Shutdown procedure:
1. Saves Aura memory and context window
2. Stops inference daemon
3. Unmounts OverlayFS layers
4. Writes shutdown timestamp to logs

---

## Updating AIOS

```bash
cd ~/aios
git pull
bash deploy/first-boot.sh --upgrade
```

---

## Uninstalling

```bash
bash deploy/container-installer.sh --uninstall
```

This removes:
- OverlayFS mounts
- Termux startup hooks
- AIOS environment variables (from `~/.bashrc`)

Model weights in `llama_model/` are NOT removed automatically — delete manually if desired.
