# AIOS Quick Start Guide

Get up and running in 5 minutes on your Samsung Galaxy S21 FE.

---

## Prerequisites

1. **Root access** — Magisk or equivalent
2. **Termux** — install from F-Droid (recommended over Play Store)
3. **Termux:API** — for hardware integration
4. ~8 GB of free internal storage

---

## Step 1 — Install Termux Packages

```bash
pkg update -y && pkg upgrade -y
pkg install -y git curl wget bash python clang make cmake
```

---

## Step 2 — Clone the Repository

```bash
cd ~
git clone https://github.com/Cbetts1/PROJECT.git aios
cd aios
```

---

## Step 3 — Run the Installer

```bash
bash deploy/container-installer.sh
```

The installer will:
- Detect your device (S21 FE)
- Set `OS_ROOT` to `$HOME/aios/OS`
- Download the quantized Llama model (~4 GB) if not already present
- Configure the Aura shell
- Set up OverlayFS mirror points (requires root)

---

## Step 4 — Boot the AI OS

```bash
bash OS/sbin/init
```

Or launch just the AI shell:

```bash
bash OS/bin/os-shell
```

---

## Step 5 — First Commands

```bash
# System information
sysinfo

# Check AI status
recall hello

# Store a memory
mem.set project.name "My AIOS build"
mem.get project.name

# Use AI inference
ai.ask "What is the weather like today?"

# Check system health
bash scripts/health-check.sh
```

---

## USB Boot (Advanced)

To create a bootable USB image:

```bash
bash deploy/usb-image-builder.sh --output /sdcard/aios.img
```

Flash to a USB drive:

```bash
dd if=/sdcard/aios.img of=/dev/sdX bs=4M status=progress
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Model not found" | Run `bash ai/model-quantizer/download-model.sh` |
| "Permission denied" | Ensure root access: `su -c 'bash deploy/container-installer.sh'` |
| "Out of memory" | Enable 4 GB zram: `bash scripts/optimize-for-phone.sh --zram` |
| Shell won't start | Check logs: `cat OS/var/log/boot.log` |

---

## Updating

```bash
cd ~/aios
git pull
bash deploy/first-boot.sh --upgrade
```

---

## Uninstall

```bash
bash deploy/container-installer.sh --uninstall
```
