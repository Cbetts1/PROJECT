# Contributing to AIOS-Lite

Thank you for your interest in contributing to **AIOS-Lite**. This guide explains how to participate in the project respectfully and effectively.

---

## Table of Contents

- [Before You Start](#before-you-start)
- [Code Standards](#code-standards)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Reporting Issues](#reporting-issues)
- [Feature Requests](#feature-requests)
- [Safe and Respectful Collaboration](#safe-and-respectful-collaboration)

---

## Before You Start

1. **Read the documentation.** Familiarise yourself with the [README](README.md), [docs/MANUAL.md](docs/MANUAL.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before making changes.
2. **Open an issue first.** For any non-trivial change (new feature, architectural change, refactor), open a GitHub Issue to discuss your proposal before writing code. This avoids duplicated effort and keeps the project coherent.
3. **Fork the repository.** Work in your own fork. Do not push directly to `main`.
4. **Keep changes focused.** One pull request should address one concern. Avoid bundling unrelated changes.

---

## Code Standards

### Shell Scripts

- Use POSIX sh syntax unless a specific bash feature is explicitly required and clearly documented.
- Use `shellcheck` to lint all shell scripts before submitting. Zero warnings is the target.
- Indent with 4 spaces. No tabs.
- Quote all variable expansions (`"$VAR"`, not `$VAR`) unless word-splitting is intentional.
- Use `set -euo pipefail` at the top of all non-trivial scripts.
- Keep lines under 100 characters where practical.
- Comment non-obvious logic. Match the existing comment style (inline `#` or block comment headers).

### Python

- Targets Python 3.8+. Use only the standard library plus explicitly declared dependencies.
- Follow [PEP 8](https://pep8.org/) style. Run `flake8` before submitting.
- Use type hints for all function signatures.
- Docstrings are required for all public functions and classes (Google-style preferred).
- Do not add new `pip` dependencies without prior discussion in an issue.

### Configuration Files

- Use existing key naming conventions in `config/aios.conf` and `etc/aios.conf`.
- Do not commit sensitive values (tokens, passwords, personal paths).

### Documentation

- Write in clear, professional British or American English.
- Update the relevant documentation file when behaviour changes.
- Use Markdown tables and code blocks consistently with the existing docs style.

---

## Submitting Pull Requests

1. **Branch from `main`** using a descriptive branch name:
   ```
   feature/ios-bridge-improvements
   fix/heartbeat-sigterm-handling
   docs/update-install-guide
   ```

2. **Write meaningful commit messages.** Use the imperative mood:
   - `Add retry logic to SSH bridge module`
   - `Fix typo correction false positives in aura-typo.sh`
   - `Update AI_MODEL_SETUP.md with Q4_K_M benchmark results`

3. **Run the test suite before opening a PR:**
   ```sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
   python3 tests/test_python_modules.py
   ```
   All tests must pass.

4. **Fill in the PR template completely.** Describe what you changed, why, and how to test it.

5. **Expect review feedback.** Respond to review comments promptly and courteously. Maintain a constructive tone.

6. **Do not merge your own PRs.** Wait for maintainer approval.

### PR Checklist

- [ ] Tests pass locally
- [ ] Shell scripts pass `shellcheck` with no warnings
- [ ] Python code passes `flake8`
- [ ] Documentation updated where applicable
- [ ] No secrets or personal data committed
- [ ] PR description clearly explains the change and how to verify it

---

## Reporting Issues

Use [GitHub Issues](https://github.com/Cbetts1/PROJECT/issues) to report bugs.

**When filing a bug report, include:**

- AIOS-Lite version (check `config/aios.conf` → `AIOS_VERSION`)
- Operating system and shell environment (e.g., Termux on Android 14, Ubuntu 22.04 bash 5.1)
- Steps to reproduce the problem (exact commands)
- Expected behaviour
- Actual behaviour / error output (use code blocks)
- Relevant log excerpts from `OS/var/log/`

**Security vulnerabilities** must **not** be reported in public issues. Please contact the maintainer directly via the repository contact information.

---

## Feature Requests

Open a GitHub Issue with the label `enhancement`. Describe:

- The use case or problem you are solving
- Your proposed solution or interface
- Any alternatives you considered

Feature requests are evaluated against the project's core goals: portability, AI integration, cross-OS bridging, and minimal dependencies.

---

## Safe and Respectful Collaboration

All contributors are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

In practical terms:

- Be constructive, patient, and professional in all communications.
- Assume good faith in others' contributions.
- Disagreements about technical direction should be resolved through reasoned discussion, not personal criticism.
- Contributions of all sizes are welcome — a corrected typo is as legitimate as a new subsystem.
- The maintainer reserves the right to decline contributions that conflict with the project's goals, quality standards, or values.

---

*AIOS-Lite — Built by Christopher Betts*
*© 2026 Christopher Betts. All rights reserved.*
