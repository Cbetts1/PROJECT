# AIOS — Portable AI Operating System

**Portable AI OS built on a quantized Llama model, designed for the Samsung Galaxy S21 FE.**

AIOS runs in two modes:
- **Hosted mode** — container/app shell running on top of Android via Termux
- **Standalone mode** — full OS booted from USB or internal storage

---

## Key Features

- Lightweight Linux-based container with OverlayFS mirroring
- Integrated Llama 3B–7B quantized model (int4/int8, ~4–6 GB)
- AI-powered interactive shell (Aura)
- Optimized for Samsung Galaxy S21 FE (Exynos 2100 / Snapdragon 888)
- One-command installation
- Dual-mode operation (hosted + standalone)
- Battery and thermal management
- Cloud sync for model weights

---

## Device Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| RAM | 6 GB | 8 GB |
| Storage | 128 GB | 256 GB |
| CPU | Exynos 2100 / SD 888 | Same |
| OS | Android 12+ | Android 13+ |
| Access | Root (Magisk) | Root + Termux |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# 2. Run the installer (hosted / Termux mode)
bash deploy/container-installer.sh

# 3. Launch the AI shell
bash OS/bin/os-shell
```

See [QUICKSTART.md](QUICKSTART.md) for a complete 5-minute guide.

---

## Project Structure

```
PROJECT/
├── docs/               Architecture, specs, setup guides
├── build/              Dockerfile, build scripts, kernel config
├── OS/                 Minimal Linux root filesystem
│   ├── bin/            Core OS binaries (Aura shell, services)
│   ├── etc/            System configuration
│   ├── lib/            Aura AI modules
│   └── sbin/           Init system
├── ai/                 Llama integration and inference engine
├── mirror/             OverlayFS host-mirroring system
├── deploy/             Installation and boot scripts
├── scripts/            Optimization and utility scripts
├── config/             Runtime configuration files
└── tests/              Unit, integration, and mobile tests
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full system design |
| [docs/PHONE_SPECS.md](docs/PHONE_SPECS.md) | S21 FE optimization guide |
| [docs/AI_MODEL_SETUP.md](docs/AI_MODEL_SETUP.md) | Llama integration guide |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Installation & boot procedures |

---

## License

MIT — see [LICENSE](LICENSE).
