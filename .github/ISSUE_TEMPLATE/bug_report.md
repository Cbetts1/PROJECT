---
name: Bug Report
about: Report a defect in AIOS-Lite
title: "[BUG] "
labels: "type: bug, status: triage"
assignees: ""
---

## Summary

<!-- One sentence description of the bug -->

## Environment

- **Platform**: <!-- Termux/Android | Debian/Ubuntu | macOS | Raspberry Pi | Other -->
- **AIOS-Lite version**: <!-- run: cat $OS_ROOT/etc/os-release -->
- **Shell**: <!-- bash / zsh / sh / other -->
- **AI backend**: <!-- llama.cpp + model name, or none (rule-based fallback) -->
- **Connected devices** (if relevant): <!-- iOS | Android | Linux/SSH | None -->

## Steps to Reproduce

1. 
2. 
3. 

## Expected Behaviour

<!-- What should happen -->

## Actual Behaviour

<!-- What actually happens -->

## Logs / Error Output

```
<!-- Paste relevant log output from $OS_ROOT/var/log/ here -->
<!-- To view logs: tail -50 $OS_ROOT/var/log/aura.log -->
```

## Severity Assessment

- [ ] **P1 Critical** — OS cannot boot, data loss, or security vulnerability
- [ ] **P2 Major** — Core feature broken, no workaround
- [ ] **P3 Minor** — Limited impact, workaround exists

## Additional Context

<!-- Screenshots, related issues, or any other relevant information -->
