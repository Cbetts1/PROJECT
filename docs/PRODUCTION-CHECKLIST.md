# AIOS Production Checklist

Comprehensive checklist for deploying AIOS-Lite to production.

## Pre-Deployment Checks

### 1. System Requirements

- [ ] Bash 4.0+ available (`bash --version`)
- [ ] Python 3.8+ available (`python3 --version`)
- [ ] Minimum 2GB RAM
- [ ] Minimum 500MB disk space (10GB with LLM)
- [ ] All file permissions correct

### 2. Run Audit Tools

```bash
# Run comprehensive production audit
bash tools/production-audit.sh

# Or run individual checks:
bash tools/health_check.sh
bash tools/system_check.sh
bash tools/security-audit.sh
bash tools/perms-audit.sh
bash tools/config-audit.sh
bash tools/offline-check.sh
```

**Expected result:** All checks pass or only warnings (no failures)

### 3. Configuration Verification

- [ ] `config/aios.conf` has correct settings
- [ ] `AIOS_VERSION` is set correctly
- [ ] `DEVICE_PROFILE` matches deployment target
- [ ] `SECURITY_HARDENED=1` is set
- [ ] `OFFLINE_MODE` is set appropriately

### 4. Security Verification

- [ ] No CRITICAL findings from security-audit.sh
- [ ] No HIGH findings from security-audit.sh
- [ ] No world-writable files in bin/ or tools/
- [ ] No hardcoded secrets in config
- [ ] `OS/etc/security.conf` is configured

### 5. Offline Capability Verification

- [ ] `OFFLINE_MODE` functions correctly
- [ ] No unguarded network dependencies
- [ ] LLM model is cached locally (if using LLM)
- [ ] System boots without network

---

## Deployment Steps

### 1. Final Preparation

```bash
# Generate fresh manifest
bash tools/generate-manifest.sh

# Create recovery point
bash tools/recovery-ctl.sh create pre-production

# Final health check
bash tools/health_check.sh
```

### 2. Deploy

```bash
# Copy to production location
cp -r /path/to/aios /opt/aios

# Set permissions
cd /opt/aios
chmod +x bin/* tools/* OS/bin/* OS/sbin/*

# Verify deployment
bash tools/health_check.sh
```

### 3. First Boot

```bash
# Boot without shell to test
OS_ROOT=$(pwd)/OS AIOS_HOME=$(pwd) sh OS/sbin/init --no-shell

# Check services
bash tools/service-ctl.sh list

# Start interactive shell
./bin/aios
```

---

## Post-Deployment Monitoring

### Daily Checks

```bash
# Service status
bash tools/service-ctl.sh list

# Recent events
bash tools/event-viewer.sh --tail 50

# Log check
tail -100 OS/var/log/os.log
```

### Weekly Checks

```bash
# Full system check
bash tools/system_check.sh

# Security audit
bash tools/security-audit.sh

# Disk usage
du -sh OS/var/log/*
du -sh OS/var/backup/*
```

### Monthly Checks

```bash
# Full production audit
bash tools/production-audit.sh

# Update check
bash tools/update-check.sh

# Purge old recovery points
bash tools/recovery-ctl.sh purge 30
```

---

## Backup Procedures

### Before Major Changes

```bash
# Create named recovery point
bash tools/recovery-ctl.sh create before-<change>

# Or quick checkpoint
OS/bin/os-checkpoint before-<change>
```

### Regular Backups

```bash
# Full backup
OS/bin/os-recover backup

# List backups
OS/bin/os-recover --list
```

---

## Update Procedures

### Check for Updates

```bash
bash tools/update-check.sh
```

### Apply Updates

```bash
# Create recovery point first
bash tools/recovery-ctl.sh create pre-update

# Apply update (with automatic rollback on failure)
bash tools/apply-update.sh

# Verify
bash tools/health_check.sh
```

### Rollback if Needed

```bash
# List recovery points
bash tools/recovery-ctl.sh list

# Restore
bash tools/recovery-ctl.sh restore <recovery-point-id>
```

---

## Troubleshooting Quick Reference

| Issue | Command |
|-------|---------|
| Service not starting | `bash tools/service-ctl.sh status <svc>` |
| System unhealthy | `bash tools/health_check.sh` |
| Security concerns | `bash tools/security-audit.sh` |
| Config problems | `bash tools/config-audit.sh` |
| Recovery needed | `OS/bin/os-recover --auto` |
| Restore needed | `bash tools/recovery-ctl.sh restore <id>` |
| Check logs | `bash tools/log-viewer.sh` |

---

## Emergency Procedures

### System Won't Boot

```bash
# Minimal boot
OS_ROOT=$(pwd)/OS sh OS/sbin/init --no-shell

# Recovery mode
OS/bin/os-recover --auto

# Restore from checkpoint
OS/bin/os-recover --checkpoint
```

### Critical Failure

```bash
# List recovery points
bash tools/recovery-ctl.sh list

# Restore from known good state
bash tools/recovery-ctl.sh restore <id>

# Or restore from backup
OS/bin/os-recover restore
```

---

## Sign-Off

| Check | Verified By | Date |
|-------|-------------|------|
| production-audit.sh passes | | |
| Security audit clean | | |
| Offline mode tested | | |
| Recovery tested | | |
| Documentation reviewed | | |
| Backup verified | | |

**Deployment Approved By:** _______________

**Date:** _______________
