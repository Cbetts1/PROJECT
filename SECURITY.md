# Security Policy

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest (`main`) | ✅ Active security fixes |
| prior releases | ⚠️ Best-effort only |

---

## Reporting a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

To report a security issue, open a **private** security advisory via:

> **GitHub → Security → Advisories → New draft security advisory**  
> <https://github.com/Cbetts1/PROJECT/security/advisories/new>

Alternatively, contact the maintainer directly through the GitHub profile page.

### What to Include

- Description of the vulnerability
- Steps to reproduce (minimal proof of concept)
- Affected component(s) and file(s)
- Potential impact (privilege escalation, data exfiltration, denial-of-service, etc.)
- Your suggested fix (optional but appreciated)

---

## Response Timeline

| Stage | Target time |
|-------|-------------|
| Acknowledgement | Within 3 business days |
| Initial assessment | Within 7 business days |
| Fix / patch | Within 30 days for critical, 90 days for others |
| Public disclosure | After patch is available |

---

## Security Architecture

AIOS-Lite implements multiple layers of defence:

### OS_ROOT Filesystem Jail

All file I/O passes through `OS/lib/filesystem.py`, which:
- Resolves every path relative to `OS_ROOT` using `os.path.realpath()`
- Denies any path that resolves outside `OS_ROOT`
- Logs every access to `OS/var/log/aura.log`

### Capability-Based Permissions

Every cross-kernel operation is gated by `OS/bin/os-perms`:
- Principals: `operator`, `aura`, `service`
- Capabilities are listed in `OS/etc/perms.d/<principal>.caps`
- Default AURA capabilities are minimal (read-only filesystem, no process kill)

### Syscall Audit Log

`OS/bin/os-syscall` writes every invocation to:
- `OS/var/log/syscall.log`
- `OS/var/log/aura.log`

### AURA Agent Restrictions

The AURA AI agent:
- Runs without interactive login shell access
- Cannot execute commands outside the `aioscpu-secure-run` wrapper
- Has a denylist of catastrophically dangerous operations
- Has no outbound network capability unless explicitly configured

### Secure-Run Denylist

The following operations are permanently denied regardless of permissions:
- Recursive deletion from root (`rm -rf /`)
- Raw disk writes (`dd if=... of=/dev/sd*`)
- Fork bombs
- Loading unsigned kernel modules

---

## Known Limitations

- AIOS-Lite runs in user-space — it relies on host OS security for true
  privilege isolation
- The `operator` principal has full capabilities by default; restrict it for
  multi-user deployments
- LLM-generated responses are not sanitised for shell injection by default;
  always review AI-suggested commands before execution

---

## Changelog

Security-relevant changes are marked with `[security]` in [CHANGELOG.md](CHANGELOG.md).
