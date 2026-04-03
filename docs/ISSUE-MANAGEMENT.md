# AIOS-Lite Issue Management

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [Issue Triage System](#1-issue-triage-system)
2. [Severity Levels](#2-severity-levels)
3. [Response Expectations](#3-response-expectations)
4. [Escalation Paths](#4-escalation-paths)
5. [Bug Report Template](#5-bug-report-template)
6. [Feature Request Template](#6-feature-request-template)

---

## 1. Issue Triage System

All new GitHub Issues enter the **Triage** state. The following steps are performed within the SLA window for each severity level:

```
New Issue Filed
      │
      ▼
Maintainer reads and labels:
  ├── severity: critical / major / minor / question / invalid / duplicate
  ├── domain: core / ai-aura / bridge / memory / build / docs
  └── type: bug / feature / enhancement / question / chore
      │
      ▼
Issue Assigned or Acknowledged
      │
      ├── If duplicate → close with reference to original
      ├── If invalid / not reproducible → close with explanation
      ├── If question → answer and close or redirect to Discussions
      └── If actionable → assign milestone + assignee
```

### Labels

| Label | Meaning |
|---|---|
| `severity: critical` | Data loss, crash, security vulnerability, total failure |
| `severity: major` | Significant functionality broken; no workaround |
| `severity: minor` | Limited impact; workaround exists |
| `type: bug` | Defect in existing behaviour |
| `type: feature` | New capability request |
| `type: enhancement` | Improvement to existing capability |
| `type: question` | Usage question (consider redirecting to Discussions) |
| `type: chore` | Maintenance task (docs, refactor, dependency update) |
| `domain: core` | Core OS, shell, init |
| `domain: ai-aura` | AI engine, intent, bots, LLM |
| `domain: bridge` | iOS/Android/Linux bridge |
| `domain: memory` | Memory subsystem |
| `domain: build` | CI/CD, tests, build scripts |
| `domain: docs` | Documentation |
| `status: needs-info` | Waiting for reporter to provide more information |
| `status: in-progress` | Actively being worked on |
| `status: blocked` | Blocked on external dependency or another issue |
| `good first issue` | Suitable for new contributors |
| `help wanted` | Maintainers welcome external contributions |

---

## 2. Severity Levels

### P1 — Critical

**Definition**: The OS cannot boot, a data-loss scenario exists, a security vulnerability is confirmed, or a complete subsystem failure occurs with no workaround.

**Examples**:
- `OS/sbin/init` fails to start on a supported platform
- AI shell crashes immediately on launch
- Privilege escalation vulnerability in `aioscpu-secure-run`
- Bridge mount corrupts mirror filesystem

**Response**: Immediate (see §3). A hotfix release may be issued outside the normal patch cadence.

---

### P2 — Major

**Definition**: A significant feature is broken or unusable, with no practical workaround for most users.

**Examples**:
- iOS bridge cannot pair with any device
- LLM integration fails silently, giving no AI responses
- Semantic memory index becomes corrupted on write
- Test suite fails on a supported platform

**Response**: High priority; targeted for the next patch release.

---

### P3 — Minor

**Definition**: A feature degrades gracefully or a workaround exists; limited user impact.

**Examples**:
- A non-critical shell command returns a slightly wrong status string
- Mirror listing is missing one field
- A documentation example has a typo
- An edge-case crash in a non-critical bot

**Response**: Normal triage; targeted for the next scheduled release.

---

### P4 — Enhancement / Feature

**Definition**: New capability or improvement request; no existing functionality is broken.

**Response**: Evaluated through the RFC process if significant; otherwise assigned to a future milestone.

---

## 3. Response Expectations

| Severity | First Response SLA | Patch / Fix SLA |
|---|---|---|
| **P1 Critical** | 24 hours | 72 hours (hotfix release) |
| **P2 Major** | 48 hours | Next patch release (≤ 2 weeks) |
| **P3 Minor** | 7 days | Next scheduled release (≤ 4 weeks) |
| **P4 Enhancement** | 14 days | Milestone-dependent |

"First response" means a maintainer has read the issue, confirmed receipt, and applied a severity label. It does not mean the fix is complete.

### Stale Issues

- Issues with `status: needs-info` that receive no response from the reporter within **21 days** are closed automatically with a note that they may be re-opened when more information is available.
- Issues with no activity for **60 days** are labelled `stale` and closed after a 7-day notice unless they are `severity: critical` or `severity: major`.

---

## 4. Escalation Paths

```
Reporter → Maintainer (domain owner)
               │
               ▼ (no response within SLA)
          Maintainer on Duty
               │
               ▼ (no response within 2× SLA)
          Creator @Cbetts1
               │
               ▼ (security issues only)
          Private disclosure: open a GitHub Security Advisory
```

### Security Issues

**Do not file security vulnerabilities as public issues.**

Report them via GitHub's private Security Advisory feature:
`https://github.com/Cbetts1/PROJECT/security/advisories/new`

See [SECURITY.md](SECURITY.md) for the full disclosure policy and response timeline.

### Escalation to Creator

If a P1 issue is not acknowledged within 24 hours, any contributor may:
1. Mention `@Cbetts1` directly on the issue
2. Open a new Discussion under `#urgent` referencing the issue number

---

## 5. Bug Report Template

> This template is also located at `.github/ISSUE_TEMPLATE/bug_report.md`.

```markdown
---
name: Bug Report
about: Report a defect in AIOS-Lite
labels: "type: bug, status: triage"
---

## Summary

<!-- One sentence description of the bug -->

## Environment

- **Platform**: <!-- Termux/Android | Debian/Ubuntu | macOS | Raspberry Pi | Other -->
- **AIOS-Lite version**: <!-- run: cat $OS_ROOT/etc/os-release -->
- **Shell**: <!-- bash / zsh / sh / other -->
- **AI backend**: <!-- llama.cpp + model name, or none (rule-based fallback) -->

## Steps to Reproduce

1. 
2. 
3. 

## Expected Behaviour

<!-- What should happen -->

## Actual Behaviour

<!-- What actually happens -->

## Logs / Error Output

```
<!-- Paste relevant log output from $OS_ROOT/var/log/ here -->
```

## Additional Context

<!-- Screenshots, related issues, or any other relevant information -->
```

---

## 6. Feature Request Template

> This template is also located at `.github/ISSUE_TEMPLATE/feature_request.md`.

```markdown
---
name: Feature Request
about: Propose a new capability for AIOS-Lite
labels: "type: feature, status: triage"
---

## Summary

<!-- One sentence description of the proposed feature -->

## Problem / Motivation

<!-- What problem does this solve? Who benefits? -->

## Proposed Solution

<!-- Describe how you imagine this feature working -->

## Alternatives Considered

<!-- What else did you consider? Why is your proposal better? -->

## Scope

- **Domain**: <!-- Core OS | AI/AURA | Bridge | Memory | Build/Test | Docs -->
- **Complexity estimate**: <!-- Small (< 1 day) | Medium (1–3 days) | Large (> 3 days) -->
- **Breaking change?**: <!-- Yes / No -->

## Additional Context

<!-- Links, references, mockups, or any other relevant information -->
```
