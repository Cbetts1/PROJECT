# AIOS-Lite — GitHub Project Page

> **AI-Augmented Portable Operating System**

---

## What Is AIOS-Lite?

**AIOS-Lite** is an AI-augmented portable operating system written in POSIX shell script. It runs on any Unix-like environment — Android (Termux), Linux, macOS, or Raspberry Pi — and can bridge to and mirror other operating systems through a unified, intelligent shell interface.

Plug AIOS-Lite into any device, and your operating system gains access to it.

---

## Purpose

Modern computing is fragmented. You have data on your phone, a server in the cloud, another machine at home, and none of them speak the same language. AIOS-Lite bridges that gap.

AIOS-Lite provides:

- A **portable AI operating system** that travels with you, on any device
- A **natural-language shell** that understands intent, not just exact commands
- A **cross-platform bridge** that connects iOS, Android, Linux, and remote servers into a single unified namespace
- A **local AI assistant** that runs entirely on-device, with no cloud dependency

---

## Key Capabilities

| Capability | Description |
|---|---|
| **POSIX Shell Kernel** | Lightweight OS core requiring only `sh`, `awk`, `grep`, `sed`, `cksum` |
| **AI Intent Engine** | Python NLP classifier routes natural language to specialist handlers |
| **Hybrid Memory** | Context window + symbolic key-value + semantic embedding search |
| **LLaMA LLM Integration** | On-device large language model inference via llama.cpp (optional) |
| **iOS Bridge** | Connect to iPhone/iPad via libimobiledevice and ifuse |
| **Android Bridge** | Connect to Android devices via ADB |
| **SSH/SSHFS Bridge** | Mirror remote Linux/macOS servers into your local namespace |
| **Mirror Filesystem** | Any connected device's files appear at `$OS_ROOT/mirror/` |
| **Service Manager** | rc2.d init system with PID tracking and health checks |
| **Heartbeat Daemon** | Configurable health monitor with thermal alerting |
| **AURA Agents** | Background automation, event-driven policy engine, scheduled tasks |

---

## Quick Start

```sh
# Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Install (Linux/macOS/Termux)
bash install.sh

# Launch the AI shell
bash bin/aios
```

**On Android (Termux):**
```sh
pkg update && pkg install git python libimobiledevice ifuse android-tools openssh sshfs
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT && bash install.sh && bash bin/aios
```

---

## Example Commands

```sh
# Ask the AI anything
ask "what is the disk usage?"
ask "show me recent logs"

# Bridge to connected devices
bridge.detect
mirror.mount ios
mirror.ls ios

# Store and retrieve knowledge
mem.set project "AIOS-Lite"
recall "what project am I working on"

# System status
status
services
```

---

## Links

| Resource | URL |
|---|---|
| **Documentation** | [docs/MANUAL.md](docs/MANUAL.md) |
| **Architecture** | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| **Installation Guide** | [docs/INSTALL.md](docs/INSTALL.md) |
| **Legal Package** | [docs/LEGAL_PACKAGE.md](docs/LEGAL_PACKAGE.md) |
| **Contributing** | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| **Code of Conduct** | [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) |
| **Issues** | [GitHub Issues](https://github.com/Cbetts1/PROJECT/issues) |
| **Releases** | [GitHub Releases](https://github.com/Cbetts1/PROJECT/releases) |
| **License** | [MIT License](../LICENSE) |

---

## Status

**Current version:** 0.1-alpha — Active development. Core systems are functional. LLM integration and AURA policy engine are in beta.

---

## Author & License

Designed and directed by **Christopher Betts**.
Licensed under the **MIT License**.

> © 2026 Christopher Betts. All rights reserved.
>
> All source code was created or refined using AI tools under the direct direction of Christopher Betts.

---

*AIOS-Lite — AI-Augmented Portable Operating System*
