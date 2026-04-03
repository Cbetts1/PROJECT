# AIOS-Lite — Release Notes

> © 2026 Chris Betts | AIOS-Lite Official | AI-generated, fully legal

---

## Release Notes Template

Use the following template for every release. Copy it, fill in the sections, and post it as the GitHub Release body.

```markdown
# AIOS-Lite v{VERSION} — "{CODENAME}"

**Released:** {DATE}
**Type:** {Major | Minor | Patch | Security Hotfix}

---

## Summary

{One to three sentences describing the theme of this release.}

---

## ⚠️ Breaking Changes

> **Upgrade action required before or during installation.**

- **{Component}:** {What changed, what breaks, and what users must do.}
  - _Before:_ `{old behavior or API}`
  - _After:_ `{new behavior or API}`
  - _Migration:_ Run `{command}` or edit `{file}` as described in
    [`docs/MIGRATION-{OLD}-to-{NEW}.md`](docs/MIGRATION-{OLD}-to-{NEW}.md).

_(Remove this section entirely if there are no breaking changes.)_

---

## ✨ New Features

- **{Feature Name}** — {Short description. Link to docs if applicable.}
- **{Feature Name}** — {Short description.}

---

## 🐛 Bug Fixes

- Fixed {short description of bug} ([#{issue}](https://github.com/Cbetts1/PROJECT/issues/{issue}))
- Fixed {short description of bug}

---

## 🔒 Security

- {CVE or description of security fix, if any. Reference `docs/SECURITY.md`.}

_(Remove this section if there are no security changes.)_

---

## 📦 What's Included

| Package | Size | Format |
|---------|------|--------|
| `aios-lite-v{VERSION}-portable.tar.gz` | ~{X} MB | Portable Shell OS |
| `aioscpu-v{VERSION}-amd64.img.gz` | ~{X} MB | Full Disk Image (x86-64) |
| `aios-lite-v{PREV}-to-v{VERSION}-update.tar.gz` | ~{X} MB | Delta Update |
| `aios-lite-v{VERSION}-source.tar.gz` | ~{X} MB | Source Archive |

---

## 🔑 Checksums (SHA-256)

```
{sha256}  aios-lite-v{VERSION}-portable.tar.gz
{sha256}  aioscpu-v{VERSION}-amd64.img.gz
{sha256}  aios-lite-v{VERSION}-source.tar.gz
```

GPG signature files (`.asc`) are attached to each asset.

---

## ⬆️ Upgrading from v{PREV}

```bash
wget https://github.com/Cbetts1/PROJECT/releases/download/v{VERSION}/\
aios-lite-v{PREV}-to-v{VERSION}-update.tar.gz
sha256sum -c aios-lite-v{PREV}-to-v{VERSION}-update.tar.gz.sha256
tar -xzf aios-lite-v{PREV}-to-v{VERSION}-update.tar.gz
bash aios-lite-v{PREV}-to-v{VERSION}-update/update.sh --aios-home ~/aios-lite
```

---

## 📖 Full Changelog

See [`CHANGELOG.md`](../../CHANGELOG.md) or compare:
https://github.com/Cbetts1/PROJECT/compare/v{PREV}...v{VERSION}

---

## 🙏 Acknowledgements

{Optional: thank contributors, testers, or reporters.}
```

---

## Example: Major Release — v2.0.0

