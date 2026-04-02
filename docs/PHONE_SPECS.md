# Samsung Galaxy S21 FE — Device Optimization Guide

## Hardware Profile

| Component | Specification |
|-----------|--------------|
| Device | Samsung Galaxy S21 FE (SM-G990B / SM-G990U) |
| SoC | Exynos 2100 (international) / Snapdragon 888 (US) |
| CPU | 1× Cortex-X1 @ 2.9 GHz + 3× A78 @ 2.8 GHz + 4× A55 @ 2.2 GHz |
| GPU | Mali-G78 MP14 / Adreno 660 |
| RAM | 6 GB or 8 GB LPDDR5 |
| Storage | 128 GB or 256 GB UFS 2.1 (no microSD) |
| Battery | 4500 mAh |
| OS | Android 12 → 14 (One UI 4–6) |
| Thermal | 5-zone thermal management, ~40°C sustained limit |

---

## CPU Affinity for Llama Inference

The Exynos 2100 big.LITTLE cluster layout:

```
Core 0       Cortex-X1  (prime)   — avoid: thermal + battery drain
Cores 1–3    Cortex-A78 (big)     — USE for inference (best perf/watt)
Cores 4–7    Cortex-A55 (little)  — USE for OS background tasks
```

Recommended affinity in `config/aios.conf`:

```ini
LLAMA_CPU_AFFINITY="1-3"   # big cores only
SYSTEM_CPU_AFFINITY="4-7"  # little cores for OS
```

Apply at runtime:

```bash
taskset -c 1-3 llama-cli --model "$MODEL_PATH" ...
```

---

## Memory Recommendations

### 8 GB Variant

```
Llama 7B int4 model    ≈ 4.0 GB
Android + AIOS OS      ≈ 2.5 GB
Inference KV cache     ≈ 1.0 GB
Buffer                 ≈ 0.5 GB
```

Recommended model: `llama-3.2-7b-instruct.Q4_K_M.gguf`

### 6 GB Variant

```
Llama 3B int4 model    ≈ 2.5 GB
Android + AIOS OS      ≈ 2.5 GB
Inference KV cache     ≈ 0.7 GB
Buffer                 ≈ 0.3 GB
```

Recommended model: `llama-3.2-3b-instruct.Q4_K_M.gguf`

Enable zram to gain ~2 GB of virtual RAM:

```bash
bash scripts/optimize-for-phone.sh --zram 4096
```

---

## Storage Layout (128 GB)

```
/data/data/com.termux/files/home/aios/    AIOS home
  OS/                                      ~200 MB  (OS scripts)
  ai/llama-integration/llama.cpp/build/    ~100 MB  (compiled binary)
  llama_model/                             ~4–6 GB  (model weights - gitignored)
  overlay/                                 variable (OverlayFS upper layer)
  var/                                     ~100 MB  (logs, state, cache)

/sdcard/aios-backup/                      optional cloud sync staging
```

---

## Thermal Management

The S21 FE will throttle the Exynos 2100 at ~70°C. AIOS monitors:

```bash
# Read current CPU temperature
cat /sys/class/thermal/thermal_zone0/temp   # millidegrees C
```

The inference engine pauses token generation above `THERMAL_LIMIT_C` (default: 68°C) and resumes when below `THERMAL_RESUME_C` (default: 60°C). Configure in `config/aios.conf`.

---

## Battery Management

| Battery Level | Behavior |
|---------------|----------|
| > 50% | Full inference, all big cores |
| 30–50% | Inference on 2 big cores |
| 15–30% | Inference on 1 big core, reduced context |
| < 15% | Inference suspended, OS-only mode |

The `deploy/phone-optimizations.sh` script sets Android wakelocks to prevent CPU sleep during inference.

---

## Android-Specific Tuning

```bash
# Disable battery optimization for Termux
adb shell dumpsys deviceidle whitelist +com.termux

# Enable performance governor (requires root)
su -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

# Increase vm.overcommit for large model mmap
su -c "echo 1 > /proc/sys/vm/overcommit_memory"

# Disable OOM killer aggressiveness
su -c "echo 0 > /proc/sys/vm/oom_kill_allocating_task"
```

These are applied automatically by `deploy/phone-optimizations.sh`.

---

## Snapdragon 888 Variant Differences

On the Snapdragon 888 variant (SM-G990U):

- CPU cluster: 1× X1 @ 2.84 GHz + 3× A78 @ 2.42 GHz + 4× A55 @ 1.8 GHz
- Use cores 1–3 for inference (same `LLAMA_CPU_AFFINITY="1-3"`)
- Slightly better sustained performance due to TSMC 5nm node
- Thermal limit same: 68°C
