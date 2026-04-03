# Permissions Model — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOS-Lite uses a **capability-based security model**. Every cross-kernel
operation is gated by a capability check via `OS/bin/os-perms`. Access is
granted if the calling principal possesses the required capability.

This model is distinct from UNIX user IDs — AIOS principals are logical
roles, not OS users.

---

## Core Concepts

| Term | Definition |
|------|-----------|
| **Principal** | A named actor (role) in the system: `operator`, `aura`, `service` |
| **Capability** | A namespaced permission token: e.g. `fs.read`, `proc.kill` |
| **Capability file** | `OS/etc/perms.d/<principal>.caps` — one capability per line |
| **Wildcard** | `fs.*` grants all capabilities in the `fs` namespace |
| **Deny** | A line starting with `!` explicitly denies a capability |

---

## Principals

### operator

The interactive human user. Has full capabilities by default.

**File:** `OS/etc/perms.d/operator.caps`

```
*.*
```

### aura

The AURA AI agent daemon. Has read-heavy, write-restricted capabilities.

**File:** `OS/etc/perms.d/aura.caps`

```
fs.read
fs.list
fs.stat
fs.exists
log.read
log.write
memory.*
health.check
health.status
ai.ask
ai.classify
net.ping
net.dns
system.sysinfo
system.uptime
event.fire
event.read
```

### service

Background services (non-AI). Minimal write capabilities.

**File:** `OS/etc/perms.d/service.caps`

```
log.write
log.rotate
health.status
system.sysinfo
system.uptime
event.fire
fs.read
fs.list
```

### plugin *(extension principal)*

Third-party plugins — further restricted.

**File:** `OS/etc/perms.d/plugin.caps`

```
fs.read
fs.list
log.read
memory.read
ai.ask
system.sysinfo
```

---

## Capability Namespaces

| Namespace | Capabilities | Description |
|-----------|-------------|-------------|
| `fs.*` | `read`, `write`, `append`, `list`, `stat`, `exists`, `mkdir`, `rm` | Filesystem operations |
| `proc.*` | `spawn`, `kill`, `read`, `nice` | Process management |
| `net.*` | `ping`, `dns`, `http`, `iflist`, `route` | Network operations |
| `log.*` | `read`, `write`, `rotate` | Log access |
| `memory.*` | `read`, `write`, `delete`, `list`, `search` | Memory store |
| `system.*` | `sysinfo`, `uptime`, `event`, `service`, `shutdown`, `reboot` | System control |
| `ai.*` | `ask`, `classify`, `infer`, `model.load` | AI inference |
| `health.*` | `check`, `status`, `repair` | Health monitoring |
| `repair.*` | `check`, `run`, `backup`, `restore` | Self-repair |

---

## Capability Check API

### Shell

```sh
# Returns: exit 0 = granted, exit 1 = denied
os-perms check <principal> <capability>

# Examples
os-perms check operator fs.read     # → 0 (granted)
os-perms check aura     proc.kill   # → 1 (denied)
os-perms check service  net.http    # → 1 (denied)

# Grant a capability at runtime (not persistent)
os-perms grant <principal> <capability>

# Revoke a capability at runtime (not persistent)
os-perms revoke <principal> <capability>

# List capabilities for a principal
os-perms list <principal>

# Audit: show last N capability checks
os-perms audit [n]
```

### Python

```python
from subprocess import run, PIPE

def check_cap(principal: str, capability: str) -> bool:
    result = run(
        ["os-perms", "check", principal, capability],
        capture_output=True
    )
    return result.returncode == 0
```

---

## How a Capability Check Works

```
os-perms check aura fs.write
         │
         ▼
1. Load OS/etc/perms.d/aura.caps
2. For each line in the file:
   a. If line starts with "!" (deny), check pattern match → deny immediately
   b. If line matches capability exactly → grant
   c. If line is a wildcard (e.g. fs.*) and matches → grant
3. If no match → deny
4. Append audit entry to var/log/perms.log
5. Exit 0 (grant) or exit 1 (deny)
```

### Audit log format (`var/log/perms.log`)

```
1743695424 operator fs.read /var/log/os.log GRANTED
1743695425 aura proc.kill 12345 DENIED
```

---

## Deny Rules

A capability can be explicitly denied regardless of wildcards:

**File:** `OS/etc/perms.d/aura.caps`

```
fs.*
!fs.write        ← deny fs.write even though fs.* is granted
!fs.rm           ← deny fs.rm
```

Deny rules take precedence over grant rules.

---

## Immutable Denials

The following capabilities are **permanently denied** to all non-operator
principals regardless of capability files:

| Capability | Reason |
|------------|--------|
| `system.shutdown` | Prevents AI-triggered shutdown |
| `system.reboot` | Prevents AI-triggered reboot |
| `proc.spawn` with `rm -rf /` | Denylist in os-syscall |
| `proc.spawn` with `dd ... /dev/sd*` | Denylist in os-syscall |
| `repair.restore` without confirmation | Requires operator confirmation |

---

## Extending the Model

To add a new principal:

1. Create `OS/etc/perms.d/<name>.caps` with one capability per line
2. Use `os-perms check <name> <cap>` in any script that requires access control
3. Document the new principal in this file

To add a new capability namespace:

1. Define all capability names in this document
2. Implement the check in the relevant command script
3. Add the capability to `operator.caps` (granted by default)
4. Explicitly add to other principals if required

---

## Security Considerations

- Capability files are stored within `OS_ROOT` — protect `OS_ROOT` from
  unauthorised write access on the host OS
- The `operator` principal has `*.*` — in multi-user environments, create
  specific named principals instead
- Capability checks add ~1 ms overhead per call; avoid checking in tight loops
- LLM-generated commands run as `aura` principal — they cannot escalate to
  `operator` capabilities without explicit user approval

---

*Last updated: 2026-04-03*
