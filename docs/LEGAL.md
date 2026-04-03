# AIOSCPU — Legal Index

> © 2026 Christopher Betts | AIOS-Lite / AIOSCPU Official  
> Author: Christopher Betts  
> AI-Generated Original Content — No Open-Source Template Reproduction

---

## Overview

AIOS-Lite / AIOSCPU is an AI-integrated, portable operating-system framework authored by
**Christopher Betts**. It includes **AURA** (Autonomous Unified Resource Agent), a software
agent capable of reading system data, executing commands, and bridging to connected devices.

**By installing, booting, or otherwise using AIOS-Lite / AIOSCPU in any form, you agree to
all of the legal documents listed below.**

---

## Legal Document Suite

| Document | Purpose |
|---|---|
| [EULA](EULA.md) | End User License Agreement — the binding software license |
| [TERMS_OF_SERVICE](TERMS_OF_SERVICE.md) | Full terms governing use of the Software |
| [PRIVACY_POLICY](PRIVACY_POLICY.md) | How data is (and is not) collected and used |
| [DISCLAIMER](DISCLAIMER.md) | Disclaimer of warranties and limitation of liability |
| [USER_WARNINGS](USER_WARNINGS.md) | Critical safety and security warnings for all users |
| [ACCEPTABLE_USE_POLICY](ACCEPTABLE_USE_POLICY.md) | What uses are and are not permitted |
| [SECURITY](SECURITY.md) | Security policy and responsible disclosure process |
| [../licenses/THIRD_PARTY_LICENSES.md](../licenses/THIRD_PARTY_LICENSES.md) | Third-party dependency licenses |

---

## AURA AI Agent — Privacy & Security Summary

AURA is embedded in AIOSCPU and has the following capabilities:

- **System data access:** AURA can query system information (CPU, memory,
  disk, network interfaces, routing tables) via `aioscpu-sysinfo` and
  `aioscpu-netinfo`.
- **Command execution:** AURA can execute shell commands **only** through
  the `aioscpu-secure-run` wrapper, which enforces a denylist of
  catastrophically dangerous operations and **logs every invocation** to
  `$OS_ROOT/var/log/aioscpu-secure-run.log`.
- **Persistent memory:** AURA stores key/value data in a local file-based
  database at `$OS_ROOT/var/lib/aura/`. This data is stored on your local
  filesystem only and is **not** transmitted externally by default.

### What AURA Cannot Do (by design)

- AURA cannot execute commands without going through `aioscpu-secure-run`.
- AURA cannot execute destructive commands (recursive root deletion, raw
  disk writes, fork bombs — see the denylist in `aioscpu-secure-run`).
- AURA has no outbound network capability by default; a model backend must
  be explicitly configured in `etc/aios.conf`.

---

## User Responsibility Summary

- You are responsible for all actions taken on a system running AIOSCPU.
- You are responsible for securing your installation and reviewing AURA's
  permissions before granting elevated access.
- You are responsible for compliance with all applicable laws in your
  jurisdiction regarding AI agents and automated system access.
- If you configure an external model backend, you are solely responsible
  for the privacy implications of transmitting data to that backend.

Full details: [TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md) and
[USER_WARNINGS.md](USER_WARNINGS.md).

---

## Third-Party Software

AIOSCPU is built on open-source foundations. See
[`licenses/THIRD_PARTY_LICENSES.md`](../licenses/THIRD_PARTY_LICENSES.md)
for a full list of third-party components and their licenses.

---

## Watermark

```
© 2026 Christopher Betts | AIOSCPU Official | AI-Generated Original Content
```

This watermark must be preserved in all permitted distributions of AIOSCPU.

---

## Contact

Project repository: <https://github.com/Cbetts1/PROJECT>
