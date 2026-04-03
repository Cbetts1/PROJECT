# AIOSCPU Architecture

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOSCPU is a Debian-based Linux operating system enhanced with **AURA**,
an AI agent that provides structured, audited access to system resources.
It supports two distinct boot modes selectable from the GRUB menu.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      GRUB Bootloader                     │
│         aioscpu_mode=ai  |  aioscpu_mode=shell           │
└─────────────────┬──────────────────┬────────────────────┘
                  │                  │
         ┌────────▼──────┐   ┌───────▼────────┐
         │  OS-AI Mode   │   │  OS-SHELL Mode  │
         │ (AURA agent)  │   │ (standard getty)│
         └────────┬──────┘   └────────────────┘
                  │
    ┌─────────────▼──────────────────┐
    │      aioscpu-mode-init.service  │
    │  reads /proc/cmdline           │
    │  writes /run/aioscpu/mode      │
    └─────────────┬──────────────────┘
                  │
    ┌─────────────▼──────────────────┐
    │         aura.service           │
    │   (systemd, user=aura)         │
    │   aura-agent.py                │
    └──┬──────────┬──────────────────┘
       │          │
       │   ┌──────▼────────────────┐
       │   │  aioscpu-secure-run   │  ← command execution (with denylist)
       │   └──────────────────────┘
       │
  ┌────▼──────────────────────────────┐
  │  SQLite Memory DB                  │
  │  /var/lib/aura/aura-memory.db     │
  └───────────────────────────────────┘
```

---

## Components

### Bootloader: GRUB

- Located in the MBR of the disk image
- Config: `/boot/grub/grub.cfg` (from `aioscpu/build/grub.cfg`)
- Two menu entries: `OS-AI` and `OS-SHELL`
- Passes `aioscpu_mode=ai|shell` on the kernel command line

### Kernel Command Line & Mode Init

- `aioscpu-mode-init.service` runs at early boot (`Before=sysinit.target`)
- Reads `/proc/cmdline` to extract `aioscpu_mode`
- Writes the detected mode to `/run/aioscpu/mode`
- In AI mode: enables and starts `aura.service`
- In Shell mode: ensures `aura.service` is stopped

### AURA Agent

- Python script: `/opt/aura/aura-agent.py`
- Config: `/opt/aura/aura-config.json`
- Runs as the `aura` system user (locked account, no login shell)
- Communicates via stdin/stdout line protocol
- Persists memory in SQLite (`/var/lib/aura/aura-memory.db`)

### Security Layer: `aioscpu-secure-run`

- The ONLY way AURA can execute shell commands
- Enforces a denylist of catastrophically dangerous patterns
- Logs every invocation to `/var/log/aioscpu-secure-run.log`
- AURA calls it via `sudo` (permitted by `/etc/sudoers.d/aura-commands`)

### User-facing Tools

| Script | Purpose |
|--------|---------|
| `auractl` | CLI to interact with AURA (interactive / single-command) |
| `aioscpu-ai-shell` | AI mode login shell (starts AURA, falls back to bash) |
| `aioscpu-shell-login` | Shell mode login wrapper (banner + `/bin/login`) |
| `aioscpu-sysinfo` | System information report |
| `aioscpu-netinfo` | Network information report |
| `aioscpu-wifi` | Wi-Fi management via nmcli |
| `aioscpu-bt` | Bluetooth management via bluetoothctl |
| `aioscpu-hotspot` | Wi-Fi hotspot creation via nmcli |
| `aioscpu-logwrap` | Audit wrapper for any command |
| `aioscpu-mode-init` | Boot mode detection and setup |

---

## Repository Layout

```
PROJECT/
├── aioscpu/
│   ├── build/
│   │   ├── build-image.sh       # Image builder script
│   │   ├── grub.cfg             # GRUB configuration
│   │   └── Makefile             # Build targets
│   └── rootfs-overlay/         # Files overlaid into the rootfs
│       ├── etc/                 # hostname, motd, issue, aioscpu-release
│       ├── systemd/system/      # aura.service, mode-init.service, getty drop-in
│       ├── sudoers.d/           # aura-commands sudoers rule
│       └── usr/local/bin/       # All AIOSCPU scripts
├── aura/
│   ├── aura-agent.py            # AURA Python agent
│   ├── aura-config.json         # Default configuration
│   ├── schema-memory.sql        # SQLite schema
│   └── README.md
├── branding/
│   ├── WATERMARK.txt
│   └── LOGO_ASCII.txt
├── licenses/
│   └── THIRD_PARTY_LICENSES.md
├── docs/
│   ├── AIOSCPU-ARCHITECTURE.md  # This file
│   ├── AURA-API.md
│   ├── BUILDING-IMAGE.md
│   ├── INSTALL.md
│   ├── LEGAL.md
│   └── SECURITY.md
├── ai/                          # llama integration (separate component)
├── OS/                          # Shell-script OS simulation
└── tests/
    └── unit-tests.sh
```

---

## Boot Sequence (AI Mode)

```
1. BIOS/UEFI → GRUB (aioscpu_mode=ai on cmdline)
2. Linux kernel boots
3. systemd starts
4. aioscpu-mode-init.service runs:
   - Reads /proc/cmdline → mode=ai
   - Writes "ai" to /run/aioscpu/mode
   - Starts aura.service
5. aura.service starts:
   - Runs aura-agent.py as user 'aura'
   - Listens on stdin (null) / logs to journal
6. getty@tty1 (with drop-in):
   - Autologins as 'aios'
   - .bash_profile detects AI mode
   - Execs aioscpu-ai-shell
7. aioscpu-ai-shell:
   - Checks aura.service is running
   - Launches auractl interactive
```

---

## Future Work

- LLM backend integration via `model_backend` config key
- Container-based AURA isolation (LXC / podman)
- Secure boot (UEFI + shim)
- Web UI for AURA interaction
- ARM64 image support
