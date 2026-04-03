# AIOS-Lite — Your AI OS. Any Device. Any Shell.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0--Aurora-blue.svg)](CHANGELOG.md)
[![Tests](https://img.shields.io/badge/tests-144%20passing-brightgreen.svg)](tests/)

**AIOS-Lite** is a portable, AI-native operating system built entirely in POSIX shell and Python 3.
It runs on any Unix-like environment (Android/Termux, Linux, macOS) — no root, no installation required.
Drop in a LLaMA model and your shell starts thinking.  Connect a device and your OS mirrors it.

- **Portable** — Runs from a USB drive, Android phone (Termux), Raspberry Pi, or any POSIX shell
- **AI-Powered** — Three-layer hybrid memory (context + symbolic + semantic) plus optional LLaMA LLM inference
- **Cross-OS Bridge** — Connect to iOS, Android, Linux, macOS, or remote SSH hosts
- **Mirror Filesystem** — Access any connected device's files through your own namespace at `$OS_ROOT/mirror/`

---

## Features

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

## Architecture

AIOS-Lite is organized into four cooperating layers:

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│        bin/aios (AI Shell)   bin/aios-sys (OS Shell)    │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                    AI Core (Python)                      │
│   intent_engine.py → router.py → HealthBot / LogBot /   │
│   RepairBot / commands.py → llama_client.py (optional)  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              AURA Framework (Shell Modules)              │
│  lib/aura-core.sh  lib/aura-fs.sh  lib/aura-proc.sh    │
│  lib/aura-net.sh   lib/aura-llm.sh  lib/aura-ai.sh     │
│  lib/aura-typo.sh                                       │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│           OS Virtual Environment (OS/)                   │
│  sbin/init  bin/ commands  lib/ subsystems  etc/ config │
│  proc/ runtime state  var/ logs  mirror/ device mounts  │
└─────────────────────────────────────────────────────────┘
```

### AI Pipeline

```
User Input
    │
    ▼
IntentEngine.classify()       [ai/core/intent_engine.py]
    │  returns Intent(category, action, entities, confidence)
    ▼
Router.dispatch(intent)       [ai/core/router.py]
    │  iterates registered bots; first can_handle() wins
    ├─▶ HealthBot              [ai/core/bots.py]
    ├─▶ LogBot
    ├─▶ RepairBot
    ├─▶ commands.parse_natural_language()   [fallback]
    └─▶ llama_client.chat()                 [LLM fallback]
```

### Directory Map

```
PROJECT/
├── bin/                       # Entry-point executables
│   ├── aios                   # Interactive AI shell
│   ├── aios-sys               # OS command dispatcher
│   └── aios-heartbeat         # Health monitoring daemon
├── ai/
│   └── core/                  # Python AI subsystem
│       ├── intent_engine.py   # NLP intent classifier
│       ├── router.py          # Intent dispatcher
│       ├── bots.py            # HealthBot / LogBot / RepairBot
│       ├── commands.py        # Legacy command parser
│       ├── ai_backend.py      # Entry point for Python AI
│       └── llama_client.py    # llama.cpp HTTP client
├── lib/                       # AURA shell modules
│   ├── aura-core.sh           # OS_ROOT jail, path rewriting
│   ├── aura-fs.sh             # Filesystem operations
│   ├── aura-proc.sh           # Process management
│   ├── aura-net.sh            # Network utilities
│   ├── aura-llm.sh            # LLM invocation wrapper
│   ├── aura-ai.sh             # AI session management
│   └── aura-typo.sh           # Typo correction
├── OS/                        # Virtual OS environment
│   ├── sbin/init              # Boot init
│   ├── bin/                   # OS commands (os-shell, os-bridge, os-mirror…)
│   ├── lib/                   # OS runtime libraries + bridge/memory modules
│   ├── etc/                   # Configuration (init.d, rc2.d, aura/)
│   ├── proc/                  # Runtime state files
│   ├── mirror/                # Mounted device filesystems
│   └── var/                   # Logs and events
├── config/                    # Project-level configuration
│   ├── aios.conf              # Main settings
│   └── llama-settings.conf    # LLM tuning
├── docs/                      # Extended documentation
├── tests/                     # Unit and integration test suites
├── build/                     # Build scripts (llama.cpp)
└── install.sh                 # Installer
```

---

## System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| Shell | POSIX sh | bash 4+ |
| OS | Any Unix-like | Android/Termux, Debian/Ubuntu, macOS |
| Python | 3.8+ | 3.11+ |
| RAM | 1 GB | 8 GB (for LLM) |
| Storage | 200 MB | 10 GB (model files) |
| CPU | Any | ARM64 (Cortex-A78) or x86-64 |

**Optional feature dependencies:**

| Feature | Package(s) |
|---|---|
| iOS Bridge | `libimobiledevice`, `ifuse` |
| Android Bridge | `adb` (Android Debug Bridge) |
| Remote Linux Bridge | `openssh`, `sshfs` |
| LLM inference | `llama.cpp` (`llama-cli`), any `.gguf` model |

**Tested target device:** Samsung Galaxy S21 FE (Exynos 2100 / Snapdragon 888, 6 GB or 8 GB RAM, Android 12–14, Termux)

---

## Installation

### Quick Install (Any POSIX system)

```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### Manual Boot

```sh
cd PROJECT/OS
export OS_ROOT="$(pwd)"
export AIOS_HOME="$(dirname $(pwd))"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh sbin/init
```

### Termux (Android)

```sh
pkg update
pkg install git python libimobiledevice ifuse android-tools openssh sshfs
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### Debian / Ubuntu

```sh
sudo apt update
sudo apt install git python3 libimobiledevice-utils ifuse adb openssh-client sshfs
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### LLM Model (Optional)

```sh
mkdir -p OS/llama_model
# Download any GGUF-format model and place it here, e.g.:
# wget -O OS/llama_model/model.gguf <model-url>
# Recommended for 8 GB RAM: Mistral-7B-Instruct Q4_K_M
# Recommended for 6 GB RAM: Llama-3.2-3B Q4_K_M
```

---

## Usage

### Launch the AI Shell

```sh
bash bin/aios
```

### Shell Commands

| Command | Description |
|---|---|
| `ask <text>` | Ask the AI a question or give a natural-language command |
| `recall <text>` | Hybrid memory search across all three memory layers |
| `mem.set <key> <value>` | Store a named fact in symbolic memory |
| `mem.get <key>` | Retrieve a named fact |
| `sem.set <key> <value>` | Store a semantic memory entry |
| `sem.search <text>` | Similarity search over semantic memory |
| `bridge.detect` | Detect connected devices (iOS, Android, SSH) |
| `mirror.mount <type>` | Mount device filesystem: `ios`, `android`, `linux`, `auto` |
| `mirror.ls <type>` | List files on a mirrored device |
| `mode <mode>` | Set shell mode: `operator`, `system`, or `talk` |
| `status` | Full OS state summary |
| `services` | Service health overview |
| `sys <cmd>` | Pass a command to the OS shell dispatcher |
| `help` | Show full command reference |

### Device Bridging

```sh
# Auto-detect any connected device
bridge.detect

# Mount an iPhone (requires libimobiledevice + ifuse + paired device)
bridge.detect ios
mirror.mount ios
mirror.ls ios

# Mount an Android device (requires USB debugging enabled + ADB)
bridge.detect android
mirror.mount android

# Mount a remote server via SSH
mirror.mount ssh user@192.168.1.100
mirror.ls linux
```

### AI Interaction Examples

```sh
# Natural language — routed through intent engine
ask "what is the disk usage?"
ask "show me recent logs"
ask "is the heartbeat service running?"

# Direct AI conversation (LLM mode)
mode talk
ask "explain how the bridge layer works"
```

---

## AI Memory System

AIOS-Lite uses a three-layer hybrid memory architecture:

| Layer | Storage | Purpose |
|---|---|---|
| **Context Window** | Rolling 50-entry file | Recent commands and conversation turns |
| **Symbolic Memory** | Key-value index (text file) | Named facts (`mem.set location "home"`) |
| **Semantic Memory** | Embedding index | Fuzzy similarity search (`sem.search "phone info"`) |

All three layers are queried together by the `recall` command:

```sh
recall "what phone did I connect yesterday"
```

---

## LLM Integration

When a `.gguf` model is present in `OS/llama_model/` and `llama-cli` is installed, the AI shell routes unrecognized commands through the LLM for natural-language responses. Without a model, AIOS-Lite falls back to its built-in rule-based command parser which handles all OS, bridge, and memory operations.

**Build llama.cpp from source:**

```sh
bash build/build.sh --target hosted
```

See [`docs/AI_MODEL_SETUP.md`](docs/AI_MODEL_SETUP.md) for full LLM configuration details.

---

## Running Tests

```sh
# Unit tests (shell + Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python AI Core tests only
python3 tests/test_python_modules.py
```

---

## Status & Roadmap

**Current version:** 0.1-alpha

| Area | Status |
|---|---|
| POSIX shell kernel | ✅ Stable |
| Boot init / rc2.d service manager | ✅ Stable |
| AI intent engine + router | ✅ Stable |
| Hybrid memory system | ✅ Stable |
| iOS bridge (libimobiledevice) | ✅ Functional |
| Android bridge (ADB) | ✅ Functional |
| SSH/SSHFS bridge | ✅ Functional |
| LLM integration (llama.cpp) | 🔧 Beta |
| Heartbeat daemon | ✅ Stable |
| AURA policy engine | 🔧 Beta |
| Web dashboard | 🔲 Planned |
| Package manager | 🔲 Planned |
| Multi-user sessions | 🔲 Planned |

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

