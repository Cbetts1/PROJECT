# Getting Started with AIOS-Lite

> © 2026 Chris Betts | AIOSCPU Official

Welcome to AIOS-Lite — the AI-Augmented Portable Operating System. This guide walks you through installation, first boot, and core features in under 15 minutes.

---

## Prerequisites

### What You Need

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Shell | POSIX sh (bash, dash, ash) | Pre-installed on all Unix-like systems |
| Python | 3.8+ | For AI core and HTTP API server |
| Git | Any | To clone the repository |
| Disk space | ~200 MB | Excluding LLM model files |
| RAM | 512 MB | 4 GB recommended with LLM enabled |

### Optional (for full features)

| Feature | Requirement |
|---------|-------------|
| LLaMA AI (local LLM) | `llama-cli` from llama.cpp + `.gguf` model |
| iOS Bridge | `libimobiledevice`, `ifuse` |
| Android Bridge | `adb` (Android Debug Bridge) |
| SSH Mirror | `ssh`, `sshfs` |
| WiFi management | `nmcli` (NetworkManager) |
| Bluetooth | `bluetoothctl` (bluez) |

---

## Step 1: Install

### Android (Termux) — Recommended for Mobile

```sh
# Install Termux from F-Droid (not Google Play)
pkg update && pkg upgrade -y
pkg install git python bash openssh

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### Linux (Debian / Ubuntu / Raspberry Pi OS)

```sh
sudo apt update
sudo apt install -y git python3 python3-pip bash openssh-client

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### macOS

```sh
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git python

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

---

## Step 2: Boot the OS

```sh
cd PROJECT
sh OS/sbin/init
```

You should see the AIOS-Lite boot banner followed by the kernel daemon starting.

---

## Step 3: Launch the AI Shell

```sh
os-shell
```

You are now inside the AIOS-Lite interactive shell. Try:

```sh
help           # Show all commands
status         # OS state
services       # Service health
ask "hello"    # Talk to the AI
```

---

## Step 4: Explore Core Commands

### AI Interaction

```sh
ask "what is the current disk usage?"
ask "is the kernel running?"
ask "check memory"
```

### System Information

```sh
sysinfo        # Full system info
uptime         # Uptime
disk           # Disk usage
ps             # Process list
netinfo        # Network interfaces
```

### Memory System

```sh
# Store a fact in symbolic memory
mem.set name "Chris"
mem.set project "AIOS-Lite"

# Recall a fact
mem.get name

# Store a semantic note
sem.set note1 "I connected my iPhone on Monday"

# Search semantic memory
sem.search "iPhone connection"

# Hybrid recall — searches all memory layers at once
recall "what phone did I connect"
```

### Cross-OS Bridge

```sh
# Detect connected devices
bridge.detect

# Mirror an Android device (requires ADB + USB debugging)
mirror.mount android
ls $OS_ROOT/mirror/android/

# Mirror a remote Linux server via SSH
mirror.mount ssh user@192.168.1.100
ls $OS_ROOT/mirror/linux/

# Mirror an iPhone (requires libimobiledevice + ifuse)
bridge.detect
mirror.mount ios
ls $OS_ROOT/mirror/ios/
```

---

## Step 5: Enable the HTTP API (optional)

The built-in HTTP API server lets you control AIOS-Lite from any web browser or HTTP client.

```sh
# Generate an API token
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --token-gen

# Start the HTTP server (development mode, no auth)
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --port 8080 --no-auth

# Or start with authentication
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --port 8080

# Verify it's running
curl http://localhost:8080/api/v1/health
# → {"status": "ok", "time": "2026-04-03T15:55:10Z"}
```

See the full [API Reference](api-reference.md) for all available endpoints.

---

## Step 6: Enable LLaMA AI (optional)

For full natural language AI, install llama.cpp and download a GGUF model.

### Install llama.cpp

```sh
# Linux / Raspberry Pi / macOS
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp && make -j4
sudo cp llama-cli /usr/local/bin/

# Android (Termux)
pkg install llama-cpp
```

### Download a Model

```sh
mkdir -p OS/llama_model
# Example: LLaMA 3.2 3B int4 (good for 6GB phones)
# Download a .gguf file from Hugging Face and place it here:
# OS/llama_model/your-model.Q4_K_M.gguf
```

### Verify LLM Works

```sh
os-shell
ask "tell me something interesting"
# Should now respond using the LLaMA model instead of rule-based fallback
```

---

## Step 7: Shell Modes

AIOS-Lite has three interaction modes:

```sh
mode operator   # Full system access (default)
mode system     # Diagnostic / service management mode
mode talk       # Conversational AI-only mode
```

---

## Next Steps

| What to do | Where to go |
|------------|-------------|
| Set up web hosting | [Deployment Guide](../DEPLOYMENT.md) |
| Use the REST API | [API Reference](api-reference.md) |
| Configure networking | [Networking Config](../NETWORKING-CONFIG.md) |
| Understand the architecture | [Architecture](../ARCHITECTURE.md) |
| View all features | [Capabilities Matrix](../CAPABILITIES.md) |
| Security hardening | [Security Guide](../SECURITY.md) |
| Build a disk image | [Building Image](../BUILDING-IMAGE.md) |

---

## Troubleshooting

### "command not found: os-shell"

```sh
# Set your PATH to include the OS bin directory
export OS_ROOT="$(pwd)/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
```

### "python3: No module named ..."

```sh
# Install required Python packages
pip3 install -r requirements.txt   # if present
# Or install individually
pip3 install openssl
```

### AI gives generic responses (rule-based fallback)

This is normal if `llama-cli` is not installed or no `.gguf` model is in `OS/llama_model/`. The fallback engine handles common OS queries. See Step 6 for LLM setup.

### Port 8080 already in use

```sh
# Find and stop the process using port 8080
lsof -ti:8080 | xargs kill -9
# Or use a different port
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --port 9090
```

### ADB device not detected

```sh
# Enable USB debugging on your Android device
# Then verify ADB sees the device
adb devices
# Should show your device serial number
os-bridge android devices
```

---

*© 2026 Chris Betts | AIOSCPU Official | Last updated: 2026-04-03*
