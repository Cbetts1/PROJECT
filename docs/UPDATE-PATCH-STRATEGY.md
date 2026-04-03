# AIOS-Lite Update & Patch Strategy

> © 2026 Chris Betts | AIOS-Lite Official

---

## Table of Contents

1. [Update Cadence](#1-update-cadence)
2. [Patch Workflow](#2-patch-workflow)
3. [Rollback Workflow](#3-rollback-workflow)
4. [Emergency Hotfix Workflow](#4-emergency-hotfix-workflow)
5. [Update Manifest Structure](#5-update-manifest-structure)

---

## 1. Update Cadence

### Release Types

| Release Type | Cadence | Version Bump | Description |
|---|---|---|---|
| **Hotfix** | As needed (P1 only) | `X.Y.Z+1` | Emergency patch for critical bugs or security vulnerabilities |
| **Patch** | Every 2 weeks | `X.Y.Z+1` | Accumulated bug fixes, minor improvements; no new features |
| **Minor** | Every 6–8 weeks | `X.Y+1.0` | New features, non-breaking changes, deprecation announcements |
| **Major** | Every 6–12 months | `X+1.0.0` | Breaking changes, architectural overhaul, new LTS candidate |

### Versioning Scheme

AIOS-Lite follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH[-pre-release][+build]

Examples:
  v1.3.0          ← stable minor release
  v1.3.1          ← patch release
  v2.0.0-rc.1     ← major release candidate 1
  v2.0.0-lts      ← LTS designation tag
```

### Release Calendar

| Month | Expected Activity |
|---|---|
| January, March, May, July, September, November | Minor release (odd-numbered months: 1, 3, 5, 7, 9, 11) |
| February, April, June, August, October, December | Patch release (even-numbered months: 2, 4, 6, 8, 10, 12) |

This is a target, not a hard commitment. Releases may slip or be skipped if the quality bar is not met.

---

## 2. Patch Workflow

```
Feature/fix branch → PR opened → CI passes → Review approved → Merge to dev
                                                                      │
                                                                      ▼
                                                               Release branch created
                                                               (release/X.Y.Z)
                                                                      │
                                                                  Changelog updated
                                                                  Version bumped
                                                                  RC tag created
                                                                      │
                                                               QA / smoke test
                                                                      │
                                                          ┌───────────┴────────────┐
                                                          │ pass                   │ fail
                                                          ▼                        ▼
                                                   Merge to main          Fix on release branch
                                                   Tag vX.Y.Z                   (repeat)
                                                   GitHub Release created
```

### Step-by-Step

1. **Develop** — All work is done on feature/fix branches branched from `dev`.
2. **PR** — Open a pull request targeting `dev`. CI must pass. One maintainer approval required.
3. **Accumulate** — Fixes accumulate in `dev` until a patch is due.
4. **Release branch** — Create `release/X.Y.Z` from `dev`.
5. **Changelog** — Update `docs/CHANGELOG.md`: move unreleased items under the new version header.
6. **Version bump** — Update the version string in `OS/etc/os-release` and any other version files.
7. **RC tag** — Tag `vX.Y.Z-rc.1` and run the full test suite (`bash tests/unit-tests.sh && bash tests/integration-tests.sh`).
8. **QA** — Smoke-test on at least two supported platforms (Termux + Linux).
9. **Merge** — If QA passes, merge `release/X.Y.Z` into `main` via PR.
10. **Tag** — Create the final annotated Git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`.
11. **GitHub Release** — Create a GitHub Release with the changelog for this version.
12. **Announce** — Post release notes in Discussions → `#announcements`.

---

## 3. Rollback Workflow

If a release is found to be defective after publishing:

### Immediate Actions (within 1 hour of discovery)

1. **Assess severity** — determine if this is a P1 (immediate rollback) or lower (monitor + hotfix).
2. **Pin the previous release** — update the GitHub Release for the bad version to add a banner:
   > ⚠️ This release has a known issue. Use vX.Y.Z-1 until a hotfix is available.
3. **File a P1 issue** referencing the release and the regression.

### Repository Rollback (if `main` must be reverted)

```sh
# Identify the last good commit
git log --oneline main

# Revert the merge commit (do NOT force-push main; use a revert commit)
git revert -m 1 <merge-commit-sha>
git push origin main

# Re-tag the previous release as the current recommended version
# (update the GitHub Release UI to mark the previous version as "Latest")
```

> **Important**: Never force-push `main` or any LTS branch. Always use `git revert`.

### LTS Branch Rollback

LTS branches follow the same process. A rollback patch for an LTS branch is versioned as `X.Y.Z+1` on that branch.

---

## 4. Emergency Hotfix Workflow

Hotfixes are used only for P1 Critical issues (data loss, security vulnerabilities, complete boot failure).

```
P1 issue confirmed
       │
       ▼
hotfix/<short-description> branch from main
       │
  Minimal fix committed
  (no unrelated changes)
       │
  CI passes + expedited review (one maintainer or Creator)
       │
       ▼
Merge to main
Tag vX.Y.Z+1
GitHub Release created (mark as hotfix)
       │
       ▼ (if LTS branch is affected)
Cherry-pick fix to lts/vX.Y
Tag vX.Y.Z_lts+1 on that branch
       │
       ▼
Post-incident review filed within 7 days
(what happened, root cause, prevention)
```

### Hotfix PR Checklist

- [ ] Branch name starts with `hotfix/`
- [ ] Fix is minimal and isolated — no unrelated changes
- [ ] Root cause is described in the PR body
- [ ] Affected versions are listed
- [ ] Regression test added
- [ ] CHANGELOG.md updated
- [ ] Security advisory filed if the issue is a vulnerability (before or at release)

---

## 5. Update Manifest Structure

Each release is accompanied by a machine-readable **update manifest** at `OS/etc/update-manifest.json`. This enables future auto-update tooling to verify and apply updates.

### Schema

```json
{
  "manifest_version": 1,
  "project": "AIOS-Lite",
  "version": "X.Y.Z",
  "release_date": "YYYY-MM-DD",
  "release_type": "patch | minor | major | hotfix",
  "lts": false,
  "channel": "stable | experimental",
  "min_upgrade_from": "X.Y.0",
  "checksum_algo": "sha256",
  "artifacts": [
    {
      "name": "aios-lite-X.Y.Z.tar.gz",
      "url": "https://github.com/Cbetts1/PROJECT/releases/download/vX.Y.Z/aios-lite-X.Y.Z.tar.gz",
      "sha256": "<hex-digest>"
    }
  ],
  "changelog_url": "https://github.com/Cbetts1/PROJECT/blob/main/docs/CHANGELOG.md#vXYZ",
  "security_advisory_ids": [],
  "breaking_changes": false,
  "deprecated_features": [],
  "removed_features": [],
  "migration_guide_url": null
}
```

### Field Reference

| Field | Type | Description |
|---|---|---|
| `manifest_version` | integer | Manifest schema version (currently `1`) |
| `project` | string | Always `"AIOS-Lite"` |
| `version` | string | SemVer string of this release |
| `release_date` | string | ISO 8601 date (YYYY-MM-DD) |
| `release_type` | string | One of: `patch`, `minor`, `major`, `hotfix` |
| `lts` | boolean | `true` if this version is an LTS release |
| `channel` | string | `stable` or `experimental` |
| `min_upgrade_from` | string | Oldest version from which a direct upgrade is supported |
| `checksum_algo` | string | Hash algorithm used for artifact checksums |
| `artifacts` | array | Downloadable release artifacts with checksums |
| `changelog_url` | string | Direct link to changelog section for this version |
| `security_advisory_ids` | array | GitHub Security Advisory IDs fixed in this release |
| `breaking_changes` | boolean | Whether this release contains breaking changes |
| `deprecated_features` | array | Feature identifiers deprecated in this release |
| `removed_features` | array | Feature identifiers removed in this release |
| `migration_guide_url` | string or null | URL to migration guide for breaking changes |
