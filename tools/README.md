# AIOS Tools Directory

This directory contains operator and maintenance tools for AIOS-Lite.

## Contents

| Tool | Description |
|------|-------------|
| `perms-audit.sh` | Permission and shebang audit — verifies executability of scripts |
| `config-audit.sh` | Configuration audit — checks for conflicts and hard-coded paths |
| `log-viewer.sh` | Log viewer — shows and summarizes log files |
| `health_check.sh` | Health check — comprehensive system health verification |
| `system_check.sh` | System check — deep scan for issues (no changes) |
| `system_autofix.sh` | System autofix — safe, reversible automatic fixes |
| `ai-test.sh` | AI test — tests the AI backend with canned inputs |

## Usage

All tools support `--help` for usage information. Most tools exit with:
- `0` — Success / no issues found
- `1` — Failure / issues found

### Quick Commands

```bash
# Check system health
bash tools/health_check.sh

# Run full system check
bash tools/system_check.sh

# Fix common issues (dry run first)
bash tools/system_autofix.sh --dry-run
bash tools/system_autofix.sh

# View recent logs
bash tools/log-viewer.sh --tail 50

# Audit permissions
bash tools/perms-audit.sh

# Audit configuration
bash tools/config-audit.sh

# Test AI backend
bash tools/ai-test.sh
```

## Adding New Tools

1. Create a new script in this directory
2. Start with `#!/usr/bin/env bash`
3. Add `set -eo pipefail` for safety
4. Include usage comments at the top
5. Support `--help` flag
6. Make executable: `chmod +x tools/your-tool.sh`
7. Update this README

## Environment Variables

Most tools respect these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AIOS_ROOT` | Project root directory | Auto-detected from script location |
| `OS_ROOT` | Virtual OS root | `$AIOS_ROOT/OS` |
| `AIOS_HOME` | Same as AIOS_ROOT | Auto-detected |

## Related Directories

- `OS/bin/` — OS-level tools (os-check, os-selftest, etc.)
- `bin/` — User-facing binaries (aios, aios-sys, aios-heartbeat)
