# AIOS Phone Specs — Samsung Galaxy S21 FE

Primary target device for AIOS-Lite mobile deployment.

## Device Overview

| Property          | Value                                   |
|-------------------|-----------------------------------------|
| Model             | Samsung Galaxy S21 FE 5G (SM-G990B)    |
| CPU               | Exynos 2100 or Snapdragon 888 (region) |
| Architecture      | ARM64 (aarch64)                         |
| RAM variants      | 6 GB / 8 GB LPDDR5                      |
| Storage           | 128 GB / 256 GB UFS 3.1                 |
| OS (stock)        | Android 12 → 14 (OneUI 4.1+)           |
| Deployment env    | Termux (Android) or Linux Deploy        |

## CPU Core Configuration

The Exynos 2100 has a big.LITTLE layout:
- **Cores 0**   : Cortex-X1 (prime, 2.91 GHz) — use for heavy LLM batch
- **Cores 1–3** : Cortex-A78 (big, 2.80 GHz) — `LLAMA_CPU_AFFINITY="1-3"`
- **Cores 4–7** : Cortex-A55 (little, 2.20 GHz) — background/agents

> **Default**: `LLAMA_CPU_AFFINITY="1-3"` (big cores, balanced performance/thermal)

## LLM Model Recommendations by RAM

| RAM  | Model                          | Quant   | Size   | Speed (tok/s) |
|------|--------------------------------|---------|--------|----------------|
| 8 GB | LLaMA-2-7B / Mistral-7B        | Q4_K_M  | ~4 GB  | ~8-12 tok/s    |
| 6 GB | Phi-2-3B / Llama-3.2-3B        | Q4_K_M  | ~2 GB  | ~18-25 tok/s   |
| 4 GB | TinyLlama-1.1B / Llama-3.2-1B  | Q4_K_M  | ~0.7 GB| ~40-60 tok/s   |

## Thermal Limits

- **Safe operating temp**: < 68°C (`DEVICE_THERMAL_LIMIT_C=68`)
- **Throttle threshold**: 70°C (Samsung hardware throttles)
- **Auto-pause**: AIOS LLM module pauses inference at 68°C
- Monitor with: `thermal` command in os-real-shell

## AIOS Configuration for This Device

In `config/aios.conf`:
```sh
LLAMA_CPU_AFFINITY="1-3"   # big Cortex-A78 cores
DEVICE_RAM_GB="8"           # or 6 for 6GB variant
DEVICE_THERMAL_LIMIT_C="68"
DEVICE_PROFILE="samsung-s21fe"
```

In `config/llama-settings.conf`:
```sh
LLM_THREADS=4
LLAMA_CPU_AFFINITY="1-3"
LLM_THERMAL_LIMIT_C=68
```

## Running on Termux

```bash
# Install dependencies
pkg update && pkg install python git cmake clang make

# Clone AIOS
git clone https://github.com/Cbetts1/PROJECT aios
cd aios

# Install
bash install.sh

# (Optional) Build llama.cpp for native ARM64
bash build/build.sh --target termux

# Download a model (3B recommended for 6GB, 7B for 8GB)
huggingface-cli download bartowski/Llama-3.2-3B-Instruct-GGUF \
    Llama-3.2-3B-Instruct-Q4_K_M.gguf --local-dir llama_model

# Launch AI shell
OS_ROOT=$(pwd)/OS bash OS/bin/os-shell
```

## Device-Specific Notes

- **ADB**: enable USB debugging in Developer Options for Android bridge
- **Termux:API**: install for WiFi, Bluetooth, thermal sensor access
- **Storage**: AIOS OS_ROOT fits in ~50 MB; models need 0.7–4 GB
- **Background**: Android may kill Termux in background; use `termux-wake-lock`
