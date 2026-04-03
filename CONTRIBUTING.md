# Contributing to AIOS-Lite / AIOSCPU

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

Thank you for your interest in contributing! This document explains how to
participate in the project.

---

## Table of Contents

1. [Code of Conduct](#1-code-of-conduct)
2. [How to Report a Bug](#2-how-to-report-a-bug)
3. [How to Request a Feature](#3-how-to-request-a-feature)
4. [Development Environment](#4-development-environment)
5. [Branching Strategy](#5-branching-strategy)
6. [Commit Message Format](#6-commit-message-format)
7. [Pull Request Process](#7-pull-request-process)
8. [Coding Standards](#8-coding-standards)
9. [Testing Requirements](#9-testing-requirements)
10. [Documentation Requirements](#10-documentation-requirements)
11. [License Agreement](#11-license-agreement)

---

## 1. Code of Conduct

All contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Violations may result in removal from the project.

---

## 2. How to Report a Bug

1. Search [existing issues](https://github.com/Cbetts1/PROJECT/issues) first.
2. If the bug is new, open an issue using the **Bug Report** template.
3. Include:
   - OS / environment (Termux, Debian, macOS)
   - AIOS version (`cat OS/etc/os-release`)
   - Steps to reproduce
   - Expected behaviour vs. actual behaviour
   - Relevant log output from `OS/var/log/os.log`

---

## 3. How to Request a Feature

1. Open an issue using the **Feature Request** template.
2. Describe the problem the feature solves.
3. Propose an implementation approach if you have one.
4. Wait for maintainer review before starting significant work.

---

## 4. Development Environment

### Prerequisites

```sh
# Minimal (core OS)
POSIX sh, awk, grep, sed, cksum, python3

# Full development
python3 >= 3.9
bash >= 5.0
shellcheck        # shell script linting
pytest            # Python tests
```

### Clone and bootstrap

```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
```

### Run tests

```sh
# Unit tests (shell + Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python modules only
python3 tests/test_python_modules.py
```

---

## 5. Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable release branch |
| `develop` | Integration branch |
| `feature/<name>` | New features |
| `fix/<name>` | Bug fixes |
| `docs/<name>` | Documentation only |
| `hotfix/<name>` | Critical production fixes |

Always branch from `develop` for features and fixes.

---

## 6. Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples:**

```
feat(ai-core): add RepairBot restart handler
fix(os-sched): remove stale pid entries on startup
docs(kernel): expand syscall table with spawn examples
```

---

## 7. Pull Request Process

1. Fork the repository and create your branch from `develop`.
2. Ensure all existing tests pass.
3. Add new tests for any new functionality.
4. Update relevant documentation.
5. Run `shellcheck` on all modified shell scripts.
6. Open a pull request against `develop`.
7. Fill in the PR template completely.
8. A maintainer will review within 7 days.
9. Address review comments; the PR will be merged when approved.

---

## 8. Coding Standards

### Shell Scripts

- Use `#!/bin/sh` (POSIX sh) unless Bash-specific features are required.
- Use `#!/usr/bin/env bash` for Bash scripts.
- Pass `shellcheck` with no warnings (`shellcheck -S warning`).
- All paths through the OS boundary must use `OS/lib/filesystem.py` or
  the `os-syscall` interface — never raw `cat`/`echo` outside OS_ROOT.
- Functions must have descriptive names using `snake_case`.
- Variables are `UPPER_CASE` for globals, `lower_case` for locals.
- Quote all variable expansions: `"$VAR"`.

### Python

- Follow [PEP 8](https://peps.python.org/pep-0008/).
- Use type hints where practical.
- Maximum line length: 100 characters.
- Use `python3` — no Python 2 compatibility required.
- All public functions must have docstrings.

### Markdown

- Follow [CommonMark](https://commonmark.org/) spec.
- All documentation must include the AIOSCPU copyright watermark.
- Keep lines under 100 characters.

---

## 9. Testing Requirements

- All new shell commands must have a corresponding test in
  `tests/unit-tests.sh`.
- All new Python modules must have tests in `tests/test_python_modules.py`.
- Integration behaviour must be covered in `tests/integration-tests.sh`.
- Tests must be idempotent — no side effects on the host OS.

---

## 10. Documentation Requirements

- Every new command must be documented in `docs/API-REFERENCE.md`.
- New OS concepts must be referenced in the relevant spec document under
  `docs/`.
- Update `CHANGELOG.md` for every user-facing change.

---

## 11. License Agreement

By submitting a pull request, you agree that your contribution will be
licensed under the [MIT License](LICENSE) and you confirm that you have the
right to submit it under that license.

---

*Questions? Open a discussion or contact the maintainer via the repository.*
