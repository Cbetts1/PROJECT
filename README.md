# AIOS-Lite

**AI-Augmented Portable Operating System**

```
    _   ___ ___  ___ ___ ___  _   _
   /_\ |_ _/ _ \/ __/ __| _ \| | | |
  / _ \ | || (_) \__ \__ \  _/ |_| |
 /_/ \_\___\___/|___/___/_|  \___/
         ___  ___
        / _ \/ __|
       | (_) \__ \
        \___/|___/
```

> *"Plug your OS into any device — and your AI comes with it."*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Termux · Linux · macOS](https://img.shields.io/badge/platform-Termux%20%7C%20Linux%20%7C%20macOS-lightgrey)](docs/INSTALL.md)
[![AI: LLaMA / llama.cpp](https://img.shields.io/badge/AI-LLaMA%20%2F%20llama.cpp-orange)](docs/AI_MODEL_SETUP.md)

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> aios && cd aios

# 2. Set permissions
chmod +x bin/* tools/* OS/bin/* OS/sbin/*

# 3. Verify installation
bash tools/health_check.sh

# 4. Start AIOS
./bin/aios
```

**Key documentation:**
- [Operator Runbook](docs/OPERATOR-RUNBOOK.md) — Complete operations guide
- [Installation Guide](docs/INSTALL.md) — Detailed setup instructions
- [AI Model Setup](docs/AI_MODEL_SETUP.md) — LLM configuration
- [Portability Matrix](docs/PORTABILITY-MATRIX.md) — Supported environments
- [Offline Behavior](docs/OFFLINE-BEHAVIOR.md) — Offline-first operation

---

## Overview

**AIOS-Lite** is a complete, self-contained AI operating system written in POSIX shell and Python. It runs on top of any Unix-like environment — your Android phone (Termux), a Raspberry Pi, a Linux desktop, or a macOS machine — without modifying the host OS.

AIOS-Lite provides:
- A **pseudo-kernel** with scheduler, resource manager, permissions, and service registry
- **AURA** — an AI cognitive layer with hybrid memory and optional LLaMA LLM
- A **cross-OS bridge** that mirrors iOS, Android, Linux, and remote SSH hosts
- A fully interactive **AI shell** with natural language commands
- A **plugin API** for extending the OS at runtime

---

## Features

| Feature | Description |
|---|---|
| 🧠 **AI Shell** | Natural language OS control via AURA + LLaMA |
| 🌉 **Cross-OS Bridge** | Connect to iOS, Android, Linux, macOS, SSH hosts |
| 🪞 **Filesystem Mirror** | Browse any connected device under `$OS_ROOT/mirror/` |
| 💾 **Hybrid Memory** | Context window + symbolic key-value + semantic embeddings |
| 🔒 **Permissions Model** | Capability-based access control per service |
| 📋 **Service Registry** | Start/stop/monitor services with health checks |
| ⏱ **Scheduler** | Cooperative round-robin scheduler with priority tiers |
| 📦 **Plugin System** | Drop shell scripts into `OS/lib/aura-mods/` to extend the OS |
| 📡 **HTTP API** | Built-in `os-httpd` for local REST-style access |
| 🔧 **Self-Repair** | `os-recover` detects and repairs broken subsystems |

---

## Architecture Summary

```
╔══════════════════════════════════════════════════════════════╗
║                    USER / AI SHELL LAYER                    ║
║          os-shell  ·  os-ai  ·  bin/aios  ·  bin/aios-sys   ║
╠══════════════════════════════════════════════════════════════╣
║                      AURA COGNITIVE LAYER                   ║
║   IntentEngine → Router → Bots/Handlers → LLM (llama.cpp)   ║
╠══════════════════════════════════════════════════════════════╣
║                    OS SERVICES LAYER                        ║
║  logging · events · message-bus · service-health · state    ║
╠══════════════════════════════════════════════════════════════╣
║                  PSEUDO-KERNEL (sbin/init)                  ║
║   scheduler · resource-mgr · permissions · service-registry ║
╠══════════════════════════════════════════════════════════════╣
║                    BRIDGE / MIRROR LAYER                    ║
║          iOS bridge · Android bridge · SSH bridge           ║
╠══════════════════════════════════════════════════════════════╣
║                      HOST POSIX KERNEL                      ║
║          Linux / Android (Termux) / macOS / Darwin          ║
╚══════════════════════════════════════════════════════════════╝
```

Full architecture documentation: [`docs/OS-ARCHITECTURE.md`](docs/OS-ARCHITECTURE.md)

---

## Install

### Android / Termux (Primary Target)

```sh
# 1. Install dependencies
pkg update && pkg upgrade
pkg install git python openssh android-tools libimobiledevice

# 2. Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# 3. Boot AIOS-Lite
cd OS
export OS_ROOT="$(pwd)"
export AIOS_HOME="$(dirname $(pwd))"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh sbin/init
```

### Debian / Ubuntu / Linux

```sh
sudo apt-get install -y git python3 openssh-client \
    android-tools-adb libimobiledevice-utils ifuse sshfs

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT/OS
export OS_ROOT="$(pwd)"
sh sbin/init
```

### macOS

```sh
brew install git python3 libimobiledevice android-platform-tools

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT/OS
export OS_ROOT="$(pwd)"
sh sbin/init
```

Detailed install guide: [`docs/INSTALL.md`](docs/INSTALL.md)

---

## Quick Start

```sh
# Launch the interactive AI shell
os-shell

# Ask the AI a question
ask what is my system status

# Store something in memory
mem.set myname "Christopher"

# Connect to an Android device (USB debugging on)
bridge.detect
mirror.mount android
mirror.ls android

# Mirror a remote server
os-mirror mount ssh user@192.168.1.100

# Check all services
services

# Run self-repair
os-recover
```

---

## Usage Examples

### AI Conversation

```
aios> ask what services are running
AURA: I can see 7 services running. aura-bridge is healthy, aura-llm is
      active with a 7B model loaded. os-kernel reports no errors.

aios> mem.set project "AI OS documentation"
AURA: Stored. You can recall this with: recall project

aios> recall project
AURA: [symbolic] project = "AI OS documentation"
```

### Bridge and Mirror

```sh
# Detect all connected devices
os-bridge detect

# Mount iOS filesystem
os-bridge ios pair
os-mirror mount ios
ls $OS_ROOT/mirror/ios/

# Android via ADB
os-mirror mount android
cat $OS_ROOT/mirror/android/_sdcard.listing

# Remote Linux via SSH
os-mirror mount ssh admin@10.0.0.5
ls $OS_ROOT/mirror/linux/ssh_10.0.0.5/
```

### Service Management

```sh
os-service list              # List all services
os-service start aura-bridge # Start bridge service
os-service-health            # Health dashboard
```

```sh
# Auto-detect any connected device
bridge.detect

## Directory Structure

```
PROJECT/
├── OS/                     # The operating system root ($OS_ROOT)
│   ├── sbin/init           # Boot init script
│   ├── bin/                # OS commands (os-shell, os-bridge, os-ai, ...)
│   ├── lib/                # AURA modules (bridge, llm, memory, policy, ...)
│   ├── etc/                # Config (init.d/, rc2.d/, perms.d/, aura/)
│   ├── proc/               # Runtime state
│   ├── mirror/             # Mounted device filesystems
│   └── var/                # Logs, events, service PID/health files
├── ai/core/                # Python AI Core (IntentEngine, Router, Bots, LLM)
├── bin/                    # Dual-shell launchers (aios, aios-sys, aios-heartbeat)
├── lib/                    # AURA shell libraries (aura-core.sh, aura-net.sh, ...)
├── config/                 # Runtime configuration (aios.conf, llama-settings.conf)
├── build/                  # Build scripts for AIOSCPU disk image
├── aura/                   # AURA agent definition and memory schema
├── docs/                   # All documentation
├── tests/                  # Unit and integration tests
└── licenses/               # Third-party license notices
```

---

## Roadmap

See [`ROADMAP.md`](ROADMAP.md) for the full roadmap.

**Upcoming milestones:**
- v0.3 — Persistent SQLite memory backend, improved intent classification
- v0.4 — Web UI dashboard, REST API hardening, plugin marketplace
- v0.5 — Multi-user sessions, encrypted memory store
- v1.0 — Stable release with full AIOSCPU disk image

See [`docs/AI_MODEL_SETUP.md`](docs/AI_MODEL_SETUP.md) for full LLM configuration details.

---

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

---

## Documentation

| Document | Description |
|---|---|
| [`docs/OS-ARCHITECTURE.md`](docs/OS-ARCHITECTURE.md) | Full OS architecture reference |
| [`docs/MANUAL.md`](docs/MANUAL.md) | Instruction manual |
| [`docs/INSTALL.md`](docs/INSTALL.md) | Detailed install guide |
| [`docs/REPRODUCIBLE-BUILD.md`](docs/REPRODUCIBLE-BUILD.md) | Reproducible build system |
| [`docs/API-REFERENCE.md`](docs/API-REFERENCE.md) | API reference |
| [`docs/AURA-API.md`](docs/AURA-API.md) | AURA cognitive API |
| [`docs/LEGAL.md`](docs/LEGAL.md) | Legal, compliance, and license package |
| [`ROADMAP.md`](ROADMAP.md) | Project roadmap |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |

---

## License

MIT — see [`LICENSE`](LICENSE)

---

## Legal

© 2026 Christopher Betts. All rights reserved.

*Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

This project contains AI-generated code. See [`docs/LEGAL.md`](docs/LEGAL.md) for full legal notices, privacy information, terms of use, and AI-generated code disclosure.
