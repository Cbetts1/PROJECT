# AIOS-Lite — Privacy Policy

> © 2026 Christopher Betts | AIOS-Lite / AIOSCPU Official  
> Author: Christopher Betts  
> AI-Generated Original Content — No Open-Source Template Reproduction

---

## 1. Introduction

This Privacy Policy explains what data AIOS-Lite and the AURA agent collect, where that data
is stored, and how it is used. Christopher Betts ("the Author") is committed to protecting
the privacy of all users ("the User") of this Software.

---

## 2. Guiding Principle: Local-First, No Telemetry

AIOS-Lite is designed as a **local-only** system. The Software does not include any telemetry
module, analytics SDK, crash reporter, or remote logging service. By default, **no data of
any kind leaves the User's device**.

---

## 3. Data Collected by the Software

### 3.1 AURA Memory Database

AURA stores key/value pairs and semantic embeddings in a local database at:

```
$OS_ROOT/var/lib/aura/aura-memory.db
```

This data consists solely of information the User explicitly provides to the AURA agent
(e.g., `mem.set name "Chris"`). It is stored on the User's local filesystem only.

### 3.2 System Logs

The Software writes operational logs to files under `$OS_ROOT/var/log/`. These logs record:

- Shell commands executed within the AIOS environment.
- Service start/stop events.
- Bridge connection and mirroring activity.
- AURA agent command invocations (including commands passed to `aioscpu-secure-run`).

Logs are auto-rotated at 1,000 lines. They remain on the User's local device and are never
transmitted externally.

### 3.3 Bridge and Mirror Data

When the User activates the cross-OS bridge (iOS, Android, Linux/SSH), the Software may
read file listings, metadata, or file contents from connected devices and cache them in:

```
$OS_ROOT/mirror/
```

This data originates from devices the User explicitly connects. It is not forwarded to the
Author or any third party.

### 3.4 No Automatic System-Information Harvest

The Software does not automatically fingerprint or harvest: device identifiers, network MAC
addresses, geographic location, IP addresses, browser history, or any personal files outside
the explicitly mounted mirror paths.

---

## 4. Optional External LLM Backend

If the User configures an external model backend (by setting `model_backend` in
`etc/aios.conf` or `aura-config.json`), prompts sent to the AI shell may be transmitted
to that external service. In this case:

- The User bears sole responsibility for the privacy implications of that transmission.
- The Author recommends reviewing the privacy policy of the chosen backend provider before
  enabling this feature.
- The Software provides a local llama.cpp integration as a privacy-preserving alternative.

---

## 5. SSH and Remote Bridge

When the User mounts a remote Linux/macOS host via SSH (`os-mirror mount ssh <host>`), the
Software connects using the User's own credentials. No session data, credentials, or remote
file contents are stored by the Author or transmitted anywhere beyond the User's own devices.

---

## 6. No Advertising, No Data Sales

The Author does not display advertisements within the Software, does not sell user data, and
does not share user data with any third parties.

---

## 7. Children's Privacy

The Software is not directed at children under 13 years of age. The Author does not
knowingly collect any personal information from children.

---

## 8. Data Security

The User is responsible for securing the device on which AIOS-Lite runs, including:

- Setting appropriate file-system permissions on `$OS_ROOT`.
- Protecting any SSH keys or authentication tokens used with the bridge modules.
- Restricting physical and network access to the device.

The Author makes no warranty regarding the security of the local data store or log files if
the User's device is compromised.

---

## 9. Data Retention and Deletion

All data created by AIOS-Lite resides on the User's own filesystem. The User may delete any
or all of this data at any time by removing the relevant files or the entire `$OS_ROOT`
directory. The Author retains no copy of User data.

---

## 10. Changes to This Privacy Policy

The Author may revise this Privacy Policy at any time by publishing an updated version in the
project repository. The User is encouraged to review this document periodically. Continued
use of the Software after a revision constitutes acceptance of the updated Policy.

---

## 11. Contact

For privacy-related enquiries, open an issue in the project repository:
<https://github.com/Cbetts1/PROJECT>

---

*Last updated: 2026 — Christopher Betts*
