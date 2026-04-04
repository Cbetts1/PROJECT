# AIOS AI Protocol Documentation

> Version: 1.0
> Last Updated: 2026-04-04

This document describes the AI pipeline architecture, interfaces, and extension points for AIOS-Lite.

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [AI Backend CLI Interface](#ai-backend-cli-interface)
3. [Adding New Bots](#adding-new-bots)
4. [Adding New Intent Categories](#adding-new-intent-categories)
5. [Structured Logging Format](#structured-logging-format)
6. [LLM Integration](#llm-integration)

---

## Pipeline Overview

The AIOS AI pipeline transforms natural language input into structured actions through a multi-stage process:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AI Pipeline                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  User Input (natural language)                                              │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 1. IntentEngine.classify(text)                                      │    │
│  │    - Pattern matching against rule tables                           │    │
│  │    - Extracts category, action, entities                            │    │
│  │    - Assigns confidence score (0.0-1.0)                             │    │
│  │    - Returns: Intent dataclass                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 2. Router.dispatch(intent)                                          │    │
│  │    - Iterates through registered bots in priority order             │    │
│  │    - Calls bot.can_handle(intent) for each bot                      │    │
│  │    - First matching bot handles the intent                          │    │
│  │    - Returns: response string or None                               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│       │                                                                      │
│       ├── Bot matched? ──────────────────────────────────────────────────▶ │
│       │                                                                      │
│       ▼ (no bot matched)                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 3. Fallback: parse_natural_language(text)                           │    │
│  │    - Legacy command parser                                          │    │
│  │    - Returns: CommandPlan (command, args)                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│       │                                                                      │
│       ├── command == "chat"? ─────────▶ run_mock() ────────────────────▶   │
│       │                                 (or run_llama if configured)        │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 4. run_system_command(plan)                                         │    │
│  │    - Executes via bin/aios-sys                                      │    │
│  │    - Returns: command output                                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│       │                                                                      │
│       ▼                                                                      │
│  Response Output (stdout)                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Files

| Component | File | Description |
|-----------|------|-------------|
| IntentEngine | `ai/core/intent_engine.py` | Rule-based intent classification |
| Router | `ai/core/router.py` | Intent → Bot dispatcher |
| Bots | `ai/core/bots.py` | Domain-specific handlers |
| Commands | `ai/core/commands.py` | Legacy command parser |
| LLaMA Client | `ai/core/llama_client.py` | LLM/mock inference |
| AI Backend | `ai/core/ai_backend.py` | Main entry point |

---

## AI Backend CLI Interface

### Basic Usage

```bash
python3 ai/core/ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--input` | Yes | User input string (natural language) |
| `--os-root` | Yes | Path to OS_ROOT jail directory |
| `--aios-root` | Yes | Path to AIOS project root |
| `--json-output` | No | Wrap response in JSON format |

### Output Formats

#### Standard Output (default)
```
<response text>
```

#### JSON Output (`--json-output`)
```json
{"status":"ok","response":"<response text>","intent":"<category>.<action>"}
```

### Examples

```bash
# Standard query
python3 ai/core/ai_backend.py \
    --input "check system health" \
    --os-root /path/to/OS \
    --aios-root /path/to/PROJECT

# JSON output
python3 ai/core/ai_backend.py \
    --input "show logs" \
    --os-root /path/to/OS \
    --aios-root /path/to/PROJECT \
    --json-output
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (argument parsing, import failure) |

---

## Adding New Bots

Bots are domain-specific handlers that respond to classified intents.

### Step 1: Create Bot Class

In `ai/core/bots.py`:

```python
class MyNewBot(BaseBot):
    """Handles my domain-specific queries."""
    
    name = "MyNewBot"
    _CATEGORIES = {"mydomain"}
    _ACTIONS = {"action1", "action2"}
    
    def can_handle(self, intent: Intent) -> bool:
        """Return True if this bot can handle the intent."""
        return (
            intent.category in self._CATEGORIES or
            intent.action in self._ACTIONS
        )
    
    def handle(self, intent: Intent) -> str:
        """Process the intent and return a response."""
        action = intent.action
        
        if action == "action1":
            return self._do_action1(intent)
        elif action == "action2":
            return self._do_action2(intent)
        
        return self._default_handler(intent)
    
    def _do_action1(self, intent: Intent) -> str:
        # Implementation
        return "[MyNewBot] Action 1 result"
    
    def _do_action2(self, intent: Intent) -> str:
        # Implementation
        return "[MyNewBot] Action 2 result"
    
    def _default_handler(self, intent: Intent) -> str:
        return f"[MyNewBot] Unknown action: {intent.action}"
```

### Step 2: Register Bot in Router

In `ai/core/router.py`, add to `_init_bots()`:

```python
def _init_bots(self) -> List[BaseBot]:
    """Instantiate all registered bots in priority order."""
    return [
        MyNewBot(os_root=self.os_root),  # Add new bot
        RepairBot(os_root=self.os_root),
        HealthBot(os_root=self.os_root),
        LogBot(os_root=self.os_root),
    ]
```

**Note**: Bots are checked in order. Place high-priority bots first.

### Step 3: Add Intent Rules (Optional)

If your bot handles new categories/actions, add rules to `intent_engine.py`:

```python
_RULES: List[tuple] = [
    # ... existing rules ...
    
    # --- mydomain ---
    ("mydomain", "action1", ("trigger1", "trigger2"), None),
    ("mydomain", "action2", ("trigger3 ",), "entity_name"),
]
```

### BaseBot Utilities

All bots inherit these helper methods:

| Method | Description |
|--------|-------------|
| `_log_path(name)` | Get path to a log file in OS_ROOT |
| `_read_file(rel_path, max_lines)` | Read last N lines from a file |
| `_run(cmd, timeout)` | Run a subprocess command |

---

## Adding New Intent Categories

The IntentEngine uses rule tables for classification.

### Rule Format

```python
(category, action, trigger_words, entity_slot)
```

| Field | Type | Description |
|-------|------|-------------|
| `category` | str | High-level category (command, health, repair, etc.) |
| `action` | str | Specific action (fs.ls, check, self-repair) |
| `trigger_words` | tuple | Phrases that trigger this rule |
| `entity_slot` | str/None | Entity name to extract (or None) |

### Trigger Word Patterns

```python
# Exact match (no trailing space)
("myaction", "do_thing", ("thing", "do thing"), None)
# Matches: "thing", "do thing", "thing foo"

# Prefix match (trailing space)
("myaction", "do_thing", ("thing ",), "target")
# Matches: "thing foo" -> extracts "foo" as entity
```

### Example: Adding a "backup" Category

```python
_RULES: List[tuple] = [
    # ... existing rules ...
    
    # --- backup ---
    ("backup", "create",  ("backup", "create backup", "save state"), None),
    ("backup", "restore", ("restore ", "restore backup "), "target"),
    ("backup", "list",    ("list backups", "show backups"), None),
]
```

Then create a `BackupBot` to handle these intents.

### Testing Intents

```python
from intent_engine import IntentEngine

engine = IntentEngine()
intent = engine.classify("backup my data")
print(f"Category: {intent.category}")
print(f"Action: {intent.action}")
print(f"Confidence: {intent.confidence}")
```

---

## Structured Logging Format

AI queries are logged in JSON format to `OS/var/log/ai-queries.log`.

### Log Entry Format

```json
{
  "ts": "2026-04-04T03:00:00Z",
  "level": "INFO",
  "component": "ai-backend",
  "input": "user query text",
  "intent": "category.action",
  "confidence": 0.95,
  "response_length": 256,
  "duration_ms": 45
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string | ISO 8601 timestamp |
| `level` | string | Log level (INFO, WARN, ERROR) |
| `component` | string | Component name |
| `input` | string | Original user input |
| `intent` | string | Classified intent (category.action) |
| `confidence` | float | Classification confidence (0.0-1.0) |
| `response_length` | int | Length of response in characters |
| `duration_ms` | int | Processing time in milliseconds |

### Shell Logging

The `log_structured()` function in `lib/aura-core.sh` outputs JSON:

```bash
log_structured "INFO" "component-name" "message" '"extra":"data"'
```

Output:
```json
{"ts":"2026-04-04T03:00:00Z","level":"INFO","component":"component-name","msg":"message","extra":"data"}
```

---

## LLM Integration

### Architecture

```
┌──────────────────────┐
│   AI Backend         │
│   (ai_backend.py)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   LLaMA Client       │
│   (llama_client.py)  │
├──────────────────────┤
│ Backend: mock        │ ◀── Default (no model required)
│ Backend: llama       │ ◀── Requires llama-cli + .gguf model
└──────────────────────┘
```

### Configuration

In `etc/aios.conf`:

```bash
# Backend selection
AI_BACKEND=mock    # Built-in responses (default)
AI_BACKEND=llama   # Real LLM inference

# LLaMA settings (when AI_BACKEND=llama)
LLAMA_MODEL_PATH=/path/to/model.gguf
LLAMA_CTX=4096
LLAMA_THREADS=4
```

### Mock Backend

The mock backend provides context-aware responses without requiring a model:

- Greetings and help
- AIOS usage guidance
- Model setup instructions
- Command documentation

### LLaMA Backend

Requirements:
1. `llama-cli` binary in PATH (from llama.cpp)
2. GGUF model file (e.g., `Llama-3.2-3B-Instruct-Q4_K_M.gguf`)

Setup:
```bash
# 1. Build llama.cpp
bash build/build.sh --target hosted

# 2. Download model
# Place in llama_model/ directory

# 3. Configure
# Edit etc/aios.conf:
AI_BACKEND=llama
LLAMA_MODEL_PATH=/path/to/model.gguf
```

### Streaming Support

For real-time output:

```python
from llama_client import stream_mock, stream_llama

# Stream mock responses
for chunk in stream_mock("hello"):
    print(chunk, end="", flush=True)

# Stream LLM responses
for chunk in stream_llama(model_path, ctx, threads, prompt):
    print(chunk, end="", flush=True)
```

---

## Testing

Use `tools/ai-test.sh` to verify the AI pipeline:

```bash
bash tools/ai-test.sh
```

This tests:
- Health queries
- Log queries
- Repair queries
- Unknown queries
- LLM availability (non-fatal)
