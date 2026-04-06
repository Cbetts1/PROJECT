# AIOS-Lite Plugin API Reference

## Overview

Third-party bots and skills can be added to AIOS-Lite without modifying the
core codebase.  Each plugin is an independent Python module that subclasses
`BaseBot` and is registered with the `Router` at runtime.

---

## Plugin Directory Layout

```
OS/var/pkg/plugins/<plugin-name>/
├── plugin.json          # required: manifest
├── plugin.json.asc      # recommended: GPG detached signature
├── <entry_point>.py     # required: Python module
└── root/                # plugin's sub-OS_ROOT jail (auto-created)
```

---

## `plugin.json` Schema

```json
{
  "name":         "hello-bot",
  "version":      "1.0.0",
  "entry_point":  "hello_bot",
  "bot_class":    "HelloBot",
  "capabilities": ["fs.read", "log.*"],
  "description":  "A sample plugin"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Unique plugin identifier (slug format) |
| `version` | ✅ | Semantic version string |
| `entry_point` | ✅ | Python module filename without `.py` |
| `bot_class` | ✅ | Name of the `BaseBot` subclass in the module |
| `capabilities` | ❌ | List of AIOS capability strings the plugin needs |
| `description` | ❌ | Human-readable description |

---

## `BaseBot` Public API

All plugins must extend `ai.core.bots.BaseBot`.

```python
from bots import BaseBot
from intent_engine import Intent

class MyBot(BaseBot):
    name = "MyBot"  # Required: unique display name

    def can_handle(self, intent: Intent) -> bool:
        """Return True if this bot should handle the given intent."""
        ...

    def handle(self, intent: Intent) -> str:
        """Process the intent and return a response string."""
        ...
```

### Constructor

```python
BaseBot(os_root: str = "")
```

`os_root` is set automatically by `PluginLoader` to the plugin's sub-jail
(`OS/var/pkg/<plugin-name>/root/`).

### Inherited utility methods

| Method | Description |
|--------|-------------|
| `self._read_file(rel_path, max_lines=200)` | Read a text file under `os_root`, returns string |
| `self._run(cmd: list, timeout=10)` | Run a subprocess, returns combined stdout/stderr |
| `self._log_path(name="os.log")` | Returns absolute path to `os_root/var/log/<name>` |

### `Intent` dataclass

```python
@dataclass
class Intent:
    category:   str          # e.g. "health", "memory", "command", "chat"
    action:     str          # e.g. "mem.set", "proc.ps"
    entities:   dict         # extracted entities (path, host, pid, …)
    raw:        str          # original user input
    confidence: float = 1.0  # classification confidence [0.0, 1.0]
```

---

## Loading Plugins

### On startup

`plugin_loader.py` is called from `ai_backend.py` before any intent is
dispatched.  Install a plugin and restart `aios` (or send SIGUSR1).

```bash
# Install reference plugin
cp -r examples/hello-bot/ OS/var/pkg/plugins/hello-bot/

# Hot-reload (no restart needed)
kill -USR1 $(pgrep -f 'bin/aios')
```

### Programmatically

```python
from ai.core.plugin_loader import load_plugins
from ai.core.router import Router

r = Router(os_root="/path/to/OS")
loaded = load_plugins(r, os_root="/path/to/OS")
print(loaded)  # [<Plugin hello-bot v1.0.0>]
```

---

## Signing Plugins

```bash
# Create a GPG key if you don't have one
gpg --gen-key

# Sign the plugin manifest
bash scripts/plugin-sign.sh OS/var/pkg/plugins/hello-bot/

# Verify the signature
gpg --verify OS/var/pkg/plugins/hello-bot/plugin.json.asc \
             OS/var/pkg/plugins/hello-bot/plugin.json
```

---

## Plugin Sandbox

Each plugin runs in a sub-OS_ROOT jail:

```
OS/var/pkg/<plugin-name>/root/
```

All `self._read_file()` and `self._run()` calls are scoped to this
directory.  The `osroot_resolve()` logic from `lib/aura-core.sh` is applied
so plugins cannot escape their jail.

---

## Example Plugin

See [`examples/hello-bot/`](../examples/hello-bot/) for a complete working
reference plugin.

---

## Plugin Catalogue

Use `scripts/plugin-repo.sh` to install plugins from the catalogue:

```bash
# List available plugins
bash scripts/plugin-repo.sh list

# Install a plugin
bash scripts/plugin-repo.sh install my-plugin

# Update all installed plugins
bash scripts/plugin-repo.sh update
```
