# 11 — Ollama & Local LLMs

Run large language models locally on the Jetson with GPU acceleration.

## 1. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Verify:

```bash
ollama --version
systemctl status ollama
```

## 2. Recommended Models (8 GB RAM)

| Model | Size | Notes |
|-------|------|-------|
| `qwen3:1.7b` | ~1.5 GB | Best quality/size ratio |
| `gemma3:4b` | ~3 GB | Good general purpose |
| `phi4-mini:3.8b` | ~2.5 GB | Microsoft, strong reasoning |
| `llama3.2:3b` | ~2 GB | Meta, well-rounded |
| `deepseek-r1:1.5b` | ~1 GB | Reasoning-focused |
| `qwen2.5-coder:1.5b` | ~1 GB | Code completion |

> **Rule of thumb**: Keep model size under ~4 GB to leave room for the OS, CUDA, and your app.

## 3. Pull & Run

```bash
# Pull a model
ollama pull qwen3:1.7b

# Interactive chat
ollama run qwen3:1.7b

# List downloaded models
ollama list

# Remove a model
ollama rm <model>
```

## 4. API Usage

Ollama exposes a REST API on `http://localhost:11434`:

```bash
# Generate
curl http://localhost:11434/api/generate -d '{
  "model": "qwen3:1.7b",
  "prompt": "Explain CUDA in one sentence.",
  "stream": false
}'

# Chat
curl http://localhost:11434/api/chat -d '{
  "model": "qwen3:1.7b",
  "messages": [{"role": "user", "content": "Hello!"}],
  "stream": false
}'
```

## 5. Python Client

```bash
pip install ollama
```

```python
import ollama

response = ollama.chat(
    model="qwen3:1.7b",
    messages=[{"role": "user", "content": "What is the Jetson Orin Nano?"}]
)
print(response["message"]["content"])
```

## 6. Open WebUI (ChatGPT-like interface)

```bash
docker run -d --network host \
    -v open-webui:/app/backend/data \
    -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main

# Access at http://localhost:3000
```

## 7. Memory Optimization

```bash
# Set max loaded models to 1 (saves RAM)
sudo systemctl edit ollama
# Add:
# [Service]
# Environment="OLLAMA_MAX_LOADED_MODELS=1"
# Environment="OLLAMA_NUM_PARALLEL=1"

sudo systemctl restart ollama
```

## 8. Docker Alternative (dustynv)

```bash
docker run --rm -it --runtime nvidia \
    -v ollama:/root/.ollama \
    -p 11434:11434 \
    dustynv/ollama:r36
```

## References

- [Ollama](https://ollama.com/)
- [Jetson AI Lab — LLM](https://www.jetson-ai-lab.com/tutorial_ollama.html)
- [NanoClaw setup](../nanoclaw/README.md) — Full OpenClaw gateway using Ollama
