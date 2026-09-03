# 11 — llama.cpp (TurboQuant) & Local LLMs

Run large language models locally on the Jetson with GPU acceleration, using a
CUDA build of the [TurboQuant fork of llama.cpp](https://github.com/TheTom/llama-cpp-turboquant)
(branch `feature/turboquant-kv-cache`). This fork adds `-ctv turbo3`/`turbo4` KV-cache
compression, which lets larger models fit long context windows in the Orin Nano's
8 GB of unified memory — validated up to Qwen3.5 9B at 100K+ tokens (see reference below).

> Ollama is not used here. Prebuilt Ollama binaries and dustynv containers lag behind
> the CUDA toolchain on newer JetPack releases; building llama.cpp from source against
> your local CUDA install with `-DCMAKE_CUDA_ARCHITECTURES=87` avoids that entirely.

## 1. Build llama.cpp (TurboQuant fork)

```bash
sudo apt install -y build-essential cmake git
git clone --branch feature/turboquant-kv-cache https://github.com/TheTom/llama-cpp-turboquant
cd llama-cpp-turboquant

cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=87 -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

Verify:

```bash
./build/bin/llama-server --version
```

> `nemoclaw/setup-openclaw.sh --with-llamacpp` automates this build plus a
> systemd service — see [NemoClaw setup](../nemoclaw/README.md).

## 2. Recommended Models (8 GB unified memory)

| Model | HF Reference | Size | Context | Notes |
|-------|-------------|------|---------|-------|
| [LiquidAI LFM2.5-2.6B](https://huggingface.co/LiquidAI/LFM2.5-2.6B) | `LiquidAI/LFM2.5-2.6B-GGUF` | ~1.8 GB | 128K | 2.6B dense, agentic-tuned, native tool calling — fastest, best default for 24/7 use |
| [Ling-3.0-tiny abliterated APEX](https://huggingface.co/SC117/Ling-3.0-tiny-abliterated-APEX-GGUF) | `SC117/Ling-3.0-tiny-abliterated-APEX-GGUF:APEX-I-Compact` | ~4.0 GB | 131K | 7.9B MoE / 1.3B active, abliterated (uncensored), hybrid KDA/MLA attention |
| [Gemma 4 E4B](https://huggingface.co/google/gemma-4-E4B) | `google/gemma-4-E4B-it-qat-q4_0-gguf` | ~5.15 GB | 128K | 4.5B effective / 8B params, multimodal (text/image/audio), QAT Q4_0 — [verified on Orin Nano by NVIDIA](https://forums.developer.nvidia.com/t/weekend-home-lab-qwen3-5-9b-on-jetson-orin-nano-super-with-turboquant4-100k-token-window/366306/6) |
| [Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) | `mradermacher/Qwen3.5-9B-GGUF:Q4_K_M` | ~5.7 GB | 100K (turbo4) / 128K (turbo3) | 9B dense hybrid Gated DeltaNet/Attention — **requires TurboQuant KV compression** to fit long context on 8 GB |

> **Rule of thumb**: leave ~2 GB of headroom for the OS, CUDA runtime, and the OpenClaw
> gateway if it's running alongside the model.

## 3. Run

The `-hf` flag downloads and caches the GGUF automatically (default cache:
`~/.cache/llama.cpp`, override with `LLAMA_CACHE`).

```bash
# Interactive chat — safe default KV compression
./build/bin/llama-cli -hf LiquidAI/LFM2.5-2.6B-GGUF \
    -ngl 99 -fa on -ctk q8_0 -ctv turbo4 -c 131072

# OpenAI-compatible API server
./build/bin/llama-server -hf LiquidAI/LFM2.5-2.6B-GGUF \
    -ngl 99 -fa on -ctk q8_0 -ctv turbo4 -c 131072 \
    --host 127.0.0.1 --port 8080
```

### TurboQuant KV cache flags

| Flag | Meaning |
|------|---------|
| `-ctk q8_0` | K-cache precision (keep at q8_0 — full-precision K is safest) |
| `-ctv turbo4` | V-cache TurboQuant compression, safe default on any model |
| `-ctv turbo3` | Higher compression (5.12x), works on most models, +1-2% PPL |
| `-ctk turbo3 -ctv turbo3` | Symmetric max compression — validated on large models only, **not** Qwen2.5 with Q4_K_M weights |

Per the [NVIDIA forum weekend test](https://forums.developer.nvidia.com/t/weekend-home-lab-qwen3-5-9b-on-jetson-orin-nano-super-with-turboquant4-100k-token-window/366306):
Qwen3.5 9B runs a **128K window with TurboQuant 3** (fastest) or a more stable
**100K window with TurboQuant 4**. Start with `turbo4`; drop to `turbo3` only if you
need the extra context and can tolerate more variance in long-running sessions.

## 4. Qwen3.5-9B Long-Context Setup

```bash
./build/bin/llama-server -hf mradermacher/Qwen3.5-9B-GGUF:Q4_K_M \
    -ngl 99 -fa on -ctk q8_0 -ctv turbo4 -c 100000 \
    --host 127.0.0.1 --port 8080

# For 128K instead, trade stability for window size:
#   -ctv turbo3 -c 131072
```

Watch memory with `jtop` — a well-tuned Qwen3.5 9B setup should sit around 7.2-7.4 GB
used, leaving enough headroom for the rest of the system.

## 5. API Usage

`llama-server` exposes an OpenAI-compatible API on `http://localhost:8080`:

```bash
# Chat completions
curl http://localhost:8080/v1/chat/completions -d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "Explain CUDA in one sentence."}],
  "stream": false
}'

# List loaded model(s)
curl http://localhost:8080/v1/models
```

## 6. Python Client (OpenAI SDK)

```bash
pip install openai
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "What is the Jetson Orin Nano?"}],
)
print(response.choices[0].message.content)
```

## 7. Open WebUI (ChatGPT-like interface)

Open WebUI supports any OpenAI-compatible backend:

```bash
docker run -d --network host \
    -v open-webui:/app/backend/data \
    -e OPENAI_API_BASE_URL=http://127.0.0.1:8080/v1 \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main

# Access at http://localhost:3000
```

## 8. systemd Service

`nemoclaw/setup-openclaw.sh --with-llamacpp[=MODEL]` installs `llama-server` as a
systemd service (`llama-server.service`) running as the `openclawuser` account, so
it starts on boot and restarts on failure:

```bash
sudo systemctl status llama-server
sudo journalctl -u llama-server -f
```

## References

- [llama-cpp-turboquant (TheTom)](https://github.com/TheTom/llama-cpp-turboquant)
- [NVIDIA Forums: Qwen3.5 9B on Orin Nano Super w/ TurboQuant4 (100K token window)](https://forums.developer.nvidia.com/t/weekend-home-lab-qwen3-5-9b-on-jetson-orin-nano-super-with-turboquant4-100k-token-window/366306)
- [Jetson AI Lab — LLM](https://www.jetson-ai-lab.com/tutorial_ollama.html)
- [NemoClaw setup](../nemoclaw/README.md) — Full OpenClaw gateway using this llama.cpp backend
