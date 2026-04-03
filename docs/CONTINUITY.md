# AIOS-Lite Sustainability & Continuity Plan

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [Backup Strategy](#1-backup-strategy)
2. [Archival Strategy](#2-archival-strategy)
3. [Succession Plan](#3-succession-plan)
4. [Project Continuity Rules](#4-project-continuity-rules)

---

## 1. Backup Strategy

### What Must Be Backed Up

| Asset | Location | Criticality |
|---|---|---|
| Source code | GitHub repository | Critical — primary source of truth |
| GitHub Issues and Discussions | GitHub API | High — project knowledge base |
| Release artifacts (tarballs, checksums) | GitHub Releases | High — distribution |
| LLM model weights | `llama_model/` (user-managed) | Medium — user-provided |
| OS runtime state (per deployment) | `OS/var/`, `OS/proc/` | Low — ephemeral by design |

### Repository Backup

- GitHub stores the canonical repository. Two independent mirrors are maintained to protect against platform outages:

  1. **Mirror A (automated)**: A GitHub Action runs weekly to push a full mirror to a secondary Git hosting service (self-hosted Gitea or Codeberg). Mirror is pushed using `git push --mirror`.
  2. **Mirror B (manual)**: The Creator maintains a local bare clone on a personal machine, updated monthly.

- The mirror workflow configuration lives at `.github/workflows/mirror.yml` (to be created alongside the CI pipeline).

### Release Artifact Backup

- All GitHub Release artifacts are archived in a project-controlled S3-compatible object store within 24 hours of release, using the `rclone` tool.
- Checksums (`sha256`) are stored alongside artifacts in a `checksums.txt` file in the release.
- Release artifacts are retained indefinitely (no TTL/expiry).

### Runtime Data (Per Deployment)

End-user deployments of AIOS-Lite should back up the following directories if they wish to preserve AI memory and OS state:

```
$OS_ROOT/
├── var/log/        ← system logs
├── etc/aura/       ← AURA configuration and memory indexes
└── llama_model/    ← LLM model weights (user-supplied)
```

Recommended approach: `tar -czf aios-backup-$(date +%Y%m%d).tar.gz $OS_ROOT/var $OS_ROOT/etc/aura`

---

## 2. Archival Strategy

### When a Project Is Archived

AIOS-Lite or any of its sub-components are archived when:

- The project is superseded by a new major version with no maintained upgrade path
- A branch reaches end-of-life (see [MAINTENANCE.md § LTS Strategy](MAINTENANCE.md#3-long-term-support-lts-strategy))
- The project is intentionally discontinued (see §3 and §4 below)

### Archive Process

1. A notice is published in `README.md` and Discussions → `#announcements` at least **60 days** before archival.
2. The final release is tagged and a GitHub Release is created with an archive notice.
3. `docs/CHANGELOG.md` is updated to mark the last supported version.
4. The GitHub repository is set to **Archived** (read-only) using the repository settings.
5. The repository remains publicly readable indefinitely.
6. If a migration path exists, it is documented in `docs/MIGRATION.md`.

### Long-Term Artifact Retention

- Release tarballs are submitted to the [Software Heritage](https://www.softwareheritage.org/) archival service, which crawls public GitHub repositories.
- For critical releases, the Creator may also submit to Zenodo (DOI-backed archival for open-source software).

### Branch End-of-Life Archival

When an LTS branch reaches EOL:

1. A final patch release is made with an EOL notice in the changelog.
2. The branch is set to read-only via GitHub branch protection (no new commits allowed).
3. The branch is listed as EOL in `README.md`.

---

## 3. Succession Plan

This plan applies if the Creator (@Cbetts1) is permanently or indefinitely unavailable to maintain the project.

### Triggers

The succession plan is activated when any of the following occur:

- The Creator explicitly announces they are stepping back
- The Creator is unreachable for **90 consecutive days** despite documented attempts to contact them
- The Creator designates a successor in writing (GitHub Discussion, email, or PR to this document)

### Lead Maintainer Appointment

1. The most senior active Maintainer (measured by longest continuous maintainer tenure) becomes **Lead Maintainer**.
2. If there is a tie, the active Maintainers vote; majority wins.
3. If no Maintainers are active, the most prolific external contributor (by merged PRs) is invited to assume the Lead Maintainer role.

### Transfer of Assets

The Lead Maintainer assumes responsibility for:

| Asset | Transfer Action |
|---|---|
| GitHub repository | Creator transfers ownership to Lead Maintainer's account or a shared organisation |
| GitHub Releases | Already public; no action required |
| Repository mirrors | Mirror secrets/tokens transferred via GitHub Actions environment |
| Release signing keys | Creator provides in a sealed document opened at succession (physical or password-manager share) |
| Domain names (if any) | Transferred to Lead Maintainer |

### Continuity During Transition

- All in-flight PRs and issues continue under normal governance rules.
- The first action of the Lead Maintainer is to post a Discussions `#announcements` note explaining the transition.
- The Lead Maintainer may invite new Maintainers without the usual 7-day review period during the first 30 days of succession, to ensure coverage.

### Emeritus Creator

If the Creator steps back voluntarily and remains reachable:

- They are listed as **Emeritus Creator** in `CONTRIBUTORS.md`.
- They retain read access to all private repository features.
- They may choose to return to an active role at any time; the Lead Maintainer and community are notified.

---

## 4. Project Continuity Rules

These rules ensure that AIOS-Lite remains functional, accessible, and governable regardless of personnel changes.

### Repository Governance

1. **No single point of failure**: At all times, at least **two** GitHub users have write access to the repository (Creator + at least one Maintainer).
2. **Branch protection is always on**: `main` and all `lts/*` branches always have branch protection rules enabled.
3. **Governance docs are versioned**: All changes to `GOVERNANCE.md`, `MAINTENANCE.md`, and `CONTINUITY.md` require a PR with at least one review.

### Release Continuity

4. **Releases are always tagged**: No release is shipped without an annotated Git tag and a GitHub Release object.
5. **Changelogs are always current**: `docs/CHANGELOG.md` is updated in every release PR; it is never skipped.
6. **Artifacts are checksummed**: Every release artifact has a `sha256` checksum published in the release.

### Documentation Continuity

7. **README is always accurate**: The README is updated in the same PR as any feature change that affects the Quick Start or Shell Commands sections.
8. **Broken docs are treated as bugs**: A documentation inaccuracy that causes a user to be unable to use a feature is treated as a P3 bug.

### Community Continuity

9. **Issues are never mass-deleted**: Even if a maintainer disagrees with an issue's content, issues are closed with a reason, never deleted (except for spam/abuse).
10. **Discussions remain open**: The Discussions forum is never closed while the project is active.
11. **Conduct is enforced consistently**: Moderation decisions follow the documented rules in `COMMUNITY.md`; no user is banned without a documented reason.

### Financial Continuity

12. AIOS-Lite is a free, open-source project with no paid tier or subscription. There is no financial continuity risk from a business perspective.
13. If any hosting costs arise (e.g., mirror servers, CI runners), they are documented transparently and the community is informed.
