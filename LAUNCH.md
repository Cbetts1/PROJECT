# AIOS-Lite v1.0.0 "Aurora" — Public Launch

> *Your AI OS. Any device. Any shell.*

---

## Project Description

### Short Description

**AIOS-Lite** is a portable, AI-powered operating system built entirely in
POSIX shell and Python 3.  It runs on any Unix-like environment — Android
(Termux), Linux, or macOS — and bridges to external devices so your AI OS
can mirror and manage iPhones, Android phones, and remote Linux servers from
a single unified shell.

### Long Description

AIOS-Lite is an AI-integrated pseudo-kernel OS that runs entirely in user
space.  It provides the full experience of an operating system — boot sequence,
process scheduler, permissions model, system calls, service registry, event bus,
networking stack, and a REST/WebSocket HTTP server — without requiring hardware
privilege rings or a custom kernel.

At its heart is **AURA** (Autonomous Unified Resource Agent), an AI agent
powered by an on-device LLaMA language model (or a lightweight rule-based
fallback when no model is present).  AURA maintains a three-layer memory
system — rolling context window, symbolic key-value store, and semantic
embedding index — and routes natural-language queries to specialised bots:
**HealthBot** (system diagnostics), **LogBot** (log analysis), and
**RepairBot** (self-healing).

AIOS-Lite also ships a **cross-OS bridge layer** that connects to iOS devices
(via libimobiledevice), Android devices (via ADB), and remote Linux hosts
(via SSH/SSHFS), mirroring their filesystems into a unified namespace at
`$OS_ROOT/mirror/`.  Plug your OS into any device and your system mirrors it.

For deployment on dedicated hardware, the **AIOSCPU** image builder produces
a reproducible Debian-based x86-64 disk image with GRUB, systemd, and the
AURA agent running under a locked-down service account.

---

## Tagline Options

1. **"Your AI OS. Any device. Any shell."**
2. **"Plug in. Mirror everything. Think out loud."**
3. **"The OS that listens."**
4. **"AI-native. Shell-portable. Infinitely extensible."**
5. **"One OS. Every device. Powered by AI."**

*Primary tagline:* **"Your AI OS. Any device. Any shell."**

---

## Feature Highlights

| Feature | What It Does |
|---------|-------------|
| 🧠 **On-device AI** | LLaMA LLM inference runs entirely on your hardware — no cloud, no telemetry |
| 🐚 **Shell-portable** | Runs on Android (Termux), Linux, or macOS without installation |
| 🔗 **Cross-OS bridge** | Connect to iOS, Android, or remote Linux and mirror their filesystems |
| 🛡️ **Capability security** | Fine-grained permissions per principal; syscall audit log on every operation |
| 🔁 **Self-healing OS** | Five-stage recovery mode detects and repairs itself automatically |
| 🌐 **REST + WebSocket API** | Full HTTP server with TLS, token auth, Server-Sent Events |
| 💾 **Three-layer memory** | Context window + symbolic key-value + semantic embeddings + hybrid recall |
| 📦 **Reproducible builds** | Portable shell (no build needed) or full AIOSCPU disk image from source |
| 🧩 **Pseudo-kernel design** | Boot sequence, scheduler, IPC, resource manager — all in user space |
| 📋 **144-test suite** | 57 unit tests + 87 integration tests, all passing |

---

## What This OS Is

AIOS-Lite is:

- **A user-space AI operating system** — a complete OS environment (init,
  services, syscalls, permissions, networking) implemented in POSIX shell
  and Python 3, running on top of any Unix host
- **A portable AI shell** — carry it on a USB drive or run it from an
  Android phone; the same environment follows you everywhere
- **A cross-device bridge** — mirror and manage iOS, Android, and Linux
  devices from one unified shell with a consistent namespace
- **An AI-augmented command line** — ask questions in plain English; AURA
  routes them to the right subsystem, remembers your context, and repairs
  itself when things go wrong
- **An open platform** — MIT licensed, fully documented, with a formal plugin
  API roadmap and a growing test suite

---

## What This OS Is Not

AIOS-Lite is **not**:

- A replacement for Linux, Android, iOS, or any full OS kernel — it runs
  *on top of* a Unix host and augments it
- A hypervisor or virtual machine — there is no hardware virtualisation
- A cloud OS — all computation, memory, and data stay on your device by
  default; no data is sent externally
- A production-hardened server OS — it is designed for personal use,
  research, mobile AI, and extensibility; production deployments require
  the additional hardening steps described in `SECURITY.md`
- A consumer appliance — it is a developer/power-user tool with a CLI-first
  interface

---

## Founder Statement

*From Christopher Betts, Creator of AIOS-Lite / AIOSCPU*

