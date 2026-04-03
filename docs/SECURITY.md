# AIOSCPU Security Documentation

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Users and Permissions

AIOSCPU creates two non-root users in addition to the standard `root` account:

### `root`
- Standard Linux superuser.
- Direct root login over SSH is disabled by default (see `/etc/ssh/sshd_config`).
- Root access for `aios` is via `sudo`.

### `aios` (Interactive User)
- Password: `aios` — **change this immediately on first boot**.
- Member of the `sudo` group; can run any command as root with password.
- The default interactive login account for humans.

### `aura` (AI Agent Service Account)
- System account (`useradd -r`), no interactive login shell (`/usr/sbin/nologin`).
- Password locked (`passwd -l aura`) — cannot authenticate directly.
- Home directory: `/opt/aura`
- May **only** run `/usr/local/bin/aioscpu-secure-run` as root (see sudoers).
- The AURA agent daemon runs under this account.

---

## Sudoers Design

The sudoers rule for AURA is in `/etc/sudoers.d/aura-commands`:

```
aura ALL=(root) NOPASSWD: /usr/local/bin/aioscpu-secure-run
```

- AURA may only invoke the single wrapper binary `aioscpu-secure-run`.
- It cannot run arbitrary commands as root — only commands that pass the
  denylist in `aioscpu-secure-run`.
- The `NOPASSWD` grant is required because AURA is a daemon with no TTY.

---

## What AURA Can and Cannot Do

### AURA CAN:
- Read system info via `aioscpu-sysinfo` (CPU, memory, disk, uptime)
- Read network info via `aioscpu-netinfo` (interfaces, routes, DNS, ARP)
- Store/retrieve key-value pairs in its local SQLite database
- Execute shell commands **through** `aioscpu-secure-run` (subject to denylist)

### AURA CANNOT:
- Log in interactively (no login shell, locked password)
- Execute commands directly as root without the secure-run wrapper
- Execute any command on the `aioscpu-secure-run` denylist:
  - `rm -rf /` or recursive deletion of root
  - `mkfs`, `mke2fs`, `mkswap` (filesystem creation on raw devices)
  - Fork bombs (`:(){:|:&};:`)
  - `dd` to disk devices (`/dev/sd*`, `/dev/nvme*`)
  - Redirects to `/dev/sd*`, `/dev/nvme*`, `/boot/`, `/etc/passwd`, etc.
  - `rmmod` (removal of kernel modules)
- Access the internet by default (no `model_backend` configured)
- Write outside `/var/lib/aura` and `/var/log` (systemd `ProtectSystem=strict`)
- Access `/home` for writing (systemd `ProtectHome=read-only`)

---

## Logging

All significant actions are logged. Log files:

| Log File | Contents |
|----------|----------|
| `/var/log/aioscpu-secure-run.log` | Every command submitted to the secure-run wrapper (permitted and rejected), with timestamp, caller user, and command string |
| `/var/log/aioscpu-audit.log` | Commands wrapped with `aioscpu-logwrap` (start, end, exit code) |
| `/var/log/aura-agent.log` | AURA agent startup, commands received, errors |
| `/var/log/syslog` (journald) | AURA systemd service stdout/stderr via `StandardOutput=journal` |

To view AURA logs in real time:
```bash
journalctl -u aura.service -f
tail -f /var/log/aioscpu-secure-run.log
```

---

## Systemd Sandboxing

The `aura.service` unit applies the following sandboxing options:

| Option | Effect |
|--------|--------|
| `NoNewPrivileges=true` | AURA cannot gain new privileges (no setuid escalation) |
| `PrivateTmp=true` | AURA gets its own isolated `/tmp` |
| `ProtectSystem=strict` | Entire filesystem is read-only except `ReadWritePaths` |
| `ReadWritePaths=/var/lib/aura /var/log` | Only these paths are writable |
| `ProtectHome=read-only` | Home directories are read-only |

---

## How to Tighten Security Further

1. **Change default passwords immediately:**
   ```bash
   passwd aios
   ```

2. **Restrict SSH access:**
   Edit `/etc/ssh/sshd_config`:
   ```
   PermitRootLogin no
   PasswordAuthentication no   # use SSH keys instead
   AllowUsers aios
   ```

3. **Audit AURA's denylist:** Review `/usr/local/bin/aioscpu-secure-run` and
   add patterns relevant to your deployment.

4. **Limit `aios` sudo access:** Replace the broad `sudo` group membership
   with specific allowed commands in `/etc/sudoers.d/aios-rules`.

5. **Enable a firewall:**
   ```bash
   apt-get install ufw
   ufw default deny incoming
   ufw allow ssh
   ufw enable
   ```

6. **Review AURA memory database regularly:**
   ```bash
   sqlite3 /var/lib/aura/aura-memory.db "SELECT * FROM memory ORDER BY id DESC LIMIT 20;"
   ```

---

## Future Plans: Containerisation

A future release will run AURA inside a container (LXC or podman) to provide
stronger isolation from the host system. Until then, the systemd sandboxing
options above provide the primary security boundary.

---

## Reporting Security Issues

Please report security vulnerabilities **privately** via the GitHub Security Advisory portal:  
<https://github.com/Cbetts1/PROJECT/security/advisories/new>

Do **not** open a public GitHub issue for security vulnerabilities.

---

## Full Security Framework

For the complete security architecture, threat model (STRIDE), hardening guidelines,
compliance rules, vulnerability management process, security testing checklists,
and incident response procedures, see:

👉 **[`docs/SECURITY-FRAMEWORK.md`](SECURITY-FRAMEWORK.md)**
