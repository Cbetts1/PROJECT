# AIOS Offline-First Behavior

AIOS-Lite is designed to work **fully offline** after installation. This document describes what works offline, what requires network access, and how to verify offline readiness.

## What Works Offline (Everything Core)

| Feature | Offline Status | Notes |
|---------|---------------|-------|
| **Boot & Init** | ✅ Full | OS boots without network |
| **AI Shell (bin/aios)** | ✅ Full | All shell commands work offline |
| **File Operations (fs.*)** | ✅ Full | Fully offline |
| **Process Management (proc.*)** | ✅ Full | Fully offline |
| **Service Management** | ✅ Full | Start/stop/status all work |
| **Recovery Mode** | ✅ Full | os-recover works offline |
| **Health Checks** | ✅ Full | All audit tools work offline |
| **LLM Inference** | ✅ Full* | *If model is cached locally |
| **Mock AI Backend** | ✅ Full | Rule-based AI always works |
| **Logs & Events** | ✅ Full | All logging is local |
| **Security Audits** | ✅ Full | All checks are local |

## What Requires Network (Optional Features)

| Feature | Network Use | Guard |
|---------|------------|-------|
| **Model Download** | One-time | Manual download step |
| **System Updates** | Optional | `OFFLINE_MODE=1` skips |
| **net.ping** | Runtime | Checks `OFFLINE_MODE` |
| **net.ifconfig** | Local only | No network required |
| **WiFi/BT Config** | Runtime | Hardware dependent |
| **Remote Bridge (SSH)** | Runtime | User-initiated |
| **Package Install** | One-time | During setup only |

## How to Enable Offline Mode

### Method 1: Environment Variable

```bash
export OFFLINE_MODE=1
./bin/aios
```

### Method 2: Config File

Edit `config/aios.conf`:

```bash
OFFLINE_MODE=1
```

### Method 3: Runtime Command

```bash
OS/bin/os-netconf --offline-mode
```

This sets `OFFLINE_MODE=1` in `OS/proc/os/state` and blocks network operations system-wide.

## How to Verify Offline Readiness

Run the offline audit tool:

```bash
bash tools/offline-check.sh
```

Expected output for a properly configured system:

```
=== Offline-First Audit Summary ===
OFFLINE_SAFE:     N items (no network needed)
NETWORK_GATED:    M items (network optional, guarded)
NETWORK_REQUIRED: 0 items (network required, REVIEW NEEDED)

✓ System is OFFLINE-SAFE (no unguarded network requirements)
```

Use `--verbose` flag to see all findings:

```bash
bash tools/offline-check.sh --verbose
```

## Offline Mode Behavior

When `OFFLINE_MODE=1`:

1. **Network Commands**: `net.ping` and other network ops return `[OFFLINE] Network disabled` instead of attempting the call

2. **Update Checks**: `tools/update-check.sh` reports `OFFLINE` status without attempting remote checks

3. **Model Loading**: LLM loads from local cache only; no download attempts

4. **Bridges**: Local bridges work; remote SSH bridges are blocked

## Pre-Installation Checklist for Air-Gapped Systems

For fully air-gapped deployments:

1. **Download model file** on a networked machine:
   ```bash
   # Example: download a GGUF model
   wget https://huggingface.co/.../model.gguf
   ```

2. **Transfer to air-gapped system**:
   ```bash
   cp model.gguf $AIOS_HOME/llama_model/
   ```

3. **Set offline mode**:
   ```bash
   echo 'OFFLINE_MODE=1' >> config/aios.conf
   ```

4. **Verify**:
   ```bash
   bash tools/offline-check.sh
   bash tools/health_check.sh
   ```

## Troubleshooting

### "Network disabled" messages

This is expected when `OFFLINE_MODE=1`. The system is working correctly.

### Model not loading

Ensure the `.gguf` model file is in `$AIOS_HOME/llama_model/`:

```bash
ls -la llama_model/*.gguf
```

### Update check fails

In offline mode, update checks gracefully skip remote operations:

```bash
OFFLINE_MODE=1 bash tools/update-check.sh
# Should report: OFFLINE
```

## Architecture Notes

The offline-first design follows these principles:

1. **No implicit network**: No command makes network calls without explicit user action
2. **Graceful degradation**: Network-dependent features fail gracefully with clear messages
3. **Local-first storage**: All state, logs, and data stored locally
4. **Explicit guards**: All network code checks `OFFLINE_MODE` before attempting connections
