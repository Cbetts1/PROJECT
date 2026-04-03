# AIOS-Lite — Release Engineering & Distribution Guide

> © 2026 Chris Betts | AIOS-Lite Official | AI-generated, fully legal

---

## Table of Contents

1. [Release Artifact Structure](#1-release-artifact-structure)
2. [Installation Packages](#2-installation-packages)
3. [Distribution Channels](#3-distribution-channels)
4. [Integrity & Verification](#4-integrity--verification)
5. [Packaging Formats & Naming Conventions](#5-packaging-formats--naming-conventions)

---

## 1. Release Artifact Structure

### 1.1 Versioning Scheme

AIOS-Lite follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

| Component | Rule |
|-----------|------|
| `MAJOR` | Incompatible API or boot interface changes |
| `MINOR` | New features, backward-compatible |
| `PATCH` | Bug fixes, security patches, hotfixes |

**Pre-release labels:**

| Label | Meaning |
|-------|---------|
| `alpha` | Early unstable build (e.g. `v1.2.0-alpha.1`) |
| `beta` | Feature-complete, undergoing testing (e.g. `v1.2.0-beta.3`) |
| `rc` | Release candidate (e.g. `v1.2.0-rc.1`) |
| *(none)* | Stable release (e.g. `v1.2.0`) |

### 1.2 Git Tag Rules

```
v{MAJOR}.{MINOR}.{PATCH}[-{label}.{N}]
```

Examples:

```
v1.0.0          # First stable release
v1.1.0-beta.1   # First beta of 1.1
v1.1.0-rc.2     # Second release candidate of 1.1
v1.1.0          # Stable 1.1
v1.1.1          # Patch on 1.1
```

**Tagging commands:**

```bash
# Create and push a signed release tag
git tag -s v1.2.0 -m "AIOS-Lite v1.2.0 - Stable Release"
git push origin v1.2.0
```

### 1.3 Release Folder Structure

Each GitHub Release contains the following directory structure (mirrored inside every package):

```
aios-lite-v{VERSION}-{VARIANT}/
├── bin/                        # Executables (aios, aios-sys, aios-heartbeat)
├── lib/                        # AURA modules (aura-*.sh)
├── ai/                         # AI Core (intent_engine.py, router.py, bots.py)
├── OS/                         # OS root jail skeleton
│   ├── sbin/init
│   ├── bin/
│   ├── lib/
│   ├── etc/
│   └── var/
├── config/                     # Default configuration files
│   ├── aios.conf
│   └── llama-settings.conf
├── docs/                       # Bundled documentation
│   ├── README.md
│   ├── INSTALL.md
│   ├── SECURITY.md
│   └── RELEASE-NOTES.md
├── install.sh                  # Interactive installer
├── LICENSE
└── CHECKSUMS.sha256            # SHA-256 checksums for all files
```

### 1.4 Release Bundle Examples

#### Portable Shell OS (Termux / Linux)

```
aios-lite-v1.2.0-portable.tar.gz
aios-lite-v1.2.0-portable.tar.gz.sha256
aios-lite-v1.2.0-portable.tar.gz.asc
```

#### Full AIOSCPU Disk Image (x86-64)

```
aioscpu-v1.2.0-amd64.img.gz
aioscpu-v1.2.0-amd64.img.gz.sha256
aioscpu-v1.2.0-amd64.img.gz.asc
```

#### Source Archive

```
aios-lite-v1.2.0-source.tar.gz
aios-lite-v1.2.0-source.tar.gz.sha256
```

#### Update Delta Package

```
aios-lite-v1.1.0-to-v1.2.0-update.tar.gz
aios-lite-v1.1.0-to-v1.2.0-update.tar.gz.sha256
```

---

## 2. Installation Packages

### 2.1 Install Package Layout

An install package is a **complete, self-contained distribution** of AIOS-Lite. It includes everything needed for a fresh installation.

```
aios-lite-v{VERSION}-portable/
├── install.sh              # Interactive installer
├── uninstall.sh            # Clean removal script
├── bin/
│   ├── aios                # AI shell
│   ├── aios-sys            # OS management shell
│   └── aios-heartbeat      # Background daemon
├── lib/
│   ├── aura-core.sh
│   ├── aura-memory.sh
│   ├── aura-bridge.sh
│   ├── aura-llm.sh
│   └── aura-policy.sh
├── ai/
│   └── core/
│       ├── intent_engine.py
│       ├── router.py
│       ├── bots.py
│       ├── llama_client.py
│       └── ai_backend.py
├── OS/                     # OS root jail skeleton (empty var/, proc/, mirror/)
├── config/
│   ├── aios.conf
│   └── llama-settings.conf
├── docs/
│   ├── INSTALL.md
│   └── SECURITY.md
├── LICENSE
└── CHECKSUMS.sha256
```

**Install instructions:**

```bash
# 1. Download and verify
wget https://github.com/Cbetts1/PROJECT/releases/download/v1.2.0/aios-lite-v1.2.0-portable.tar.gz
sha256sum -c aios-lite-v1.2.0-portable.tar.gz.sha256

# 2. Extract
tar -xzf aios-lite-v1.2.0-portable.tar.gz
cd aios-lite-v1.2.0-portable

# 3. Run the installer
bash install.sh

# 4. Launch the AI shell
aios
```

### 2.2 Update Package Layout

An update package is a **delta bundle** containing only changed/added files from the previous stable release, plus a migration script.

```
aios-lite-v1.1.0-to-v1.2.0-update/
├── update.sh               # Applies the delta, backs up current install first
├── rollback.sh             # Reverts to prior version using the backup
├── delta/
│   ├── bin/                # Only changed binaries
│   ├── lib/                # Only changed modules
│   └── ai/core/            # Only changed AI Core files
├── migrations/
│   └── migrate-1.1-to-1.2.sh   # Schema / config migrations
├── manifest.json           # Lists every changed file and its checksum
└── CHECKSUMS.sha256
```

**Update instructions:**

```bash
# 1. Download and verify
wget https://github.com/Cbetts1/PROJECT/releases/download/v1.2.0/aios-lite-v1.1.0-to-v1.2.0-update.tar.gz
sha256sum -c aios-lite-v1.1.0-to-v1.2.0-update.tar.gz.sha256

# 2. Extract
tar -xzf aios-lite-v1.1.0-to-v1.2.0-update.tar.gz
cd aios-lite-v1.1.0-to-v1.2.0-update

# 3. Apply the update (creates a backup automatically)
bash update.sh --aios-home /path/to/aios-lite

# 4. Verify the installation
aios --version
```

### 2.3 Repair Package Layout

A repair package restores individual components to their known-good state without a full reinstall. It re-deploys the binary and module tree while preserving user configuration and memory databases.

```
aios-lite-v1.2.0-repair/
├── repair.sh               # Selective repair tool
├── bin/                    # Full copy of all binaries (checksummed)
├── lib/                    # Full copy of all modules
├── ai/core/                # Full copy of all AI Core files
├── config/                 # Default config files (not overwritten if custom)
├── integrity-check.sh      # Reports which files have been modified
└── CHECKSUMS.sha256
```

**Repair instructions:**

```bash
# 1. Check what is broken
bash repair.sh --check --aios-home /path/to/aios-lite

# Output example:
#   [OK]  bin/aios
#   [MODIFIED] lib/aura-core.sh  (checksum mismatch)
#   [MISSING]  ai/core/router.py

# 2. Repair only damaged/missing files (preserves user data)
bash repair.sh --fix --aios-home /path/to/aios-lite

# 3. Full repair (replaces all core files, preserves config/ and OS/var/)
bash repair.sh --full --aios-home /path/to/aios-lite
```

### 2.4 Integrity Verification Steps

Every package ships with a `CHECKSUMS.sha256` file listing SHA-256 hashes for all included files.

```bash
# Verify the downloaded archive
sha256sum -c aios-lite-v1.2.0-portable.tar.gz.sha256

# After extraction, verify all internal files
cd aios-lite-v1.2.0-portable
sha256sum -c CHECKSUMS.sha256
```

GPG signature verification:

```bash
# Import the release signing key (first time only)
gpg --keyserver keyserver.ubuntu.com --recv-keys <RELEASE_KEY_ID>

# Verify the detached signature
gpg --verify aios-lite-v1.2.0-portable.tar.gz.asc aios-lite-v1.2.0-portable.tar.gz
```

Expected output:

```
gpg: Good signature from "Chris Betts <release@aios-lite>"
```

---

## 3. Distribution Channels

### 3.1 GitHub Releases (Primary Channel)

All official releases are published to:

```
https://github.com/Cbetts1/PROJECT/releases
```

**GitHub Release structure:**

```
Release: v1.2.0 — "Codename: AURA 2"
│
├── Release Notes (body)            # Rendered Markdown from RELEASE-NOTES.md
│
├── Assets
│   ├── aios-lite-v1.2.0-portable.tar.gz          # Portable install (Linux/Termux)
│   ├── aios-lite-v1.2.0-portable.tar.gz.sha256   # SHA-256 checksum
│   ├── aios-lite-v1.2.0-portable.tar.gz.asc      # GPG signature
│   ├── aioscpu-v1.2.0-amd64.img.gz               # Full disk image
│   ├── aioscpu-v1.2.0-amd64.img.gz.sha256
│   ├── aioscpu-v1.2.0-amd64.img.gz.asc
│   ├── aios-lite-v1.1.0-to-v1.2.0-update.tar.gz # Delta update
│   ├── aios-lite-v1.1.0-to-v1.2.0-update.tar.gz.sha256
│   ├── aios-lite-v1.2.0-source.tar.gz            # Source archive
│   └── aios-lite-v1.2.0-source.tar.gz.sha256
```

**Recommended GitHub Release workflow:**

```bash
# 1. Finalize version bump in config/aios.conf and etc/aios.conf
# 2. Run full test suite
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# 3. Tag the release
git tag -s v1.2.0 -m "AIOS-Lite v1.2.0 - Stable"
git push origin v1.2.0

# 4. Build artifacts
bash build/build.sh --target release --version 1.2.0

# 5. Generate checksums
sha256sum aios-lite-v1.2.0-*.tar.gz aioscpu-v1.2.0-*.img.gz > CHECKSUMS.sha256

# 6. Sign artifacts
gpg --armor --detach-sign aios-lite-v1.2.0-portable.tar.gz
gpg --armor --detach-sign aioscpu-v1.2.0-amd64.img.gz

# 7. Publish via GitHub CLI
gh release create v1.2.0 \
  --title "AIOS-Lite v1.2.0" \
  --notes-file docs/RELEASE-NOTES.md \
  aios-lite-v1.2.0-portable.tar.gz \
  aios-lite-v1.2.0-portable.tar.gz.sha256 \
  aios-lite-v1.2.0-portable.tar.gz.asc \
  aioscpu-v1.2.0-amd64.img.gz \
  aioscpu-v1.2.0-amd64.img.gz.sha256 \
  aioscpu-v1.2.0-amd64.img.gz.asc \
  aios-lite-v1.2.0-source.tar.gz \
  aios-lite-v1.2.0-source.tar.gz.sha256
```

### 3.2 Optional Mirror Hosting

For redundancy, release artifacts may be mirrored to secondary hosts. Mirror metadata lives at:

```
mirror/
├── releases/
│   └── v1.2.0/
│       ├── aios-lite-v1.2.0-portable.tar.gz
│       ├── aios-lite-v1.2.0-portable.tar.gz.sha256
│       └── ...
└── latest.json      # Pointer to the latest stable version
```

`latest.json` format:

```json
{
  "stable": "1.2.0",
  "beta": "1.3.0-beta.1",
  "nightly": "1.3.0-nightly.20260403",
  "stable_url": "https://github.com/Cbetts1/PROJECT/releases/download/v1.2.0/",
  "updated_at": "2026-04-03T00:00:00Z"
}
```

### 3.3 Optional Package Manager Integration

| Manager | Target Platform | Format |
|---------|----------------|--------|
| `pkg` (Termux) | Android / Termux | `.deb` |
| `apt` | Debian / Ubuntu | `.deb` |
| `brew` | macOS / Linux | Homebrew formula |
| `pacman` | Arch Linux | PKGBUILD |

Example Termux `pkg` installation (future):

```bash
pkg install aios-lite
```

Example Homebrew installation (future):

```bash
brew tap Cbetts1/aios
brew install aios-lite
```

### 3.4 Recommended Distribution Workflow

```
┌─────────────┐     ┌──────────────┐     ┌────────────────────┐
│  git tag    │────▶│  CI / Build  │────▶│  Artifact signing  │
│  v1.2.0     │     │  & Test      │     │  (GPG + SHA-256)   │
└─────────────┘     └──────────────┘     └────────────┬───────┘
                                                       │
                          ┌────────────────────────────┼──────────────────────┐
                          ▼                            ▼                      ▼
                   GitHub Releases            Mirror / CDN             Package Repos
                   (primary)                 (optional)               (optional)
```

---

## 4. Integrity & Verification

### 4.1 Checksum Generation

Generate SHA-256 checksums for all release artifacts:

```bash
# Single file
sha256sum aios-lite-v1.2.0-portable.tar.gz > aios-lite-v1.2.0-portable.tar.gz.sha256

# All release files at once
sha256sum aios-lite-v1.2.0-*.tar.gz aioscpu-v1.2.0-*.img.gz > CHECKSUMS.sha256
```

Verify on the user side:

```bash
sha256sum -c CHECKSUMS.sha256
# Expected output:
# aios-lite-v1.2.0-portable.tar.gz: OK
# aioscpu-v1.2.0-amd64.img.gz: OK
```

### 4.2 GPG Signing

**Key setup (one-time, for maintainers):**

```bash
# Generate a dedicated release signing key
gpg --full-generate-key
# Select: RSA and RSA, 4096-bit, no expiry
# Name: AIOS-Lite Release
# Email: release@aios-lite

# Export the public key for distribution
gpg --armor --export release@aios-lite > aios-lite-release.pub.asc
```

**Sign a release artifact:**

```bash
gpg --armor --detach-sign --default-key release@aios-lite \
    aios-lite-v1.2.0-portable.tar.gz
# Produces: aios-lite-v1.2.0-portable.tar.gz.asc
```

**User verification:**

```bash
# Import the public key (first time)
gpg --import aios-lite-release.pub.asc

# Verify
gpg --verify aios-lite-v1.2.0-portable.tar.gz.asc \
              aios-lite-v1.2.0-portable.tar.gz
```

### 4.3 Authenticity Guidelines

- All stable releases **must** be GPG-signed before publication.
- The release signing key fingerprint is published in the repository `README.md` and on the GitHub Organization verified profile.
- Pre-release builds (alpha, beta, rc) should be SHA-256 checksummed; GPG signing is optional but recommended.
- Nightly builds are checksummed only.
- Never distribute unsigned stable release artifacts.

### 4.4 Recommended Security Practices

| Practice | Action |
|----------|--------|
| Offline signing key | Keep the GPG private key on an air-gapped device or hardware token |
| Key rotation | Rotate the signing key every 2 years or immediately after a suspected compromise |
| Reproducible builds | Follow `docs/REPRODUCIBLE-BUILD.md` to allow independent verification |
| Artifact retention | Keep all release artifacts permanently; never delete or overwrite a published release |
| SHA-256 minimum | Never use MD5 or SHA-1 for release checksums |
| HTTPS only | Only serve artifacts over HTTPS; never plain HTTP |

---

## 5. Packaging Formats & Naming Conventions

### 5.1 Recommended Formats

| Package | Format | Rationale |
|---------|--------|-----------|
| Portable OS (scripts + AI) | `.tar.gz` | Universal; works on all Unix platforms including Termux |
| Full disk image | `.img.gz` | Raw image, gzip-compressed; standard for bootable media |
| Source archive | `.tar.gz` | Reproducible; no binary blobs |
| Delta update | `.tar.gz` | Lightweight; only changed files |
| Windows users (optional) | `.zip` | No tar required |

### 5.2 Naming Convention

```
{project}-v{VERSION}-{VARIANT}.{ext}
```

| Token | Values | Example |
|-------|--------|---------|
| `{project}` | `aios-lite`, `aioscpu` | `aios-lite` |
| `{VERSION}` | Full semver | `1.2.0`, `1.2.0-beta.1` |
| `{VARIANT}` | `portable`, `amd64`, `source`, `repair`, `update` | `portable` |
| `{ext}` | `tar.gz`, `img.gz`, `zip` | `tar.gz` |

**Full examples:**

```
aios-lite-v1.2.0-portable.tar.gz
aios-lite-v1.2.0-portable.tar.gz.sha256
aios-lite-v1.2.0-portable.tar.gz.asc
aioscpu-v1.2.0-amd64.img.gz
aioscpu-v1.2.0-amd64.img.gz.sha256
aioscpu-v1.2.0-amd64.img.gz.asc
aios-lite-v1.2.0-source.tar.gz
aios-lite-v1.2.0-source.tar.gz.sha256
aios-lite-v1.2.0-repair.tar.gz
aios-lite-v1.1.0-to-v1.2.0-update.tar.gz
```

### 5.3 Compatibility Notes

| Format | Android (Termux) | Linux | macOS | Windows |
|--------|:---------:|:-----:|:-----:|:-------:|
| `.tar.gz` | ✅ (`pkg install tar`) | ✅ | ✅ | ⚠️ (WSL or 7-Zip) |
| `.img.gz` | ❌ (not bootable on Android) | ✅ (QEMU) | ✅ (QEMU) | ✅ (QEMU/VirtualBox) |
| `.zip` | ✅ | ✅ | ✅ | ✅ |

---

*See also: [`docs/RELEASE-NOTES.md`](RELEASE-NOTES.md) for release notes templates and [`docs/UPDATE-SYSTEM.md`](UPDATE-SYSTEM.md) for the update channel and rollback system.*