> I built AIOS-Lite because I wanted an operating system that truly works
> *with* me — one that remembers what I've done, understands what I'm trying
> to do, and helps me manage every device I own from a single shell.
>
> I started from a simple question: what if your OS could think?  Not in the
> cloud, not with a subscription, but right here on the device in your pocket.
>
> AIOS-Lite is the answer I built for myself.  It runs on my phone, bridges to
> my other devices, and speaks plain English.  It boots in seconds, heals
> itself when something breaks, and gets smarter the longer you use it.
>
> Today I'm sharing it with the world as a free, open-source project.  I hope
> it becomes a foundation for a new generation of personal AI tools — tools
> that are private, portable, and owned by the person using them.
>
> — **Christopher Betts**, Founder & Lead Architect, AIOSCPU

---

## Press-Release Announcement

**FOR IMMEDIATE RELEASE**

**AIOSCPU Launches AIOS-Lite v1.0.0 "Aurora" — The First Fully Open-Source,
AI-Native, Shell-Portable Operating System**

*Portable AI OS runs on Android, Linux, and macOS; bridges to iPhone and
remote servers; powered by on-device LLaMA AI with no cloud dependency*

**[April 3, 2026]** — AIOSCPU today announced the public release of
**AIOS-Lite v1.0.0 "Aurora"**, the first production release of an AI-native
operating system built entirely in POSIX shell and Python 3.

AIOS-Lite delivers a complete OS environment — boot sequence, process
scheduler, capability-based permissions, system call interface, service
registry, event bus, networking stack, REST/WebSocket server, and
cross-device bridge — entirely in user space, running on any Unix-like
platform without requiring root access or a custom kernel.

At the core of AIOS-Lite is **AURA** (Autonomous Unified Resource Agent),
an on-device AI agent that classifies natural-language queries, routes them
to specialised diagnostic and repair bots, and maintains a three-layer
memory system (context window + symbolic + semantic) so it remembers context
across sessions.

**Key capabilities of v1.0.0:**

- On-device LLaMA LLM inference with rule-based fallback (no cloud required)
- Cross-OS bridge: mirror iOS, Android, and Linux device filesystems
- Full HTTP REST + WebSocket API with TLS 1.2, token auth, and SSE
- Five-stage self-repair mode (automated recovery without manual intervention)
- 144-test suite (57 unit + 87 integration tests)
- Reproducible AIOSCPU disk image builder for x86-64 hardware
- MIT License — free for personal and commercial use

AIOS-Lite is available now on GitHub at <https://github.com/Cbetts1/PROJECT>.

---

## Social Media Announcement

### GitHub / Developer Communities

```
🚀 AIOS-Lite v1.0.0 "Aurora" is live!

An AI-native OS that runs in your shell — on Android, Linux, or macOS.

✅ On-device LLaMA AI (no cloud)
✅ Cross-OS bridge: mirror iPhone, Android, Linux
✅ Pseudo-kernel: boot, scheduler, perms, syscalls — all in userspace
✅ Self-healing with 5-stage recovery
✅ Full REST + WebSocket API with TLS
✅ MIT License

→ https://github.com/Cbetts1/PROJECT
```

### Twitter / X

```
Your AI OS in a shell.

AIOS-Lite v1.0.0 "Aurora" is out 🚀

• Runs on Android (Termux), Linux, macOS
• On-device LLaMA AI — zero cloud
• Bridges to iOS, Android, Linux devices
• Self-healing pseudo-kernel
• MIT open source

github.com/Cbetts1/PROJECT

#AI #OpenSource #Linux #Android #LLM
```

### LinkedIn

```
I'm thrilled to announce the public release of AIOS-Lite v1.0.0 "Aurora"
— an AI-native operating system I've been building.

AIOS-Lite runs entirely in POSIX shell + Python 3 on any Unix device
(Android/Termux, Linux, macOS). It bridges to iPhones and Android phones,
mirrors their filesystems, and lets you manage everything from one AI-powered
shell with on-device LLaMA inference.

No cloud. No subscription. Your data stays on your device.

It ships with a pseudo-kernel (boot sequence, scheduler, permissions, syscalls),
a three-layer AI memory system, a full REST/WebSocket API, and a 144-test suite.

Open source under the MIT License:
https://github.com/Cbetts1/PROJECT

I'd love to hear what you think.

#AI #OperatingSystems #OpenSource #LLM #MobileAI
```

---

## Website Landing Page Copy

