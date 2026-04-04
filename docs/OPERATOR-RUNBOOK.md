# AIOS Operator Runbook

The definitive guide for operating and maintaining AIOS-Lite.

## Table of Contents

1. [System Overview](#system-overview)
2. [Day-1 Setup Checklist](#day-1-setup-checklist)
3. [Boot Procedure](#boot-procedure)
4. [Service Management](#service-management)
5. [Log Locations](#log-locations)
6. [Health Checks](#health-checks)
7. [Recovery Procedures](#recovery-procedures)
8. [Security Checklist](#security-checklist)
9. [Common Failures](#common-failures)
10. [Update Procedure](#update-procedure)

---

## System Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER / AI SHELL LAYER                    │
│       bin/aios  ·  bin/aios-sys  ·  OS/bin/os-shell        │
├─────────────────────────────────────────────────────────────┤
│                     AURA AI LAYER                           │
│   Intent Engine  ·  Router  ·  Bots  ·  LLaMA Backend      │
├─────────────────────────────────────────────────────────────┤
│                    SERVICE LAYER                            │
│   os-kernel  ·  aura-llm  ·  aura-agents  ·  aura-tasks    │
├─────────────────────────────────────────────────────────────┤
│                      OS LAYER                               │
│   init  ·  syscall  ·  perms  ·  sched  ·  recover         │
└─────────────────────────────────────────────────────────────┘
```

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `bin/` | Top-level shells and tools |
| `lib/` | Shell libraries (aura-*.sh) |
| `config/` | System configuration |
| `etc/` | Shell-level config |
| `tools/` | Operator tools |
| `OS/` | Virtual OS root |
| `OS/bin/` | OS tools |
| `OS/sbin/` | Boot scripts |
| `OS/etc/init.d/` | Service scripts |
| `OS/etc/rc2.d/` | Service startup order |
| `OS/var/log/` | Logs |
| `OS/var/service/` | Service state (PIDs, health) |
| `OS/var/events/` | Event files |
| `OS/proc/` | Runtime state |
| `ai/core/` | Python AI backend |

---

## Day-1 Setup Checklist

### Prerequisites

- [ ] Bash 4.0+ installed
- [ ] Python 3.8+ installed
- [ ] 2GB+ RAM available
- [ ] 500MB+ disk space

### Initial Setup

1. **Clone or extract AIOS**:
   ```bash
   git clone <repo-url> aios
   cd aios
   ```

2. **Set permissions**:
   ```bash
   chmod +x bin/* tools/* OS/bin/* OS/sbin/*
   ```

3. **Run health check**:
   ```bash
   bash tools/health_check.sh
   ```

4. **Configure (optional)**:
   ```bash
   # Edit config/aios.conf for custom settings
   vi config/aios.conf
   ```

5. **Start AIOS**:
   ```bash
   ./bin/aios
   ```

### LLM Setup (Optional)

1. Download a GGUF model:
   ```bash
   mkdir -p llama_model
   # Download model to llama_model/
   ```

2. Build or install llama.cpp:
   ```bash
   bash build/build.sh --target hosted
   ```

3. Enable LLM in config:
   ```bash
   # config/aios.conf
   ENABLE_LLM=1
   AI_BACKEND=llama
   ```

---

## Boot Procedure

### Normal Boot

```bash
# Full boot with shell
OS_ROOT=$(pwd)/OS AIOS_HOME=$(pwd) sh OS/sbin/init

# Boot without shell
OS_ROOT=$(pwd)/OS AIOS_HOME=$(pwd) sh OS/sbin/init --no-shell
```

### Boot Sequence

1. `OS/sbin/init` resolves paths
2. Creates runtime directories (`var/`, `proc/`, etc.)
3. Loads `config/aios.conf`
4. Runs `OS/etc/rc2.d/S*` scripts in order
5. Emits `boot.complete` event
6. Launches shell (unless `--no-shell`)

### Troubleshooting Boot

**Boot hangs**:
```bash
# Boot with verbose output
sh -x OS/sbin/init --no-shell 2>&1 | tee boot.log
```

**Service fails to start**:
```bash
# Check service logs
cat OS/var/log/os.log | tail -50
bash tools/service-ctl.sh status <service>
```

---

## Service Management

### List Services

```bash
bash tools/service-ctl.sh list
```

### Manage Services

```bash
# Start/stop/restart
bash tools/service-ctl.sh start os-kernel
bash tools/service-ctl.sh stop aura-agents
bash tools/service-ctl.sh restart aura-llm

# Check status
bash tools/service-ctl.sh status os-kernel

# Enable/disable at boot
bash tools/service-ctl.sh enable aura-llm
bash tools/service-ctl.sh disable aura-tasks
```

### Service Health Files

Located in `OS/var/service/*.health`:
```
status=running
time=1704067200
pid=12345
```

---

## Log Locations

| Log | Path | Purpose |
|-----|------|---------|
| OS Log | `OS/var/log/os.log` | Kernel and system messages |
| AURA Log | `OS/var/log/aura.log` | AI subsystem activity |
| Events Log | `OS/var/log/events.log` | Event bus messages |
| Security Log | `OS/var/log/security.log` | Security-related events |
| Service Log | `OS/var/log/service.log` | Service lifecycle |
| Recovery Log | `OS/var/log/recover.log` | Recovery operations |
| Update Log | `OS/var/log/update.log` | Update operations |

### Viewing Logs

```bash
# Quick view
bash tools/log-viewer.sh

# Tail specific log
tail -f OS/var/log/os.log

# Filter events
bash tools/event-viewer.sh --type kernel
```

---

## Health Checks

### Quick Health Check

```bash
bash tools/health_check.sh
```

Checks:
- Directory structure
- Key files present
- File permissions
- Boot dry-run
- Python imports
- Config syntax

### System Check

```bash
bash tools/system_check.sh
```

Checks:
- CPU/memory/disk status
- Service health
- File integrity
- Config validation

### Security Audit

```bash
bash tools/security-audit.sh
```

Checks:
- World-writable files
- Eval usage
- Shell injection risks
- Hardcoded secrets

### Offline Check

```bash
bash tools/offline-check.sh
```

Checks:
- Network dependencies
- Hardcoded URLs
- Offline readiness

---

## Recovery Procedures

### Quick Recovery

```bash
# Run automatic repair
OS/bin/os-recover --auto
```

### Manual Recovery Steps

1. **Check integrity**:
   ```bash
   OS/bin/os-recover check
   ```

2. **Create backup**:
   ```bash
   OS/bin/os-recover backup
   ```

3. **Run repair**:
   ```bash
   OS/bin/os-recover repair
   ```

### Recovery Points

```bash
# Create recovery point
bash tools/recovery-ctl.sh create before-upgrade

# List recovery points
bash tools/recovery-ctl.sh list

# Restore from point
bash tools/recovery-ctl.sh restore 20260102-153045
```

### Quick Checkpoint

```bash
# Create minimal checkpoint
OS/bin/os-checkpoint before-test

# Restore from latest checkpoint
OS/bin/os-recover --checkpoint
```

---

## Security Checklist

### Pre-Deployment

- [ ] Run `bash tools/security-audit.sh`
- [ ] No CRITICAL or HIGH findings
- [ ] Permissions correct (`bash tools/perms-audit.sh`)
- [ ] No hardcoded secrets in config
- [ ] `SECURITY_HARDENED=1` in config

### Runtime Security

- [ ] Security logging enabled (`LOG_SECURITY_EVENTS=1`)
- [ ] Input sanitization active
- [ ] OS_ROOT jail enforced

### Periodic Audits

Run weekly:
```bash
bash tools/security-audit.sh
bash tools/perms-audit.sh
bash tools/config-audit.sh
```

---

## Common Failures

### "Python module not found"

```bash
# Check Python path
python3 -c "import sys; print(sys.path)"

# Verify AI modules
cd ai/core && python3 -c "import ai_backend"
```

### "Service dead"

```bash
# Check service status
bash tools/service-ctl.sh status <service>

# Restart service
bash tools/service-ctl.sh restart <service>

# Check logs
cat OS/var/log/os.log | grep <service>
```

### "Boot incomplete"

```bash
# Check boot target
cat OS/etc/boot.target

# Check rc2.d scripts
ls -la OS/etc/rc2.d/

# Run recovery
OS/bin/os-recover --auto
```

### "Disk full"

```bash
# Check disk usage
du -sh OS/var/log/*

# Rotate logs
OS/bin/os-recover repair  # Rotates oversized logs

# Purge old backups
bash tools/recovery-ctl.sh purge 7
```

---

## Update Procedure

### Pre-Update

1. **Check for updates**:
   ```bash
   bash tools/update-check.sh
   ```

2. **Create recovery point**:
   ```bash
   bash tools/recovery-ctl.sh create pre-update
   ```

3. **Backup critical data**:
   ```bash
   OS/bin/os-recover backup
   ```

### Apply Update

```bash
bash tools/apply-update.sh
```

This automatically:
- Creates backup
- Runs `git pull`
- Verifies with health check
- Rolls back on failure

### Post-Update

1. **Verify health**:
   ```bash
   bash tools/health_check.sh
   ```

2. **Restart services**:
   ```bash
   bash tools/service-ctl.sh restart os-kernel
   ```

3. **Test AI shell**:
   ```bash
   ./bin/aios
   # Type: help
   # Type: fs.ls /
   ```

### Rollback

If update fails:

```bash
# Automatic rollback (apply-update.sh does this)
# Or manual:
bash tools/recovery-ctl.sh list
bash tools/recovery-ctl.sh restore <pre-update-id>
```

---

## Quick Reference

### Essential Commands

```bash
# Start AIOS
./bin/aios

# Health check
bash tools/health_check.sh

# Service status
bash tools/service-ctl.sh list

# View logs
bash tools/log-viewer.sh

# Recovery
OS/bin/os-recover --auto

# Update
bash tools/update-check.sh
bash tools/apply-update.sh
```

### Emergency Recovery

```bash
# Minimal boot
OS_ROOT=$(pwd)/OS sh OS/sbin/init --no-shell

# Full recovery
OS/bin/os-recover --auto

# Restore from checkpoint
OS/bin/os-recover --checkpoint
```
