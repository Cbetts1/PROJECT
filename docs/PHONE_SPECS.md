# Samsung Galaxy S21 FE — Device Specifications for AIOS

> Primary target hardware for AIOS-Lite mobile deployment.
> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Hardware Overview

| Attribute | Value |
|-----------|-------|
| **Model** | Samsung Galaxy S21 FE (Fan Edition) |
| **SoC** | Qualcomm Snapdragon 888 (5 nm) |
| **CPU** | 1× Cortex-X1 @ 2.84 GHz + 3× Cortex-A78 @ 2.42 GHz + 4× Cortex-A55 @ 1.80 GHz |
| **GPU** | Adreno 660 |
| **RAM** | 6 GB LPDDR5 (base) or 8 GB LPDDR5 |
| **Storage** | 128 GB / 256 GB UFS 3.1 (no microSD) |
| **OS (stock)** | Android 12 (upgradeable to 14) |
| **Display** | 6.4″ AMOLED, 120 Hz, 1080 × 2340 |
| **Battery** | 4500 mAh, 25 W wired |
| **Connectivity** | 5G, Wi-Fi 6 (802.11ax), Bluetooth 5.0, USB-C 3.2 |

---

## CPU Core Topology (Linux logical indices)

```
Core 0   — Cortex-A55  @ 1.80 GHz  (efficiency)
Core 1   — Cortex-A55  @ 1.80 GHz  (efficiency)
Core 2   — Cortex-A55  @ 1.80 GHz  (efficiency)
Core 3   — Cortex-A55  @ 1.80 GHz  (efficiency)
Core 4   — Cortex-A78  @ 2.42 GHz  (performance)
Core 5   — Cortex-A78  @ 2.42 GHz  (performance)
Core 6   — Cortex-A78  @ 2.42 GHz  (performance)
Core 7   — Cortex-X1   @ 2.84 GHz  (prime)
```

**AIOS LLM affinity setting:** `LLAMA_CPU_AFFINITY="1-3"` pins llama.cpp
inference to logical cores 1–3 as a conservative default that avoids the
efficiency cluster while not over-stressing the prime core on thermally-
limited mobile hardware.  For maximum throughput adjust to `4-6`.

---

## AI Model Recommendations

| Device RAM | Recommended Model | Quantisation | Approx. Size |
|-----------|-------------------|-------------|-------------|
| 8 GB | LLaMA 3 8B Instruct | Q4\_K\_M (int4) | ~4.7 GB |
| 6 GB | LLaMA 3 3B Instruct | Q4\_K\_M (int4) | ~1.9 GB |

The model file should be placed in `$OS_ROOT/llama_model/` with the exact
filename matching `LLM_MODEL_8GB` / `LLM_MODEL_6GB` in `config/llama-settings.conf`.

---

## Thermal Constraints

| Threshold | Action |
|-----------|--------|
| < 60 °C | Normal inference — full speed |
| 60–68 °C | Reduce LLAMA_THREADS (warn user) |
| ≥ 68 °C | Pause inference; wait for cooldown |

Sensor path (Snapdragon 888 typical): `/sys/class/thermal/thermal_zone0/temp`
(value reported in milli-Celsius; divide by 1000 for °C)

---

## Running AIOS on the S21 FE

### Via Termux (recommended for development)

```sh
# Install dependencies
pkg update && pkg upgrade
pkg install git python openssh android-tools libimobiledevice

# Clone and set up AIOS
git clone https://github.com/Cbetts1/PROJECT aios
cd aios
export OS_ROOT="$(pwd)/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"

# Boot
sh OS/sbin/init
os-shell
```

### LLaMA model placement

```sh
mkdir -p "$OS_ROOT/llama_model"
# Copy or symlink your .gguf file here:
cp ~/Downloads/llama-3-3b-instruct.Q4_K_M.gguf "$OS_ROOT/llama_model/"
```

Install a llama.cpp build for Android/AArch64 from
<https://github.com/ggerganov/llama.cpp/releases> and ensure `llama-cli`
is on your `PATH`.

---

## Known Limitations

- USB OTG power delivery may limit simultaneous charging + bridge use.
- Adreno GPU offload (`LLAMA_N_GPU_LAYERS`) is not supported in standard
  llama.cpp Android builds; keep at `0`.
- Thermal throttling kicks in quickly under sustained LLM load; short queries
  (≤256 tokens) are recommended for responsive use.
