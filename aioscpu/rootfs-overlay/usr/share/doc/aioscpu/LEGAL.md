# AIOSCPU Legal Notice

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

This is the in-system copy of the AIOSCPU legal notice, installed at
`/usr/share/doc/aioscpu/LEGAL.md` on the running system.

For the full legal documentation, see `/usr/share/doc/aioscpu/LEGAL.md`
or the project repository at: https://github.com/Cbetts1/PROJECT

---

## Summary

AIOSCPU includes **AURA**, an AI agent that can:
- Read system information (CPU, memory, disk, network)
- Execute commands **only** through a secure, audited wrapper
- Store data in a local SQLite database

AURA **cannot** log in interactively, execute destructive commands
(rm -rf /, mkfs, raw disk writes), or transmit data externally by default.

All AURA-triggered command executions are logged to:
  `/var/log/aioscpu-secure-run.log`

## Disclaimer

AIOSCPU is provided **"as is", without warranty of any kind**.
The authors are not liable for any damages arising from use.

You are responsible for securing your installation.
Change the default `aios` password immediately after first boot.

## Watermark

```
© 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
```

This watermark must be preserved in all distributions of AIOSCPU.

---

See also:
- `/usr/share/doc/aioscpu/AURA-API.md` — AURA command reference
- Project repository: https://github.com/Cbetts1/PROJECT
