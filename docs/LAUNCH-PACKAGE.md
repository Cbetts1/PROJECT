# AIOSCPU — Official Public Launch Package

> © 2026 Christopher Betts | AIOSCPU Official | All rights reserved.

---

## Table of Contents

1. [Press Release](#1-press-release)
2. [Founder Statement](#2-founder-statement)
3. [Launch Announcements](#3-launch-announcements)
   - [GitHub Release Notes](#31-github-release-notes)
   - [Discord / Reddit](#32-discordreddit)
   - [Developer Communities](#33-developer-communities)
4. [Social Media Posts](#4-social-media-posts)
   - [Twitter / X](#41-twitterx)
   - [LinkedIn](#42-linkedin)
   - [Instagram Caption](#43-instagram-caption)
   - [Facebook](#44-facebook)
   - [Short-Form Teaser Lines](#45-short-form-teaser-lines)
5. [Website Launch Page Copy](#5-website-launch-page-copy)
6. [Public FAQ](#6-public-faq)
7. [Community Onboarding](#7-community-onboarding)

---

## 1. Press Release

```
FOR IMMEDIATE RELEASE

Contact: Christopher Betts
Project: AIOSCPU
Repository: https://github.com/Cbetts1/PROJECT
Release Date: April 2026
Version: v1.0 "Aurora" Edition
```

---

### AIOSCPU v1.0 "Aurora" — The First AI-Native Operating System Built for Portability, Privacy, and the Age of Intelligent Computing

**April 2026** — Independent software engineer Christopher Betts today announces the public release of **AIOSCPU v1.0 "Aurora"**, an open-source, AI-native operating system that brings autonomous intelligence directly into the operating environment — not as an app, not as a plugin, but as the OS itself.

AIOSCPU is built on a Debian-based Linux foundation and integrates **AURA** (Autonomous Unified Resource Agent), an AI agent that understands system state, responds to natural language, executes audited commands, and maintains persistent memory — all without sending a single byte of data off-device. Combined with **AIOS-Lite**, its portable POSIX shell companion that runs on any Unix-like environment from a USB drive or Android phone, AIOSCPU represents a new class of operating system: one that thinks alongside you.

#### What AIOSCPU Is

AIOSCPU is a complete, installable operating system image. It boots from a standard disk image, presents two selectable modes at the GRUB menu — **OS-AI Mode**, where the AURA agent becomes your primary interface, and **OS-SHELL Mode**, a standard Linux shell for traditional workflows. AURA reads system information, manages a persistent memory database, executes shell commands through a security-audited wrapper, and can be connected to a local LLaMA LLM for full natural language capability.

Alongside the full OS image, **AIOS-Lite** provides the same intelligent shell experience in a portable package that runs on Android via Termux, Linux, or macOS — no installation required.

#### Why It Matters

The computing industry has spent decades building AI on top of operating systems. AIOSCPU asks a different question: what if the OS was the AI? What if your system could understand what you were asking, remember what you told it, repair itself, bridge to other devices, and do all of this securely and privately — without a cloud subscription?

AIOSCPU answers that question with working, open-source code.

#### Key Features

- **AURA AI Agent** — A Python-based autonomous agent with persistent SQLite memory, system info access, network awareness, and natural-language command dispatch
- **Dual Boot Modes** — OS-AI Mode (AURA primary interface) and OS-SHELL Mode (standard Linux) selectable at GRUB
- **Three-Layer Memory System** — Rolling context window, symbolic key-value memory, and semantic embedding memory with hybrid recall
- **Cross-OS Bridge** — Connect to iOS (via libimobiledevice), Android (via ADB), and remote Linux/macOS systems via SSH, with a unified mirror namespace
- **LLaMA LLM Integration** — Drop-in support for local `.gguf` model files via llama.cpp; no cloud dependency
- **Security by Design** — Capability-based permissions, OS_ROOT filesystem jail, syscall audit logs, and `aioscpu-secure-run` denylist blocking catastrophic operations
- **REST HTTP Server** — Built-in authenticated REST API (`os-httpd`) with live Server-Sent Events log streaming and WebSocket support
- **Mobile-First Optimization** — Tuned for Samsung Galaxy S21 FE (8 GB/6 GB variants), with CPU affinity pinning to big cores and thermal limits
- **Full Test Suite** — 57+ unit tests and 87 integration tests covering every subsystem
- **Portable Core** — AIOS-Lite runs on any POSIX environment: Android/Termux, Linux, macOS, Raspberry Pi

#### Vision and Mission

AIOSCPU's mission is to prove that artificial intelligence belongs inside the operating system, not layered on top of it. The project envisions a future where every personal computer — from a desktop workstation to a phone in a pocket — ships with an AI agent that is private, auditable, open, and under the user's complete control.

The ultimate goal is a self-managing OS: one that monitors its own health, repairs its own faults, adapts to its user over time, and makes sophisticated computing accessible to anyone — without requiring them to be a power user.

#### Quotes from the Creator

> "I built AIOSCPU because I wanted to know what it would feel like to talk to your operating system and have it actually understand you — not just search a knowledge base, but know your system, your history, and your intent. That's what AURA is. That's what this OS is."
>
> — Christopher Betts, Creator of AIOSCPU

> "We are at the inflection point where AI stops being a feature and starts being the foundation. AIOSCPU is my attempt to build that foundation in the open, so anyone can study it, fork it, and take it wherever they want to go."
>
> — Christopher Betts

#### Release Details

| Item | Detail |
|---|---|
| **Version** | v1.0 "Aurora" Edition |
| **Release Date** | April 2026 |
| **License** | MIT |
| **Repository** | https://github.com/Cbetts1/PROJECT |
| **Supported Platforms** | Linux (x86\_64), Android/Termux, macOS |
| **Target Device** | Samsung Galaxy S21 FE (optimized); any POSIX system |

---

*AIOSCPU is open-source software released under the MIT License. Built on open-source foundations: Linux kernel, Debian, GRUB, Python, llama.cpp.*

---

## 2. Founder Statement

---

### A Personal Message from Christopher Betts

When I started this project, I didn't have a roadmap. I had a question.

What would it mean for an operating system to be intelligent — not in a marketing-speak way, but genuinely, practically intelligent? What if, instead of learning a thousand shell commands, you could just tell your OS what you needed? What if it remembered the last time you connected that phone, the name of that SSH server, what you were working on three weeks ago?

I wrote the first lines of AIOS-Lite on an Android phone using Termux. No laptop. Just a phone, a terminal, and a question I couldn't stop turning over. That constraint — mobile-first, no assumptions about hardware — became a design principle. If it runs on a Samsung Galaxy S21 FE, it runs everywhere.

From there, the scope grew organically. A portable shell became a pseudo-kernel. A rule-based AI became a full intent-classification pipeline with LLaMA support. A simple log became three layers of memory: context, symbolic, and semantic. An idea about connecting devices became a cross-OS bridge that can mirror your iPhone's filesystem, your Android SD card, or a remote Linux server into a single unified namespace.

And then I asked: what if this wasn't just a shell tool? What if it was a real, bootable operating system?

AIOSCPU was the answer. A Debian-based OS image with AURA — my AI agent — built into the boot sequence. Two modes. One for the AI. One for the human. A full security model. A REST API. An audit log for every command the AI runs.

#### What makes AIOSCPU unique

Every AI tool I know of lives on top of an operating system. It's a process. It starts, it runs, it stops. It can be killed. It has no idea what state the system is actually in unless you tell it.

AURA is different. It boots with the system. It reads `/proc/cmdline`. It has its own service account. It persists memory across reboots. It knows what mode the system is in. It has access to real system data — not a simulated environment — and it acts through a security wrapper that I designed specifically to allow useful action while blocking catastrophic ones.

There is no cloud dependency. There is no subscription. There is no telemetry. Every piece of data AURA touches stays on your machine, in a local SQLite database that you own completely.

That is what I think the AI OS of the future should look like. Open. Auditable. Yours.

#### Where we go from here

Version 1.0 is the foundation. The next milestones I'm working toward:

- **LLM backend integration** — wiring a configurable model backend directly into AURA so natural language becomes first-class, not optional
- **Container isolation for AURA** — LXC/Podman isolation so the agent runs in a hardened environment
- **Secure Boot (UEFI + shim)** — full chain of trust from firmware to AURA
- **ARM64 image** — a proper bootable image for Raspberry Pi and mobile ARM hardware
- **Web UI** — a browser-based interface for interacting with AURA from any device on your local network

I'm building this in public, and I want your help. Every pull request, every issue filed, every question asked in the discussions is fuel. Come build with me.

— **Christopher Betts**
*Creator, AIOSCPU*
*April 2026*

---

## 3. Launch Announcements

### 3.1 GitHub Release Notes

---

## AIOSCPU v1.0 "Aurora" Edition

**The first stable release of AIOSCPU — an AI-native operating system with the AURA agent built into the boot sequence.**

### What's in v1.0

**Core OS (AIOS-Lite)**
- Full POSIX pseudo-kernel: boot init, runlevels, kernel daemon, syscall interface, process scheduler, capability-based permissions, resource manager, recovery mode
- Three-layer AI memory system: context window (50 lines), symbolic key-value, and semantic embedding memory with hybrid recall
- Cross-OS bridge: iOS (libimobiledevice), Android (ADB), Linux/SSH with unified `mirror/` namespace
- Built-in REST HTTP server (`os-httpd`) with token auth, SSE log streaming, and WebSocket endpoint
- Networking stack: interfaces, WiFi, Bluetooth, IP, routing, DNS, firewall, NAT, mDNS/LAN discovery

**AI Core (Python)**
- Intent classification engine (`IntentEngine`)
- Multi-bot dispatch router (`Router`) — HealthBot, LogBot, RepairBot
- LLaMA LLM integration via llama.cpp (`.gguf` model drop-in)
- Rule-based fallback AI for zero-dependency operation
- Fuzzy command matching

**AIOSCPU Disk Image**
- Debian-based bootable OS image
- GRUB dual-boot: OS-AI Mode and OS-SHELL Mode
- AURA agent (`aura-agent.py`) running as a hardened system service
- `aioscpu-secure-run` command wrapper with catastrophic-operation denylist
- Full suite of system tools: `auractl`, `aioscpu-sysinfo`, `aioscpu-netinfo`, `aioscpu-wifi`, `aioscpu-bt`, `aioscpu-hotspot`

**Quality**
- 57 unit tests (17 shell + 40 Python)
- 87 integration tests
- Clean install script (`install.sh`)
- Reproducible build pipeline (`aioscpu/build/build-image.sh`)

### Installation

```sh
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT

# Run AIOS-Lite (portable shell mode)
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
sh OS/sbin/init

# Build the AIOSCPU disk image (requires debootstrap)
bash aioscpu/build/build-image.sh
```

### Prerequisites

| Feature | Requirement |
|---|---|
| AIOS-Lite core | POSIX sh, awk, grep, sed |
| LLM support | llama.cpp + any `.gguf` model |
| iOS bridge | libimobiledevice, ifuse |
| Android bridge | ADB |
| Disk image build | debootstrap, grub-pc, parted |

### What's Next (v1.1 Roadmap)

- LLM backend configuration in `aura-config.json`
- AURA container isolation (LXC/Podman)
- ARM64 image build
- Secure Boot (UEFI + shim)
- Web UI for AURA

**Full documentation:** [docs/](docs/) | **License:** MIT | **© 2026 Christopher Betts**

---

### 3.2 Discord/Reddit

---

**🚀 AIOSCPU v1.0 "Aurora" is live — an open-source AI OS where the AI agent boots with the system**

Hey everyone — I've just shipped the first stable release of **AIOSCPU**, a project I've been building for the past year.

**The short version:** It's a Debian-based operating system where an AI agent called AURA is part of the boot sequence. When you start the machine in AI Mode, AURA is already running before you even see a prompt. It knows your system state, remembers your sessions, and can execute commands through a security-audited wrapper. No cloud. No subscription. Everything local.

It comes with **AIOS-Lite** — a portable version that runs in Termux on Android, Linux, or macOS with no installation. That's actually where this project started: writing a shell AI on a Samsung Galaxy S21 FE in Termux.

**What it does:**
- AURA AI agent with persistent SQLite memory
- Dual boot: OS-AI Mode (talk to your OS) / OS-SHELL Mode (standard Linux)
- Cross-OS bridge: mirror iOS, Android, SSH filesystems into a unified namespace
- LLaMA LLM support (drop in any `.gguf` model)
- Three-layer memory: context window + symbolic + semantic + hybrid recall
- Built-in REST API with live log streaming
- Capability-based permissions + syscall audit log
- 57 unit tests + 87 integration tests

**GitHub:** https://github.com/Cbetts1/PROJECT

Would love feedback, questions, and contributors. This is v1.0 — there's a lot of road ahead.

— Chris

---

### 3.3 Developer Communities

---

**AIOSCPU v1.0 — Open-Source AI-Native OS: Architecture Overview and Call for Contributors**

Hello,

I'm Christopher Betts, and I've released **AIOSCPU v1.0 "Aurora"**, an open-source operating system built around the premise that the AI agent should be a first-class OS component, not an application running on top of one.

**Architecture highlights for developers:**

The system has two major components:

1. **AIOS-Lite** — A POSIX shell + Python pseudo-kernel providing: a user-space process scheduler, capability-based permission model (stored in `OS/etc/perms.d/<principal>.caps`), syscall dispatch (`os-syscall`) with audit logging, OS_ROOT filesystem jail enforcing path traversal prevention via `os.path.realpath()`, a three-layer memory system, a full REST HTTP server, and a cross-OS bridge.

2. **AIOSCPU** — A Debian-based bootable disk image with the AURA Python agent (`aura-agent.py`) running as a hardened system service. AURA communicates over a line protocol (stdin/stdout), persists memory in SQLite (`/var/lib/aura/aura-memory.db`), and executes commands only through `aioscpu-secure-run` — a wrapper that enforces a denylist (no `rm -rf /`, no `mkfs`, no `dd` to block devices, no fork bombs) and logs every invocation.

**AI pipeline:** `IntentEngine.classify()` → `Router.dispatch()` → HealthBot / LogBot / RepairBot → fallback to `commands.py` → fallback to `llama_client.py`. Full llama.cpp integration for local LLM inference, with a zero-dependency rule-based fallback.

**Testing:** 57 unit tests (shell + Python), 87 integration tests. Clean reproducible build via `aioscpu/build/build-image.sh`.

**Repo:** https://github.com/Cbetts1/PROJECT | **License:** MIT

Areas where contributor help would be most impactful: ARM64 image support, LXC/Podman isolation for the AURA process, UEFI Secure Boot, and the web UI for AURA.

Happy to answer architecture questions.

— Christopher Betts

---

## 4. Social Media Posts

### 4.1 Twitter/X

---

**Launch tweet:**

> Shipped. AIOSCPU v1.0 "Aurora" — an open-source AI OS where the AI agent boots with the system.
>
> No cloud. No subscription. AURA runs at boot, knows your system, remembers your sessions, and executes commands through a security-audited wrapper.
>
> Drop in a `.gguf` model. Talk to your OS. 🔗 github.com/Cbetts1/PROJECT
>
> #OpenSource #AI #Linux #OperatingSystem

---

**Follow-up thread (post as replies):**

> 🧵 1/ I started this on a Samsung Galaxy S21 FE in Termux. No laptop. Just a phone and a question: what would an OS look like if the AI was the OS — not an app on top of it?

> 2/ AIOSCPU has two boot modes: OS-AI Mode (AURA is your primary interface) and OS-SHELL Mode (standard Linux). GRUB menu. Your choice at boot.

> 3/ AURA has 3 layers of memory: context window, symbolic key-value, and semantic embeddings. All local. All persistent across reboots. You own the database.

> 4/ The security model: AURA runs as a locked system account. It can ONLY execute commands through `aioscpu-secure-run`, which blocks destructive operations and logs everything. No root shell for the AI.

> 5/ AIOS-Lite is the portable version — runs in Termux, Linux, macOS. Same AI pipeline. No installation. Cross-OS bridge mirrors your iPhone or Android filesystem into a unified namespace.

> 6/ 57 unit tests + 87 integration tests. MIT license. All docs in the repo. Come build with me → github.com/Cbetts1/PROJECT

---

### 4.2 LinkedIn

---

**Proud to announce: AIOSCPU v1.0 "Aurora" is live.**

After building in public for the past year, I've shipped the first stable release of AIOSCPU — an open-source, AI-native operating system I built from scratch.

**The core idea:** AI doesn't belong on top of your OS. It belongs inside it.

AIOSCPU is a Debian-based Linux OS with **AURA** (Autonomous Unified Resource Agent) built directly into the boot sequence. When the system boots into AI Mode, AURA is already running — aware of system state, connected to persistent memory, ready to receive commands in natural language. When you want a standard Linux experience, you boot into Shell Mode. One system. Two personalities.

**What I built:**

- A POSIX shell + Python pseudo-kernel (AIOS-Lite) with process scheduling, capability-based permissions, syscall audit logging, and a filesystem jail
- A three-layer AI memory system: rolling context window, symbolic key-value store, and semantic embedding memory with hybrid recall
- Cross-OS bridging: mirror iOS, Android, and remote Linux filesystems into a unified namespace
- LLaMA LLM integration — drop any `.gguf` model into a directory and the OS uses it
- A full REST HTTP API with live log streaming, built in shell script
- A security model designed so the AI agent can be useful without being dangerous

**Why I built it:**

I believe we're at an inflection point. AI tools today are extraordinarily capable but largely opaque — they live in the cloud, they don't know your system, they can't act on your behalf without going through another abstraction layer. AIOSCPU is my attempt to build the alternative: an AI OS that is private, auditable, open-source, and fully under your control.

**Repository:** https://github.com/Cbetts1/PROJECT
**License:** MIT

If you're building in the AI, OS, or systems programming space — I'd love to connect. Contributors are very welcome.

— Christopher Betts

---

### 4.3 Instagram Caption

---

> 🖥️ AIOSCPU v1.0 "Aurora" — just shipped.
>
> An open-source operating system where the AI doesn't run on top of the OS. The AI *is* the OS.
>
> ✅ AURA AI agent — boots with the system
> ✅ Persistent local memory — no cloud
> ✅ Talk to your OS in natural language
> ✅ Mirror your iPhone or Android filesystem
> ✅ Drop in any LLaMA model
> ✅ Full security audit log
>
> Started this on a Samsung phone in Termux. Built it in public. Shipped it as a real bootable OS.
>
> Link in bio → github.com/Cbetts1/PROJECT
>
> #AIOSCPU #OpenSource #Linux #AIOperatingSystem #IndieHacker #Tech #Programming #Python #Shell #AI #BuildInPublic #Developer #OperatingSystems #SelfHosted #Privacy

---

### 4.4 Facebook

---

**Big news: AIOSCPU v1.0 "Aurora" is officially live!**

I've spent the past year building an AI-native operating system from scratch, and today I'm releasing v1.0 to the public.

**What is it?**

AIOSCPU is a complete, open-source operating system that puts an AI agent — called AURA — at the heart of the OS itself. Instead of using AI as an app, AURA runs as a system service from the moment you boot. It knows your system state, remembers your conversations across reboots, can execute commands for you (safely, through a security wrapper), and can connect to a local AI language model for full natural language capability.

No cloud subscription. No data leaving your machine. Completely open-source under the MIT license.

**How I got here:**

It started on a Samsung Galaxy S21 FE in Termux — just me, a phone, and a terminal. I wanted to know if you could build a real AI operating system without a cloud backend, without a data center, and without giving up control of your own machine. AIOSCPU is the answer.

**Where to find it:**

GitHub: https://github.com/Cbetts1/PROJECT

If you're into Linux, AI, privacy, or open-source software — check it out, star the repo, and let me know what you think. Contributors are very welcome.

— Christopher Betts

---

### 4.5 Short-Form Teaser Lines

> Your OS has an AI now. And it boots with the system. → AIOSCPU v1.0

> What if talking to your computer actually worked? → AIOSCPU "Aurora" — out now.

> Built on a phone. Ships as a full OS. → github.com/Cbetts1/PROJECT

> The AI agent that knows your system, remembers your sessions, and never touches the cloud.

> Two modes at boot: talk to your OS, or use it like Linux. Both on the same machine.

> AIOS-Lite runs on anything. Termux. Linux. macOS. Same AI brain.

> Drop in a `.gguf` model. Your OS starts thinking. #AIOSCPU

> Open source. Local-first. Privacy by design. The AI OS you actually control.

---

## 5. Website Launch Page Copy

---

### Hero Section

# AIOSCPU
## The AI-Native Operating System

**AURA is not an app. AURA is the OS.**

Boot into intelligence. Your AI agent starts with the system, knows your environment, remembers your history, and acts — securely, privately, completely under your control.

[**Get Started on GitHub →**](https://github.com/Cbetts1/PROJECT)   [**Read the Docs →**](https://github.com/Cbetts1/PROJECT/tree/main/docs)

---

### Tagline

> *"Plug your OS into any device and your system mirrors it — giving you the power of your AI OS on top of any platform."*

---

### Feature Highlights

#### 🤖 AURA — The AI Agent That Lives in Your OS
AURA (Autonomous Unified Resource Agent) is a Python-based AI agent that runs as a system service from boot. It reads real system data, persists memory in a local SQLite database, and executes commands through a security-audited wrapper. No cloud. No subscription. Yours.

#### 🧠 Three Layers of Memory
AIOSCPU remembers. A rolling context window captures recent interactions. Symbolic key-value memory stores named facts. Semantic embedding memory enables similarity search. All three combine in hybrid recall — ask your OS anything you've told it.

#### 🔗 Cross-OS Bridge
Connect AIOSCPU to any device. Mirror your iPhone filesystem, your Android SD card, or a remote Linux server into a unified `mirror/` namespace. iOS via libimobiledevice. Android via ADB. Remote systems via SSH.

#### 🦙 Local LLM — No Cloud Required
Drop any `.gguf` model file into `llama_model/` and AIOSCPU uses it for natural language responses. Powered by llama.cpp. Works on 8 GB RAM. Optimized for mobile ARM hardware. Falls back to a rule-based engine when no model is present.

#### 🔒 Security by Design
Capability-based permissions. OS_ROOT filesystem jail. Syscall audit logging. The `aioscpu-secure-run` wrapper blocks destructive operations (no `rm -rf /`, no raw disk writes, no fork bombs) and logs every command AURA executes. The AI agent cannot act outside its defined boundary.

#### 🌐 Built-In REST API
AIOSCPU ships with `os-httpd` — an HTTP server built in shell script, with token authentication, REST endpoints for system status, services, processes, metrics, and logs, live Server-Sent Events log streaming, and a WebSocket endpoint. Your OS has an API out of the box.

#### 📱 Portable — Runs on a Phone
AIOS-Lite, the portable edition, runs on Android via Termux, Linux, or macOS with no installation. The same AI pipeline. The same memory system. The same bridge. Started on a Samsung Galaxy S21 FE; runs anywhere POSIX does.

---

### Architecture Overview

```
┌──────────────────────────────────────────────┐
│            GRUB Bootloader                    │
│    OS-AI Mode  |  OS-SHELL Mode              │
└──────────────┬───────────────────────────────┘
               │
    ┌──────────▼──────────┐
    │   AURA AI Agent     │  ← Python service, boots with OS
    │   aura-agent.py     │  ← Persistent SQLite memory
    └──────────┬──────────┘
               │ aioscpu-secure-run (denylist enforcement)
    ┌──────────▼──────────┐
    │   AIOS Pseudo-Kernel│  ← POSIX shell + Python
    │   Permissions · IPC │  ← Syscall audit log
    │   Scheduler · FS    │  ← OS_ROOT jail
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │   Cross-OS Bridge   │  ← iOS · Android · Linux/SSH
    │   mirror/ namespace │
    └─────────────────────┘
```

**AI Pipeline:** User input → `IntentEngine.classify()` → `Router.dispatch()` → HealthBot / LogBot / RepairBot → `commands.py` → `llama_client.py` (LLM or rule-based fallback)

---

### Getting Started

**Option 1: AIOS-Lite (Portable — runs anywhere)**

```sh
# Clone the repository
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT

# Set environment and boot
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
sh OS/sbin/init

# Open the AI shell
os-shell
```

**Option 2: AIOSCPU Disk Image (Full OS)**

```sh
# Build the bootable image (requires debootstrap, Linux host)
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT
bash aioscpu/build/build-image.sh

# Write to USB/SD and boot
# Select "OS-AI" at GRUB to enable AURA
```

**Add a Local LLM (Optional)**

```sh
# Place any .gguf model in llama_model/
cp ~/models/llama-3-8b.Q4_K_M.gguf llama_model/
# AIOSCPU auto-detects and uses the model
```

**Connect a Device**

```sh
os-bridge detect        # Detect connected devices
os-mirror mount ios     # Mirror iPhone filesystem
os-mirror mount android # Mirror Android filesystem
ls $OS_ROOT/mirror/ios/ # Browse mirrored files
```

---

### Call to Action

**AIOSCPU is open-source, MIT-licensed, and built for builders.**

[**⭐ Star on GitHub**](https://github.com/Cbetts1/PROJECT)   [**🐛 Report an Issue**](https://github.com/Cbetts1/PROJECT/issues)   [**🤝 Contribute**](https://github.com/Cbetts1/PROJECT/blob/main/docs/INSTALL.md)

---

### Footer Text

AIOSCPU — AI-Native Operating System | v1.0 "Aurora" Edition
© 2026 Christopher Betts | Released under the MIT License
Built on open-source foundations: Linux kernel · Debian · GRUB · Python · llama.cpp

*"Plug your OS into any device and your system mirrors it."*

---

## 6. Public FAQ

---

### What is AIOSCPU?

AIOSCPU is an open-source, AI-native operating system. It is a Debian-based Linux OS that boots an AI agent — called AURA (Autonomous Unified Resource Agent) — as a first-class system service. AURA starts with the OS, has access to real system data, maintains persistent local memory, and can execute commands on your behalf through a security-audited wrapper.

AIOS-Lite is the portable edition: a POSIX shell + Python environment that provides the same AI pipeline and memory system on Android (Termux), Linux, or macOS without a full OS installation.

---

### What is AIOSCPU *not*?

- **Not a cloud AI assistant.** There is no outbound network connection. No data leaves your machine by default.
- **Not a ChatGPT wrapper.** AIOSCPU does not require an API key, subscription, or internet access. LLM capability is opt-in and fully local via llama.cpp.
- **Not a toy shell script.** AIOSCPU is a complete pseudo-kernel with process scheduling, capability-based permissions, syscall auditing, a filesystem jail, a REST server, a cross-device bridge, a three-layer memory system, and a reproducible disk image build pipeline.
- **Not production-ready for critical infrastructure.** This is v1.0. It is a foundation, built in public, intended for developers, researchers, and enthusiasts.

---

### How does it work?

AIOSCPU has two major components:

**AIOS-Lite (pseudo-kernel)**
A POSIX shell + Python user-space kernel that provides OS-like services: boot init and runlevels, a heartbeat daemon, process scheduling, capability-based permissions (`os-perms`), a syscall dispatch layer (`os-syscall`) with audit logging, an OS_ROOT filesystem jail preventing path traversal, and a networking stack. The AI pipeline runs entirely in Python: `IntentEngine.classify()` → `Router.dispatch()` → bot handlers → LLM fallback.

**AIOSCPU (disk image)**
A Debian-based bootable OS with GRUB dual-boot. In OS-AI Mode, `aioscpu-mode-init.service` reads `/proc/cmdline`, writes the boot mode to `/run/aioscpu/mode`, and starts `aura.service`. AURA runs as a locked system account (`aura`), communicates via a line protocol on stdin/stdout, persists memory in SQLite, and executes commands only through `aioscpu-secure-run`.

---

### How do I install it?

**AIOS-Lite (no installation):**

```sh
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
sh OS/sbin/init
```

On Android (Termux):
```sh
pkg update && pkg install git python
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT/OS && export OS_ROOT=$(pwd) && sh sbin/init
```

**AIOSCPU disk image (Linux host required):**
```sh
# Install build dependencies
sudo apt install debootstrap grub-pc parted

# Build the image
git clone https://github.com/Cbetts1/PROJECT
cd PROJECT
bash aioscpu/build/build-image.sh

# Write to USB or SD card and boot
```

Full installation guide: [docs/INSTALL.md](docs/INSTALL.md)

---

### How do I contribute?

1. Fork the repository at https://github.com/Cbetts1/PROJECT
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes. Run the test suite:
   ```sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
   ```
4. Ensure all tests pass before submitting.
5. Open a pull request with a clear description of what you changed and why.

Priority contribution areas: ARM64 image support, LXC/Podman AURA isolation, UEFI Secure Boot, web UI, and additional AI bot handlers.

---

### How was AI used in building AIOSCPU?

AIOSCPU is a human-designed and human-coded project. AI tools were used as productivity aids during development — for exploring ideas, reviewing logic, and generating boilerplate — but all architecture decisions, security design choices, and core implementation work reflect the deliberate engineering judgment of Christopher Betts.

The AI agent *inside* AIOSCPU (AURA) runs entirely locally, using llama.cpp with a `.gguf` model file. No training data was collected from AIOSCPU users. No telemetry is transmitted.

---

### Legal and Safety Notes

**License:** AIOSCPU is released under the MIT License. You are free to use, copy, modify, merge, publish, distribute, sublicense, and sell copies of the software, subject to the license terms in [licenses/THIRD_PARTY_LICENSES.md](licenses/THIRD_PARTY_LICENSES.md).

**Warranty:** AIOSCPU is provided "as is", without warranty of any kind. See [docs/LEGAL.md](docs/LEGAL.md) for the full disclaimer.

**User responsibility:** You are responsible for all actions taken on a system running AIOSCPU. The AURA agent executes commands that affect your system. Review the security documentation ([docs/SECURITY.md](docs/SECURITY.md)) before deploying in any environment.

**Default credentials:** The AIOSCPU disk image ships with default credentials (`aios`/`aios`). **Change the password immediately on first boot.**

**AURA agent safety:** AURA's command execution is constrained to `aioscpu-secure-run`, which enforces a denylist blocking destructive operations (recursive root deletion, raw disk writes, fork bombs, filesystem creation on block devices). Every execution is logged to `/var/log/aioscpu-secure-run.log`. See [docs/SECURITY.md](docs/SECURITY.md) for the full model.

**Data privacy:** AURA's memory database is stored locally at `/var/lib/aura/aura-memory.db`. No data is transmitted externally by default. If you configure an external `model_backend` in `aura-config.json`, your prompts will be sent to that endpoint — review its privacy policy accordingly.

---

## 7. Community Onboarding

---

### Welcome to the AIOSCPU Community

AIOSCPU is built in public. That means the roadmap is open, the architecture is documented, the test suite is in the repo, and every design decision is available for review, challenge, and improvement. You are not just a user — you are invited to be a builder.

---

### Contribution Invitation

Whether you are a shell scripter, a Python developer, a Linux kernel enthusiast, a security researcher, or someone who just wants to try running AI locally — there is a place for you here.

**High-priority contribution areas:**

| Area | Description |
|---|---|
| **ARM64 image** | Build and test AIOSCPU on Raspberry Pi and mobile ARM hardware |
| **AURA container isolation** | Wrap the AURA agent in LXC or Podman for stronger privilege separation |
| **UEFI Secure Boot** | Add shim-based chain of trust to the disk image build |
| **Web UI** | Browser-based interface for AURA interaction over the local REST API |
| **LLM backend config** | Wire `model_backend` in `aura-config.json` to support configurable LLM endpoints |
| **New AI bots** | Extend the `Router` with new `BaseBot` subclasses for additional intent categories |
| **Test coverage** | Expand the integration test suite, particularly for networking and bridge modules |
| **Documentation** | Improve API docs, add tutorials, translate into other languages |

**To get started:**
1. Read [docs/AIOSCPU-ARCHITECTURE.md](docs/AIOSCPU-ARCHITECTURE.md) for a full system overview
2. Read [docs/AURA-API.md](docs/AURA-API.md) to understand the AURA line protocol
3. Read [docs/SECURITY.md](docs/SECURITY.md) before working on anything security-related
4. Run the test suite to confirm your environment is working
5. Pick an issue, leave a comment that you're working on it, and open a PR

---

### Issue Reporting Guidelines

**Before opening an issue:**
- Search existing issues to avoid duplicates
- Confirm the issue is reproducible on the latest commit of `main`
- Collect relevant logs from `OS/var/log/` or `journalctl -u aura` (AIOSCPU disk image)

**Bug reports should include:**
- AIOSCPU version or commit SHA
- Host OS and architecture (e.g., `Ubuntu 22.04 x86_64`, `Termux on Android 14 ARM64`)
- Steps to reproduce, expected behavior, and actual behavior
- Relevant log output

**Feature requests should include:**
- A clear description of the problem the feature solves
- Whether you are willing to implement it (we will prioritize issues with volunteer implementers)

**Security vulnerabilities:**
Do not open public issues for security vulnerabilities. Report them privately by email to the project maintainer. See [docs/SECURITY.md](docs/SECURITY.md) for the responsible disclosure process.

---

### Community Expectations

AIOSCPU is a technical community. We keep things professional and direct.

**We expect:**
- Clear, specific communication — vague questions get vague answers
- Respect for other contributors' time — read the docs before asking
- Constructive criticism — challenge ideas, not people
- Attribution — if you build on this work, say so

**We do not tolerate:**
- Harassment, discrimination, or personal attacks
- Deliberately misleading information about the project's capabilities
- Attempts to introduce security vulnerabilities under the guise of contributions

All contributors are expected to follow the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

---

### Support Channels

| Channel | Purpose |
|---|---|
| **GitHub Issues** | Bug reports, feature requests, reproducible problems |
| **GitHub Discussions** | Questions, ideas, architecture discussions, show-and-tell |
| **GitHub Pull Requests** | Code contributions, documentation improvements |

There is no official Discord or Slack at this time. All project communication happens on GitHub. This keeps the record open, searchable, and permanent.

For security disclosures, contact the maintainer directly via the GitHub profile at https://github.com/Cbetts1.

---

*Thank you for your interest in AIOSCPU. Let's build the AI OS together.*

— **Christopher Betts**, Creator of AIOSCPU
*April 2026*

---

*© 2026 Christopher Betts | AIOSCPU Official | Released under the MIT License*
*AIOSCPU is built on open-source foundations: Linux kernel, Debian, GRUB, Python, llama.cpp*
