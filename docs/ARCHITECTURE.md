# AIOS System Architecture

**Portable AI Operating System for Samsung Galaxy S21 FE**

---

## Overview

AIOS is a lightweight, portable AI operating system that can run in two modes:

1. **Hosted mode** — runs as a container application on top of Android/Termux, using OverlayFS to mirror the host filesystem
2. **Standalone mode** — full OS kernel booted from USB or internal storage

The AI backbone is a quantized Llama model (3B–7B parameters) optimized for the Exynos 2100 / Snapdragon 888 SoC.

---

## System Layers

```
┌─────────────────────────────────────────────────────────┐
│                    User / Applications                   │
├─────────────────────────────────────────────────────────┤
│               Aura AI Shell (os-shell)                  │
│         Hybrid Memory · Semantic Engine · Policy        │
├─────────────────────────────────────────────────────────┤
│            Llama Inference Engine (ai/)                  │
│    llama.cpp bindings · int4/int8 quantized model       │
├─────────────────────────────────────────────────────────┤
│              AIOS Core Services (OS/)                    │
│   init · os-kernel · os-service · os-event · sysinfo   │
├─────────────────────────────────────────────────────────┤
│           OverlayFS Mirror Layer (mirror/)               │
│    read-only host base + read-write AIOS layer          │
├──────────────────────────┬──────────────────────────────┤
│     Hosted Mode          │      Standalone Mode          │
│  Android + Termux        │  Minimal Linux kernel        │
│  (namespace isolation)   │  (USB / internal boot)       │
└──────────────────────────┴──────────────────────────────┘
```

---

## Component Map

### OS Core (`OS/`)

| Path | Purpose |
|------|---------|
| `OS/sbin/init` | Init process — runs boot target and rc scripts |
| `OS/bin/os-shell` | Aura AI interactive shell |
| `OS/bin/os-service` | Service lifecycle manager |
| `OS/bin/os-kernel` | Kernel emulation / process table |
| `OS/bin/os-event` | Event bus dispatcher |
| `OS/bin/sysinfo` | Hardware + OS information |
| `OS/etc/init.d/` | rc-style startup scripts |
| `OS/lib/aura-*` | Pluggable AI engine modules |

### AI Layer (`ai/`)

| Path | Purpose |
|------|---------|
| `ai/llama-integration/` | llama.cpp build harness and bindings |
| `ai/model-quantizer/` | GGUF model download and quantization |
| `ai/shell-interface/` | AI command parser wired into Aura shell |
| `ai/inference-engine/` | Inference wrapper with thermal/RAM guards |

### Mirror Layer (`mirror/`)

| Path | Purpose |
|------|---------|
| `mirror/overlay-manager.sh` | Mount/unmount OverlayFS stacks |
| `mirror/mount-points.conf` | Declare host directories to mirror |
| `mirror/sync-daemon.sh` | Bidirectional sync for writable paths |

### Deploy (`deploy/`)

| Path | Purpose |
|------|---------|
| `deploy/container-installer.sh` | Hosted-mode one-command install |
| `deploy/usb-image-builder.sh` | Builds bootable USB/download image |
| `deploy/first-boot.sh` | First-run initialization |
| `deploy/phone-optimizations.sh` | S21 FE hardware tuning |

---

## Memory Budget (8 GB RAM)

```
┌──────────────────────────────────────────┐
│  Android System + Kernel    ~2.0 GB      │
│  Llama Model (int4, 7B)     ~4.0 GB      │
│  AIOS Core Services         ~0.5 GB      │
│  Inference Cache / KV       ~1.0 GB      │
│  Free / Buffer              ~0.5 GB      │
└──────────────────────────────────────────┘
```

With 6 GB RAM, use a 3B int4 model (~2.5 GB) instead.

---

## Storage Budget (128 GB internal)

```
AIOS OS footprint            ~3–5 GB
Llama model (int4 7B)        ~4–6 GB
System cache / temp          ~2   GB
User data / logs             ~5   GB
Android system               ~20  GB
Free headroom                ~90+ GB
```

---

## Boot Flow

```
Power On / Termux Launch
        │
        ▼
OS/sbin/init
  ├─ Read /etc/boot.target
  ├─ Execute /etc/init.d/S* scripts
  │     ├─ banner        (splash + version)
  │     ├─ devices       (dev node setup)
  │     └─ os-kernel     (process table init)
  ├─ Mount OverlayFS mirror  (mirror/overlay-manager.sh)
  ├─ Start inference daemon  (ai/inference-engine/)
  └─ Launch Aura shell       (OS/bin/os-shell)
```

---

## OverlayFS Architecture

```
Host filesystem (read-only lower layer)
       /data/data/com.termux/files/usr  →  /usr
       /system                           →  /system
       /proc, /sys, /dev                 (bind mounts)

AIOS read-write upper layer
       $OS_ROOT/overlay/upper

Merged view (workdir)
       $OS_ROOT/overlay/merged
```

Changes made within the AIOS environment land in the upper layer without modifying the host.

---

## AI Integration

The Aura shell calls into the inference engine via a Unix socket (`$OS_ROOT/var/run/llama.sock`). The inference engine manages:

- Model loading (memory-mapped, lazy)
- Context window management
- Thermal throttling (reads `/sys/class/thermal`)
- Battery-aware scheduling (pauses inference below 15% battery)
- Response streaming back to the shell

---

## Security Model

- AIOS runs under the host user's UID (no privilege escalation by default)
- OverlayFS upper layer is within the AIOS home directory
- Root operations (mounting, namespace creation) are explicit and gated by `aios.conf`
- Model weights are verified by SHA-256 checksum on first load