```markdown
# AIOS-Lite v2.0.0 — "AURA Core"

**Released:** 2026-06-01
**Type:** Major

---

## Summary

AIOS-Lite 2.0.0 introduces the AURA Core rewrite with a fully modular AI pipeline,
a new dual-shell architecture (`aios` + `aios-sys`), and first-class Samsung Galaxy
S21 FE optimizations. This release contains breaking changes to the shell API and
configuration format.

---

## ⚠️ Breaking Changes

> **Upgrade action required before installation.**

- **Shell binary renamed:** The main entry point changed from `os-shell` to `aios`.
  - _Before:_ `os-shell`
  - _After:_ `aios`
  - _Migration:_ Update any scripts or aliases that invoke `os-shell`.

- **Configuration format:** `config/aios.conf` now uses `KEY=VALUE` (no spaces around `=`).
  - _Before:_ `LLAMA_THREADS = 4`
  - _After:_ `LLAMA_THREADS=4`
  - _Migration:_ Run `bash migrations/migrate-1.x-to-2.0-config.sh`.

- **Memory schema:** The symbolic memory index moved from `OS/var/mem/` to
  `OS/var/memory/symbolic/`. Existing memory entries will not load until migrated.
  - _Migration:_ Run `bash migrations/migrate-1.x-to-2.0-memory.sh`.

---

## ✨ New Features

- **AURA Core AI Pipeline** — New modular pipeline: `IntentEngine` → `Router` →
  subsystem bots (`HealthBot`, `LogBot`, `RepairBot`). See `docs/ARCHITECTURE.md`.
- **Dual-Shell Mode** — `aios` (AI shell) and `aios-sys` (OS management shell)
  are now separate entry points with distinct permission models.
- **Samsung Galaxy S21 FE Optimization** — CPU affinity pinned to Cortex-A78 big
  cores, thermal ceiling at 68°C, auto-selects 7B (8 GB) or 3B (6 GB) int4 model.
- **Heartbeat Daemon** — `aios-heartbeat` provides background health monitoring
  with auto-restart on model crash.
- **Hybrid Memory Recall** — Three-layer recall: context window + symbolic + semantic.

---

## 🐛 Bug Fixes

- Fixed `os-bridge` hanging indefinitely on ADB device disconnect (#42)
- Fixed `aura-memory.sh` corrupting the index when `mem.set` is called with a
  value containing newlines (#38)
- Fixed `llama-cli` invocation failing when `LLAMA_CPU_AFFINITY` contains a dash (#51)

---

## 🔒 Security

- The OS root jail (`OS_ROOT`) now enforces strict path rewriting in
  `lib/aura-core.sh`, preventing directory traversal via symlink.
- Default `aios` user password requirement added to `install.sh`.

---

## 📦 What's Included

| Package | Size | Format |
|---------|------|--------|
| `aios-lite-v2.0.0-portable.tar.gz` | ~4 MB | Portable Shell OS |
| `aioscpu-v2.0.0-amd64.img.gz` | ~850 MB | Full Disk Image (x86-64) |
| `aios-lite-v1.x-to-v2.0.0-update.tar.gz` | ~3.5 MB | Delta Update |
| `aios-lite-v2.0.0-source.tar.gz` | ~4 MB | Source Archive |

---

## ⬆️ Upgrading from v1.x

See [`docs/MIGRATION-1.x-to-2.0.md`](docs/MIGRATION-1.x-to-2.0.md) for full
step-by-step instructions before running the update script.

---

## 📖 Full Changelog

https://github.com/Cbetts1/PROJECT/compare/v1.5.0...v2.0.0
```

---

## Example: Minor Release — v1.3.0

```markdown
# AIOS-Lite v1.3.0 — "Bridge Expansion"

**Released:** 2026-04-15
**Type:** Minor

---

## Summary

v1.3.0 adds SSH mirror improvements, a new `aura-policy` engine for event-driven
automation, and expanded bot coverage in the AI Core. No breaking changes.

---

## ✨ New Features

- **Policy Engine** — `lib/aura-policy.sh` enables rule-based event automation.
  Define triggers in `OS/etc/aura/policy.conf`. See `docs/AURA-API.md`.
- **SSH Mirror Auto-Reconnect** — `os-mirror mount ssh` now retries lost connections
  up to 5 times before marking the mirror as offline.
- **`LogBot`** — New AI Core bot handles log-query intents (`show logs`, `tail log`).
- **Nightly Update Channel** — Opt in with `UPDATE_CHANNEL=nightly` in `config/aios.conf`.

---

## 🐛 Bug Fixes

- Fixed `os-bridge ios pair` failing silently when `idevicepair` returns code 3 (#60)
- Fixed memory index not persisting after `OS_ROOT` path changes (#63)

---

## 📦 What's Included

| Package | Size | Format |
|---------|------|--------|
| `aios-lite-v1.3.0-portable.tar.gz` | ~3.8 MB | Portable Shell OS |
| `aioscpu-v1.3.0-amd64.img.gz` | ~840 MB | Full Disk Image |
| `aios-lite-v1.2.0-to-v1.3.0-update.tar.gz` | ~0.8 MB | Delta Update |
| `aios-lite-v1.3.0-source.tar.gz` | ~3.8 MB | Source Archive |

---

## ⬆️ Upgrading from v1.2.0

```bash
bash aios-lite-v1.2.0-to-v1.3.0-update/update.sh --aios-home ~/aios-lite
```

No migration scripts required for this release.
```

