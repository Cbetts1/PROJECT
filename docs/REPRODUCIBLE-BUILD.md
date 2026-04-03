# AIOS-Lite Reproducible Build Instructions

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOS-Lite has two deployment modes:

| Mode | Target | Build Required |
|------|--------|---------------|
| **Portable Shell** | Termux (Android), Linux, macOS | None — clone and run |
| **AIOSCPU Image** | Any x86-64 machine / QEMU | `sudo bash aioscpu/build/build-image.sh` |

Both modes are reproducible: given the same source tree they produce the same
functional result.

---

## 1. Portable Shell Mode (No Build Required)

This is the primary mode for running AIOS-Lite on a mobile device (Android/Termux).

### 1.1 Prerequisites

#### Android / Termux

```sh
pkg update && pkg upgrade
pkg install python git openssh
# Optional — for AI inference
pkg install clang cmake ninja
# Optional — for device bridges
pkg install android-tools libimobiledevice
```

#### Debian / Ubuntu (Linux)

```sh
sudo apt-get update
sudo apt-get install -y python3 git openssh-client
# Optional
sudo apt-get install -y android-tools-adb libimobiledevice-utils ifuse
```

#### macOS

```sh
brew install python3 git
# Optional
brew install libimobiledevice ifuse android-platform-tools
```

### 1.2 Clone & Boot

```sh
# Step 1: Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Step 2: Export environment variables
export AIOS_HOME="$(pwd)"
export OS_ROOT="$(pwd)/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# Step 3: Boot the OS
sh OS/sbin/init

# Step 4: (Optional) Generate API token for HTTP server
OS_ROOT="$OS_ROOT" python3 OS/bin/os-httpd --token-gen
```

### 1.3 Install AI Model (Optional)

For full LLM inference:

```sh
# Build llama.cpp
cd /tmp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp && cmake -B build -DLLAMA_NATIVE=ON && cmake --build build -j4
cp build/bin/llama-cli "$AIOS_HOME/llama_model/"

# Place a GGUF model
# 8 GB RAM → 7B Q4_K_M model (~4 GB)
# 6 GB RAM → 3B Q4_K_M model (~2 GB)
cp ~/models/your-model.Q4_K_M.gguf "$AIOS_HOME/llama_model/"
```

### 1.4 Environment Variables Reference

| Variable | Default | Purpose |
|----------|---------|---------|
| `AIOS_HOME` | repo root | AIOS project root |
| `OS_ROOT` | `$AIOS_HOME/OS` | Virtual filesystem jail |
| `AIOS_NAME` | `AIOS-Lite` | OS display name |
| `AIOS_VERSION` | `0.1` | OS version |
| `ENABLE_LLM` | `1` | Enable LLaMA inference |
| `ENABLE_BRIDGE` | `1` | Enable cross-OS bridge |
| `ENABLE_AGENTS` | `1` | Enable background agents |
| `KERNEL_HEARTBEAT_INTERVAL` | `5` | Heartbeat interval (seconds) |
| `LOG_MAX_LINES` | `1000` | Log rotation threshold |

---

## 2. AIOSCPU Disk Image Mode

Produces a bootable `aioscpu-debian-amd64.img` suitable for QEMU or bare metal.

### 2.1 Host Requirements

- Linux host (Debian/Ubuntu recommended)
- 10 GB free disk space
- 2 GB RAM minimum
- Root / sudo access

### 2.2 Dependencies

```sh
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

### 2.3 Build the Image

```sh
cd aioscpu/build
sudo bash build-image.sh
# Output: aioscpu/build/aioscpu-debian-amd64.img (~6 GB)
```

The build script:
1. Runs `debootstrap` for a minimal Debian rootfs
2. Installs required packages in a chroot
3. Creates `aios` and `aura` system users
4. Applies `rootfs-overlay/` tree
5. Copies the AURA agent to `/opt/aura/`
6. Creates a 6 GB image with ext4 root partition
7. Installs GRUB into the image MBR

### 2.4 Run in QEMU

```sh
# Text console (fastest)
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -nographic

# With KVM acceleration
qemu-system-x86_64 \
    -m 2048 \
    -hda aioscpu/build/aioscpu-debian-amd64.img \
    -enable-kvm \
    -nographic
```

Default credentials: `aios` / `aios` — **change immediately**.

---

## 3. Dependency Audit

Run the built-in dependency audit at any time:

```sh
OS_ROOT="$(pwd)/OS" sh OS/bin/os-recover deps
```

### Required (core functionality)

| Binary | Package | Purpose |
|--------|---------|---------|
| `sh` | built-in | POSIX shell |
| `python3` | `python3` | AI core, filesystem module, HTTP server |
| `awk` | `gawk` or `mawk` | Fuzzy matching, log processing |
| `grep` | `grep` | Pattern matching |
| `sed` | `sed` | Text processing |
| `date` | `coreutils` | Timestamps |
| `mkdir` | `coreutils` | Directory creation |
| `uname` | `coreutils` | System identification |

### Optional (enhanced features)

| Binary | Package | Feature |
|--------|---------|---------|
| `openssl` | `openssl` | HTTPS certificate generation |
| `llama-cli` | `llama.cpp` | LLM inference |
| `adb` | `android-tools` | Android bridge |
| `ideviceinfo` | `libimobiledevice` | iOS bridge |
| `nmcli` | `network-manager` | WiFi management |
| `bluetoothctl` | `bluez` | Bluetooth management |
| `avahi-browse` | `avahi-utils` | mDNS service discovery |
| `nmap` | `nmap` | Network scanning |
| `iptables` | `iptables` | Firewall rules |

---

## 4. Running the Test Suite

All tests must pass before deployment.

```sh
# From repo root:
cd /path/to/PROJECT

# 1. Unit tests (shell + Python AI core)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# 2. Integration tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# 3. Python module tests only
python3 tests/test_python_modules.py

# Expected output:
# Unit:        17 passed, 0 failed
# Integration: 49 passed, 0 failed
# Python:      40 tests, 0 failures
```

---

## 5. Self-Repair Test

Verify the self-repair system works on a clean slate:

```sh
# Step 1: Remove some required directories to simulate corruption
cd /path/to/PROJECT
rm -rf OS/var/resource OS/var/backup OS/mirror

# Step 2: Run recovery
OS_ROOT=$(pwd)/OS sh OS/bin/os-recover repair

# Step 3: Verify repair succeeded
OS_ROOT=$(pwd)/OS sh OS/bin/os-recover check
# Expected: all checks pass
```

---

## 6. Persistence Test

Verify that state persists across reboots:

```sh
# Step 1: Set a memory value
export OS_ROOT="$(pwd)/OS"
echo "mem.set test.key my_persistent_value" | sh OS/bin/os-shell

# Step 2: Simulate reboot (re-init)
sh OS/sbin/init --no-shell

# Step 3: Read it back
echo "mem.get test.key" | sh OS/bin/os-shell
# Expected output: my_persistent_value
```

---

## 7. Environment Isolation

AIOS-Lite is fully self-contained within `OS_ROOT`:

```
All runtime state → OS/proc/
All logs          → OS/var/log/
All service PIDs  → OS/var/service/
All memory        → OS/proc/aura/
All events        → OS/var/events/
All config        → OS/etc/
```

No files are written outside `OS_ROOT` during normal operation.  The
filesystem jail (`OS/lib/filesystem.py`) enforces this boundary with a
realpath check on every I/O operation.

---

*Last updated: 2026-04-03*
