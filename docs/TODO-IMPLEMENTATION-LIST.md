# TODO Implementation List

> Generated: 2026-04-04
> Project: AIOS-Lite v0.1

This document catalogs all TODO, PLACEHOLDER, STUB, FIXME, and similar markers found in the codebase, with classification and implementation notes.

## Classification Key

| Status | Meaning |
|--------|---------|
| ✅ safe-to-remove | Code that can be safely removed with no functional impact |
| 🔧 must-implement | Code that needs to be implemented for full functionality |
| 📌 keep-as-stub | Intentional placeholder that should remain |

---

## Found Items

### tests/unit-tests.sh

| Line | Marker | Code | Classification | Notes |
|------|--------|------|----------------|-------|
| 21 | `_STUB_OS_LOG` | Variable name | 📌 keep-as-stub | Test fixture variable - intentionally named to indicate it's stub data for testing |
| 22 | `_STUB_OS_STATE` | Variable name | 📌 keep-as-stub | Test fixture variable - intentionally named to indicate it's stub data for testing |
| 28-34 | `_STUB_*` | Stub file creation | 📌 keep-as-stub | Creates temporary test fixtures if they don't exist - necessary for test isolation |
| 315-316 | `_STUB_*` | Cleanup | 📌 keep-as-stub | Cleans up test fixtures - pairs with creation code above |

**Rationale**: These are test fixtures that create minimal state files for unit tests. They ensure tests can run in isolation without requiring a full boot. The `_STUB_` prefix is a naming convention to indicate these are test stubs, not incomplete production code.

### docs/GOVERNANCE.md

| Line | Marker | Code | Classification | Notes |
|------|--------|------|----------------|-------|
| 119 | `RFC-XXXX` | Template placeholder | 📌 keep-as-stub | Template for RFC documents - `XXXX` should be replaced when creating actual RFCs |

**Rationale**: This is an intentional template placeholder in a governance document. It provides a format for future RFC submissions.

---

## Summary

| Classification | Count | Action Required |
|----------------|-------|-----------------|
| 📌 keep-as-stub | 6 | None - these are intentional |
| 🔧 must-implement | 0 | None |
| ✅ safe-to-remove | 0 | None |

**Conclusion**: The codebase is clean. All found markers are intentional test fixtures or documentation templates, not incomplete production code.

---

## Code Quality Notes

### Python AI Core (ai/core/)

The following files were reviewed and found to be complete implementations:

- `ai_backend.py` — Full AI dispatch backend with IntentEngine → Router → Bot pipeline
- `bots.py` — Complete implementations of HealthBot, LogBot, RepairBot
- `commands.py` — Complete command parser with all documented commands
- `fuzzy.py` — Complete fuzzy matching implementation
- `intent_engine.py` — Complete rule-based intent classification
- `llama_client.py` — Complete LLaMA client with mock fallback
- `router.py` — Complete intent router with bot registration

### Shell Libraries (lib/)

The following files were reviewed and found to be complete implementations:

- `aura-core.sh` — Core library with logging, command registry, path resolver
- `aura-fs.sh` — Filesystem operations
- `aura-proc.sh` — Process management
- `aura-net.sh` — Network operations
- `aura-typo.sh` — Typo correction
- `aura-llama.sh` — LLaMA wrapper
- `aura-ai.sh` — AI backend wrapper

### Services (OS/etc/init.d/)

All service scripts have complete start/stop implementations:

- `banner` — Complete
- `devices` — Complete
- `aura-bridge` — Complete
- `os-kernel` — Complete
- `aura-agents` — Complete
- `aura-tasks` — Complete
- `aura-llm` — Complete (newly added)

---

## Recommendations

1. **Keep test stubs**: The `_STUB_*` naming convention is clear and helpful
2. **Keep RFC template**: Useful for governance
3. **No cleanup needed**: Codebase is production-ready