---

## Example: Patch Release — v1.2.1

```markdown
# AIOS-Lite v1.2.1 — Patch

**Released:** 2026-04-08
**Type:** Patch

---

## Summary

Security and stability patch. Addresses a path-traversal vulnerability in the
OS root jail and two crash fixes in the AI Core router.

---

## 🔒 Security

- **Path traversal fix in `aura-core.sh`** — Symlinks inside `OS_ROOT` could
  previously escape the jail via `../` sequences. Now fully blocked.
  All users on v1.2.0 are advised to update immediately.

---

## 🐛 Bug Fixes

- Fixed `Router.dispatch()` crashing with `AttributeError` when intent confidence
  is below threshold and no fallback bot is registered (#71)
- Fixed `aios-heartbeat` writing duplicate PID entries on rapid restart (#68)

---

## 📦 What's Included

| Package | Size | Format |
|---------|------|--------|
| `aios-lite-v1.2.1-portable.tar.gz` | ~3.7 MB | Portable Shell OS |
| `aios-lite-v1.2.0-to-v1.2.1-update.tar.gz` | ~120 KB | Delta Update |
| `aios-lite-v1.2.1-source.tar.gz` | ~3.7 MB | Source Archive |

---

## ⬆️ Upgrading from v1.2.0

```bash
bash aios-lite-v1.2.0-to-v1.2.1-update/update.sh --aios-home ~/aios-lite
```
```

---

## Communicating Breaking Changes

A breaking change is any change that requires a user action to prevent their existing installation from failing after the update. Always:

1. **Highlight at the top** of the release notes under `⚠️ Breaking Changes` — never bury it.
2. **State the before/after** clearly: what the old behavior was, what the new behavior is.
3. **Provide an exact migration command** or link to a migration guide document.
4. **Label the Git tag** as a major version bump so update tools can warn the user.
5. **Do not ship** a breaking change in a minor or patch release. If a security fix requires a breaking change, bump the major version.

Categories that are always breaking changes in AIOS-Lite:

| Category | Example |
|----------|---------|
| Binary renames or removals | `os-shell` → `aios` |
| Config key renames or format changes | `LLAMA_THREADS = 4` → `LLAMA_THREADS=4` |
| Memory schema changes | Index path moves |
| AI Core API changes | `Router.dispatch()` signature change |
| OS root jail path changes | `OS/var/mem/` → `OS/var/memory/symbolic/` |

## Communicating New Features

New features go in the `✨ New Features` section. Each entry should:

1. **Name the feature** in bold.
2. **Describe it in one sentence** — what it does and why it matters.
3. **Link to documentation** if a new doc page was added (e.g. `docs/AURA-API.md`).
4. **Include a usage example** inline if the feature is a new command.

Example format:

```markdown
- **SSH Mirror Auto-Reconnect** — `os-mirror mount ssh` now retries lost
  connections up to 5 times before marking the mirror as offline.
  Usage: `os-mirror mount ssh user@host --retry 5`
```

---

*See also: [`docs/RELEASE-ENGINEERING.md`](RELEASE-ENGINEERING.md) for artifact structure and distribution, and [`docs/UPDATE-SYSTEM.md`](UPDATE-SYSTEM.md) for the update channel system.*