```markdown
# AIOS-Lite — Your AI OS. Any Device. Any Shell.

> The operating system that thinks, bridges, and heals itself.

---

## Run Your AI OS Anywhere

AIOS-Lite runs on your Android phone (Termux), your Linux laptop, or your
Mac — no installation, no root, no cloud. Pull the repo and boot in under
a minute.

[Get Started on GitHub →](https://github.com/Cbetts1/PROJECT)

---

## Powered by On-Device AI

AURA (Autonomous Unified Resource Agent) is the brain of AIOS-Lite.
Drop a LLaMA model into the `llama_model/` folder and your OS starts
answering questions in plain English — about your system, your devices,
your files, and your history.

No subscription. No telemetry. Your AI runs on your hardware.

---

## Bridge to Any Device

Connect your OS to an iPhone, an Android phone, or a remote Linux server.
AIOS-Lite mirrors their filesystems into a unified namespace so you can
browse, copy, and manage files from one shell.

```sh
os-bridge ios pair      # pair with iPhone
os-mirror mount ios     # mount iPhone at OS/mirror/ios/
ls $OS_ROOT/mirror/ios/ # browse iPhone files
```

---

## A Real OS Architecture

AIOS-Lite isn't a shell script collection. It's a complete OS:

- **Boot sequence** — `sbin/init` + `rc2.d` runlevel chain
- **Pseudo-kernel** — syscall gate, scheduler, permissions, resource manager
- **Service registry** — start, stop, monitor background services
- **Event bus** — inter-process messaging
- **REST + WebSocket API** — TLS 1.2, token auth, Server-Sent Events
- **Self-repair** — five-stage automated recovery mode

---

## Features

| | |
|---|---|
| 🧠 On-device LLaMA AI | 🔗 iOS / Android / Linux bridge |
| 💾 3-layer AI memory | 🛡️ Capability-based security |
| 🌐 HTTP REST + WebSocket | 🔁 Self-healing recovery |
| 📦 Reproducible builds | 🧩 Portable — no root needed |

---

## Open Source. MIT License.

AIOS-Lite is free for personal and commercial use.
Built by Christopher Betts. Contributions welcome.

[View on GitHub](https://github.com/Cbetts1/PROJECT) ·
[Read the Docs](https://github.com/Cbetts1/PROJECT/tree/main/docs) ·
[Report a Bug](https://github.com/Cbetts1/PROJECT/issues)

---

© 2026 Christopher Betts · AIOSCPU
```

---

## Branding & Identity

### OS Name

**AIOS-Lite** — portable shell / user-space distribution  
**AIOSCPU** — full disk image / dedicated hardware distribution

Both share the **AURA** agent and the same codebase.

### Version Naming Scheme

Releases follow **semantic versioning** (`MAJOR.MINOR.PATCH`) with a
codename for each major release:

| Version | Codename | Theme |
|---------|----------|-------|
| 1.0.x | **Aurora** | Dawn / first light / new beginning |
| 1.1.x | **Beacon** | Navigation / guidance |
| 1.2.x | **Catalyst** | Acceleration / transformation |
| 2.0.x | **Meridian** | Peak / turning point |

### Logo Description

```
  ___  ___ ___  ___ ___ ___  _   _
 / _ \|_ _/ _ \/ __/ __| _ \| | | |
| (_) || || (_) \__ \__ \  _/ |_| |
 \__,_|___\___/|___/___/_|  \___/

     A I O S
  "Aurora" Edition
  v1.0  © 2026 Chris Betts

  [ AURA AI Agent: ONLINE ]
  [ Mode: AI | Shell ]
  [ Status: Ready ]
```

*The logo uses the project ASCII art from `branding/LOGO_ASCII.txt`.
A vector/raster version for web use should use a monospace font
(e.g., JetBrains Mono, Fira Code) with the same letterforms.*

### Color Palette

| Role | Color | Hex |
|------|-------|-----|
| Primary — terminal green | Matrix / phosphor green | `#00FF41` |
| Secondary — deep space | Near-black background | `#0D1117` |
| Accent — aurora cyan | Arctic blue-green | `#79C0FF` |
| Highlight — AI purple | Neural purple | `#BC8CFF` |
| Warning | Amber | `#E3B341` |
| Error | Soft red | `#F85149` |
| Text — light | Off-white | `#E6EDF3` |

*Palette inspired by GitHub dark mode + classic terminal green.
The aurora cyan and AI purple evoke the "Aurora" release codename and
the AI-native nature of the OS.*

### Tagline Options (ranked)

1. **"Your AI OS. Any device. Any shell."** ← selected primary
2. **"Plug in. Mirror everything. Think out loud."**
3. **"The OS that listens."**
4. **"AI-native. Shell-portable. Infinitely extensible."**
5. **"One OS. Every device. Powered by AI."**

---

*© 2026 Christopher Betts | AIOSCPU Official*
