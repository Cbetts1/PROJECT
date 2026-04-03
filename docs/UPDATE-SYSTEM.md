# AIOS-Lite — Update System

> © 2026 Chris Betts | AIOS-Lite Official | AI-generated, fully legal

---

## Table of Contents

1. [Update Channels](#1-update-channels)
2. [Update Workflow](#2-update-workflow)
3. [Rollback Workflow](#3-rollback-workflow)
4. [Update Manifest Format](#4-update-manifest-format)

---

## 1. Update Channels

AIOS-Lite maintains three update channels. Users opt in by setting
`UPDATE_CHANNEL` in `config/aios.conf`.

| Channel | `UPDATE_CHANNEL` value | Stability | Update Frequency | Audience |
|---------|----------------------|-----------|-----------------|----------|
| **Stable** | `stable` *(default)* | Production-ready | On versioned release | All users |
| **Beta** | `beta` | Feature-complete, testing | Weekly or per RC tag | Early adopters, testers |
| **Nightly** | `nightly` | Bleeding edge, may break | Daily automated builds | Developers only |

**Configure your channel:**

```bash
# In config/aios.conf
UPDATE_CHANNEL=stable     # or: beta, nightly
```

### Channel Feed URLs

```
Stable:   https://github.com/Cbetts1/PROJECT/releases/latest.json
Beta:     https://github.com/Cbetts1/PROJECT/releases/beta.json
Nightly:  https://github.com/Cbetts1/PROJECT/releases/nightly.json
```

*(These point to the `mirror/releases/latest.json` structure defined in
`docs/RELEASE-ENGINEERING.md`.)*

### Channel Promotion Path

```
  Developer commit
        │
        ▼
   Nightly build  ──────────────────────┐
   (automated, daily)                   │ if stable after ~1 week
        │                               ▼
        ▼                          Beta release
   Integration tests               (tagged RC)
        │                               │
        │                               │ if stable after ~2 weeks
        │                               ▼
        └──────────────────────▶  Stable release
                                   (tagged vX.Y.Z)
```

---

## 2. Update Workflow

### 2.1 Checking for Updates

```bash
# Check using the built-in update tool
aios update check

# Manual check — compares installed version against channel feed
CURRENT=$(aios --version)
LATEST=$(curl -sf https://github.com/Cbetts1/PROJECT/releases/latest.json | \
         python3 -c "import sys,json; print(json.load(sys.stdin)['stable'])")
echo "Installed: $CURRENT | Latest: $LATEST"
```

### 2.2 Full Update (All Files)

A full update replaces all core files while preserving user data and configuration.
It is equivalent to reinstalling the current version over the top.

```bash
# Step 1 — Download the full install package for the target version
wget https://github.com/Cbetts1/PROJECT/releases/download/v1.3.0/\
aios-lite-v1.3.0-portable.tar.gz

# Step 2 — Verify integrity
sha256sum -c aios-lite-v1.3.0-portable.tar.gz.sha256
gpg --verify aios-lite-v1.3.0-portable.tar.gz.asc \
             aios-lite-v1.3.0-portable.tar.gz

# Step 3 — Extract and run the installer in update mode
tar -xzf aios-lite-v1.3.0-portable.tar.gz
bash aios-lite-v1.3.0-portable/install.sh --update --aios-home ~/aios-lite

# Step 4 — Verify the result
aios --version
AIOS_HOME=~/aios-lite OS_ROOT=~/aios-lite/OS bash tests/unit-tests.sh
```

### 2.3 Delta Update (Changed Files Only)

A delta update applies only the files that changed between two versions.
It is faster and smaller than a full update.

```bash
# Step 1 — Download the delta package
wget https://github.com/Cbetts1/PROJECT/releases/download/v1.3.0/\
aios-lite-v1.2.0-to-v1.3.0-update.tar.gz

# Step 2 — Verify integrity
sha256sum -c aios-lite-v1.2.0-to-v1.3.0-update.tar.gz.sha256

# Step 3 — Extract
tar -xzf aios-lite-v1.2.0-to-v1.3.0-update.tar.gz
cd aios-lite-v1.2.0-to-v1.3.0-update

# Step 4 — Apply the update
# The update script automatically backs up the existing installation to
# ~/aios-lite/.backup/v1.2.0/ before making any changes.
bash update.sh --aios-home ~/aios-lite

# Step 5 — Run any required migration scripts
bash migrations/migrate-1.2-to-1.3.sh --aios-home ~/aios-lite

# Step 6 — Verify
aios --version
AIOS_HOME=~/aios-lite OS_ROOT=~/aios-lite/OS bash tests/unit-tests.sh
```

### 2.4 Automated Update (aios update)

When `UPDATE_CHANNEL` is configured, the `aios update` command handles
the full workflow:

```bash
# Check without applying
aios update check

# Download the latest update for your channel
aios update download

# Apply (backs up first, then patches, then verifies)
aios update apply

# One-step check + apply
aios update install
```

Automated updates always:
- Create a backup before applying changes.
- Verify checksums before and after patching.
- Run the unit test suite after applying.
- Abort and restore from backup if any step fails.

---

## 3. Rollback Workflow

### 3.1 Automatic Rollback

If `aios update apply` fails (checksum mismatch, test failure, or aborted
mid-patch), it automatically restores the previous version from the backup:

```
[AIOS Update] Applying v1.2.0 → v1.3.0 ...
[AIOS Update] Backing up to ~/.aios-lite/.backup/v1.2.0/ ...
[AIOS Update] Patching files ...
[AIOS Update] Running unit tests ...
[AIOS Update] ✗ Unit tests failed (exit 1). Rolling back ...
[AIOS Update] Restored from backup. Version is still v1.2.0.
```

### 3.2 Manual Rollback

If you need to manually revert to a previous version:

```bash
# Option A — Restore from the automatic backup
bash ~/aios-lite/.backup/v1.2.0/rollback.sh --aios-home ~/aios-lite

# Option B — Re-install the previous full package
wget https://github.com/Cbetts1/PROJECT/releases/download/v1.2.0/\
aios-lite-v1.2.0-portable.tar.gz
sha256sum -c aios-lite-v1.2.0-portable.tar.gz.sha256
tar -xzf aios-lite-v1.2.0-portable.tar.gz
bash aios-lite-v1.2.0-portable/install.sh --update --aios-home ~/aios-lite

# Option C — Use the rollback.sh from the update package
bash aios-lite-v1.2.0-to-v1.3.0-update/rollback.sh --aios-home ~/aios-lite
```

### 3.3 Rollback Limitations

| Scenario | Rollback possible? | Notes |
|----------|--------------------|-------|
| Binary/module changes | ✅ Yes | Files restored from backup |
| Config file changes | ✅ Yes | Config backed up before migration |
| Memory schema migration | ⚠️ Partial | Old schema files restored; data added after migration may be lost |
| AIOSCPU disk image | ✅ Yes | Re-flash previous `.img.gz`; no in-place rollback |

For disk image rollbacks:
```bash
# Re-flash the previous image (destructive — overwrites disk data)
gunzip -c aioscpu-v1.2.0-amd64.img.gz | \
  sudo dd of=/dev/sdX bs=4M status=progress
```

---

## 4. Update Manifest Format

Every delta update package includes a `manifest.json` that describes exactly
what changed. The update script reads this file to apply only the necessary
changes and to verify file integrity.

### 4.1 Schema

```json
{
  "schema_version": "1",
  "from_version": "1.2.0",
  "to_version": "1.3.0",
  "channel": "stable",
  "released_at": "2026-04-15T12:00:00Z",
  "requires_migration": true,
  "migration_scripts": [
    "migrations/migrate-1.2-to-1.3.sh"
  ],
  "breaking_changes": false,
  "files": [
    {
      "action": "add",
      "path": "lib/aura-policy.sh",
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "size_bytes": 4096,
      "executable": true
    },
    {
      "action": "modify",
      "path": "ai/core/router.py",
      "sha256": "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      "size_bytes": 8192,
      "executable": false
    },
    {
      "action": "modify",
      "path": "bin/aios",
      "sha256": "2c624232cdd221771294dfbb310acbc7c17f5968e703a12bff9e3e494a7c7a56",
      "size_bytes": 12288,
      "executable": true
    },
    {
      "action": "delete",
      "path": "lib/aura-legacy-compat.sh",
      "sha256": null,
      "size_bytes": null,
      "executable": null
    }
  ],
  "config_changes": [
    {
      "file": "config/aios.conf",
      "key": "UPDATE_CHANNEL",
      "action": "add",
      "default": "stable",
      "notes": "New in v1.3.0 — set to stable, beta, or nightly"
    }
  ],
  "checksums": {
    "manifest": "b94d27b9934d3e08a52e52d7da7dabfac484efe04294e576f5e9ba2782f68b38"
  }
}
```

### 4.2 Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | string | Manifest format version (currently `"1"`) |
| `from_version` | string | Source version this delta applies to |
| `to_version` | string | Target version after applying this delta |
| `channel` | string | `stable`, `beta`, or `nightly` |
| `released_at` | ISO 8601 | Publication timestamp |
| `requires_migration` | bool | If `true`, run `migration_scripts` after patching |
| `migration_scripts` | array | Paths to migration scripts, run in order |
| `breaking_changes` | bool | If `true`, the update script warns and requires `--accept-breaking` flag |
| `files[].action` | string | `add`, `modify`, or `delete` |
| `files[].path` | string | Relative path from `AIOS_HOME` |
| `files[].sha256` | string | Expected SHA-256 of the file after the action (null for delete) |
| `files[].executable` | bool | Whether to `chmod +x` after placing the file |
| `config_changes` | array | New, changed, or removed config keys (informational) |
| `checksums.manifest` | string | SHA-256 of the manifest file itself (for tamper detection) |

### 4.3 Example: Nightly Manifest Stub

Nightly manifests follow the same schema but use a date-based `to_version`:

```json
{
  "schema_version": "1",
  "from_version": "1.3.0",
  "to_version": "1.3.0-nightly.20260403",
  "channel": "nightly",
  "released_at": "2026-04-03T03:00:00Z",
  "requires_migration": false,
  "migration_scripts": [],
  "breaking_changes": false,
  "files": [
    {
      "action": "modify",
      "path": "ai/core/intent_engine.py",
      "sha256": "...",
      "size_bytes": 5120,
      "executable": false
    }
  ],
  "config_changes": [],
  "checksums": {
    "manifest": "..."
  }
}
```

---

*See also: [`docs/RELEASE-ENGINEERING.md`](RELEASE-ENGINEERING.md) for artifact structure, distribution channels, and integrity verification.*
