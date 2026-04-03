# Privacy Notice — AIOSCPU / AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

*Effective date: 2026-04-03*

---

## 1. Overview

This Privacy Notice explains what data AIOSCPU and AIOS-Lite collect, how
it is stored, and how it is used. The Software is designed to operate
entirely locally with **no outbound data transmission by default**.

---

## 2. Data Collected Locally

The Software collects and stores the following data **only on your local
device**:

### 2.1 System Information

| Data | Where stored | Purpose |
|------|-------------|---------|
| CPU usage, memory, disk statistics | `OS/var/log/os.log` | Resource monitoring |
| Hostname, OS_ROOT path | `OS/proc/os.state` | OS operation |
| Network interface names and IP addresses | `OS/var/log/os.log` | Bridge and netconf |
| Running process PIDs | `OS/var/service/*.pid` | Service management |

### 2.2 User-Provided Memory

| Data | Where stored | Purpose |
|------|-------------|---------|
| Symbolic key-value facts (`mem.set`) | `OS/proc/aura.memory` | AI memory |
| Semantic memory entries (`sem.set`) | `OS/lib/aura-memory/` | AI recall |
| Conversation context (last 50 lines) | `OS/proc/aura/context/window` | AI context |

### 2.3 Command and Audit Logs

| Data | Where stored | Retention |
|------|-------------|-----------|
| Syscall invocations with arguments | `OS/var/log/syscall.log` | Auto-rotate at 1000 lines |
| AURA AI agent queries and responses | `OS/var/log/aura.log` | Auto-rotate at 1000 lines |
| Permission check events | `OS/var/log/perms.log` | Auto-rotate at 1000 lines |
| System events | `OS/var/events/` | Cleared after processing |

### 2.4 AURA Agent SQLite Database

If the AURA agent is running, it may store a local SQLite database at
`/var/lib/aura/aura-memory.db` (on AIOSCPU native installations) containing
structured memory entries. This data stays on your device.

---

## 3. Data NOT Collected

The Software does **not**:

- Create user accounts or profiles
- Collect telemetry, crash reports, or analytics
- Transmit any data to the project maintainer
- Connect to any remote server unless you explicitly configure a bridge
  or external AI model backend

---

## 4. External Model Backends

If you configure an external AI model backend in `aura/aura-config.json`:

```json
{
  "model_backend": "https://api.openai.com/v1"
}
```

Your AI queries will be transmitted to that third-party service. You are
solely responsible for reviewing the privacy policy of any external service
you configure. The project maintainer has no visibility into this data.

---

## 5. Cross-OS Bridge Data

When you use the cross-OS bridge to mirror a device:

- File listings and file contents accessed via `mirror/` are processed
  locally within `OS_ROOT`
- No bridge data is transmitted externally
- You are responsible for ensuring you have the legal right to access
  any device you connect

---

## 6. Data Deletion

To delete all locally stored data:

```sh
# Remove logs
rm -f "$OS_ROOT/var/log/"*

# Remove memory store
rm -f "$OS_ROOT/proc/aura.memory"
rm -rf "$OS_ROOT/lib/aura-memory/"*
rm -rf "$OS_ROOT/proc/aura/"

# Remove AURA SQLite database (AIOSCPU native)
rm -f /var/lib/aura/aura-memory.db

# Remove the entire OS tree
rm -rf "$OS_ROOT"
```

---

## 7. Children's Privacy

The Software is not directed at children under 13. We do not knowingly
collect data from children under 13.

---

## 8. Changes to This Notice

This Privacy Notice may be updated as the Software evolves. Continued use
after changes are posted constitutes acceptance of the revised Notice.

---

## 9. Contact

Project repository: <https://github.com/Cbetts1/PROJECT>

---

*See also: [docs/TERMS-OF-USE.md](TERMS-OF-USE.md) |
[docs/DISCLAIMER.md](DISCLAIMER.md) | [docs/AI-DISCLOSURE.md](AI-DISCLOSURE.md)*
