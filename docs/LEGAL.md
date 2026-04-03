# AIOS-Lite — Legal and Compliance Package

> © 2026 Christopher Betts | AIOSCPU Official

---

## Table of Contents

1. [Copyright Notice](#1-copyright-notice)
2. [Authorship Statement](#2-authorship-statement)
3. [AI-Generated Code Disclosure](#3-ai-generated-code-disclosure)
4. [MIT License](#4-mit-license)
5. [Terms of Use](#5-terms-of-use)
6. [Privacy Notice](#6-privacy-notice)
7. [Disclaimer](#7-disclaimer)
8. [Third-Party Notices](#8-third-party-notices)

---

## 1. Copyright Notice

Copyright © 2026 Christopher Betts. All rights reserved.

The name **AIOS-Lite**, the name **AURA**, the **AIOSCPU** brand, and all associated logos, branding materials, and documentation in this repository are the intellectual property of Christopher Betts.

The source code in this repository is licensed under the MIT License (see §4). All documentation, branding, and non-code assets are copyright © 2026 Christopher Betts and may not be reproduced without attribution.

---

## 2. Authorship Statement

*Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

Christopher Betts is the sole originator, designer, and maintainer of the AIOS-Lite project. The creative direction, system architecture, design decisions, and overall vision of the project are the intellectual work of Christopher Betts. AI tools were used as instruments of implementation under his direct supervision and editorial control.

---

## 3. AI-Generated Code Disclosure

This project contains code that was generated or refined using artificial intelligence tools, including but not limited to large language models. The following disclosures apply:

- **Human oversight**: All AI-generated code was reviewed, edited, tested, and accepted by Christopher Betts. No code was committed to this repository without human review.
- **Responsibility**: Christopher Betts accepts full responsibility for the contents of this repository, including any AI-generated portions, as though each line were written entirely by hand.
- **No implied warranty from AI tools**: The use of AI tools does not transfer any warranty, indemnity, or intellectual property from the AI tool provider to this project. The AI tools used were accessed under their respective terms of service.
- **Originality**: To the best of the creator's knowledge, the AI-generated code in this repository does not reproduce any copyrighted work in substantial or recognisable form. If any such reproduction is identified, please raise an issue and it will be addressed promptly.
- **AI tool providers**: Code generation tools used may include services offered by Anthropic, OpenAI, or similar providers. This disclosure is made in the spirit of transparency and does not imply affiliation with or endorsement by those providers.

---

## 4. MIT License

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

---

## 5. Terms of Use

**Effective date: 2026-01-01**

By cloning, installing, running, or distributing AIOS-Lite (the "Software"), you ("User") agree to the following terms.

### 5.1 Permitted Uses

- Running the Software for personal, educational, research, or commercial purposes, subject to the MIT License.
- Modifying the Software and distributing modifications, provided the MIT License copyright notice is retained.
- Integrating the Software into other projects, provided attribution is given to Christopher Betts.

### 5.2 Prohibited Uses

Users may not:

- Use the Software to gain unauthorised access to computer systems, networks, or data.
- Use the Software to collect, harvest, or store personal data of other individuals without their knowledge and consent.
- Remove, obscure, or alter the copyright notice, authorship statement, or AI-generated code disclosure.
- Represent the Software as their own original work without attribution to Christopher Betts.
- Use the Software in any manner that violates applicable laws or regulations in the User's jurisdiction.

### 5.3 AI and Automation Capabilities

AIOS-Lite includes an AI agent (AURA) and automation capabilities. Users are solely responsible for how they configure and use these features. The creator is not liable for any actions taken by the AI agent or automation scripts configured by the User.

### 5.4 No Support Obligation

The Software is provided on an "as is" basis. Christopher Betts has no obligation to provide support, maintenance, updates, or bug fixes, though contributions and issues are welcome via GitHub.

### 5.5 Governing Law

These terms are governed by the laws of England and Wales. Any disputes arising from use of the Software shall be subject to the exclusive jurisdiction of the courts of England and Wales.

---

## 6. Privacy Notice

**Effective date: 2026-01-01**

### 6.1 Data Collected by AIOS-Lite

AIOS-Lite is a **locally running system**. By default:

- **No data is transmitted to any external server** by the Software itself.
- All memory, logs, and state are stored locally on the user's device inside `$OS_ROOT/`.
- AURA's memory database (if SQLite backend is enabled) is stored at `$OS_ROOT/var/lib/aura/aura-memory.db`.
- System logs are written to `$OS_ROOT/var/log/`.

### 6.2 LLM / AI Model

If the user configures AIOS-Lite to use a **remote AI backend** (e.g., an API endpoint), queries sent to that backend are subject to the privacy policy of that third-party service. AIOS-Lite itself does not control or log what those third-party services do with data. The default configuration uses a **local llama.cpp model** with no network connectivity.

### 6.3 Bridge and Mirror Features

When using bridge features (iOS, Android, SSH), AIOS-Lite may read filesystem data from connected devices. This data:

- Is only accessed in response to explicit User commands.
- Is cached in `$OS_ROOT/mirror/` on the User's device.
- Is never transmitted externally by AIOS-Lite.

### 6.4 No Tracking or Analytics

AIOS-Lite contains no telemetry, analytics, crash reporting, or usage tracking. The creator receives no data about how the Software is used.

### 6.5 User Responsibility

Users who deploy AIOS-Lite in a context where it processes other people's data are responsible for complying with all applicable privacy laws (including GDPR, UK GDPR, CCPA, or other applicable frameworks).

### 6.6 Contact

To report a privacy concern, open an issue at: https://github.com/Cbetts1/PROJECT/issues

---

## 7. Disclaimer

### 7.1 No Warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT.

### 7.2 Limitation of Liability

IN NO EVENT SHALL CHRISTOPHER BETTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### 7.3 AI Outputs

AIOS-Lite includes AI-powered features. AI-generated responses may be inaccurate, incomplete, or misleading. Users must not rely on AI outputs for safety-critical decisions, medical advice, legal advice, or financial advice. Christopher Betts accepts no liability for any loss or damage resulting from reliance on AI-generated outputs.

### 7.4 Third-Party Integrations

AIOS-Lite may interact with third-party devices and services (iOS, Android, SSH hosts, LLM APIs). Christopher Betts is not responsible for the behaviour of, or any damage caused by, third-party systems.

### 7.5 Experimental Software

AIOS-Lite is an experimental project. It has not been certified, audited, or approved for use in production, safety-critical, or regulated environments.

---

## 8. Third-Party Notices

Third-party open-source components used as system dependencies are listed in [`licenses/THIRD_PARTY_LICENSES.md`](../licenses/THIRD_PARTY_LICENSES.md).

AIOS-Lite does not embed third-party source code in this repository. All third-party tools are installed as host dependencies at the user's discretion.

---

*End of Legal and Compliance Package*

> © 2026 Christopher Betts | AIOS-Lite | https://github.com/Cbetts1/PROJECT
