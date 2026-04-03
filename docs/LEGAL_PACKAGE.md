# AIOS-Lite — Legal Package

**Project:** AIOS-Lite (AI-Augmented Portable Operating System)
**Repository:** <https://github.com/Cbetts1/PROJECT>
**Author:** Christopher Betts
**Effective Date:** 1 January 2026
**Last Revised:** 3 April 2026

> © 2026 Christopher Betts. All rights reserved.

---

## Table of Contents

1. [License](#1-license)
2. [Copyright Notice](#2-copyright-notice)
3. [Authorship Statement](#3-authorship-statement)
4. [AI-Generated Code Disclosure](#4-ai-generated-code-disclosure)
5. [Terms of Use](#5-terms-of-use)
6. [Privacy Notice](#6-privacy-notice)
7. [Disclaimer of Warranties](#7-disclaimer-of-warranties)
8. [Limitation of Liability](#8-limitation-of-liability)
9. [Third-Party Technologies](#9-third-party-technologies)
10. [Governing Principles](#10-governing-principles)

---

## 1. License

AIOS-Lite is released under the **MIT License**.

**Why MIT?** MIT was chosen because it is permissive, well-understood, and compatible with the open-source ecosystem on which AIOS-Lite builds. It allows users to use, copy, modify, merge, publish, distribute, sublicense, and sell the software with minimal restriction, while preserving the copyright attribution to Christopher Betts. It is consistent with the licenses of the primary open-source tools that AIOS-Lite integrates (llama.cpp, libimobiledevice, ADB tooling).

### Full MIT License Text

```
MIT License

Copyright (c) 2026 Christopher Betts

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

The full LICENSE file is available at the root of this repository: [`LICENSE`](../LICENSE).

---

## 2. Copyright Notice

```
© 2026 Christopher Betts
AIOS-Lite — AI-Augmented Portable Operating System
All rights reserved.
```

This copyright notice must be preserved in all copies or substantial portions of this software and its documentation.

Christopher Betts is the sole author and copyright holder of AIOS-Lite. All creative direction, system design, architecture decisions, and intellectual authorship originate with Christopher Betts.

---

## 3. Authorship Statement

**AIOS-Lite** was conceived, architected, and directed entirely by **Christopher Betts**.

Christopher Betts:
- Conceived the vision of a portable AI-augmented OS with cross-device bridging
- Designed the system architecture (AI pipeline, AURA framework, bridge subsystems, memory model)
- Directed all development decisions, including integration with third-party tools
- Supervised, reviewed, and curated all code produced for this project
- Holds sole authorship and copyright over the AIOS-Lite codebase

This statement is made in good faith for purposes of intellectual property identification, licensing clarity, and legal attribution.

---

## 4. AI-Generated Code Disclosure

**AIOS-Lite openly discloses the following:**

All or substantially all of the source code in this repository was generated or refined using AI tools, including large language models (LLMs), under the direct creative direction and supervision of Christopher Betts.

Specifically:
- Code was produced by or with the assistance of AI language models responding to prompts formulated by Christopher Betts.
- All generated code was reviewed, modified where necessary, integrated, and accepted by Christopher Betts as the responsible author.
- The creative vision, system design, functional requirements, and architectural decisions are entirely those of Christopher Betts.

This disclosure is made in accordance with emerging best practices for AI-assisted software development and in the spirit of transparency with users, contributors, and the open-source community.

**This disclosure does not diminish the copyright ownership or authorship rights of Christopher Betts,** who remains the legal author of the work under applicable copyright law principles governing works created using tools under an author's direction.

---

## 5. Terms of Use

By downloading, installing, running, copying, modifying, or distributing AIOS-Lite, you agree to the following terms.

### 5.1 Permitted Uses

Subject to the MIT License, you may:

- Use AIOS-Lite for any personal, educational, research, or commercial purpose
- Modify the source code to suit your requirements
- Distribute original or modified versions, provided copyright notices are preserved
- Incorporate AIOS-Lite into your own projects, subject to the MIT License terms

### 5.2 Prohibited Uses

You must not use AIOS-Lite to:

- Violate any applicable local, national, or international law or regulation
- Gain unauthorized access to any computer system, network, or device
- Circumvent security mechanisms on devices you do not own or have explicit permission to access
- Infringe the intellectual property rights of any third party
- Engage in any activity that could damage, disable, or impair any system, service, or infrastructure

### 5.3 User Responsibility

You are solely responsible for:

- All actions performed on systems running AIOS-Lite
- Ensuring your use complies with applicable laws in your jurisdiction, including laws governing AI agents, automated system access, and data privacy
- Securing your installation (restricting permissions, reviewing configurations, auditing access)
- The consequences of connecting AIOS-Lite to external devices or services
- Any data transmitted to or stored by third-party tools configured alongside AIOS-Lite (including external LLM backends)

### 5.4 Modifications and Distributions

If you distribute modified versions of AIOS-Lite, you must:

- Retain all original copyright notices
- Clearly mark your version as modified and distinct from the original
- Not represent your modified version as the official AIOS-Lite release

---

## 6. Privacy Notice

AIOS-Lite is designed to operate entirely on-device with no mandatory network communication or telemetry.

### 6.1 Data AIOS-Lite Stores Locally

AIOS-Lite may store the following data on your local filesystem under `$OS_ROOT/`:

| Data | Location | Purpose |
|---|---|---|
| Symbolic memory entries | `OS/var/` (memory index files) | User-defined named facts |
| Semantic memory entries | `OS/var/` (embedding index files) | Similarity-searchable memories |
| Context window | `OS/proc/` (runtime state files) | Recent commands and conversation |
| System logs | `OS/var/log/` | Operational logging and diagnostics |
| Audit log | `OS/var/log/aura.log` | AURA agent activity log |
| Heartbeat log | Configured via `HEARTBEAT_LOG_FILE` | Service health records |
| Bridge status | `OS/proc/` | Connected device state |

All data remains on the local device unless you explicitly configure an external service (such as a remote LLM backend).

### 6.2 Data AIOS-Lite Does NOT Collect

AIOS-Lite does **not**:

- Collect telemetry, analytics, or usage data
- Transmit any data to the AIOS-Lite author or any third party
- Access personal files beyond those you explicitly command it to access
- Maintain any remote database of user information

### 6.3 Third-Party LLM Backends

If you configure AIOS-Lite to use an **external** LLM backend (e.g., a remote API), any data you send to that backend is subject to that provider's privacy policy. You are solely responsible for this configuration and its privacy implications. AIOS-Lite's default configuration uses local llama.cpp inference only.

### 6.4 Bridge and Mirror Features

When you use the bridge and mirror features to connect to external devices (iOS, Android, SSH), you are explicitly directing AIOS-Lite to access those devices' filesystems. AIOS-Lite does not transmit mirrored data externally. You are responsible for ensuring you have the right to access any device you connect.

---

## 7. Disclaimer of Warranties

**AIOS-LITE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.**

To the maximum extent permitted by applicable law, Christopher Betts and the AIOS-Lite contributors disclaim all warranties, including but not limited to:

- Warranties of **merchantability**
- Warranties of **fitness for a particular purpose**
- Warranties of **non-infringement**
- Warranties that the software will be **error-free**, **uninterrupted**, or **secure**
- Warranties regarding the **accuracy or completeness** of outputs produced by the software or any integrated AI model

**You use AIOS-Lite at your own risk.**

This disclaimer applies to all components of AIOS-Lite, including the AI intent engine, the AURA framework, the bridge subsystems, and any integrated LLM functionality.

---

## 8. Limitation of Liability

To the maximum extent permitted by applicable law:

**In no event shall Christopher Betts or any contributor to AIOS-Lite be liable for any:**

- Direct, indirect, incidental, special, exemplary, or consequential damages
- Loss of data, loss of profits, loss of business, or business interruption
- Costs of procurement of substitute goods or services
- Personal injury or property damage
- Unauthorized access to or corruption of data

arising from or in connection with:

- Your use of or inability to use AIOS-Lite
- Actions taken by the AURA AI agent on your system
- Connections made to external devices via the bridge subsystem
- Outputs or recommendations produced by any integrated AI or LLM component
- Any security vulnerability in the software

**even if Christopher Betts has been advised of the possibility of such damages.**

Some jurisdictions do not allow the exclusion or limitation of certain warranties or liabilities. In such jurisdictions, the above limitations apply to the fullest extent permitted by law.

---

## 9. Third-Party Technologies

AIOS-Lite integrates with and is designed to operate alongside a number of third-party open-source tools. **Christopher Betts makes no copyright claims over any of these third-party technologies.**

| Technology | Purpose | License |
|---|---|---|
| llama.cpp | On-device LLM inference engine | MIT |
| libimobiledevice | iOS device communication | LGPL-2.1 |
| ifuse | iOS filesystem mounting | LGPL-2.1 |
| Android Debug Bridge (ADB) | Android device communication | Apache 2.0 |
| OpenSSH | Secure remote shell access | BSD |
| SSHFS | SSH filesystem mounting | GPL-2.0 |
| Python 3 | AI core runtime | PSF License |

Full license texts for all third-party components are available in [`licenses/THIRD_PARTY_LICENSES.md`](../licenses/THIRD_PARTY_LICENSES.md).

AIOS-Lite's compatibility with these tools does not imply endorsement by their respective authors or projects.

---

## 10. Governing Principles

This legal package is intended to be clear, honest, and fair. The governing principles are:

1. **Transparency** — All material facts about authorship, AI assistance, and data handling are disclosed.
2. **User autonomy** — Users retain full control over their data and systems.
3. **Open source integrity** — Third-party contributions and licenses are respected and attributed.
4. **Proportionality** — Legal protections are limited to what is reasonable and necessary for an open-source project of this nature.

If you have questions about this legal package, please open a GitHub Issue at <https://github.com/Cbetts1/PROJECT/issues>.

---

*© 2026 Christopher Betts. All rights reserved.*
*AIOS-Lite — AI-Augmented Portable Operating System*
*This watermark must be preserved in all distributions: © 2026 Christopher Betts | AIOS-Lite Official | AI-generated, fully legal*
