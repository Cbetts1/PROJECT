# AIOS-Lite Compliance Statement

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## 1. Overview

AIOS-Lite is an AI-integrated portable operating system built entirely in
user space (POSIX shell + Python 3).  This document covers:

- Licensing
- Privacy and data handling
- Security assurances and limitations
- Export compliance
- Accessibility statement
- Third-party dependency disclosure

---

## 2. Licensing

### AIOS-Lite Core

AIOS-Lite is released under the **MIT License**.

```
MIT License

Copyright (c) 2026 Chris Betts

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Commercial Licensing

For commercial use, OEM embedding, or closed-source derivative works, contact:
**Chris Betts** via the GitHub repository issue tracker.

### Third-Party Licenses

See `licenses/THIRD_PARTY_LICENSES.md` for the complete list of third-party
components and their licenses.

---

## 3. Privacy and Data Handling

### Data Stored Locally

AIOS-Lite stores the following data on the local device only:

| Data | Location | Purpose |
|------|----------|---------|
| Symbolic memory | `OS/proc/aura/memory/*.mem` | User-defined key-value pairs |
| Semantic memory | `OS/proc/aura/semantic/*.sem` | Similarity-search embeddings |
| Context window | `OS/proc/aura/context/window` | Rolling conversation history |
| System state | `OS/proc/os.state` | Boot time, runlevel, kernel PID |
| System logs | `OS/var/log/*.log` | Operation audit trail |
| API token | `OS/etc/api.token` | Local authentication credential |

### Data NOT Transmitted

By default, AIOS-Lite **does not transmit any data** to external servers.
The AI backend uses either:

1. A **local LLaMA model** (`.gguf` file, fully offline), or
2. A **rule-based mock backend** (fully offline, no network required)

No telemetry, analytics, or crash reporting is sent externally.

### When External Transmission Occurs

External network access occurs **only** when explicitly initiated by the user:

- `os-bridge ios pair` — communicates with a connected iOS device via USB
- `os-bridge android devices` — communicates with an Android device via ADB/USB
- `os-mirror mount ssh <host>` — SSH connection to a user-specified host
- `os-netconf wifi connect` — connects to a user-specified WiFi network
- `POST /api/v1/command` via HTTP — if the HTTP server is enabled by the user

---

## 4. Security Assurances

### What AIOS-Lite Enforces

1. **OS_ROOT filesystem jail** — all file I/O is realpath-checked to stay
   within `OS_ROOT`.  See `OS/lib/filesystem.py`.

2. **Capability-based permissions** — operations require explicit capability
   grants (`OS/etc/perms.d/<principal>.caps`).

3. **System call audit log** — every `os-syscall` invocation is logged to
   `OS/var/log/syscall.log`.

4. **Spawn whitelist** — `os-syscall spawn` only executes binaries from an
   explicit allowlist: `ls cat echo date uptime df ps uname hostname id env`.

5. **API authentication** — the HTTP REST server requires an `X-API-Token`
   header (except the `/api/v1/health` liveness endpoint).

### What AIOS-Lite Does NOT Guarantee

- **Hardware isolation**: AIOS-Lite runs in user space.  The host OS kernel
  enforces actual isolation.  A compromised host OS can access all AIOS data.

- **Cryptographic integrity**: File contents within `OS_ROOT` are not
  integrity-checked or encrypted at rest by default.

- **Network security in untrusted environments**: If the HTTP server
  (`os-httpd`) is exposed on a public network without TLS enabled, traffic
  is unencrypted.  Always use `--tls` in production.

### Vulnerability Disclosure

To report a security vulnerability, open a **private** GitHub Security
Advisory at:
`https://github.com/Cbetts1/PROJECT/security/advisories/new`

---

## 5. Export Compliance

AIOS-Lite contains **cryptographic software** (the TLS implementation in
`os-httpd` uses Python's `ssl` module, which wraps OpenSSL).

Under U.S. Export Administration Regulations (EAR), this software is
classified as **EAR99** (not subject to EAR controls) or falls under
License Exception **TSU** (Technology and Software Unrestricted) for
publicly available cryptographic software.

Redistribution is permitted worldwide except to persons or entities on U.S.
denied parties lists (OFAC SDN List, BIS Entity List, etc.).

---

## 6. AI-Generated Content Disclosure

Portions of AIOS-Lite were generated or assisted by AI tools.
All AI-generated code has been reviewed and is published under the MIT License.
The use of AI assistance does not affect copyright or license status.

---

## 7. Accessibility Statement

AIOS-Lite is a command-line operating system.  It:

- Outputs plain text only (no color codes in core components unless the
  terminal supports them)
- Is fully operable via keyboard / text-to-speech terminal emulators
- Does not require a graphical display

---

## 8. Warranty Disclaimer

AIOS-Lite is provided **"as-is"** without warranty of any kind.  The authors
disclaim all warranties, express or implied, including but not limited to
warranties of merchantability, fitness for a particular purpose, and
non-infringement.

In no event shall the authors be liable for any direct, indirect, incidental,
special, exemplary, or consequential damages arising from use of the software.

---

*Last updated: 2026-04-03*
*Document version: 1.0*
