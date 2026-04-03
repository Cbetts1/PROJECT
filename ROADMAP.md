# Roadmap

> **AIOS-Lite / AIOSCPU** — development roadmap

This document describes what has been achieved in v1.0.0 and where the project
is heading next.  All milestones are aspirational; timelines may shift.

---

## Current Release — v1.0.0 "Aurora" (2026-Q1)

Everything listed below is **complete and shipped**:

- Pseudo-kernel (syscall gate, scheduler, permissions, resource manager, recovery)
- Full boot sequence with `rc2.d` runlevel chain
- Capability-based security model + syscall audit log
- AI Core: intent engine → router → bots (Health / Log / Repair)
- LLaMA LLM integration with rule-based fallback
- Three-layer memory: context window + symbolic + semantic + hybrid recall
- Cross-OS bridge: iOS (libimobiledevice), Android (ADB), Linux/SSH
- Filesystem mirroring into `OS/mirror/`
- HTTP REST + WebSocket server (`os-httpd`) with TLS, token auth, SSE
- Full networking stack (`os-netconf`): WiFi, BT, IP, routing, DNS, firewall, NAT
- AIOSCPU reproducible disk image (Debian x86-64, GRUB, systemd)
- AURA systemd service with `ProtectSystem=strict` sandboxing
- 144-test suite (57 unit + 87 integration)
- Complete documentation suite (architecture, kernel, API, security, compliance)

---

## Short-Term — v1.1.0 "Beacon" (2026-Q2)

| # | Goal | Notes |
|---|------|-------|
| 1 | **Plugin API** — formal `aura-mods/` plugin loader | Allow third-party bots and services to register without patching core |
| 2 | **Web UI dashboard** — minimal browser UI served by `os-httpd` | Read-only status, log viewer, service toggle |
| 3 | **Persistent AURA memory search** — SQLite FTS5 full-text search | Replace linear scan in `sem.search` with indexed FTS |
| 4 | **Improved fuzzy command matching** — Levenshtein-based ranking | Reduce false-positive intent classification |
| 5 | **Android Termux one-liner installer** | Single `curl | sh` bootstrap for mobile |
| 6 | **ARM64 AIOSCPU image variant** | Raspberry Pi 4/5 and Apple Silicon QEMU targets |
| 7 | **Signed releases** — GPG-signed tarballs and checksums | Supply-chain security baseline |
| 8 | **CI/CD pipeline** — GitHub Actions build + test on every push | Automated unit + integration tests on Linux runners |

---

## Medium-Term — v1.2.0 "Beacon" (2026-Q3)

| # | Goal | Notes |
|---|------|-------|
| 1 | **Multi-user support** — per-user capability profiles | `operator`, `guest`, `developer` roles |
| 2 | **Encrypted at-rest memory** — AES-256 SQLite storage | Protect AURA memory database |
| 3 | **LLM hot-swap** — change model without restart | Reload model path from config at runtime |
| 4 | **Embedded vector store** — local semantic embeddings without a server | Replace file-based `sem.*` with a proper embedding index |
| 5 | **Remote OS bridge hardening** — mutual SSH key verification, audit trails | Prevent MITM on SSH mirrors |
| 6 | **Container-isolated AURA** — LXC or podman sandbox | Stronger isolation than systemd alone |
| 7 | **Package manager** — install / remove AIOS extensions | `aios-pkg install <module>` |
| 8 | **Structured log format** — JSON log lines | Machine-parseable logs for external observability |

---

## Long-Term — v2.0.0 "Meridian" (2026-Q4 / 2027)

| # | Goal | Notes |
|---|------|-------|
| 1 | **Multi-device mesh** — AURA agents coordinating across devices | Distributed context sharing over local network |
| 2 | **Voice interface** — speech-to-text input for `os-shell` | On-device STT (Whisper.cpp integration) |
| 3 | **Model fine-tuning pipeline** — personalise the on-device LLM | LoRA adapter training on user interaction logs |
| 4 | **Graphical shell** — minimal TUI or web-based OS shell | For users who prefer a visual interface |
| 5 | **Mobile OS companion app** — Android app that wraps the bridge layer | No ADB / Termux required |
| 6 | **Trusted execution environment** — hardware-backed key storage | TPM / Secure Enclave integration |
| 7 | **Federated memory** — optional encrypted memory sync across devices | User-controlled cloud or self-hosted relay |
| 8 | **Certification** — explore FIPS 140-3 compliance path for enterprise | Relevant if deployed in regulated environments |

---

## Backlog / Ideas

- Windows host bridge (WSL2 compatibility layer)
- Real-time collaborative shell sessions (tmux-style multi-user)
- Hardware abstraction layer for IoT sensors (GPIO, I²C, SPI)
- Automated security hardening wizard (`aios-harden`)
- Differential OS image updates (delta patching for AIOSCPU images)

---

## Contributing

If you want to work on any of these goals, open an issue on GitHub to discuss
scope and approach before submitting a pull request.

---

*Last updated: 2026-04-03*
