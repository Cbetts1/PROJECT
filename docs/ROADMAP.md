# AIOS-Lite Long-Term Roadmap

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [1-Year Roadmap (2026)](#1-1-year-roadmap-2026)
2. [3-Year Vision (2026–2029)](#2-3-year-vision-20262029)
3. [Major Milestones](#3-major-milestones)
4. [Expansion Opportunities](#4-expansion-opportunities)
5. [Risk Mitigation Strategies](#5-risk-mitigation-strategies)

---

## 1. 1-Year Roadmap (2026)

### Q1 (January – March 2026) — Foundation & Stability

| Goal | Description | Status |
|---|---|---|
| **v1.0 Stable release** | First formal stable release; freeze the public API; publish SemVer versioning | 🔄 In progress |
| **CI/CD pipeline** | GitHub Actions: run unit + integration tests on every PR across Termux and Linux runners | 🔄 In progress |
| **Governance framework** | Publish `GOVERNANCE.md`, `MAINTENANCE.md`, `COMMUNITY.md`, `ROADMAP.md` | ✅ Complete |
| **Issue templates** | Bug report + feature request templates in `.github/ISSUE_TEMPLATE/` | ✅ Complete |
| **Security advisory process** | Enable GitHub Security Advisories; update `SECURITY.md` | 🔄 In progress |

### Q2 (April – June 2026) — Core OS Polish

| Goal | Description |
|---|---|
| **Reproducible builds** | Publish `docs/REPRODUCIBLE-BUILD.md`; verify SHA-256 checksums on release artifacts |
| **Installer improvements** | `install.sh` supports Termux, Debian/Ubuntu, Raspberry Pi with auto-detection |
| **Memory subsystem v2** | Improve hybrid recall latency; add index pruning for large memory stores |
| **Bridge stability** | Fix top P2 bridge issues (iOS pairing reliability; ADB reconnect on disconnect) |
| **Log rotation** | Automated log rotation and archival via `aura-tasks` |

### Q3 (July – September 2026) — AI Enhancements

| Goal | Description |
|---|---|
| **Intent engine v2** | Improve classification accuracy; add confidence scoring; expose via API |
| **Pluggable LLM backends** | Support Ollama, OpenAI-compatible endpoints, and llama.cpp (current) |
| **AURA policy engine** | Event-driven rule engine for autonomous OS actions |
| **Semantic memory persistence** | Persist semantic index across reboots without re-embedding |
| **AI shell UX** | Tab completion, command history search, inline help improvements |

### Q4 (October – December 2026) — Platform Expansion

| Goal | Description |
|---|---|
| **v1.1 Minor release** | Aggregate Q2–Q3 features; release notes and migration guide |
| **Docker / container image** | Official `Dockerfile` and image published to GitHub Container Registry |
| **Windows/WSL support** | Document and test AIOS-Lite under Windows Subsystem for Linux |
| **First LTS candidate evaluation** | Assess v1.x stability for LTS designation |
| **Contributor growth** | At least 3 external contributors have merged PRs |

---

## 2. 3-Year Vision (2026–2029)

### 2026 — Stability & Community

Focus: Production-ready v1.x with a solid governance model, reproducible builds, and a growing contributor base.

- Formal v1.0 stable release
- Governance, maintenance, and community frameworks live
- Active CI/CD on all major platforms
- First LTS branch (`lts/v1.x`)

### 2027 — Intelligence & Extensibility

Focus: A modular, extensible AI OS with a plugin ecosystem and significantly improved AI capabilities.

- **Plugin/module system**: Third-party modules loadable at runtime without modifying core files
- **Multi-agent orchestration**: Multiple AURA bots coordinating on complex tasks
- **Fine-tuning integration**: Tooling to fine-tune small LLMs on user-specific data within AIOS
- **Web dashboard**: Optional browser-based dashboard for monitoring OS state, memory, and bridge connections
- **v2.0 major release**: Stable plugin API, potential breaking changes from v1.x with migration guide

### 2028 — Distribution & Ecosystem

Focus: AIOS-Lite becomes a reference platform for AI-native portable OS design.

- **Package repository**: `aios-pkg` package manager for installing community-built modules
- **Cloud sync**: Optional encrypted sync of symbolic and semantic memory across devices
- **Multi-device orchestration**: One AIOS instance can delegate tasks to another via the bridge layer
- **Embedded/IoT targets**: Support for OpenWrt/router firmware and similar constrained platforms
- **First LTS v2.x**: If v2.x is stable, designate an LTS branch

### 2029 — Self-Improving OS

Focus: The OS can model its own state, learn from usage patterns, and suggest or apply optimisations autonomously.

- **Adaptive intent engine**: Learns from per-user command patterns
- **Autonomous maintenance**: AURA detects and repairs broken services without human intervention
- **Federated memory**: Opt-in sharing of anonymised memory embeddings across the community
- **v3.0 milestone**: Evaluate architectural evolution based on 3 years of real-world usage

---

## 3. Major Milestones

| Milestone | Target | Description |
|---|---|---|
| **M1 — v1.0 Stable** | Q1 2026 | First versioned stable release with full test coverage |
| **M2 — LTS v1.x** | Q4 2026 | First long-term support branch; 18-month support window |
| **M3 — Plugin API** | Q2 2027 | Stable, documented module/plugin API |
| **M4 — v2.0** | Q4 2027 | Major release with plugin system, multi-agent support |
| **M5 — Package Repository** | Q2 2028 | `aios-pkg` package manager live |
| **M6 — LTS v2.x** | Q4 2028 | Second LTS branch |
| **M7 — v3.0 Vision** | Q4 2029 | Adaptive, self-maintaining OS |

---

## 4. Expansion Opportunities

### Platform Expansion

| Opportunity | Description | Priority |
|---|---|---|
| **Windows/WSL** | Native WSL2 support documented and CI-tested | High |
| **Raspberry Pi Zero 2 W** | Optimised minimal image for constrained hardware | Medium |
| **OpenWrt/router** | Shell-only image for embedded Linux routers | Low |
| **ChromeOS (Crostini)** | Install guide and compatibility testing | Medium |

### AI / Intelligence Expansion

| Opportunity | Description | Priority |
|---|---|---|
| **Ollama backend** | Use Ollama as an LLM backend alongside llama.cpp | High |
| **OpenAI-compatible API** | Support any OpenAI-compatible endpoint (hosted or local) | High |
| **Voice input** | `whisper.cpp` integration for voice-to-text commands | Medium |
| **Code interpreter** | Sandboxed Python/shell code execution via AURA | Medium |

### Ecosystem Expansion

| Opportunity | Description | Priority |
|---|---|---|
| **Web dashboard** | Browser UI for OS state, memory, and bridge monitoring | Medium |
| **Community module registry** | GitHub-hosted index of third-party AIOS modules | Medium |
| **Cloud memory sync** | Encrypted sync of symbolic/semantic memory via a self-hosted server | Low |
| **Mobile companion app** | React Native app as a front-end for AIOS running on a server | Low |

---

## 5. Risk Mitigation Strategies

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **llama.cpp API breaks** | High | High | Pin llama.cpp version; use abstraction layer; automated update tests |
| **Android ADB / iOS bridge deprecation** | Medium | High | Monitor upstream projects; maintain fallback to SSH-only bridge |
| **Shell portability regression** | Medium | Medium | CI on POSIX sh + bash + zsh; POSIX-strict linting (`shellcheck`) |
| **Performance degradation on low-end hardware** | Medium | Medium | Benchmark on Galaxy S21 FE / Raspberry Pi in CI |
| **Memory index corruption** | Low | High | Atomic writes; checksums on index files; automated repair on startup |

### Project Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Creator unavailability** | Medium | High | Succession plan (see [CONTINUITY.md](CONTINUITY.md)); trained Maintainers |
| **Contributor burnout** | Medium | Medium | Healthy rotation, recognition, and `good first issue` backlog |
| **Scope creep** | High | Medium | RFC process gatekeeps new features; roadmap reviewed quarterly |
| **Dependency abandonment** | Low | Medium | Prefer widely-maintained tools; document fallbacks in `ARCHITECTURE.md` |
| **Security vulnerability in AI output** | Medium | High | Output sandboxing via `aioscpu-secure-run`; denylist review each release |

### Mitigation Playbooks

- **Breaking upstream dependency**: Freeze the dependency version, open a `feat/replace-<dep>` RFC, complete migration before the next minor release.
- **Security vulnerability discovered**: Follow the hotfix workflow in [UPDATE-PATCH-STRATEGY.md](UPDATE-PATCH-STRATEGY.md#4-emergency-hotfix-workflow); file a GitHub Security Advisory before public disclosure.
- **Creator steps back**: Follow the succession plan in [CONTINUITY.md](CONTINUITY.md#3-succession-plan).
