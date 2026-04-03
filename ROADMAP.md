# Roadmap

> © 2026 Christopher Betts | AIOS-Lite

This roadmap describes planned work for AIOS-Lite. Items are prioritised but not time-bound unless stated.

---

## Current Version: v0.2

See [CHANGELOG.md](CHANGELOG.md) for what has been delivered.

---

## v0.3 — Intelligence and Persistence

**Focus: Smarter memory and more accurate intent classification**

- [ ] Persistent SQLite memory backend replacing flat-file symbolic store
- [ ] Improved `IntentEngine` using a lightweight on-device classifier (TF-IDF or ONNX)
- [ ] Context-aware responses: AURA reads recent memory before answering
- [ ] `mem.search` fuzzy command for symbolic memory (not just exact key lookup)
- [ ] Structured event payloads (JSON) in the event bus
- [ ] `aura-tasks` cron-style scheduler (time-based, not just event-based)
- [ ] `os-state diff` — compare current state against a saved snapshot
- [ ] Improved `os-recover` — deeper diagnostics and auto-fix coverage

---

## v0.4 — Interface and API

**Focus: Web UI, hardened REST API, plugin marketplace**

- [ ] Web UI dashboard served by `os-httpd` — service status, memory browser, log viewer
- [ ] REST API hardening: authentication token, rate limiting, JSON schema validation
- [ ] `os-api` command — manage API tokens and inspect active sessions
- [ ] Plugin registry — list, install, and update plugins from a curated index
- [ ] `os-plugin install <name>` command
- [ ] OpenAPI / Swagger spec for the HTTP API
- [ ] WebSocket live event stream from the event bus

---

## v0.5 — Security and Multi-User

**Focus: Encrypted memory, multi-user sessions, audit logging**

- [ ] Encrypted symbolic memory store (AES-256, passphrase-protected)
- [ ] Multi-user session support — separate OS_ROOT contexts per user
- [ ] Fine-grained audit log for all syscall invocations
- [ ] `os-perms audit` — report all permission checks in the last N minutes
- [ ] Secure bridge mode — require explicit per-mount confirmation for bridge operations
- [ ] Signed plugin verification (SHA-256 + creator signature)
- [ ] `os-hardened` mode — disable all network features and bridge by default

---

## v1.0 — Stable Release

**Focus: Production-ready, full AIOSCPU image, complete documentation**

- [ ] All documentation complete and reviewed
- [ ] AIOSCPU x86-64 disk image passing all integration tests in QEMU
- [ ] Reproducible build with published SHA-256 hashes
- [ ] GitHub Actions CI pipeline (lint + unit + integration tests on every push)
- [ ] Stability: zero known crashes in 72-hour soak test on Samsung Galaxy S21 FE
- [ ] Performance: cold boot under 3 seconds on Termux (without LLM)
- [ ] LLM inference under 5 seconds per response on Cortex-A78 with 3B int4 model
- [ ] Official v1.0 GitHub release with binaries and model download instructions

---

## Future Ideas (Unscheduled)

- Voice input / output via on-device TTS and STT
- Remote AIOS-Lite instances controlled from a central hub
- iOS Shortcut integration (trigger AIOS events from iOS Shortcuts)
- Android Tasker integration
- Collaborative memory — share memory keys between devices over SSH
- Plugin: `aura-calendar` — AI reads and writes calendar events
- Plugin: `aura-notes` — structured note-taking with semantic search
- Plugin: `aura-shell-completion` — AI-powered tab completion in any shell
- WASM build target for running AIOS-Lite in a browser

---

*End of Roadmap*

> © 2026 Christopher Betts | AIOS-Lite | https://github.com/Cbetts1/PROJECT
