# AIOS-Lite

**AI-Augmented Portable Operating System**

> *"Plug your OS into any device and your system mirrors it — giving you the power of your AI OS on top of any platform."*

---

## What is AIOS-Lite?

AIOS-Lite is a lightweight, AI-powered operating system built entirely in POSIX shell script. It runs on **any Unix-like environment** — Android (Termux), Linux, macOS, or Raspberry Pi — and can bridge to and mirror other operating systems.

Connect it to an iPhone, Android device, or remote server, and your OS gains access to those systems through a unified AI-driven interface.

---

## Key Features

| Feature | Description |
|---------|-------------|
| 🤖 **AI-Powered Shell** | Natural language commands via LLaMA LLM or rule-based fallback |
| 📱 **Cross-OS Bridge** | Mirror iOS, Android, Linux/macOS, and remote SSH hosts |
| 🧠 **Hybrid Memory** | Context window + symbolic key-value + semantic embedding memory |
| 🌐 **HTTP REST API** | Full REST + SSE + WebSocket API server built in |
| 🔒 **Secure by Design** | Capability-based permissions, OS_ROOT filesystem jail, audit logs |
| 📦 **Portable** | Runs from a USB drive, phone, Pi, or any POSIX shell |
| 🔧 **Self-Healing** | Auto-repair, log rotation, health monitoring built in |
| 🖥️ **Full Disk Image** | Bootable AIOSCPU Debian image for bare-metal x86 deployments |

---

## Quick Install

### Android (Termux)

```sh
pkg update && pkg install git
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### Linux / macOS

```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh
```

### Boot the OS

```sh
cd PROJECT
export OS_ROOT="$(pwd)/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh OS/sbin/init
os-shell
```

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│           AIOS-Lite Shell               │
│        (AI + OS + Memory)               │
└──────────────────┬──────────────────────┘
                   │ HTTP REST / WS / SSE
                   ▼
         ┌───────────────────┐
         │    os-httpd API   │
         │  /api/v1/*  /ws   │
         └───────────────────┘
                   │ bridge layer
      ┌────────────┼────────────┐
      ▼            ▼            ▼
   iOS Bridge  Android Bridge  Linux/SSH
   (ifuse)     (ADB)           (sshfs)
      │            │            │
   mirror/ios/ mirror/android/ mirror/linux/
```

---

## Supported Platforms

| Platform | Install Method | LLM Support |
|----------|---------------|-------------|
| Android (Termux) | `pkg install` | ✅ llama.cpp ARM |
| Raspberry Pi | `bash install.sh` | ✅ llama.cpp ARM |
| Debian / Ubuntu | `bash install.sh` | ✅ llama.cpp x86 |
| macOS | `bash install.sh` | ✅ llama.cpp Metal |
| AIOSCPU (bare metal x86) | Disk image | ✅ Full |
| Docker / OCI | Container image | ✅ CPU only |
| Termux + Phone USB tether | `pkg install` | ✅ |

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](getting-started.md) | Step-by-step setup for new users |
| [API Reference](api-reference.md) | Complete REST / WebSocket / SSE API docs |
| [Deployment Guide](../DEPLOYMENT.md) | Hosting, servers, reverse proxy, scripts |
| [API Deployment](../API-DEPLOYMENT.md) | Endpoints, auth, versioning |
| [Networking Config](../NETWORKING-CONFIG.md) | WiFi, Bluetooth, firewall, NAT |
| [Architecture](../ARCHITECTURE.md) | System design and component overview |
| [Security](../SECURITY.md) | Threat model, audit logs, permissions |
| [Capabilities](../CAPABILITIES.md) | Full feature matrix |

---

## Why AIOS-Lite?

> Traditional operating systems are locked to one device. AIOS-Lite breaks that boundary.

- **Your AI OS, your rules.** No cloud subscription, no telemetry, no lock-in.
- **It runs everywhere.** From a $15 Raspberry Pi Zero to a Samsung Galaxy to a cloud VPS.
- **It talks to everything.** iOS, Android, Linux, macOS, remote SSH — all unified.
- **It remembers.** Hybrid memory means your AI assistant knows context, history, and facts.
- **It's open.** MIT licensed. Fork it, extend it, make it yours.

---

## License

MIT — Built by [Chris Betts](https://github.com/Cbetts1)

---

*© 2026 Chris Betts | AIOSCPU Official*
