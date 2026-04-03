# Changelog

All notable changes to AIOS-Lite are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### In Progress
- Persistent SQLite memory backend for symbolic and semantic layers
- Improved intent classification accuracy
- Web UI dashboard (`os-httpd` frontend)

---

## [0.2.0] — 2026-04-01

### Added
- Dual-shell architecture: `bin/aios` (AI shell) and `bin/aios-sys` (system shell)
- `bin/aios-heartbeat` daemon for continuous service health monitoring
- Cross-OS bridge layer (`OS/lib/aura-bridge/`) with iOS, Android, and SSH modules
- Filesystem mirror system (`OS/bin/os-mirror`) — mount any device under `$OS_ROOT/mirror/`
- AURA semantic memory layer (`OS/lib/aura-semantic/`) with embedding-based search
- AURA hybrid recall engine (`OS/lib/aura-hybrid/`) combining all memory layers
- AURA policy engine (`OS/lib/aura-policy/`) for event-driven automation rules
- AURA background agents (`OS/lib/aura-agents/`)
- AURA scheduled tasks (`OS/lib/aura-tasks/`)
- `OS/lib/filesystem.py` — OS_ROOT-isolated Python file I/O abstraction
- `os-recover` self-repair command
- `os-httpd` built-in HTTP server for local REST API access
- `os-netconf` network configuration command (WiFi, Bluetooth, IP, routing)
- Capability-based permissions model (`OS/etc/perms.d/`, `os-perms`)
- Service registry with health files (`os-service`, `os-service-health`, `os-service-status`)
- Runlevel system (0–3) with `os-kernelctl runlevel` transitions
- Syscall dispatcher (`OS/bin/os-syscall`)
- Cooperative scheduler (`OS/bin/os-sched`) with priority tiers
- Resource manager (`OS/bin/os-resource`) with soft CPU/memory quotas
- `AIOSCPU` disk image build system (`aioscpu/build/build-image.sh`) for x86-64
- Integration test suite (`tests/integration-tests.sh`, 87 tests)
- `docs/OS-ARCHITECTURE.md` — full architecture reference
- `docs/MANUAL.md` — instruction manual
- `docs/LEGAL.md` — complete legal and compliance package
- `ROADMAP.md` and `CHANGELOG.md`
- `LICENSE` (MIT)

### Changed
- `sbin/init` boot sequence refactored into five distinct phases
- `README.md` fully rewritten as GitHub landing page
- `docs/REPRODUCIBLE-BUILD.md` expanded with one-shot install script description and verification checklist
- `OS/etc/os-release` updated to version `0.2`

### Fixed
- `os-shell` now correctly handles missing `$OS_ROOT/proc/` directory on first boot
- Log rotation now triggers reliably at 1000 lines
- Bridge detection no longer crashes when `adb` is not installed

---

## [0.1.0] — 2026-01-15

### Added
- Initial project structure: `OS/sbin/init`, `OS/bin/os-shell`, `OS/bin/os-ai`
- Basic AI shell with rule-based intent handling
- llama.cpp integration via `OS/lib/aura-llm/` and `lib/aura-llama.sh`
- Symbolic key-value memory (`OS/lib/aura-memory/`)
- Event system (`OS/bin/os-event`)
- Message bus (`OS/bin/os-msg`)
- Service health basics (`OS/bin/os-service`, `OS/bin/os-service-status`)
- Python AI Core: `ai/core/intent_engine.py`, `router.py`, `bots.py`, `ai_backend.py`
- Fuzzy command matching (`ai/core/fuzzy.py`)
- Unit test suite (`tests/unit-tests.sh`, 57 tests: 17 shell + 40 Python)
- `docs/ARCHITECTURE.md`, `docs/INSTALL.md`, `docs/CAPABILITIES.md`
- `branding/LOGO_ASCII.txt`, `branding/WATERMARK.txt`
- Samsung Galaxy S21 FE optimisation profile (`docs/PHONE_SPECS.md`)
- `config/aios.conf` and `config/llama-settings.conf`

---

*End of Changelog*

> © 2026 Christopher Betts | AIOS-Lite | https://github.com/Cbetts1/PROJECT
