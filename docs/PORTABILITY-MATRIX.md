# AIOS Portability Matrix

AIOS-Lite is designed to run on any Unix-like environment. This document describes supported environments and feature availability.

## Supported Environments

| Environment | Description | Status |
|-------------|-------------|--------|
| **Termux** | Android terminal emulator | ✅ Full |
| **Linux** | Any Linux distribution | ✅ Full |
| **macOS** | Apple macOS | ✅ Full |
| **Docker** | Container environments | ✅ Full |
| **WSL** | Windows Subsystem for Linux | ✅ Full |

## Feature Availability Matrix

| Feature | Termux | Linux | macOS | Docker | WSL |
|---------|--------|-------|-------|--------|-----|
| **Core Shell** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **AI Shell (bin/aios)** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Mock AI Backend** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **LLaMA Inference** | ✓* | ✓ | ✓ | ✓ | ✓ |
| **File Operations** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Process Management** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Service Management** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **iOS Bridge** | — | — | ✓ | — | — |
| **Android Bridge** | local | ✓ | ✓ | ✓** | ✓ |
| **Linux/SSH Bridge** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **HTTP API** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Systemd Integration** | — | ✓ | — | varies | ✓ |
| **Recovery Mode** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Health Checks** | ✓ | ✓ | ✓ | ✓ | ✓ |

**Legend:**
- ✓ = Fully supported
- — = Not applicable / Not available
- \* = With limitations (see notes)
- \*\* = Requires special configuration

## Environment-Specific Notes

### Termux (Android)

**Requirements:**
- Termux app from F-Droid (recommended) or Play Store
- `pkg install bash python git` minimum

**Limitations:**
- LLaMA inference works but may be slow on older devices
- Thermal throttling more aggressive
- No root access by default

**Optimizations:**
- Use the `termux.conf` device profile
- Reduce LLAMA_CTX to 2048 for better performance
- Use 2 threads maximum to avoid overheating

```bash
# Setup on Termux
pkg install bash python git curl
export DEVICE_PROFILE=termux
./bin/aios
```

### Linux (Generic)

**Requirements:**
- Bash 4.0+ (for associative arrays)
- Python 3.8+
- Standard GNU tools

**Notes:**
- Best overall performance
- Full systemd integration available
- All bridges supported with appropriate tools

```bash
# Verify requirements
bash --version
python3 --version
```

### macOS

**Requirements:**
- macOS 10.15+ (Catalina or later)
- Xcode Command Line Tools
- Homebrew (recommended)

**Notes:**
- zsh is default shell (bash works fine)
- Some GNU tools differ from BSD defaults
- iOS bridge requires libimobiledevice: `brew install libimobiledevice`

```bash
# Setup on macOS
xcode-select --install
brew install bash python@3 libimobiledevice
```

### Docker

**Requirements:**
- Docker 20.10+
- Sufficient memory allocation (4GB+ recommended)

**Notes:**
- Persistent storage requires volume mounts
- Device bridges may need `--privileged` flag
- Use `docker` device profile

```bash
# Run in Docker
docker run -it -v aios-data:/opt/aios ubuntu:22.04 bash
# Inside container:
./bin/aios
```

### WSL (Windows Subsystem for Linux)

**Requirements:**
- WSL 2 (recommended)
- Ubuntu or Debian distribution

**Notes:**
- Full Linux compatibility
- Windows filesystem accessible at `/mnt/c/`
- May need to install additional packages

```bash
# Setup on WSL
sudo apt update
sudo apt install bash python3 python3-pip git
```

## Device Profiles

AIOS includes pre-configured device profiles in `config/device-profiles/`:

| Profile | File | Description |
|---------|------|-------------|
| Samsung S21 FE | `samsung-s21fe.conf` | Optimized for Exynos/Snapdragon |
| Generic Linux | `generic-linux.conf` | Sane defaults for any Linux |
| Termux | `termux.conf` | Android/Termux specific |

### Using a Device Profile

```bash
# Auto-detect (default)
./bin/aios

# Specify profile
export DEVICE_PROFILE=samsung-s21fe
./bin/aios

# Or set in config/aios.conf
DEVICE_PROFILE="generic-linux"
```

## Environment Detection

AIOS includes an environment detection tool:

```bash
# Print full portability matrix
bash tools/detect-env.sh

# Source to set environment variables
source tools/detect-env.sh
echo $AIOS_ENV  # termux, linux, macos, docker, wsl, or unknown
```

## Minimum Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM | 2 GB | 8 GB |
| Storage | 500 MB | 10 GB (with LLM) |
| Bash | 4.0 | 5.0+ |
| Python | 3.8 | 3.10+ |
| CPU Cores | 1 | 4+ |

## Troubleshooting

### "Associative array not supported"

Your bash version is too old. Install bash 4.0+:

```bash
# macOS
brew install bash

# Termux
pkg install bash

# Linux
sudo apt install bash
```

### "Python module not found"

Ensure Python 3.8+ is installed and in PATH:

```bash
python3 --version
which python3
```

### Slow LLaMA inference

Reduce context size and thread count:

```bash
export LLAMA_CTX=2048
export LLAMA_THREADS=2
```

### Permission denied

Ensure scripts are executable:

```bash
chmod +x bin/* tools/* OS/bin/* OS/sbin/*
```
