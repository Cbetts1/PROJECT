# Changelog

All notable changes to **AIOS-Lite / AIOSCPU** are documented here.

This project follows [Semantic Versioning](https://semver.org/) and the
[Keep a Changelog](https://keepachangelog.com/) format.

---

## [1.0.0] — 2026-04-03 — "Aurora"

*First public release.*

### Added

#### OS Kernel & Boot
- `OS/sbin/init` — PID-1 equivalent: resolves `OS_ROOT`, creates runtime
  directories, writes initial `proc/os.state`, then runs `rc2.d` services
- `OS/etc/rc2.d/` runlevel 2 service chain: S10-banner → S20-devices →
  S30-aura-bridge → S40-os-kernel → S60-aura-agents → S70-aura-tasks
- `OS/bin/os-syscall` — system-call gate (read, write, spawn, kill, …)
  with audit logging to `var/log/syscall.log`
- `OS/bin/os-sched` — priority round-robin scheduler; background pruning of
  dead PIDs every 5 s
- `OS/bin/os-perms` — capability-based permission model with wildcard matching
- `OS/bin/os-resource` — CPU / memory / disk / thermal resource monitor
  (68 °C thermal limit for Samsung S21 FE)
- `OS/bin/os-recover` — five-stage recovery: directory repair → state repair
  → service cleanup → log rotation → dependency audit
- `OS/bin/os-service` and `os-service-status` — service lifecycle management
- `OS/bin/os-event` and `os-msg` — event bus for inter-process messaging
- `OS/bin/os-httpd` — Python 3 HTTP/WebSocket REST server with TLS support,
  token authentication, Server-Sent Events, and per-request metrics logging
- `OS/bin/os-netconf` — full network manager: interfaces, WiFi, Bluetooth,
  IP, routing, DNS, firewall (iptables), NAT, mDNS discovery, snapshot save/load
- `OS/lib/filesystem.py` — `OS_ROOT`-jailed file I/O; path-traversal blocking
  via `os.path.realpath()` comparison

#### AI Core
- `ai/core/intent_engine.py` — natural-language intent classification
- `ai/core/router.py` — intent-to-bot dispatcher
- `ai/core/bots.py` — HealthBot, LogBot, RepairBot (all extend `BaseBot`)
- `ai/core/fuzzy.py` — fuzzy command matching
- `ai/core/llama_client.py` — LLaMA inference wrapper + rule-based mock fallback
- `ai/core/commands.py` — natural-language command parser
- `ai/core/ai_backend.py` — top-level AI dispatch backend
- LLaMA model slot: place any `.gguf` file in `llama_model/` to enable full LLM

#### Memory System
- Rolling 50-line context window at `OS/proc/aura/context/window`
- Symbolic key-value memory (`mem.set` / `mem.get`)
- Semantic embedding memory (`sem.set` / `sem.search`)
- Hybrid recall engine combining all three layers
- AURA persistent SQLite memory (`aura/schema-memory.sql`)

#### Cross-OS Bridge
- `OS/bin/os-bridge` — bridge control for iOS (libimobiledevice), Android
  (ADB), and Linux/SSH targets
- `OS/bin/os-mirror` — device filesystem mirroring into `OS/mirror/`
- Host-OS auto-detection at boot (`OS/etc/init.d/aura-bridge`)

#### Shell & User Interface
- `OS/bin/os-shell` — primary interactive AI shell with `ask`, `recall`,
  `mem.*`, `sem.*`, `bridge.*`, `mirror.*`, `status`, `services`, `help`
- `OS/bin/os-real-shell` — full OS shell
- `bin/aios` — dual AI shell entry-point
- `bin/aios-sys` — OS shell entry-point
- `bin/aios-heartbeat` — background heartbeat daemon

#### AURA Agent Layer
- `aura/aura-agent.py` — AURA autonomous agent
- `aura/aura-config.json` — agent configuration
- `lib/aura-core.sh`, `aura-ai.sh`, `aura-fs.sh`, `aura-llama.sh`,
  `aura-net.sh`, `aura-proc.sh`, `aura-typo.sh` — AURA module library

#### AIOSCPU Disk Image
- `aioscpu/build/build-image.sh` — reproducible Debian-based x86-64 disk
  image builder (requires `debootstrap`)
- `aioscpu/rootfs-overlay/` — OS overlay files baked into the image
- `aioscpu-secure-run` wrapper with command denylist
- `aura.service` systemd unit with `ProtectSystem=strict` sandboxing

#### Security & Compliance
- Capability-based permissions with syscall audit log
- TLS 1.2-minimum enforcement in `os-httpd`
- API token authentication for all REST endpoints
- Spawn whitelist in `os-syscall`
- Path-traversal blocking in `filesystem.py`
- AURA sudoers rule scoped to single secure-run wrapper only
- `docs/SECURITY.md` — full security documentation
- `docs/COMPLIANCE.md` — licensing, privacy, and export compliance
- `docs/LEGAL.md` — AURA privacy & security notice
- `licenses/THIRD_PARTY_LICENSES.md` — upstream dependency licenses

#### Documentation
- `docs/ARCHITECTURE.md` — system architecture and directory structure
- `docs/KERNEL-DESIGN.md` — pseudo-kernel design, boot sequence, syscall table
- `docs/CAPABILITIES.md` — full capability matrix (status / component / tested)
- `docs/API-REFERENCE.md` — complete API reference (syscall, kernel, REST, AI)
- `docs/AURA-API.md` — AURA agent API reference
- `docs/AIOSCPU-ARCHITECTURE.md` — disk-image architecture
- `docs/AI_MODEL_SETUP.md` — LLM model setup guide
- `docs/BUILDING-IMAGE.md` — disk image build guide
- `docs/INSTALL.md` — installation guide
- `docs/PHONE_SPECS.md` — Samsung Galaxy S21 FE target device specs
- `docs/REPRODUCIBLE-BUILD.md` — reproducible build instructions

#### Testing
- `tests/unit-tests.sh` — 17 shell tests + 40 Python module tests (57 total)
- `tests/integration-tests.sh` — 87 integration tests
- `tests/test_python_modules.py` — standalone Python AI core test suite

#### Branding & Identity
- `branding/LOGO_ASCII.txt` — ASCII logo and AIOSCPU banner
- `branding/WATERMARK.txt` — distribution watermark

### Changed

- Nothing — this is the initial public release.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- `OS/bin/os-httpd`: enforced TLS 1.2 minimum (resolved CodeQL
  `py/insecure-protocol` finding).

### Security

- TLS floor set to `PROTOCOL_TLS_CLIENT` + `minimum_version=TLSVersion.TLSv1_2`
  in `os-httpd` to prevent downgrade to SSLv3 / TLS 1.0 / TLS 1.1.

---

## [0.1.0] — 2026-01 — *Pre-release / Development*

Internal development build. Not publicly released.

---

[1.0.0]: https://github.com/Cbetts1/PROJECT/releases/tag/v1.0.0
[0.1.0]: https://github.com/Cbetts1/PROJECT/releases/tag/v0.1.0
