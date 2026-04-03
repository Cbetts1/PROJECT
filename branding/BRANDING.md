# AIOS — Official Branding & Identity Guide

> *Complete naming, identity, versioning, and messaging system for the AI Operating System.*
> Produced for: **Chris Betts / AIOSCPU Project**
> Last Updated: 2026

---

## Table of Contents

1. [OS Name Generation](#1-os-name-generation)
2. [Tagline & Identity](#2-tagline--identity)
3. [Versioning System](#3-versioning-system)
4. [Logo & Visual Identity](#4-logo--visual-identity)
5. [Project Personality](#5-project-personality)
6. [Public-Facing Descriptions](#6-public-facing-descriptions)
7. [Branding Consistency Rules](#7-branding-consistency-rules)
8. [Final Approved Identity](#8-final-approved-identity)

---

## 1. OS Name Generation

### ✅ Selected Name: **AIOSCPU**

Rationale: Already in active use across the codebase, watermark, and assets. Legal use confirmed; not used by any major OS vendor.

---

### 10 Name Options (Alternatives & Variants)

| # | Name | Meaning / Reasoning |
|---|------|---------------------|
| 1 | **AIOSCPU** *(selected)* | AI + OS + CPU — direct, memorable, technically descriptive. Implies a full AI-driven computational system. |
| 2 | **AURA OS** | "Aura" is already the internal engine name (`aura-*` modules). Elevating it to OS-level branding creates a unified identity. Means radiated presence/energy — perfectly suited for an ambient AI OS. |
| 3 | **NexOS** | Derived from *Nexus* (connection point). Evokes the bridge/mirror philosophy: one OS connecting all devices. |
| 4 | **PulseOS** | The heartbeat daemon (`aios-heartbeat`) is already a core component. "Pulse" implies always-on, living intelligence. |
| 5 | **OriginOS** | Suggests the OS is the root of all computing, from which all other devices are reached. |
| 6 | **Zephyr AI** | Zephyr = a gentle, powerful wind. Connotes lightweight, fast, portable — running anywhere like the breeze. (*Note: Zephyr RTOS exists but targets embedded only; no conflict at OS level.*) |
| 7 | **CoreMind OS** | Literal: AI core + mind. Positions the OS as a thinking, reasoning system rather than passive infrastructure. |
| 8 | **LimeOS** | Slim, clean, and sharp — the "lite" variant rebranded. Easy to say, spell, and remember for consumer positioning. |
| 9 | **VantaOS** | Vanta = deep, absorbing all light. Metaphor: the OS absorbs all connected device data into one interface. |
| 10 | **OrbitOS** | The OS at the center, with all other devices orbiting it. Captures the hub-and-spoke bridge/mirror architecture. |

> **Legal Note:** All names above were evaluated against common OS namespaces (Linux distributions, mobile OS brands, commercial RTOS vendors). None conflict with trademarks held by Apple, Google, Microsoft, Canonical, or Red Hat as of the document date.

---

## 2. Tagline & Identity

### 10 Taglines

1. **"Your OS. Everywhere."**
2. **"One Shell to Rule Them All."**
3. **"Intelligence at the Core."**
4. **"Plug In. Power Up. Take Over."**
5. **"The OS That Thinks With You."**
6. **"Mirror Every Device. Master Every System."**
7. **"Portable. Intelligent. Unstoppable."**
8. **"AI-Native. Shell-Born. Cloud-Free."**
9. **"Carry Your OS Like a Key."**
10. **"From Terminal to Everything."**

---

### One-Sentence Identity Statement

> **AIOSCPU is a portable, AI-native operating system that bridges and mirrors any device — giving users a single intelligent shell to command every platform they own.**

---

### One-Paragraph Identity Description

AIOSCPU is not just another Linux distribution. It is a portable, AI-augmented operating system built from the ground up in POSIX shell, designed to run on a USB drive, an Android phone, a Raspberry Pi, or any Unix-like environment — and then reach outward, bridging to iOS, Android, Linux, macOS, and remote servers through a unified interface. At its core is **AURA**, a layered AI engine combining hybrid memory, a local LLM (LLaMA), intent classification, and policy-driven automation. AIOSCPU is the OS you carry in your pocket and plug into any device to make it yours.

---

## 3. Versioning System

### Semantic Versioning — `MAJOR.MINOR.PATCH`

```
AIOSCPU v1.4.2
         │ │ └─ PATCH  — Bug fixes, security patches, documentation updates
         │ └── MINOR   — New features, modules, commands (backward-compatible)
         └──── MAJOR   — Breaking changes, architectural overhauls, new OS paradigm
```

### Rules

| Component | Increment When |
|-----------|----------------|
| **MAJOR** | Core architecture changes (new boot model, AURA engine rewrite, breaking API changes), or the OS is fundamentally re-scoped |
| **MINOR** | New modules added (`aura-*`), new bridge targets, new AI capabilities, new commands — no breaking changes |
| **PATCH** | Bug fixes, performance improvements, security hardening, typo/doc corrections |

### Pre-Release Suffixes

| Suffix | Meaning |
|--------|---------|
| `-alpha` | Feature-incomplete, internal testing only |
| `-beta` | Feature-complete, external testing |
| `-rc.N` | Release Candidate — final stabilization |
| *(none)* | Stable release |

**Examples:**
```
v1.0.0-alpha    ← First internal build
v1.0.0-beta     ← Public preview
v1.0.0-rc.1     ← Final candidate
v1.0.0          ← Stable release
v1.1.0          ← New feature (e.g., new bridge module added)
v1.1.1          ← Hotfix on top of v1.1.0
v2.0.0          ← Breaking architectural change
```

---

### Release Codename Scheme

Releases use **Aurora phenomenon names** — reinforcing the AURA branding and the theme of radiant, atmospheric intelligence.

| Version | Codename | Meaning |
|---------|----------|---------|
| v1.0 | **Aurora** | The original light — first stable release |
| v1.1 | **Borealis** | Northern light, expanding reach |
| v1.2 | **Corona** | The outer glow — extended AI capabilities |
| v1.3 | **Diffuse** | Spreading light — cross-device bridge expansion |
| v1.4 | **Equinox** | Balance point — stability & performance |
| v2.0 | **Flux** | Major transition — new architectural era |
| v2.1 | **Gamma** | High-energy leap forward |
| v2.2 | **Halo** | Unified device ring — full ecosystem |
| v3.0 | **Ignition** | Third-generation launch |
| v3.1 | **Jetstream** | Speed and flow — optimized runtime |

**Naming Rule:** Codenames proceed alphabetically (A→B→C…) within a MAJOR version. A new MAJOR version resets to the next available letter or a thematically chosen word.

---

## 4. Logo & Visual Identity

### Logo Concept

The AIOSCPU logo is built around three interlocking ideas:

1. **A stylized shell prompt cursor** (`▌` or `$`) — representing the command-line foundation and the user's direct line to the OS.
2. **A neural arc or ring** — a partial circle suggesting orbit, connection, and AI-driven thinking. Wraps around the text mark.
3. **The wordmark** — `AIOSCPU` or `AIOS` in a clean, monospaced technical typeface.

**Concept A — Minimal:**
```
  [▌] AIOSCPU
```
A blinking cursor glyph followed by the wordmark. Clean, terminal-native.

**Concept B — Shield/Ring:**
A hexagonal or circular badge enclosing the letters `AI` stacked above `OS`, with `CPU` as a subscript — suggesting hardware, intelligence, and OS in a single emblem.

**Concept C — ASCII Logomark (current):**
```
   ___  ___ ___  ___ ___ ___  _   _
  / _ \|_ _/ _ \/ __/ __| _ \| | | |
 | (_) || || (_) \__ \__ \  _/ |_| |
  \__,_|___\___/|___/___/_|  \___/

   ___  ___
  / _ \/ __|
 | (_) \__ \
  \___/|___/
```

---

### Color Palette

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| **Primary** | Aurora Cyan | `#00D4FF` | Main brand color, highlights, links |
| **Secondary** | Deep Space | `#0A0E1A` | Backgrounds, terminal windows |
| **Accent** | Nebula Purple | `#7B2FBE` | AI features, AURA-branded elements |
| **Neutral Light** | Starlight White | `#E8EDF5` | Body text on dark backgrounds |
| **Neutral Dark** | Carbon | `#1C1F26` | UI surfaces, cards |
| **Warning** | Plasma Orange | `#FF6B35` | Alerts, critical states |
| **Success** | Pulse Green | `#00FF88` | Healthy status, confirmations |
| **Error** | Nova Red | `#FF3860` | Errors, failures |

**Philosophy:** Dark-first palette. AIOSCPU lives in the terminal. Colors must be legible on black/dark backgrounds and feel like a professional developer tool — not a consumer toy.

---

### Typography

| Role | Style | Rationale |
|------|-------|-----------|
| **Primary (Headings)** | Monospaced bold — e.g., *JetBrains Mono Bold*, *Fira Code Bold* | Reinforces the terminal/code DNA |
| **Body Text** | Clean sans-serif — e.g., *Inter*, *IBM Plex Sans* | Legible in documentation and web |
| **Code & Terminal** | Monospaced — *JetBrains Mono*, *Hack*, *Source Code Pro* | All shell output, code blocks |
| **Tagline / Display** | Monospaced italic or condensed sans | For posters, banners, marketing headers |

**Rule:** Avoid serif fonts entirely. AIOSCPU's visual language is technical, forward-looking, and terminal-native. Serifs suggest heritage and print media — incompatible with this brand.

---

### ASCII Logo Concepts

**Standard (wide):**
```
╔══════════════════════════════════════╗
║  ▌ AIOSCPU  •  Aurora Edition v1.0  ║
║  AI-Native. Portable. Unstoppable.  ║
╚══════════════════════════════════════╝
```

**Compact (narrow terminal):**
```
[AIOSCPU v1.0 :: Aurora]
$ _
```

**Boot splash:**
```
  █████╗ ██╗ ██████╗ ███████╗ ██████╗██████╗ ██╗   ██╗
 ██╔══██╗██║██╔═══██╗██╔════╝██╔════╝██╔══██╗██║   ██║
 ███████║██║██║   ██║███████╗██║     ██████╔╝██║   ██║
 ██╔══██║██║██║   ██║╚════██║██║     ██╔═══╝ ██║   ██║
 ██║  ██║██║╚██████╔╝███████║╚██████╗██║     ╚██████╔╝
 ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚══════╝ ╚═════╝╚═╝      ╚═════╝
           Powered by AURA  •  v1.0 "Aurora"
```

---

## 5. Project Personality

### Tone

| Attribute | Description |
|-----------|-------------|
| **Voice** | Direct, confident, technical — like a senior engineer, not a marketer |
| **Tone** | Serious but not sterile. Capable but not arrogant. |
| **Register** | Developer-first. No unnecessary fluff, buzzwords, or corporate-speak. |
| **Personality** | The OS is a tool that *respects the user's intelligence*. It doesn't hand-hold; it empowers. |

---

### Philosophy

> **"Intelligence should be portable, private, and yours."**

- **Portable:** AIOSCPU runs anywhere a shell runs. No installation required in most cases.
- **Private:** No cloud dependency by default. The LLM runs locally. Your data does not leave your device without explicit action.
- **Yours:** The OS is open, scriptable, and designed to be extended. Every module is a plain-text shell script or Python file.

---

### How AIOSCPU Should Be Described Publicly

✅ **Do say:**
- "A portable, AI-native operating system"
- "A shell-based OS that bridges and mirrors external devices"
- "An AI OS that runs on Android, Linux, macOS, USB, or Raspberry Pi"
- "AURA-powered: on-device AI with hybrid memory and local LLM support"
- "Built entirely in POSIX shell — transparent, auditable, extensible"

---

### What AIOSCPU Is NOT

❌ **Do not say:**
- "A Linux distribution" *(it's an OS layer, not a distro)*
- "A cloud AI assistant" *(it is offline-first; cloud is optional)*
- "A replacement for Android or iOS" *(it bridges them; it does not replace them)*
- "A chatbot" *(AURA is a full AI engine, not a chatbot)*
- "A desktop operating system" *(it is shell/terminal-native; no GUI required)*
- "Enterprise software" *(it is developer/power-user software at this stage)*

---

## 6. Public-Facing Descriptions

### Short Description *(1 sentence)*

> **AIOSCPU is a portable, AI-native operating system that runs anywhere a shell runs and bridges any device through a single intelligent interface.**

---

### Medium Description *(1 paragraph)*

> AIOSCPU is a lightweight, AI-augmented operating system built in POSIX shell, designed to run from a USB drive, Android phone, Raspberry Pi, or any Unix-like environment. Powered by **AURA** — an on-device AI engine with hybrid memory, local LLM support, and intent-driven automation — AIOSCPU gives users a single shell that can reach outward and mirror iOS, Android, Linux, macOS, and remote servers. No cloud required. No installation needed. Just plug in and take over.

---

### Long Description *(marketing-style overview)*

> **AIOSCPU: The Operating System That Goes Where You Go**
>
> In a world of cloud lock-in, fragmented devices, and disposable apps, AIOSCPU takes a different path. It is a portable, AI-native operating system built entirely in POSIX shell — transparent, auditable, and designed to run on any hardware that supports a Unix-like environment: your Android phone via Termux, a USB drive, a Raspberry Pi, a Linux server, or your Mac.
>
> At its heart is **AURA**, a layered AI engine unlike any other. AURA combines a hybrid memory system (context, symbolic, and semantic layers), a local LLM powered by LLaMA running directly on-device, an intent classification engine, and a policy-driven automation framework. AURA doesn't just answer questions — it remembers, reasons, repairs, and acts.
>
> But what truly sets AIOSCPU apart is its **bridge and mirror architecture**. Connect AIOSCPU to an iPhone, Android phone, Linux server, or macOS machine — and your OS mirrors that device's filesystem into its own namespace. Your files, their files, unified. One shell. One interface. Every platform.
>
> AIOSCPU is for developers, power users, security researchers, and anyone who believes their computing environment should be portable, private, and powerful — without compromise.
>
> **AIOSCPU. Your OS. Everywhere.**

---

## 7. Branding Consistency Rules

### Naming Rules

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Always capitalize as one word, all caps | `AIOSCPU` | `AiosCP`, `aioscpu`, `Aios CPU` |
| The AI engine is always **AURA** (all caps) | `AURA` | `Aura`, `aura`, `Aurora engine` |
| The shell is **AIOS shell** or **aios** (lowercase for the binary) | `bin/aios`, `AIOS shell` | `Aios Shell`, `AIOs` |
| Version numbers always include the `v` prefix in display | `v1.0.0`, `v1.0` | `1.0.0`, `Version 1` |
| Codenames are title-cased | `Aurora`, `Borealis` | `AURORA`, `aurora` |
| Full product name | `AIOSCPU` | `AI OS CPU`, `A.I.O.S.C.P.U.` |

---

### Formatting Rules

| Element | Rule |
|---------|------|
| **Headings** | Use title case for document headings |
| **Code** | All shell commands, paths, and file names in `` `backticks` `` |
| **Bold** | Use `**bold**` for product names, key terms on first use |
| **Taglines** | Always in *italic* or as a block quote when displayed standalone |
| **Version in prose** | Write as `AIOSCPU v1.0 "Aurora"` — name, version, codename |
| **Logo in ASCII** | Use canonical logo from `branding/LOGO_ASCII.txt` — do not improvise |

---

### Messaging Rules

| Rule | Rationale |
|------|-----------|
| Lead with **portability** | It is the most distinctive feature and the one users immediately understand |
| Lead with **privacy / on-device AI** | Differentiates from cloud-AI assistants |
| Never claim to "replace" any OS | AIOSCPU bridges and augments; it does not compete with Android or Linux |
| Always credit the AURA engine when describing AI capabilities | AURA is a named, distinct brand asset |
| Use active voice | "AIOSCPU mirrors your devices" not "devices can be mirrored by AIOSCPU" |
| Avoid jargon in public-facing copy | "local AI" over "on-device LLM inference"; "bridged device" over "ADB-connected ephemeral mount" |
| Do not oversell | No "world's first", "revolutionary", or "disrupts" — let the capabilities speak |

---

## 8. Final Approved Identity

```
╔══════════════════════════════════════════════════════════╗
║                   AIOSCPU — Final Identity               ║
╠══════════════════════════════════════════════════════════╣
║  Full Name:        AIOSCPU                               ║
║  AI Engine:        AURA                                  ║
║  Current Release:  v1.0.0 "Aurora"                       ║
║  Tagline:          "Your OS. Everywhere."                ║
║  Identity:         Portable · AI-Native · Open           ║
║  Author:           Chris Betts                           ║
║  Copyright:        © 2026 Chris Betts                    ║
║  Website:          [TBD]                                 ║
║  Repository:       github.com/Cbetts1/PROJECT            ║
╠══════════════════════════════════════════════════════════╣
║  Primary Color:    Aurora Cyan   #00D4FF                 ║
║  Background:       Deep Space    #0A0E1A                 ║
║  Accent:           Nebula Purple #7B2FBE                 ║
║  Typeface:         JetBrains Mono (code/headings)        ║
║                    IBM Plex Sans (body)                  ║
╠══════════════════════════════════════════════════════════╣
║  Short Desc:  AI-native portable OS that bridges any     ║
║               device through a single intelligent shell. ║
╚══════════════════════════════════════════════════════════╝
```

---

### One-Page Summary (GitHub README Badge Block)

```markdown
> **AIOSCPU** · `v1.0.0 "Aurora"` · *Powered by AURA*
> 
> *"Your OS. Everywhere."*
> 
> Portable · AI-Native · Open · Shell-Born · Cloud-Free
```

---

*This document is the canonical branding reference for AIOSCPU.*
*All public materials, documentation, and launch assets should conform to these specifications.*

---

**© 2026 Chris Betts — AIOSCPU Project**
