# AI Model Setup Guide — Llama Integration

## Supported Models

| Model | Size (int4) | RAM Needed | Quality |
|-------|-------------|------------|---------|
| Llama-3.2-1B-Instruct | ~0.8 GB | 3 GB | Fast, basic |
| Llama-3.2-3B-Instruct | ~2.0 GB | 4 GB | Good for 6 GB RAM |
| Llama-3.1-7B-Instruct | ~4.1 GB | 6 GB | Recommended for 8 GB RAM |
| Llama-3.1-8B-Instruct | ~4.7 GB | 7 GB | Best quality for device |

Default: **Llama-3.2-3B-Instruct Q4_K_M** (works on both 6 GB and 8 GB variants).

---

## Step 1 — Build llama.cpp

```bash
cd ai/llama-integration
bash build.sh
```

This compiles `llama.cpp` targeting `aarch64-linux-android` using the Android NDK or the Termux clang toolchain.

After building, the `llama-cli` binary is placed in `ai/llama-integration/bin/`.

---

## Step 2 — Download a Quantized Model

```bash
bash ai/model-quantizer/download-model.sh --model llama-3.2-3b-instruct --quant Q4_K_M
```

Models are saved to `llama_model/` (gitignored). The script:

1. Downloads the GGUF from Hugging Face (requires `huggingface-hub` or `wget`)
2. Verifies the SHA-256 checksum
3. Links the model to `config/llama-settings.conf`

---

## Step 3 — Run Model Quantization (Optional)

If you have a full-precision model, quantize it:

```bash
bash ai/model-quantizer/quantize.sh \
  --input llama_model/original.safetensors \
  --output llama_model/model.Q4_K_M.gguf \
  --type Q4_K_M
```

---

## Step 4 — Start the Inference Daemon

```bash
bash ai/inference-engine/start-daemon.sh
```

The daemon listens on `$OS_ROOT/var/run/llama.sock` and streams responses back.

---

## Step 5 — Test Inference

```bash
bash ai/shell-interface/ai-ask.sh "What is 2+2?"
```

Or from inside the Aura shell:

```
ai.ask What is the capital of France?
```

---

## Configuration

Edit `config/llama-settings.conf`:

```ini
MODEL_PATH=llama_model/model.Q4_K_M.gguf
CONTEXT_SIZE=2048
THREADS=3
GPU_LAYERS=0
TEMP=0.7
TOP_P=0.9
REPEAT_PENALTY=1.1
```

### Key Parameters for S21 FE

| Parameter | 6 GB RAM | 8 GB RAM |
|-----------|----------|----------|
| `CONTEXT_SIZE` | 1024 | 2048 |
| `THREADS` | 2 | 3 |
| `GPU_LAYERS` | 0 | 0 (no GPU offload on Android) |
| `MMAP` | true | true |
| `MLOCK` | false | true (locks model in RAM) |

---

## Thermal-Aware Inference

The inference engine reads thermal zones before each token:

```bash
THERMAL_LIMIT_C=68     # pause inference
THERMAL_RESUME_C=60    # resume inference
```

Configure in `config/aios.conf`.

---

## Model Storage

Models are stored in `llama_model/` which is **gitignored** to avoid committing large binary files.

Use cloud sync to back up your model:

```bash
bash scripts/optimize-for-phone.sh --sync-model
```

This rsyncs `llama_model/` to a configured remote (e.g., Google Drive via rclone).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `GGML_ASSERT` crash | Out of memory | Use smaller model or lower `CONTEXT_SIZE` |
| Very slow inference | Wrong CPU affinity | Set `LLAMA_CPU_AFFINITY=1-3` |
| Model not loading | Wrong path | Check `MODEL_PATH` in `config/llama-settings.conf` |
| OOM kill | System RAM exhausted | Enable zram: `optimize-for-phone.sh --zram` |
