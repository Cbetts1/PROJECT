# AIOS-Lite — Reproducible Build System

> © 2026 Christopher Betts | AIOSCPU Official
> *Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

---

## Overview

AIOS-Lite has two deployment modes:

| Mode | Target | Build Required |
|------|--------|---------------|
| **Portable Shell** | Termux (Android), Linux, macOS | None — clone and run |
| **AIOSCPU Image** | Any x86-64 machine / QEMU | `sudo bash aioscpu/build/build-image.sh` |

Both modes are reproducible: given the same source tree they produce the same functional result.

---

## 1. One-Shot Install Script

The install script at `install.sh` in the repository root performs a complete setup in a single command. It does not require root on Termux/Android; it does require `sudo` on Debian/Ubuntu for optional system-wide tools.

**What the script does (in order):**

1. **Detects the host environment** (Termux/Android, Debian/Ubuntu, Arch, macOS).
2. **Installs system dependencies** using the appropriate package manager (`pkg`, `apt`, `brew`).
3. **Sets `OS_ROOT`** to the `OS/` directory inside the cloned repository.
4. **Creates runtime directories** that are not tracked by git (`var/log/`, `var/run/`, `var/service/`, `proc/`).
5. **Writes `etc/os-release`** with the current version.
6. **Optionally downloads a quantised LLaMA model** (prompts the user; downloads `llama-3.2-3B-Instruct-Q4_K_M.gguf` from Hugging Face if confirmed).
7. **Optionally builds llama.cpp** from source using `build/build.sh --target hosted`.
8. **Runs the test suite** (`bash tests/unit-tests.sh`) to verify the installation.
9. **Prints the boot command** and exits.

**To run:**
```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

---

## 2. Clean-Device Setup Steps

These steps describe a fully manual, step-by-step install from a clean device — no prior setup assumed.

### 2.1 Android (Termux) — Clean Device

```sh
# Step 1: Install Termux from F-Droid (recommended) or Play Store
# Step 2: Open Termux and update base packages
pkg update && pkg upgrade -y

# Step 3: Install runtime dependencies
pkg install -y git python openssh android-tools libimobiledevice ifuse

# Step 4: Install optional build tools (for llama.cpp)
pkg install -y clang cmake ninja

# Step 5: Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Step 6: Set up environment
cd OS
export OS_ROOT="$(pwd)"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# Step 7: Create runtime directories
mkdir -p var/log var/run var/service var/events proc

# Step 8: Boot the OS
sh sbin/init
```

### 2.2 Debian / Ubuntu — Clean Machine

```sh
# Step 1: Update system
sudo apt-get update && sudo apt-get upgrade -y

# Step 2: Install dependencies
sudo apt-get install -y \
    git python3 python3-pip openssh-client \
    android-tools-adb libimobiledevice-utils ifuse sshfs \
    build-essential cmake ninja-build

# Step 3: Clone repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Step 4: Set up environment
cd OS
export OS_ROOT="$(pwd)"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
mkdir -p var/log var/run var/service var/events proc

# Step 5: Optional — install Python dependencies for AI Core
pip3 install -r ../ai/requirements.txt 2>/dev/null || true

# Step 6: Boot
sh sbin/init
```

### 2.3 macOS — Clean Machine

```sh
# Step 1: Install Homebrew (if not present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Step 2: Install dependencies
brew install git python3 libimobiledevice android-platform-tools sshfs

# Step 3: Clone and boot (same as Linux)
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT/OS
export OS_ROOT="$(pwd)"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
mkdir -p var/log var/run var/service var/events proc
sh sbin/init
```

### 2.4 LLaMA Model Setup

```sh
# Create model directory
mkdir -p "$OS_ROOT/../llama_model"

# Option A: Download a small quantised model (3B, ~2GB)
# From Hugging Face (requires huggingface-cli or wget):
wget -O "$OS_ROOT/../llama_model/llama-3.2-3B-Q4_K_M.gguf" \
    "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"

# Option B: Copy a model you already have
cp ~/models/your-model.gguf "$OS_ROOT/../llama_model/"

# Build llama.cpp (optional, for inference)
bash "$OS_ROOT/../build/build.sh" --target hosted
```

### 2.5 AIOSCPU Disk Image (x86-64)

```sh
# Requires: Linux host, sudo, debootstrap, parted, qemu-utils, xorriso, grub
sudo apt-get install -y debootstrap parted qemu-utils xorriso grub-pc-bin grub-common

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
sudo bash aioscpu/build/build-image.sh
# Output: aioscpu/build/aioscpu.iso  (bootable ISO)
# Test:   qemu-system-x86_64 -m 2G -cdrom aioscpu/build/aioscpu.iso
```

---

## 3. Verification Checklist

After installation, run through this checklist to confirm a working system.

### 3.1 Core Boot

- [ ] `sh OS/sbin/init` completes without errors
- [ ] `OS/proc/os.state` file exists and contains `OS_STATE=running`
- [ ] `OS/proc/os.identity` file exists and contains `OS_NAME=AIOS-Lite`
- [ ] `OS/var/log/` directory is writable and contains at least one log entry

### 3.2 Commands

- [ ] `os-info` prints OS name, version, and capabilities
- [ ] `os-state` dumps the current OS state without errors
- [ ] `os-ps` lists running processes
- [ ] `os-service list` shows services with status

### 3.3 AI Shell

- [ ] `os-shell` launches without errors
- [ ] `help` inside `os-shell` prints the command list
- [ ] `ask hello` returns a response (rule-based fallback if no LLM)
- [ ] `mem.set testkey testval` stores a value without error
- [ ] `mem.get testkey` returns `testval`

### 3.4 LLM (if model installed)

- [ ] A `.gguf` file exists in `llama_model/`
- [ ] `llama-cli --version` works (or `llama-cli` is on PATH)
- [ ] `ask what time is it` returns an LLM-generated response
- [ ] Token generation completes within a reasonable time for the hardware

### 3.5 Bridge (if devices connected)

- [ ] `os-bridge detect` runs without error
- [ ] `os-mirror mount android` succeeds (if Android device connected with USB debugging)
- [ ] `ls $OS_ROOT/mirror/android/` shows device files

### 3.6 Test Suite

```sh
# Unit tests (57 total: 17 shell + 40 Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests (87 total)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python AI Core tests only
python3 tests/test_python_modules.py
```

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Python module tests pass

### 3.7 Reproducibility Hash

To verify your build matches a known-good state, compute a checksum of the OS tree (excluding runtime-generated files):

```sh
find OS/ -type f \
    ! -path 'OS/var/*' \
    ! -path 'OS/proc/*' \
    ! -path 'OS/mirror/*' \
    ! -name '*.pid' \
    ! -name '*.health' \
    | sort | xargs cksum | cksum
```

Compare the output with the hash published in the release notes for the version you have installed.

---

*End of Reproducible Build System*

> © 2026 Christopher Betts | AIOS-Lite | https://github.com/Cbetts1/PROJECT
