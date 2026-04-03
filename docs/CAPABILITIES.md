# AIOS-Lite Capabilities Matrix

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## How to Read This Document

Each row describes one capability.  Columns indicate:

| Column | Meaning |
|--------|---------|
| **Status** | `✅ Implemented` / `⚠️ Partial` / `🔲 Planned` |
| **Component** | The file(s) that implement it |
| **Tested** | Whether automated tests cover it |
| **Principal** | Which permission role can invoke it |

---

## 1. OS Kernel & Boot

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Boot sequence (init, rc2.d runlevels) | ✅ | `OS/sbin/init`, `OS/etc/rc2.d/` | ✅ | system |
| Boot target selection | ✅ | `OS/etc/boot.target` | ✅ | system |
| Kernel daemon (heartbeat, pid tracking) | ✅ | `OS/etc/init.d/os-kernel` | ✅ | system |
| System call interface | ✅ | `OS/bin/os-syscall` | ✅ | operator |
| Process scheduler (priority round-robin) | ✅ | `OS/bin/os-sched` | ✅ | operator |
| Permissions model (capability-based) | ✅ | `OS/bin/os-perms` | ✅ | operator |
| Resource manager (CPU/mem/disk/thermal) | ✅ | `OS/bin/os-resource` | ✅ | operator |
| Recovery mode (repair, backup, restore) | ✅ | `OS/bin/os-recover` | ✅ | operator |
| OS state persistence | ✅ | `OS/proc/os.state`, `OS/proc/os.identity` | ✅ | system |
| Service registry | ✅ | `OS/bin/os-service`, `OS/bin/os-service-status` | ✅ | operator |
| Event bus | ✅ | `OS/bin/os-event`, `OS/bin/os-msg` | ✅ | operator |
| Log rotation | ✅ | `OS/sbin/init`, `OS/bin/os-recover` | ✅ | system |

---

## 2. AI Core

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Intent classification | ✅ | `ai/core/intent_engine.py` | ✅ | any |
| Multi-bot dispatch (Router) | ✅ | `ai/core/router.py` | ✅ | any |
| HealthBot (status, uptime, disk) | ✅ | `ai/core/bots.py:HealthBot` | ✅ | any |
| LogBot (read/write logs) | ✅ | `ai/core/bots.py:LogBot` | ✅ | any |
| RepairBot (self-repair, reinstall) | ✅ | `ai/core/bots.py:RepairBot` | ✅ | any |
| Fuzzy command matching | ✅ | `ai/core/fuzzy.py` | ✅ | any |
| LLaMA LLM inference | ✅ | `ai/core/llama_client.py` | ✅ | operator |
| Mock/rule-based AI fallback | ✅ | `ai/core/llama_client.py:run_mock` | ✅ | any |
| Natural-language command parsing | ✅ | `ai/core/commands.py` | ✅ | any |
| AI query dispatch (backend) | ✅ | `ai/core/ai_backend.py` | ✅ | any |

---

## 3. Memory System

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Context window (rolling 50-line) | ✅ | `OS/proc/aura/context/window` | ✅ | any |
| Symbolic key-value memory | ✅ | `OS/bin/os-shell` (mem.set/get) | ✅ | any |
| Semantic embedding memory | ✅ | `OS/bin/os-shell` (sem.set/search) | ✅ | any |
| Hybrid recall (context+symbolic+semantic) | ✅ | `OS/bin/os-shell` (recall) | ✅ | any |
| AURA persistent memory (SQLite) | ✅ | `aura/schema-memory.sql` | ⚠️ | aura |
| Memory scoped by principal | ✅ | `OS/proc/aura/memory/` | ✅ | any |

---

## 4. WWW / HTTP Infrastructure

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| HTTP REST server | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| HTTPS (TLS) support | ✅ | `OS/bin/os-httpd` (ssl module) | ⚠️ (requires openssl) | operator |
| Self-signed certificate generation | ✅ | `OS/bin/os-httpd --gen-cert` | ⚠️ | operator |
| Token-based authentication | ✅ | `OS/bin/os-httpd` + `OS/etc/api.token` | ✅ | operator |
| REST: GET /api/v1/status | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| REST: GET /api/v1/services | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| REST: GET /api/v1/processes | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| REST: GET /api/v1/metrics | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| REST: GET /api/v1/logs | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| REST: POST /api/v1/command | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| GET /api/v1/health (unauthenticated) | ✅ | `OS/bin/os-httpd` | ✅ | any |
| Server-Sent Events (live log stream) | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| WebSocket (RFC 6455 echo endpoint) | ✅ | `OS/bin/os-httpd` | ⚠️ | operator |
| Access + error logging | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| Metrics logging (per request) | ✅ | `OS/bin/os-httpd` | ✅ | operator |

