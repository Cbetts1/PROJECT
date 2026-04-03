# AIOS-Lite Community Guidelines

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [Community Guidelines](#1-community-guidelines)
2. [Communication Channels](#2-communication-channels)
3. [Moderation Rules](#3-moderation-rules)
4. [Onboarding for New Contributors](#4-onboarding-for-new-contributors)

---

## 1. Community Guidelines

AIOS-Lite is a project built in public, and the community around it matters. Everyone who participates — whether filing an issue, submitting code, or just asking a question — is expected to follow these guidelines.

### Be Respectful

- Treat everyone with respect, regardless of experience level, background, or opinion.
- Critique code and ideas, not people.
- Assume good intent in the absence of evidence to the contrary.

### Be Constructive

- When reporting a bug, provide enough information to reproduce it.
- When requesting a feature, explain the *problem* you want solved, not just the solution you have in mind.
- When reviewing code, explain *why* something should change, not just *what* to change.

### Be Clear

- Write in plain language. Non-native English speakers are welcome and should not be penalised for grammar.
- Use code blocks and log excerpts when discussing technical details.
- Keep issues and PRs focused on a single topic.

### Be Patient

- This is a community project. Maintainers volunteer their time.
- If you have not received a response within the SLA window (see [ISSUE-MANAGEMENT.md](ISSUE-MANAGEMENT.md#3-response-expectations)), you may politely follow up once.

### Not Acceptable

The following behaviours will result in immediate moderation action:

- Harassment, intimidation, or personal attacks of any kind
- Discriminatory language or imagery
- Unsolicited commercial promotion or spam
- Sharing private information about others without consent
- Deliberately disruptive behaviour (e.g., repeatedly re-opening closed issues)
- Any behaviour that violates applicable law

---

## 2. Communication Channels

### GitHub — Primary Channel

| Location | Purpose |
|---|---|
| [Issues](https://github.com/Cbetts1/PROJECT/issues) | Bug reports, feature requests |
| [Pull Requests](https://github.com/Cbetts1/PROJECT/pulls) | Code contributions |
| [Discussions](https://github.com/Cbetts1/PROJECT/discussions) | Questions, ideas, announcements, status updates |
| [Security Advisories](https://github.com/Cbetts1/PROJECT/security/advisories) | Private security disclosures |

### GitHub Discussions Categories

| Category | Purpose |
|---|---|
| `#announcements` | Release notes, project news (maintainers only) |
| `#status` | Weekly status updates |
| `#proposals` | RFC announcements and discussion |
| `#help` | Usage questions and troubleshooting |
| `#show-and-tell` | Share what you have built with AIOS-Lite |
| `#on-call` | Maintainer on-duty roster |
| `#urgent` | Escalation for P1 issues not receiving timely response |

### Response Times in Channels

| Channel | Expected response |
|---|---|
| Issues (P1) | 24 hours |
| Issues (P2) | 48 hours |
| Issues (P3/P4) | 7 days |
| Discussions `#help` | Best-effort, typically 1–3 days |

---

## 3. Moderation Rules

### Moderation Authority

The Creator (@Cbetts1) and any designated Maintainer may take moderation actions on GitHub (issues, discussions, PR comments).

### Moderation Actions

| Action | When Used |
|---|---|
| **Edit comment** | Remove personal information or offensive content while preserving context |
| **Hide comment** | Content is off-topic or minimally harmful but not worth deleting |
| **Delete comment** | Clear policy violation; hate speech; doxxing |
| **Lock issue / PR** | Discussion has become unconstructive; topic is closed |
| **Block user** | Repeated or severe violations after warning |

### Warning Process

For most first-time violations:

1. Moderator leaves a comment citing the relevant guideline and asking for a change in behaviour.
2. If the violation continues, the content is hidden or deleted.
3. If the pattern continues, the user is blocked from the repository.

For severe violations (hate speech, doxxing, harassment), immediate action is taken without a prior warning.

### Appeals

A moderated user may appeal by emailing the Creator directly (contact linked in the GitHub profile). Appeals are reviewed within 7 days. The Creator's decision is final.

---

## 4. Onboarding for New Contributors

### Step 1 — Understand the Project

1. Read the [README](../README.md) for a project overview.
2. Read the [Architecture guide](ARCHITECTURE.md) to understand the system structure.
3. Browse recent closed PRs to understand the code review style.

### Step 2 — Set Up Your Environment

```sh
# Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Run the test suite to verify your environment
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
```

### Step 3 — Find Something to Work On

- Browse issues labelled [`good first issue`](https://github.com/Cbetts1/PROJECT/issues?q=is:open+label:%22good+first+issue%22) for beginner-friendly tasks.
- Browse issues labelled [`help wanted`](https://github.com/Cbetts1/PROJECT/issues?q=is:open+label:%22help+wanted%22) for tasks where maintainers welcome external contributions.
- Comment on the issue to let maintainers know you intend to work on it, to avoid duplicate effort.

### Step 4 — Make Your Change

1. Fork the repository and create a branch from `dev`:
   ```sh
   git checkout dev
   git pull origin dev
   git checkout -b fix/my-fix-description
   ```
2. Make your changes following the code style of the surrounding files.
3. Add or update tests as appropriate.
4. Run the test suite locally before opening a PR.

### Step 5 — Open a Pull Request

1. Push your branch to your fork.
2. Open a PR targeting the `dev` branch of the upstream repository.
3. Fill in the PR template (description of change, motivation, testing steps).
4. Ensure CI passes.
5. Wait for a maintainer review. Respond to feedback promptly and respectfully.

### Step 6 — After Your PR is Merged

- Your contribution is credited in the commit history and, for significant contributions, in `CONTRIBUTORS.md`.
- Welcome to the AIOS-Lite contributor community!

### Contributor Resources

| Resource | Location |
|---|---|
| Architecture overview | `docs/ARCHITECTURE.md` |
| API reference | `docs/API-REFERENCE.md` |
| Security model | `docs/SECURITY.md` |
| Governance & roles | `docs/GOVERNANCE.md` |
| Maintenance model | `docs/MAINTENANCE.md` |
| Issue management | `docs/ISSUE-MANAGEMENT.md` |
| Patch strategy | `docs/UPDATE-PATCH-STRATEGY.md` |
| Roadmap | `docs/ROADMAP.md` |
