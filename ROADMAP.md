# Roadmap

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

This document describes the planned evolution of AIOS-Lite / AIOSCPU.
Features are grouped by milestone. Status markers:

| Symbol | Meaning |
|--------|---------|
| ✅ | Completed |
| 🔄 | In progress |
| 🔲 | Planned |
| 💡 | Proposed / under consideration |

---

## Milestone 1 — Core OS (Complete ✅)

- ✅ PID-1 boot init with runlevel support
- ✅ OS_ROOT filesystem jail
- ✅ Syscall interface (`os-syscall`)
- ✅ Capability-based permissions model
- ✅ Priority round-robin scheduler
- ✅ Resource manager (CPU / mem / disk / thermal)
- ✅ Five-stage recovery mode
- ✅ Service registry and event bus
- ✅ Context-window + symbolic + semantic memory
- ✅ Hybrid recall engine
- ✅ LLaMA LLM integration
- ✅ Cross-OS bridge (iOS, Android, Linux, SSH)
- ✅ Device filesystem mirroring

---

## Milestone 2 — AI Core Hardening (Complete ✅)

- ✅ Intent classification engine
- ✅ Multi-bot dispatch router
- ✅ HealthBot / LogBot / RepairBot
- ✅ Fuzzy command matching
- ✅ Python REST/WebSocket server (`os-httpd`)
- ✅ AURA policy engine
- ✅ Background agent framework
- ✅ Scheduled task framework
- ✅ Loadable module system

---

## Milestone 3 — Stability & Documentation (Current 🔄)

- ✅ CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
- ✅ CHANGELOG.md, ROADMAP.md, INSTALL.md, USAGE.md
- ✅ OS specification documents (boot, syscall, process, scheduler, etc.)
- ✅ Legal documents (terms, privacy, disclaimer, copyright, AI disclosure)
- ✅ System config templates and module registry
- ✅ Complete INSTRUCTION-MANUAL.md
- 🔲 Automated CI pipeline (GitHub Actions)
- 🔲 shellcheck enforcement in CI
- 🔲 pytest enforcement in CI
- 🔲 Coverage reporting

---

## Milestone 4 — AIOSCPU Native Build 🔲

- 🔲 Buildroot-based rootfs with AIOS-Lite pre-installed
- 🔲 GRUB bootloader configuration for x86-64
- 🔲 ARM64 image for Samsung Galaxy S21 FE
- 🔲 Signed OTA update pipeline
- 🔲 Reproducible build verification
- 🔲 ISO image distribution

---

## Milestone 5 — Networking & Remote Services 🔲

- 🔲 WireGuard VPN integration
- 🔲 mDNS/DNS-SD service discovery
- 🔲 AIOS device-to-device peer networking
- 🔲 Remote AIOS shell over WebSocket (TLS)
- 🔲 Bluetooth PAN bridge
- 🔲 Network policy enforcement (firewall rules via `os-netconf`)

---

## Milestone 6 — Plugin & Extension Ecosystem 🔲

- 🔲 Signed plugin manifest and loader
- 🔲 Plugin sandbox (OS_ROOT sub-jail per plugin)
- 🔲 Plugin repository / catalogue
- 🔲 AURA skill extension API
- 🔲 Third-party bot framework (BaseBot subclass loader)
- 🔲 Hot-reload for modules without reboot

---

## Milestone 7 — Multi-User & Security Hardening 🔲

- 🔲 Multi-user principal support (beyond operator/aura/service)
- 🔲 PAM-style authentication integration
- 🔲 Audit log signing (HMAC)
- 🔲 Encrypted memory store (SQLCipher)
- 🔲 SELinux/AppArmor policy generation for AURA
- 🔲 Hardware-backed key storage (Android Keystore integration)

---

## Milestone 8 — User Experience 💡

- 💡 Web-based dashboard (served by `os-httpd`)
- 💡 Mobile companion app
- 💡 Voice command interface (Whisper integration)
- 💡 Graphical terminal emulator for AIOSCPU
- 💡 Plugin marketplace UI

---

## Long-Term Vision 💡

- 💡 AIOS-Lite as a hypervisor guest (KVM/QEMU image)
- 💡 Federated AIOS network (peer discovery, shared memory)
- 💡 AI-driven automated patching and self-upgrade
- 💡 AIOS-certified hardware programme

---

*This roadmap is subject to change. Contributions that advance any milestone
are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).*
