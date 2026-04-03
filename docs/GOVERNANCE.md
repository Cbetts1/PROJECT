# AIOS-Lite Governance Model

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [Project Roles](#1-project-roles)
2. [Decision-Making Rules](#2-decision-making-rules)
3. [Proposal Process (RFC)](#3-proposal-process-rfc)
4. [Acceptance Criteria](#4-acceptance-criteria)
5. [Deprecation Policy](#5-deprecation-policy)

---

## 1. Project Roles

### Creator / Owner — `@Cbetts1`

- Holds final authority over all architectural and strategic decisions
- Merges or vetoes any pull request
- Owns the release process and version tagging
- Manages GitHub repository settings, branch protections, and access
- Approves new maintainers

### Maintainer

- Trusted contributors granted write access to the repository
- Reviews and merges pull requests within their domain
- Triages issues and labels them appropriately
- Participates in RFC discussions and votes on proposals
- Enforces community guidelines
- Nominated by the Creator; confirmed after a 7-day community review period with no objections

### Contributor

- Any person who opens a pull request, files an issue, or participates in discussions
- Must sign off on the project license (MIT) by submitting a contribution
- Expected to follow the [Community Guidelines](COMMUNITY.md)
- No write access to the repository

### Domain Areas

| Domain | Scope |
|---|---|
| **Core OS** | Shell init, boot, service layers |
| **AI / AURA** | AI core, intent engine, bots, LLM integration |
| **Bridge** | iOS, Android, Linux cross-OS bridge modules |
| **Memory** | Symbolic, semantic, hybrid recall systems |
| **Build / Test** | CI/CD, test suite, build scripts |
| **Docs** | Documentation, governance, roadmap |

Each Maintainer is assigned one or more domains. The Creator may act as a maintainer for any domain at any time.

---

## 2. Decision-Making Rules

### Everyday Changes (No RFC Required)

The following changes may be merged by a Maintainer with a single approving review:

- Bug fixes that do not change the public interface
- Documentation improvements
- Test additions or corrections
- Minor dependency updates (patch-level)
- Minor performance improvements

### Significant Changes (RFC Required)

The following changes require a formal RFC (see §3) before any implementation begins:

- New features or subsystems
- Changes to the public API or shell command interface
- Breaking changes to existing behaviour
- New external dependencies
- Major refactors affecting two or more subsystems
- Changes to governance, release, or maintenance processes

### Voting

| Outcome | Requirement |
|---|---|
| **Consensus** | No objections from Maintainers within the comment window |
| **Lazy consensus** | Used for non-breaking improvements; silence = approval after 3 days |
| **Majority vote** | Used when consensus is not reached; simple majority of active Maintainers |
| **Creator override** | Creator may accept or reject any proposal at any time |

A Maintainer is considered "active" if they have made a repository contribution (commit, review, or issue comment) within the last 90 days.

---

## 3. Proposal Process (RFC)

### Step 1 — Draft

1. Fork the repository and create a branch named `rfc/<short-title>`.
2. Copy `.github/rfc-template.md` to `docs/rfcs/XXXX-short-title.md` using the next available RFC number.
3. Fill in all sections of the template.
4. Open a draft Pull Request with the prefix `[RFC] ` in the title.

### Step 2 — Open for Comment

1. Remove the "draft" status from the PR.
2. Post an announcement in the Discussions → `#proposals` category linking to the PR.
3. The comment period is **14 days** for new features, **7 days** for minor changes.

### Step 3 — Resolution

- **Accepted**: Creator or majority of Maintainers approve → PR merged into `docs/rfcs/` → implementation work may begin.
- **Revised**: Significant objections require the author to revise and restart the comment period.
- **Rejected**: Creator or majority reject → PR closed with a recorded reason.
- **Withdrawn**: Author may withdraw at any time; PR closed with note.

### RFC Template Fields

```markdown
# RFC-XXXX: <Title>

**Status**: Draft | Open | Accepted | Rejected | Withdrawn
**Author**: @username
**Created**: YYYY-MM-DD
**Domain**: Core OS | AI/AURA | Bridge | Memory | Build/Test | Docs

## Summary
One paragraph summary.

## Motivation
Why is this needed? What problem does it solve?

## Proposal
Detailed description of the change.

## Alternatives Considered
What else was considered and why was this approach chosen?

## Drawbacks
Any downsides, risks, or trade-offs?

## Unresolved Questions
What is still uncertain at the time of proposal?
```

---

## 4. Acceptance Criteria

All pull requests must satisfy the following before merge:

| Criterion | Requirement |
|---|---|
| **Tests** | New or changed behaviour is covered by unit or integration tests |
| **Documentation** | Public-facing changes update the relevant docs file |
| **Lint / CI** | All CI checks pass |
| **Review** | At least one approving review from a Maintainer or the Creator |
| **RFC** | A merged RFC exists for significant changes (see §2) |
| **Compatibility** | Breaking changes are noted in the PR description and follow the Deprecation Policy |
| **License** | No copyleft or incompatible license is introduced |

---

## 5. Deprecation Policy

### Principles

- **No silent removal.** Features are never removed without prior notice.
- **Migration path.** A replacement or workaround must be documented before deprecation begins.
- **Minimum notice period.** At least one stable release must include a deprecation warning before removal.

### Deprecation Lifecycle

```
Announced → Deprecated (warning emitted) → Removed
     │               │                         │
  RFC merged     Next minor release         Next major release
                 (minimum 1 cycle)          (minimum 1 LTS cycle)
```

### Deprecation Notice Format

When deprecating a shell command or API function, include a warning in the output:

```
[DEPRECATED] <feature> is deprecated and will be removed in <version>.
Use <replacement> instead. See docs/CHANGELOG.md for details.
```

### Removed Features

Removed features are documented in `docs/CHANGELOG.md` under the heading `### Removed` with a migration guide link.
