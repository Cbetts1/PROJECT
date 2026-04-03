# Maintainers

> **AIOS-Lite / AIOSCPU** — roles and responsibilities

---

## Project Lead

| Name | GitHub | Role |
|------|--------|------|
| **Christopher Betts** | [@Cbetts1](https://github.com/Cbetts1) | Founder, Lead Architect, Release Engineer |

### Responsibilities

Christopher Betts is responsible for:

- Overall project direction and roadmap
- Architecture decisions and design reviews
- Release management (versioning, tagging, changelogs)
- Security vulnerability triage and patch coordination
- Merging pull requests into the `main` branch
- Maintaining the GitHub repository, issue tracker, and discussions
- All legal and licensing matters

---

## Core Contributor Guidelines

There are currently no additional core contributors.  The project welcomes
contributions from the community.

If you make significant, sustained contributions to the codebase, you may be
invited to become a Core Contributor.  Core Contributors:

- Have write access to non-protected branches
- Are listed in this file under "Core Contributors"
- Participate in architecture discussions and release planning
- Help triage issues and review pull requests

---

## How to Contribute

1. Fork the repository: <https://github.com/Cbetts1/PROJECT>
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes with tests where applicable
4. Run the test suite:
   ```sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
   AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
   ```
5. Open a pull request against `main` with a clear description

All contributions are welcome: bug fixes, documentation improvements, new
bridge modules, AI core enhancements, security hardening, and more.

---

## Security Contact

To report a security vulnerability privately, open a GitHub Security Advisory:
<https://github.com/Cbetts1/PROJECT/security/advisories/new>

See [SECURITY.md](./SECURITY.md) for the full vulnerability reporting policy.

---

## Code of Conduct

Contributors are expected to be respectful and constructive in all
interactions.  Harassment, abuse, or discriminatory behaviour will not be
tolerated.

---

*Last updated: 2026-04-03*
