# AIOS-Lite — AI-Augmented Portable Operating System

**AIOS-Lite** is a lightweight, AI-powered operating system built entirely in POSIX shell script. It runs on any Unix-like environment (Termux/Android, Linux, macOS) and can **bridge to and mirror** other operating systems — plug it into an iPhone, Android phone, or remote Linux server, and your OS gains access to those systems through a unified interface.

---

## Vision

> *"Plug your OS into any device and your system mirrors it — giving you the power of your AI OS on top of any platform."*

- **Portable**: Runs from a USB drive, Android phone (Termux), Raspberry Pi, or any shell
- **AI-Powered**: Hybrid memory (context + symbolic + semantic) + optional LLaMA LLM
- **Cross-OS Bridge**: Connect to iOS, Android, Linux, macOS, or remote SSH hosts
- **Mirror Filesystem**: Access other devices' files through your own namespace at `$OS_ROOT/mirror/`

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

## License

MIT — Built by Chris
