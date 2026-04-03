# AIOS-Lite — Your AI OS. Any Device. Any Shell.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0--Aurora-blue.svg)](CHANGELOG.md)
[![Tests](https://img.shields.io/badge/tests-144%20passing-brightgreen.svg)](tests/)

**AIOS-Lite** is a portable, AI-native operating system built entirely in POSIX shell and Python 3.
It runs on any Unix-like environment (Android/Termux, Linux, macOS) — no root, no installation required.
Drop in a LLaMA model and your shell starts thinking.  Connect a device and your OS mirrors it.

> *"Plug your OS into any device and your system mirrors it — giving you the power of your AI OS on top of any platform."*

---

## Why AIOS-Lite?

| | |
|---|---|
| 🧠 **On-device AI** | LLaMA inference runs on your hardware — no cloud, no subscription, no telemetry |
| 🐚 **Shell-portable** | Clone and boot in under a minute on Android (Termux), Linux, or macOS |
| 🔗 **Cross-OS bridge** | Mirror iOS, Android, and Linux filesystems into a unified namespace |
| 🛡️ **Capability security** | Fine-grained permissions per principal; every syscall is audit-logged |
| 🔁 **Self-healing** | Five-stage automated recovery mode detects and repairs itself |
| 🌐 **REST + WebSocket API** | Built-in HTTP server with TLS 1.2, token auth, and Server-Sent Events |
| 💾 **3-layer AI memory** | Context window + symbolic key-value + semantic embeddings + hybrid recall |
| 📦 **Reproducible builds** | Portable shell mode (zero build) or full AIOSCPU disk image from source |

---

## Directory Structure

```
OS/
├── sbin/init              # Boot init (auto-detects OS_ROOT)
├── bin/                   # Commands
│   ├── os-shell           # Main interactive AI shell
│   ├── os-bridge          # Cross-OS bridge control
│   ├── os-mirror          # Device filesystem mirroring
│   ├── os-ai              # Standalone AI chat interface
│   ├── os-kernelctl       # Kernel daemon control
│   ├── os-info            # System information
│   ├── os-state           # OS state dump
│   ├── os-service-status  # Service health overview
│   ├── os-event           # Fire system events
│   ├── os-msg             # Send messages to bus
│   └── os-log             # Write to system log
├── lib/
│   ├── aura-llm/          # LLM integration (llama.cpp wrapper + fallback)
│   ├── aura-bridge/       # Cross-OS bridge modules
│   │   ├── detect.mod     # Host OS + device detection
│   │   ├── ios.mod        # Apple iOS bridge (libimobiledevice)
│   │   ├── android.mod    # Android bridge (ADB)
│   │   ├── linux.mod      # Linux/macOS/SSH bridge
│   │   └── mirror.mod     # Unified mirror orchestration
│   ├── aura-memory/       # Symbolic key-value memory
│   ├── aura-semantic/     # Semantic embedding memory
│   ├── aura-hybrid/       # Hybrid recall engine
│   ├── aura-policy/       # Event-driven policy engine
│   ├── aura-agents/       # Background agents
│   ├── aura-tasks/        # Scheduled tasks
│   └── aura-mods/         # Loadable modules (core, bus, sysinfo)
├── etc/
│   ├── init.d/            # Service scripts (banner, devices, os-kernel, aura-bridge)
│   ├── rc2.d/             # Runlevel 2 service symlinks
│   ├── aura/              # Aura config (modules, agents, tasks, policy, memory indexes)
│   └── os-release         # OS identity
├── proc/                  # Runtime state (kernel, memory, bridge status)
├── mirror/                # Mounted device filesystems
│   ├── ios/               # iOS device (via ifuse)
│   ├── android/           # Android device (via ADB)
│   ├── linux/             # Host or remote Linux
│   └── custom/            # Custom mounts
├── var/
│   ├── log/               # System logs (auto-rotated at 1000 lines)
│   ├── events/            # Event files
│   └── service/           # PID and health files
└── llama_model/           # Place your .gguf LLaMA model here
```

---

## Quick Start

### 1. Boot the OS

```sh
# From any Unix shell:
cd /path/to/OS
export OS_ROOT="$(pwd)"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh sbin/init
```

### 2. Launch the AI Shell

```sh
os-shell
```

### 3. Enable AI (Optional — LLaMA model)

```sh
mkdir -p "$OS_ROOT/llama_model"
# Place a GGUF model file here, e.g.:
# cp ~/models/llama-3-8b.Q4_K_M.gguf "$OS_ROOT/llama_model/"
# Install llama.cpp: https://github.com/ggerganov/llama.cpp
```

### 4. Connect to Another Device

```sh
# Detect what's connected
os-bridge detect

# Mirror an iPhone (requires libimobiledevice + ifuse)
os-bridge ios pair
os-mirror mount ios
ls $OS_ROOT/mirror/ios/

# Mirror an Android device (requires ADB + USB debugging)
os-bridge android devices
os-mirror mount android
cat $OS_ROOT/mirror/android/_sdcard.listing

# Mirror a remote Linux/macOS via SSH
os-mirror mount ssh myuser@192.168.1.100
ls $OS_ROOT/mirror/linux/ssh_192.168.1.100/
```

---

## Shell Commands

| Command | Description |
|---|---|
| `ask <text>` | Ask the AI |
| `bridge.detect` | Detect connected devices |
| `mirror.mount <type>` | Mount device: ios/android/linux/auto |
| `mirror.ls <type>` | Browse mirrored files |
| `recall <text>` | Hybrid memory recall |
| `mem.set <k> <v>` | Store symbolic memory |
| `sem.set <k> <v>` | Store semantic memory |
| `mode <m>` | Shell mode: operator/system/talk |
| `status` | Full OS state |
| `services` | Service health |
| `help` | Full command list |

---

## Cross-OS Bridge Architecture

```
┌─────────────────────────────────────────┐
│           AIOS-Lite Shell               │
│   (Your Portable AI OS)                 │
└─────────────────┬───────────────────────┘
                  │ bridge layer
     ┌────────────┼────────────┐
     ▼            ▼            ▼
  iOS Bridge  Android Bridge  Linux Bridge
  (libimob)   (ADB)           (native/SSH/SSHFS)
     │            │            │
     ▼            ▼            ▼
  iPhone      Android       Linux/macOS/
  iPad        Device        Remote Server
     │            │            │
     └────────────┴────────────┘
                  │
            mirror/ios/
            mirror/android/
            mirror/linux/
```

---

## Prerequisites

| Feature | Requirement |
|---|---|
| Core OS | POSIX sh, awk, grep, sed, cksum |
| iOS Bridge | `libimobiledevice` (`ideviceinfo`, `idevicepair`), `ifuse` |
| Android Bridge | `adb` (Android Debug Bridge) |
| Remote Linux | `ssh`, `sshfs` (optional) |
| Full AI (LLM) | `llama-cli` or `llama.cpp`, any `.gguf` model |

### Install on Termux (Android)
```sh
pkg update
pkg install libimobiledevice ifuse android-tools openssh sshfs
```

### Install on Debian/Ubuntu
```sh
apt install libimobiledevice-utils ifuse adb openssh-client sshfs
```

---

## AI Memory System

AIOS-Lite has three layers of memory:

| Layer | Storage | Use case |
|---|---|---|
| **Context Window** | Rolling 50-line file | Recent conversation + commands |
| **Symbolic Memory** | Key-value index | Named facts (`mem.set name "Chris"`) |
| **Semantic Memory** | Embedding index | Similarity search (`sem.search "phone info"`) |

All three combine in **hybrid recall**:
```sh
recall "what phone did I connect"
```

---

## LLM Integration

When a `.gguf` model is present in `llama_model/` and `llama-cli` is installed, the AI shell uses it for natural language responses. Without a model, it uses a rule-based fallback that handles common queries about the OS, bridge, and memory.

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture and directory structure |
| [docs/KERNEL-DESIGN.md](docs/KERNEL-DESIGN.md) | Pseudo-kernel design, boot sequence, syscall table |
| [docs/CAPABILITIES.md](docs/CAPABILITIES.md) | Full capability matrix (status / component / tested) |
| [docs/API-REFERENCE.md](docs/API-REFERENCE.md) | Complete API reference (syscall, kernel, REST, AI) |
| [docs/AURA-API.md](docs/AURA-API.md) | AURA agent API reference |
| [docs/SECURITY.md](docs/SECURITY.md) | Security architecture and hardening guide |
| [docs/INSTALL.md](docs/INSTALL.md) | Installation guide (AIOSCPU image) |
| [docs/REPRODUCIBLE-BUILD.md](docs/REPRODUCIBLE-BUILD.md) | Reproducible build instructions |
| [docs/AI_MODEL_SETUP.md](docs/AI_MODEL_SETUP.md) | LLaMA model setup guide |
| [CHANGELOG.md](CHANGELOG.md) | Full release history |
| [ROADMAP.md](ROADMAP.md) | Short-term and long-term goals |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting policy |
| [LAUNCH.md](LAUNCH.md) | Public launch materials, press release, branding |

---

## Contributing

Contributions are welcome!  See [MAINTAINERS.md](MAINTAINERS.md) for the
contribution process.

Run the test suite before submitting:
```sh
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
```

---

## License

MIT — © 2026 Christopher Betts.  See [LICENSE](LICENSE) for the full text.

Third-party dependency licenses: [licenses/THIRD_PARTY_LICENSES.md](licenses/THIRD_PARTY_LICENSES.md)

