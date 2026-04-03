# Networking Model — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOS-Lite's networking model operates at the **application layer** of the
host OS network stack. It does not implement kernel-level drivers. Instead,
it:

1. Queries and configures the host OS network via standard POSIX tools
2. Provides a unified `os-netconf` interface for network management
3. Implements device-to-device bridging over the cross-OS bridge
4. Exposes network primitives as syscalls (see `docs/SYSCALL-LIST.md`)

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AIOS-Lite Network Stack                      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Application Layer                       │  │
│  │  os-shell  |  os-httpd  |  aura-agent  |  bridge mods    │  │
│  └────────────────────────────┬──────────────────────────────┘  │
│                               │                                 │
│  ┌────────────────────────────▼──────────────────────────────┐  │
│  │                  AIOS Network API (os-netconf)             │  │
│  │  net.ping  |  net.dns  |  net.http  |  net.iflist         │  │
│  │  net.route  |  net.wifi  |  net.bt                        │  │
│  └────────────────────────────┬──────────────────────────────┘  │
│                               │                                 │
│  ┌────────────────────────────▼──────────────────────────────┐  │
│  │              Host OS Network Stack                         │  │
│  │  Wi-Fi (wpa_supplicant / nmcli / Termux)                  │  │
│  │  Bluetooth (bluetoothctl / hcitools)                       │  │
│  │  IP / TCP / UDP (host kernel)                             │  │
│  │  Routing (ip route / route)                               │  │
│  └─────────────────────────────────────────────────────────  ┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Network Layers

### Wi-Fi

AIOS delegates Wi-Fi management to the host OS. `os-netconf wifi` is a
thin wrapper:

```sh
# List available networks
os-netconf wifi scan

# Connect to a network
os-netconf wifi connect <SSID> [password]

# Show current connection
os-netconf wifi status

# Disconnect
os-netconf wifi disconnect
```

**Backend tool selection** (in priority order):

| Platform | Tool |
|----------|------|
| Linux / Debian | `nmcli` |
| Termux / Android | `termux-wifi-connectioninfo`, `termux-wifi-scaninfo` |
| macOS | `networksetup` |
| Generic POSIX | `wpa_cli` |

---

### Bluetooth

Bluetooth is managed via `os-netconf bt`:

```sh
# Enable/disable Bluetooth
os-netconf bt on
os-netconf bt off

# Scan for devices
os-netconf bt scan

# Pair with device
os-netconf bt pair <MAC>

# Connect to device
os-netconf bt connect <MAC>

# List paired devices
os-netconf bt list
```

**Backend tool selection:**

| Platform | Tool |
|----------|------|
| Linux | `bluetoothctl` |
| Termux / Android | `termux-bluetooth-enable` / `hcitools` |
| macOS | `blueutil` (if installed) |

---

### IP Configuration

```sh
# Show all interfaces and IP addresses
os-netconf ip iflist

# Show interface details
os-netconf ip show <iface>

# Set static IP (requires host sudo/root)
os-netconf ip set <iface> <ip>/<prefix> <gateway>

# Use DHCP
os-netconf ip dhcp <iface>

# Show routing table
os-netconf ip route

# Add/delete route
os-netconf ip route add <dest>/<mask> via <gateway>
os-netconf ip route del <dest>/<mask>

# Flush interface
os-netconf ip flush <iface>
```

---

### DNS

```sh
# Query DNS
os-netconf dns lookup <hostname>

# Show current resolvers
os-netconf dns resolvers

# Set resolver (writes to /etc/resolv.conf if permitted)
os-netconf dns set <ip>

# Flush DNS cache (platform-dependent)
os-netconf dns flush
```

---

### Cross-OS Bridge Networking

The bridge layer uses the following network transports:

| Bridge | Transport | Port/Protocol |
|--------|-----------|--------------|
| iOS | USB (libimobiledevice) | — |
| Android | USB / TCP (ADB) | TCP 5037 |
| Linux remote | SSH | TCP 22 |
| SSHFS mount | SSH | TCP 22 |
| REST API | HTTP | TCP 8080 |
| WebSocket | WS/WSS | TCP 8080 |

---

### HTTP REST Server (`os-httpd`)

AIOS-Lite includes a lightweight HTTP server implemented in Python 3.

| Setting | Default |
|---------|---------|
| Listen address | `127.0.0.1` |
| Port | `8080` |
| Protocol | HTTP (HTTPS if cert configured) |
| Auth | Bearer token (set in `config/aios.conf`) |

Enable in `config/aios.conf`:

```sh
HTTPD_ENABLED=true
HTTPD_BIND=127.0.0.1
HTTPD_PORT=8080
HTTPD_TOKEN=changeme
```

See `docs/API-REFERENCE.md` §6 for the full REST endpoint list.

---

## Network Syscalls (os-syscall)

| Syscall | Arguments | Capability required |
|---------|-----------|-------------------|
| `net.ping` | `<host>` | `net.ping` |
| `net.dns` | `<hostname>` | `net.dns` |
| `net.http` | `<url>` | `net.http` |
| `net.iflist` | — | `net.read` |
| `net.route` | — | `net.read` |

Default AURA capabilities include `net.ping` and `net.dns` only.
`net.http` requires explicit grant.

---

## Firewall / Egress Policy

AIOS-Lite does not implement a firewall. It relies on the host OS.
The following egress is used by built-in components:

| Component | Destination | Port | Purpose |
|-----------|-------------|------|---------|
| `adb` bridge | Android device | 5037 | ADB protocol |
| SSH bridge | Remote host | 22 | SSHFS / remote shell |
| LLaMA (if cloud model) | Configured endpoint | 443 | AI inference |
| `os-httpd` | localhost | 8080 | REST API |

If no external model backend is configured (`model_backend` in
`aura-config.json`), AIOS has **no outbound network traffic** beyond
bridge connections.

---

## Network Configuration Templates

See `config/network.conf` for the full configuration template.

---

## Platform Notes

### Android / Termux

- Wi-Fi management uses `termux-wifi-*` APIs (requires Termux:API app)
- Bluetooth scanning requires Termux:API with location permission
- ADB bridge requires USB debugging enabled on the Android device

### Linux (Debian / Ubuntu)

- Wi-Fi via `nmcli` (NetworkManager must be running)
- Bluetooth via `bluetoothctl` (BlueZ)
- IP configuration via `ip` command (iproute2)

### macOS

- Wi-Fi via `networksetup -setairportnetwork`
- Bluetooth via `blueutil` (install with `brew install blueutil`)
- IP configuration via `ifconfig` / `networksetup`

---

*Last updated: 2026-04-03*
