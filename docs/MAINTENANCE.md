# AIOS-Lite Maintenance Model

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [How the OS Is Maintained](#1-how-the-os-is-maintained)
2. [Maintenance Cycles](#2-maintenance-cycles)
3. [Long-Term Support (LTS) Strategy](#3-long-term-support-lts-strategy)
4. [Stable vs. Experimental Branches](#4-stable-vs-experimental-branches)
5. [Maintenance Responsibilities](#5-maintenance-responsibilities)

---

## 1. How the OS Is Maintained

AIOS-Lite is maintained as an **open, community-supported project** with a single creator/owner (@Cbetts1) and a small trusted team of maintainers. Maintenance covers:

- **Correctness** — bug fixes, test coverage, and CI health
- **Security** — vulnerability monitoring, patching, and disclosure (see [SECURITY.md](SECURITY.md))
- **Compatibility** — keeping the project working on Termux/Android, Debian/Ubuntu, macOS, and Raspberry Pi
- **Evolution** — new features and subsystems following the [RFC process](GOVERNANCE.md#3-proposal-process-rfc)
- **Documentation** — keeping docs accurate and complete
- **Dependency hygiene** — reviewing and updating external tools and libraries

All maintenance work is tracked through GitHub Issues and Pull Requests. The [Issue Management guide](ISSUE-MANAGEMENT.md) describes triage, severity, and response expectations in detail.

---

## 2. Maintenance Cycles

### Daily

| Task | Owner |
|---|---|
| Monitor CI/CD status | Maintainer on duty |
| Triage newly filed issues (assign severity label within 24 h for P1/P2) | Maintainer on duty |
| Review and merge small, low-risk PRs | Maintainer on duty |
| Check automated security alerts (Dependabot / GitHub Advisories) | Maintainer on duty |

### Weekly

| Task | Owner |
|---|---|
| Weekly issue backlog review — label, assign, or close stale items | Maintainers |
| Review open PRs not yet actioned | Maintainers |
| Run the full test suite locally against the `main` branch | Maintainer on duty |
| Post a weekly status note in Discussions → `#status` | Maintainer on duty |
| Dependency version check (patch-level updates) | Maintainer (Build/Test) |

### Monthly

| Task | Owner |
|---|---|
| Milestone review — measure progress against roadmap | Creator |
| Release decision — evaluate if a new stable release is due | Creator + Maintainers |
| Rotate "maintainer on duty" roster | Creator |
| Review and close stale issues (no activity ≥ 60 days) | Maintainers |
| Documentation audit — verify accuracy of top-level docs | Maintainer (Docs) |
| Dependency review — evaluate minor/major dependency updates | Maintainer (Build/Test) |
| Security review — review logs, permissions, and known CVEs | Maintainer (AI/AURA) |

### Quarterly

| Task | Owner |
|---|---|
| Roadmap review — adjust 1-year roadmap | Creator |
| LTS evaluation — assess if an LTS branch is needed | Creator |
| Contributor health check — invite inactive maintainers to step down | Creator |
| Announce upcoming deprecations | Creator + Maintainers |

---

## 3. Long-Term Support (LTS) Strategy

### LTS Eligibility

A release qualifies for LTS designation when it meets all of the following:

- Has been stable for at least **3 months** without a critical regression
- Represents a major milestone (major version number bump, e.g., v2.0)
- The Creator designates it as LTS at release time

### LTS Guarantees

| Guarantee | Duration |
|---|---|
| **Critical security patches** | 24 months from LTS designation date |
| **Critical bug fixes** | 18 months from LTS designation date |
| **No breaking changes** | For the full support window |
| **Documentation maintained** | For the full support window |

### LTS vs. Current Stable

| Attribute | Current Stable | LTS |
|---|---|---|
| New features | Yes | No |
| Bug fixes | Yes | Critical only |
| Security patches | Yes | Yes |
| API stability | Best-effort | Guaranteed |
| Support window | Until next release | 18–24 months |

### LTS Branch Naming

LTS branches follow the pattern `lts/vX.Y` (e.g., `lts/v2.0`).

### End-of-Life (EOL)

When an LTS branch reaches the end of its support window:

1. A notice is posted in Discussions and the README at least **60 days** before EOL.
2. The branch is archived (read-only) on GitHub.
3. A migration guide to the current stable or next LTS is published.

---

## 4. Stable vs. Experimental Branches

### Branch Map

```
main              ← Production-ready; protected; requires PR + review
  │
  ├── lts/vX.Y   ← Long-term support snapshots (frozen features)
  │
  ├── release/X.Y ← Release preparation branch (RC testing, changelog)
  │
  ├── dev         ← Integration branch for completed features
  │
  └── feat/<name> ← Individual feature branches (short-lived)
      fix/<name>
      rfc/<name>
      hotfix/<name>
```

### Branch Policies

| Branch | Direct push | Force push | Auto-delete |
|---|---|---|---|
| `main` | ❌ (PR only) | ❌ | No |
| `lts/vX.Y` | ❌ (PR only) | ❌ | No |
| `release/X.Y` | Maintainer+ | ❌ | After merge |
| `dev` | ❌ (PR only) | ❌ | No |
| `feat/*`, `fix/*` | Author | ❌ | After merge |
| `hotfix/*` | Maintainer+ | ❌ | After merge |

### Experimental Features

Features that are not yet stable may be merged behind a **feature flag** using the `AIOS_EXPERIMENTAL` environment variable:

```sh
export AIOS_EXPERIMENTAL=1
```

Experimental features:
- Are documented with an `[EXPERIMENTAL]` header in their help text
- May change or be removed without RFC or deprecation notice
- Are excluded from LTS branches

---

## 5. Maintenance Responsibilities

### Maintainer on Duty (Rotation)

One maintainer is designated "on duty" for a given week. They are responsible for:
- Responding to new P1/P2 issues within 24 hours
- Monitoring CI status
- Merging low-risk, approved PRs
- Posting the weekly status update

The rotation schedule is maintained in Discussions → `#on-call`.

### Domain Ownership

| Domain | Responsibilities |
|---|---|
| **Core OS** | Boot, init, service layer, shell commands |
| **AI / AURA** | Intent engine, router, bots, LLM integration, memory |
| **Bridge** | iOS/Android/Linux bridge modules, mirror filesystem |
| **Build / Test** | CI/CD pipeline, test suite, build scripts, dependencies |
| **Docs** | Documentation accuracy, governance docs, changelogs |

### Unowned Issues

If an issue falls outside a clear domain or no maintainer picks it up within 7 days of triage, the Creator assumes responsibility.

### Maintainer Inactivity

A Maintainer who has not made any contribution (commit, review, comment) for **90 consecutive days** is:
1. Contacted privately by the Creator
2. Given 14 days to respond or re-engage
3. If no response, moved to "Emeritus Maintainer" status (no write access; credited in CONTRIBUTORS.md)
