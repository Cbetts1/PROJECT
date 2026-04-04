# Changelog

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

All notable changes to AIOS-Lite / AIOSCPU are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
This project uses [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

No unreleased changes at this time.

---

## [1.6.0] — 2026-04-04

### Verified / Audited (Multi-Agent OS Engineering Integration Pass)

Full multi-agent OS engineering audit confirmed the following components are
complete, functional, and consistent with documentation:

#### Boot Flow
- `run.sh` → `boot/bootloader.sh` (6 stages) → `bin/aios` — verified end-to-end
- `OS/sbin/init` — PID-1 bootstrap with runlevel 2 service orchestration
- `OS/etc/init.d/` — services: `os-kernel`, `aura-agents`, `aura-bridge`,
  `aura-llm`, `aura-tasks`, `banner`, `devices`
- Boot stages: 0 (Env Detection) → 1 (FS Init) → 2 (Permissions) →
  3 (Service Health) → 4 (Kernel State) → 5 (Boot Complete)

#### OS Shell & AI
- `OS/bin/os-shell` — full interactive shell with personality engine (operator/
  system/talk modes), AURA memory, event logging, all OS commands
- `OS/bin/os-ai` — interactive AI assistant with LLM backend + rule-based fallback
- `bin/aios` — AI shell with readline history, `status`, `sysinfo`, `version`,
  `log.tail`, `clear` built-ins, full AI dispatch pipeline
- `bin/aios-sys` — raw OS shell bypass
- `bin/aios-heartbeat` — background health daemon

#### AI Integration Pipeline
- `ai/core/intent_engine.py` → `router.py` → `bots.py` — intent classification
  and dispatch to `HealthBot`, `LogBot`, `RepairBot`, `UpgradeBot`, plus 3
  additional bots (`ProcessBot`, `NetworkBot`, `MemoryBot`) in `router.py`
- `ai/core/llama_client.py` — llama.cpp subprocess client + mock fallback
- `lib/aura-llama.sh` — shell-level LLM wrapper calling the Python client
- `build/build.sh` — llama.cpp build script (hosted/termux/arm64)

#### OS Services
- `OS/bin/os-log`, `os-state`, `os-ps`, `os-event`, `os-emit`,
  `os-resource`, `os-recover`, `os-netconf`, `os-service`, `os-kernelctl`
- `OS/lib/filesystem.py` — OS_ROOT-isolated file operations (read/write/list)
- `OS/lib/aura-memory/`, `aura-semantic/`, `aura-hybrid/`, `aura-llm/`,
  `aura-policy/`, `aura-bridge/`, `aura-mods/` — all AURA subsystem modules

#### DevOps Scripts
- `install.sh` — full installer: permissions, dirs, files, module verify,
  dep detection, unit tests; accepts `--build-llama`, `--start`, `--self-test`
- `run.sh` — first-run bootstrap + boot pipeline + exec `bin/aios`
- `update.sh` — git pull + re-install + optional test suite
- `scripts/install.sh`, `scripts/run.sh`, `scripts/update.sh` — thin wrappers
  delegating to root-level scripts; all work on Termux and Linux

#### Documentation
- `README.md` (670 lines) — accurate, complete, matches real system
- `CHANGELOG.md` — full version history from v1.0.0 to v1.6.0
- `docs/architecture.md` — 6-layer architecture blueprint
- `docs/development.md` (877 lines) — developer guide with 18 sections
- 30+ spec documents in `docs/`

#### Test Suite
- **264 total tests passing**: 27 shell unit + 150 Python unit + 87 integration
- `tests/unit-tests.sh` — filesystem.py, os-shell, os-real-shell, os-kernelctl,
  os-service, os-bridge, os-mirror, os-emit, os-event, os-state, os-sched,
  os-resource, os-recover, os-netconf, os-httpd, AI pipeline
- `tests/integration-tests.sh` — 87 end-to-end integration scenarios
- `tests/test_python_modules.py` — 150 Python unit tests (AI core)
- `install.sh --self-test` — full self-test: modules, deps, unit + integration

---

## [1.5.0] — 2026-04-04

### Fixed
- **Critical boot regression**: `config/aios.conf` referenced bare `$AIOS_HOME`
  inside a `${OS_ROOT:-$AIOS_HOME/OS}` fallback expression. With `set -o nounset`
  active in `lib/aura-core.sh`, this caused the shell to exit immediately on
  startup. Fixed by using `${AIOS_HOME:-${AIOS_ROOT:-$PWD}}` throughout
  `config/aios.conf` and by pre-setting `AIOS_HOME` in `etc/aios.conf` before
  the OS-level config is sourced.
- **Typo correction coverage**: `lib/aura-typo.sh` `aura_known_commands()` was
  missing the REPL built-ins (`status`, `sysinfo`, `version`, `log.tail`,
  `clear`). Fuzzy correction now covers the full command set.

### Added
- **`run.sh`** — clean top-level launcher. Runs the boot sequence then execs
  `bin/aios`. Accepts `--no-boot` to skip the boot animation.
- **`boot/bootloader.sh`** — six-stage visual boot pipeline:
  - Stage 0: environment detection (Termux / Linux / macOS)
  - Stage 1: filesystem initialisation (creates all required runtime dirs/files)
  - Stage 2: executable permission check (auto-fixes missing +x bits)
  - Stage 3: service health pre-check (Python AI backend, aura modules, LLM)
  - Stage 4: kernel state write (`OS/proc/os.state`)
  - Stage 5: boot-complete banner with elapsed time
- **`update.sh`** — git pull + re-install + optional self-test. Supports
  `--check` (show pending commits), `--self-test` (run test suite after update).
- **`bin/aios` enhancements**:
  - Readline command history with `read -e -p`; persisted to `var/run/aios_history`
  - `status` command — live kernel/AI state (uptime, log lines, backend, PIDs)
  - `sysinfo` command — host OS, memory, disk, Bash/Python versions
  - `version` command — print AIOS version and paths
  - `clear` command — clear terminal
  - `log.tail [n]` command — show last N lines of `var/log/aios.log`
  - All dispatched commands now logged to `var/log/aios.log`
- **`ai/core/bots.py` — `UpgradeBot`**: new bot handling upgrade/update intents
  (`check updates`, `apply update`, `upgrade-all`, `upgrade <pkg>`). Registered
  in `router.py` before HealthBot and LogBot.
- **`ai/core/intent_engine.py`**: upgrade category with four actions:
  `pkg.check`, `pkg.apply`, `pkg.upgrade-all`, `pkg.upgrade`.
- **`.github/workflows/ci.yml`** — GitHub Actions CI pipeline: shellcheck,
  pytest with coverage (Python 3.10/3.11/3.12), unit-tests, integration-tests.
- Complete documentation suite: CONTRIBUTING.md, CODE_OF_CONDUCT.md,
  SECURITY.md, ROADMAP.md, INSTALL.md.
- OS-level specification documents: BOOT-SEQUENCE.md, SYSCALL-LIST.md,
  PROCESS-MODEL.md, SCHEDULER.md, RESOURCE-MANAGER.md, PERMISSIONS-MODEL.md,
  SERVICE-REGISTRY.md, NETWORKING-MODEL.md.
- Legal documents: TERMS-OF-USE.md, PRIVACY-NOTICE.md, DISCLAIMER.md,
  COPYRIGHT.md, AI-DISCLOSURE.md.
- System configuration templates: services.conf, module-registry.conf,
  api-endpoints.conf, network.conf, system-manifest.conf.
- INSTRUCTION-MANUAL.md — complete operator and developer reference.

### Changed
- `README.md` — full rewrite: What Is AIOS, Requirements table (per platform),
  Installation steps, How to Run (all three methods), Example Session,
  Available Commands table, Architecture diagram, Troubleshooting section,
  Running Tests, Documentation Index.
- `bin/aios` version string updated to `v1.0 (Aurora)`.
- ROADMAP.md Milestone 3 marked complete (✅).
- Test suite expanded to 27 shell + 150 Python unit tests + 87 integration tests
  (264 total).

---

## [1.4.0] — 2026-03-15

### Added
- Dual-shell architecture: `bin/aios` (AI shell) and `bin/aios-sys` (OS shell)
- `bin/aios-heartbeat` daemon for continuous kernel health monitoring
- `OS/lib/aura-bridge/` modules: `detect.mod`, `ios.mod`, `android.mod`,
  `linux.mod`, `mirror.mod`
- `OS/lib/aura-semantic/` — semantic embedding memory subsystem
- `OS/lib/aura-hybrid/` — hybrid recall engine combining context, symbolic,
  and semantic memory
- `OS/lib/aura-policy/` — event-driven policy engine
- `OS/lib/aura-agents/` — background agent framework
- `OS/lib/aura-tasks/` — scheduled task framework
- `OS/lib/aura-mods/` — loadable module system
- `OS/bin/os-httpd` — Python 3 REST / WebSocket server
- `OS/bin/os-netconf` — network configuration tool
- `OS/bin/os-mirror` — device filesystem mirroring
- AIOSCPU native build pipeline (`aioscpu/build/`)

### Changed
- `lib/aura-core.sh` now implements chroot-style OS_ROOT path rewriting
- `OS/lib/filesystem.py` extended with `stat` and `log` methods
- Boot sequence extended to 10 stages with `S60-aura-agents` and
  `S70-aura-tasks`

### Fixed
- `os-sched` stale PID entries no longer cause false-positive crash events
- Log rotation threshold corrected to 1000 lines (was 500)

---

## [1.3.0] — 2026-02-20

### Added
- `ai/core/router.py` — intent-based bot dispatch router
- `ai/core/bots.py` — HealthBot, LogBot, RepairBot
- `ai/core/fuzzy.py` — fuzzy command matching
- `ai/core/intent_engine.py` — natural language intent classification
- `tests/integration-tests.sh` — 87 integration test cases
- `tests/test_python_modules.py` — Python AI Core test suite

### Changed
- `ai/core/ai_backend.py` refactored to use Router with legacy fallback

---

## [1.2.0] — 2026-01-30

### Added
- `OS/bin/os-syscall` — unified system call interface with audit logging
- `OS/bin/os-perms` — capability-based permissions model
- `OS/bin/os-resource` — resource manager (CPU/mem/disk/thermal)
- `OS/bin/os-recover` — five-stage recovery mode
- `OS/bin/os-sched` — priority round-robin scheduler
- `OS/lib/filesystem.py` — OS_ROOT-jailed file I/O
- `OS/etc/perms.d/` — per-principal capability files

### Security
- [security] All file I/O routed through OS_ROOT jail (path traversal prevention)
- [security] `os-perms` capability check added to all kernel operations

---

## [1.1.0] — 2026-01-10

### Added
- `OS/bin/os-bridge` — cross-OS bridge control
- `OS/bin/os-event` — event bus
- `OS/bin/os-service` — service lifecycle management
- `OS/bin/os-kernelctl` — kernel daemon control
- `OS/etc/rc2.d/` — runlevel 2 service scripts
- `aura/` directory with `aura-agent.py`, `aura-config.json`,
  `schema-memory.sql`

---

## [1.0.0] — 2025-12-01

### Added
- Initial release of AIOS-Lite
- `OS/sbin/init` — PID 1 boot init
- `OS/bin/os-shell` — interactive AI shell
- `OS/bin/os-info`, `os-log`, `os-ps`, `os-state`
- Context-window memory system
- Symbolic key-value memory (`mem.set` / `mem.get`)
- LLaMA LLM integration (`ai/llama-integration/`)
- `config/aios.conf`, `config/llama-settings.conf`
- `build/build.sh` — llama.cpp build script
- `tests/unit-tests.sh` — 57 unit tests (17 shell + 40 Python)

---

[Unreleased]: https://github.com/Cbetts1/PROJECT/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/Cbetts1/PROJECT/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Cbetts1/PROJECT/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Cbetts1/PROJECT/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Cbetts1/PROJECT/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Cbetts1/PROJECT/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Cbetts1/PROJECT/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Cbetts1/PROJECT/releases/tag/v1.0.0
