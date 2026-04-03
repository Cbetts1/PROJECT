# Installation Guide — AIOS-Lite / AIOSCPU

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Quick Install — One Line](#2-quick-install--one-line)
3. [Manual Install — Step by Step](#3-manual-install--step-by-step)
4. [Platform-Specific Instructions](#4-platform-specific-instructions)
   - [Android / Termux](#41-android--termux)
   - [Debian / Ubuntu / Kali](#42-debian--ubuntu--kali)
   - [macOS](#43-macos)
   - [Raspberry Pi / ARM Linux](#44-raspberry-pi--arm-linux)
5. [AI Model Setup (Optional)](#5-ai-model-setup-optional)
6. [Cross-OS Bridge Dependencies](#6-cross-os-bridge-dependencies)
7. [AIOSCPU Native Image (Advanced)](#7-aioscpu-native-image-advanced)
8. [Verifying the Installation](#8-verifying-the-installation)
9. [Uninstalling](#9-uninstalling)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. System Requirements

### Minimum (core OS, no LLM)

| Requirement | Minimum |
|-------------|---------|
| Shell | POSIX sh (`/bin/sh`) |
| Utilities | `awk`, `grep`, `sed`, `cksum`, `date`, `ps`, `kill` |
| Python | Python 3.9+ |
| Disk | 20 MB for the OS tree |
| RAM | 32 MB available |

### Recommended (with LLaMA AI)

| Requirement | Recommended |
|-------------|-------------|
| RAM | 4 GB+ (6–8 GB for 7B model) |
| Disk | 5 GB+ (model file) |
| CPU | 4+ cores (big cores for inference) |
| Python | 3.11+ |

---

## 2. Quick Install — One Line

```sh
git clone https://github.com/Cbetts1/PROJECT.git && cd PROJECT && sh install.sh
```

The `install.sh` script will:
1. Detect your platform
2. Set `AIOS_HOME` and `OS_ROOT`
3. Create the OS runtime directory tree
4. Add AIOS to your shell's `PATH`
5. Print a success message with next steps

---

## 3. Manual Install — Step by Step

### Step 1: Clone the repository

```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
```

### Step 2: Set environment variables

Add to your `~/.bashrc`, `~/.zshrc`, or `~/.profile`:

```sh
export AIOS_HOME="/path/to/PROJECT"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"
```

Reload your shell:

```sh
source ~/.bashrc   # or ~/.zshrc
```

### Step 3: Bootstrap the OS tree

```sh
cd "$AIOS_HOME"
sh OS/sbin/init
```

This resolves `OS_ROOT`, creates all required runtime directories, and
writes the initial OS state files.

### Step 4: Launch the AI shell

```sh
os-shell
```

You should see the AIOS banner and the `aios>` prompt.

---

## 4. Platform-Specific Instructions

### 4.1 Android / Termux

```sh
# Install Termux from F-Droid (recommended) or Google Play
pkg update && pkg upgrade
pkg install git python python-pip

# Optional: cross-OS bridge tools
pkg install libimobiledevice ifuse android-tools openssh sshfs

# Clone and boot
git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios
export AIOS_HOME="$HOME/aios"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"
sh OS/sbin/init
os-shell
```

### 4.2 Debian / Ubuntu / Kali

```sh
sudo apt update
sudo apt install git python3 python3-pip awk grep sed

# Optional: cross-OS bridge tools
sudo apt install libimobiledevice-utils ifuse adb openssh-client sshfs

git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios
sh install.sh
```

### 4.3 macOS

```sh
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"

brew install git python3

# Optional: cross-OS bridge tools
brew install libimobiledevice ifuse android-platform-tools openssh

git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios
sh install.sh
```

### 4.4 Raspberry Pi / ARM Linux

```sh
sudo apt update
sudo apt install git python3 python3-pip

git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios
sh install.sh
```

---

## 5. AI Model Setup (Optional)

AIOS-Lite works without a model (rule-based fallback). For full AI:

### Download a GGUF model

```sh
# Example: llama-3.2-3B-Instruct (good for 6 GB RAM devices)
mkdir -p "$AIOS_HOME/llama_model"
# Download from Hugging Face:
# https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF
# Place the .gguf file in llama_model/
```

### Install llama.cpp

```sh
# Build from source (see docs/AI_MODEL_SETUP.md for full instructions)
bash build/build.sh --target hosted
```

### Configure the model path

Edit `config/aios.conf`:

```sh
LLAMA_MODEL="$AIOS_HOME/llama_model/your-model.Q4_K_M.gguf"
LLAMA_BINARY="$AIOS_HOME/build/llama.cpp/build/bin/llama-cli"
```

---

## 6. Cross-OS Bridge Dependencies

| Bridge | Required packages |
|--------|------------------|
| iOS | `libimobiledevice`, `ifuse`, `ideviceinfo`, `idevicepair` |
| Android | `adb` (Android Debug Bridge) |
| Remote Linux | `ssh`, `sshfs` (optional for mount) |

Enable after installing:

```sh
os-bridge detect        # auto-detect connected devices
os-mirror mount ios     # mount iPhone filesystem
os-mirror mount android # mount Android filesystem
os-mirror mount ssh user@host # mount remote Linux via SSH
```

---

## 7. AIOSCPU Native Image (Advanced)

To build a bootable AIOSCPU ISO image:

```sh
# Requires: Buildroot, GRUB, make, xorriso
cd aioscpu/build
make
# Output: aioscpu.iso
```

See [docs/BUILDING-IMAGE.md](docs/BUILDING-IMAGE.md) and
[docs/AIOSCPU-ARCHITECTURE.md](docs/AIOSCPU-ARCHITECTURE.md) for details.

---

## 8. Verifying the Installation

```sh
# Check OS state
os-info

# Run all tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Verify kernel
os-kernelctl status

# Check services
os-service-status
```

Expected output includes `AIOS-Lite` version, runlevel `2`, and all services `RUNNING`.

---

## 9. Uninstalling

```sh
# Stop the kernel daemon
os-kernelctl stop

# Remove the directory
rm -rf "$AIOS_HOME"

# Remove PATH entries from your shell profile
# Edit ~/.bashrc or ~/.zshrc and remove AIOS_HOME / OS_ROOT lines
```

---

## 10. Troubleshooting

| Problem | Solution |
|---------|---------|
| `os-shell: command not found` | Ensure `$OS_ROOT/bin` is in `PATH` |
| `OS_ROOT is not set` | Export `OS_ROOT` before running any OS command |
| `python3: command not found` | Install Python 3.9+ for your platform |
| AI returns "mock response" | No GGUF model found — see §5 above |
| iOS bridge fails | Run `idevicepair pair` first; check `libimobiledevice` version |
| Android bridge fails | Enable USB debugging; run `adb devices` to verify |
| Tests fail with permission errors | Ensure `OS_ROOT` points to a writable directory |

For more detailed troubleshooting, see the [INSTRUCTION-MANUAL.md](docs/INSTRUCTION-MANUAL.md).
