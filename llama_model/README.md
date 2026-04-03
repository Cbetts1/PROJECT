# llama_model/

Place your `.gguf` LLaMA model files here. AIOS-Lite will auto-detect the
first `.gguf` file and use it for AI inference via `llama-cli` (llama.cpp).

## Recommended models (by device RAM)

| RAM  | Recommended model                       | Quantization | Size   |
|------|-----------------------------------------|--------------|--------|
| 8 GB | LLaMA-2 7B or Mistral 7B                | Q4_K_M       | ~4 GB  |
| 6 GB | Phi-2 3B or Llama-3.2-3B               | Q4_K_M       | ~2 GB  |
| 4 GB | TinyLlama 1.1B or Llama-3.2-1B         | Q4_K_M       | ~0.7 GB|

## Download sources

- **Hugging Face** (GGUF format): https://huggingface.co/models?library=gguf
- **TheBloke** models: https://huggingface.co/TheBloke
- **Llama-3.2** (official Meta): https://huggingface.co/meta-llama

## Quick download example (using huggingface-cli)

```bash
pip install huggingface_hub
# 7B model for 8GB RAM
huggingface-cli download TheBloke/Llama-2-7B-GGUF llama-2-7b.Q4_K_M.gguf \
    --local-dir ./llama_model

# 1B model for 4GB RAM (fastest)
huggingface-cli download bartowski/Llama-3.2-1B-Instruct-GGUF Llama-3.2-1B-Instruct-Q4_K_M.gguf \
    --local-dir ./llama_model
```

## With Termux (Android/Galaxy S21 FE)

```bash
pkg install python wget
pip install huggingface_hub
huggingface-cli download bartowski/Llama-3.2-3B-Instruct-GGUF \
    Llama-3.2-3B-Instruct-Q4_K_M.gguf \
    --local-dir ~/aios/llama_model
```

## Build llama.cpp first

```bash
bash build/build.sh --target hosted
```

This compiles `llama-cli` and places it in `build/llama.cpp/`.

## Verify your setup

```bash
OS_ROOT=$(pwd)/OS bash OS/bin/os-shell
# Then in os-shell:
ask hello
```

If the model loads, you will see it respond with a real LLM answer.
Otherwise, AIOS falls back to the rule-based engine automatically.

---

*This directory is intentionally empty — add your own .gguf model files.*
*The `.gitignore` excludes *.gguf and *.bin files to keep the repo small.*
