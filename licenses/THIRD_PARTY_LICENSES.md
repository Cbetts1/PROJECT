# Third-Party Licenses

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

AIOSCPU is built on open-source foundations. The following third-party
components are used as **system dependencies** — they are not embedded
in this repository as source code, but are installed at build time via
`debootstrap` / `apt`.

All licenses listed here are the licenses of the respective upstream projects.
AIOSCPU itself is distributed under the terms stated in `docs/LEGAL.md`.

---

## Linux Kernel

- **License:** GPL-2.0-only (with syscall note exception)
- **URL:** <https://kernel.org>
- **Notes:** The Linux kernel is used as the OS kernel. No kernel source is
  modified or distributed in this repository.

---

## Debian GNU/Linux

- **License:** Various (Debian Free Software Guidelines — DFSG-compliant mix
  of GPL, LGPL, MIT, BSD, and others)
- **URL:** <https://www.debian.org/legal/licenses/>
- **Notes:** The Debian userland and package ecosystem are used as the base OS.
  Individual package licenses are available inside the image at
  `/usr/share/doc/<package>/copyright`.

---

## GNU GRUB (GRand Unified Bootloader)

- **License:** GPL-3.0-or-later
- **URL:** <https://www.gnu.org/software/grub/>
- **Notes:** Used as the bootloader for the AIOSCPU disk image.

---

## Python

- **License:** PSF License (Python Software Foundation License) version 2
- **URL:** <https://docs.python.org/3/license.html>
- **Notes:** Python 3 is used for the AURA agent (`aura-agent.py`) and any
  future AI model integration.

---

## SQLite

- **License:** Public Domain
- **URL:** <https://sqlite.org/copyright.html>
- **Notes:** Used by the AURA agent for persistent memory storage. SQLite is
  entirely in the public domain — no license restrictions apply.

---

## GNU Coreutils

- **License:** GPL-3.0-or-later
- **URL:** <https://www.gnu.org/software/coreutils/>
- **Notes:** Standard Unix utilities (ls, cp, mv, etc.) used throughout
  AIOSCPU shell scripts.

---

## GNU Bash

- **License:** GPL-3.0-or-later
- **URL:** <https://www.gnu.org/software/bash/>
- **Notes:** All AIOSCPU shell scripts use Bash (`#!/usr/bin/env bash`).

---

## NetworkManager

- **License:** GPL-2.0-or-later
- **URL:** <https://networkmanager.dev>
- **Notes:** Used for Wi-Fi, hotspot, and network management via `nmcli`.
  Wrapped by `aioscpu-wifi` and `aioscpu-hotspot`.

---

## BlueZ

- **License:** GPL-2.0-or-later
- **URL:** <http://www.bluez.org>
- **Notes:** Linux Bluetooth stack used by `aioscpu-bt` for device
  scanning, pairing, and connection management.

---

## OpenSSH

- **License:** BSD/MIT-like (OpenSSH license — see upstream)
- **URL:** <https://www.openssh.com/security.html>
- **Notes:** Used for remote shell access to AIOSCPU. The OpenSSH license
  is a permissive BSD-style license.

---

## Notice

All the above are **system-level dependencies** installed at image build time.
None of their source code is reproduced or distributed in this repository.
Each package's full license text is available inside the built image at
`/usr/share/doc/<package>/copyright`.

For questions about license compliance, contact the maintainer via the
project repository at <https://github.com/Cbetts1/PROJECT>.
