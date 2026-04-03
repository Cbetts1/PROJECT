# Security Policy

> **AIOS-Lite / AIOSCPU** — security policy and vulnerability reporting

---

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ Active security support |
| < 1.0   | ❌ Not supported (pre-release) |

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately so they can be assessed and patched before
public disclosure.

### How to Report

1. **Open a private security advisory** on GitHub:
   <https://github.com/Cbetts1/PROJECT/security/advisories/new>

2. Include the following in your report:
   - A clear description of the vulnerability
   - Affected component(s) and file path(s)
   - Steps to reproduce or a proof-of-concept
   - Potential impact (confidentiality, integrity, availability)
   - Any suggested fix (optional but appreciated)

3. You will receive an acknowledgement within **72 hours**.

4. A patch or mitigation will be developed within **14 days** for critical
   issues, **30 days** for moderate/low issues.

5. You will be credited in the release notes and `CHANGELOG.md` unless you
   prefer to remain anonymous.

---

## Disclosure Policy

AIOS-Lite follows **coordinated disclosure**:

- The maintainer fixes the vulnerability before public disclosure.
- A security advisory is published on GitHub when the patch is released.
- The CVE process is followed for vulnerabilities that qualify.

---

## Security Architecture

### OS_ROOT Filesystem Jail

All file I/O in AIOS-Lite passes through `OS/lib/filesystem.py`, which:

- Resolves every path relative to `OS_ROOT` using `os.path.realpath()`
- Blocks any path that resolves outside `OS_ROOT` (path-traversal prevention)
- Returns `PermissionError("Access denied")` on boundary violation
- Provides an auditable minimal API: `read`, `write`, `append`, `list`,
  `exists`, `stat`, `log`

### Capability-Based Permissions

Every privileged operation is checked via `OS/bin/os-perms`:

```sh
os-perms check <principal> <capability>   # exit 0 = allowed, 1 = denied
```

Principals:

| Principal | Default Capabilities |
|-----------|---------------------|
| `operator` | All (`*.*`) |
| `aura` | `fs.read`, `fs.list`, `log.read`, `memory.*`, `health.check`, `ai.ask`, `net.ping` |
| `service` | `log.write`, `health.status`, `system.sysinfo` |

### Syscall Audit Log

Every invocation of `OS/bin/os-syscall` is appended to:
- `OS/var/log/syscall.log`
- `OS/var/log/aura.log`

### Spawn Whitelist

`os-syscall spawn` only executes binaries on an explicit allowlist.
Unlisted binaries are rejected.

### HTTP API Authentication

`OS/bin/os-httpd` requires a bearer token for all endpoints except
`GET /api/v1/health`.  The token is stored in `OS/etc/api.token`.

### TLS Policy

`os-httpd` enforces TLS 1.2 as the minimum protocol version:
```python
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
```
SSLv3, TLS 1.0, and TLS 1.1 are not accepted.

### AURA Agent Sandboxing (AIOSCPU image)

In the AIOSCPU disk image, the AURA agent runs under the `aura` system account
with:
- No interactive login shell (`/usr/sbin/nologin`)
- Locked password (`passwd -l aura`)
- `sudo` access limited to `/usr/local/bin/aioscpu-secure-run` only
- `aioscpu-secure-run` denylist blocks: `rm -rf /`, raw disk writes (`dd` to
  `/dev/sd*`), `mkfs`, fork bombs, kernel module removal, and writes to
  `/boot/`, `/etc/passwd`
- systemd unit: `NoNewPrivileges=true`, `PrivateTmp=true`,
  `ProtectSystem=strict`, `ReadWritePaths=/var/lib/aura /var/log`,
  `ProtectHome=read-only`

---

## Known Limitations

| Area | Limitation |
|------|-----------|
| Portable shell mode | No hardware privilege rings; security relies on POSIX permissions of the host OS |
| HTTPS | Self-signed certificate by default; users should deploy a CA-signed certificate in production |
| AURA containerisation | Full LXC/podman container isolation is planned for v1.2.0; current boundary is systemd sandboxing |
| WiFi / BT / firewall | Network operations in `os-netconf` require host-level tools (`nmcli`, `bluetoothctl`, `iptables`) and their security is inherited from the host |
| LLM model trust | Model weights loaded from `llama_model/` are not verified by checksum; users are responsible for validating downloaded model files |

---

## Security Hardening Checklist

After installation, apply the following mitigations:

- [ ] Change the default `aios` user password: `passwd aios`
- [ ] Disable SSH password authentication; use key-based auth only
- [ ] Set `PermitRootLogin no` in `/etc/ssh/sshd_config`
- [ ] Replace the self-signed TLS certificate with a CA-signed one
- [ ] Review and rotate `OS/etc/api.token`
- [ ] Enable and configure the host firewall (`ufw` or `iptables`)
- [ ] Audit `aioscpu-secure-run` denylist for your deployment context
- [ ] Enable log monitoring (`journalctl -u aura.service -f`)

---

## Past Security Fixes

| Version | Issue | Fix |
|---------|-------|-----|
| v1.0.0 | `os-httpd` accepted TLS < 1.2 (CodeQL `py/insecure-protocol`) | Enforced `minimum_version = TLSVersion.TLSv1_2` |

---

*Maintained by Christopher Betts — <https://github.com/Cbetts1>*
