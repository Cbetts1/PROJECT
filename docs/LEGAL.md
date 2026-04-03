# AIOSCPU Legal Notice

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOSCPU is an AI-integrated operating system that includes **AURA**
(Autonomous Unified Resource Agent), a software agent capable of reading
system data and executing commands on the host system.

**By using, running, or distributing AIOSCPU you agree to the terms in this
document.**

---

## AURA AI Agent — Privacy & Security Notice

AURA is embedded in AIOSCPU and has the following capabilities:

- **System data access:** AURA can query system information (CPU, memory,
  disk, network interfaces, routing tables) via `aioscpu-sysinfo` and
  `aioscpu-netinfo`.
- **Command execution:** AURA can execute shell commands **only** through
  the `aioscpu-secure-run` wrapper, which enforces a denylist of
  catastrophically dangerous operations and **logs every invocation** to
  `/var/log/aioscpu-secure-run.log`.
- **Persistent memory:** AURA stores key/value data in a local SQLite
  database at `/var/lib/aura/aura-memory.db`. This data is stored on your
  local filesystem only — it is not transmitted externally by default.

### What AURA Cannot Do (by design)

- AURA cannot log in interactively (its account uses `/usr/sbin/nologin`).
- AURA cannot execute commands without going through `aioscpu-secure-run`.
- AURA cannot execute destructive commands (recursive root deletion, raw
  disk writes, fork bombs — see the denylist in `aioscpu-secure-run`).
- AURA has no outbound network capability by default (no model backend
  is configured unless you explicitly set `model_backend` in
  `aura-config.json`).

---

## "As-Is" Disclaimer

AIOSCPU is provided **"as is", without warranty of any kind**, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose, and non-infringement.

In no event shall the authors or copyright holders be liable for any claim,
damages, or other liability, whether in an action of contract, tort, or
otherwise, arising from, out of, or in connection with the software or the
use or other dealings in the software.

---

## User Responsibility

- You are responsible for all actions taken on a system running AIOSCPU.
- You are responsible for securing your installation (changing default
  passwords, reviewing sudoers rules, auditing AURA's permissions).
- You are responsible for compliance with all applicable laws in your
  jurisdiction regarding the use of AI agents and automated system access.
- If you configure AURA with an external model backend (`model_backend`
  in `aura-config.json`), you are solely responsible for the privacy
  implications of transmitting system data to that backend.

---

## Third-Party Software

AIOSCPU is built on open-source foundations. See
[`licenses/THIRD_PARTY_LICENSES.md`](../licenses/THIRD_PARTY_LICENSES.md)
for a full list of third-party components and their licenses.

---

## Watermark

```
© 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
```

This watermark must be preserved in all distributions of AIOSCPU.

---

## Contact

Project repository: <https://github.com/Cbetts1/PROJECT>