---

## 5. Networking

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Interface listing | ✅ | `OS/bin/os-netconf interfaces` | ✅ | operator |
| WiFi status / scan / connect | ✅ | `OS/bin/os-netconf wifi` | ⚠️ (needs nmcli) | operator |
| Bluetooth status / scan | ✅ | `OS/bin/os-netconf bt` | ⚠️ (needs bluetoothctl) | operator |
| IP address assignment / flush | ✅ | `OS/bin/os-netconf ip` | ⚠️ (needs ip) | operator |
| Routing table management | ✅ | `OS/bin/os-netconf route` | ⚠️ (needs ip) | operator |
| DNS configuration | ✅ | `OS/bin/os-netconf dns` | ✅ | operator |
| Firewall rules (iptables) | ✅ | `OS/bin/os-netconf firewall` | ⚠️ (needs iptables) | operator |
| NAT / masquerade | ✅ | `OS/bin/os-netconf nat` | ⚠️ (needs iptables) | operator |
| LAN service discovery (mDNS/nmap) | ✅ | `OS/bin/os-netconf discover` | ⚠️ (needs avahi/nmap) | operator |
| Network config snapshot save/load | ✅ | `OS/bin/os-netconf save` | ✅ | operator |
| Ping (network.ping) | ✅ | `lib/aura-net.sh` | ✅ | operator |
| ifconfig / ip addr | ✅ | `lib/aura-net.sh` | ✅ | operator |

---

## 6. Cross-OS Bridge

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Host OS detection | ✅ | `OS/etc/init.d/aura-bridge` | ✅ | system |
| iOS bridge (libimobiledevice) | ✅ | `OS/bin/os-bridge ios` | ⚠️ (needs libimob) | operator |
| Android bridge (ADB) | ✅ | `OS/bin/os-bridge android` | ⚠️ (needs adb) | operator |
| Linux/SSH bridge | ✅ | `OS/bin/os-bridge linux` | ⚠️ (needs ssh) | operator |
| Filesystem mirroring | ✅ | `OS/bin/os-mirror` | ⚠️ | operator |
| Mirror namespace: `mirror/ios/` | ✅ | `OS/mirror/` | ✅ | operator |

---

## 7. Security

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| Capability-based permission checks | ✅ | `OS/bin/os-perms` | ✅ | system |
| Syscall audit log | ✅ | `OS/bin/os-syscall` | ✅ | system |
| Permissions audit log | ✅ | `OS/bin/os-perms` | ✅ | system |
| OS_ROOT filesystem jail | ✅ | `OS/lib/filesystem.py` | ✅ | system |
| Path traversal blocking | ✅ | `OS/lib/filesystem.py` | ✅ | system |
| API token authentication | ✅ | `OS/bin/os-httpd` | ✅ | operator |
| Spawn whitelist (syscall) | ✅ | `OS/bin/os-syscall` | ✅ | system |
| Secure run wrapper (AIOSCPU) | ✅ | `aioscpu/` (image build) | ⚠️ | aura |

---

## 8. Persistence & Identity

| Capability | Status | Component | Tested | Principal |
|---|---|---|---|---|
| OS identity file | ✅ | `OS/proc/os.identity` | ✅ | system |
| OS manifest file | ✅ | `OS/proc/os.manifest` | ✅ | system |
| Persistent state across reboots | ✅ | `OS/proc/os.state` | ✅ | system |
| AURA memory persistence | ✅ | `OS/proc/aura/memory/` | ✅ | aura |
| State backup / restore | ✅ | `OS/bin/os-recover backup/restore` | ✅ | operator |

---

## 9. Reproducibility

| Capability | Status | Component | Tested |
|---|---|---|---|
| Clean-device install script | ✅ | `install.sh` | ✅ |
| Dependency audit | ✅ | `OS/bin/os-recover deps` | ✅ |
| Disk image build (AIOSCPU) | ✅ | `aioscpu/build/build-image.sh` | ⚠️ (needs debootstrap) |
| Unit test suite | ✅ | `tests/unit-tests.sh` | ✅ |
| Integration test suite | ✅ | `tests/integration-tests.sh` | ✅ |
| Python module tests | ✅ | `tests/test_python_modules.py` | ✅ |
| Self-repair test | ✅ | `OS/bin/os-recover repair` | ✅ |

---

*Last updated: 2026-04-03*
