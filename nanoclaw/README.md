# NanoClaw — OpenClaw on Jetson Orin Nano

Local AI assistant powered by [OpenClaw](https://github.com/openclaw/openclaw) running on the NVIDIA Jetson Orin Nano.

**Latest stable release: `2026.3.28`**

## Overview

OpenClaw is a self-hosted AI gateway that connects to multiple AI backends (Ollama, OpenAI, Anthropic, Google, xAI, etc.) and exposes them through a unified Control UI, CLI, Telegram, Discord, Slack, and more.

Running it on the Jetson gives you a 24/7 edge AI assistant with local inference via Ollama and optional cloud fallback.

## Prerequisites

- **JetPack 6.2+** (Jetson Linux 36.5)
- **Node.js 22** (installed by `host/Makefile` → `make node`)
- **8 GB RAM** — recommend closing desktop/compositor for best performance
- **Ollama** (optional, for local inference)

## Quick Start

```bash
# Run the automated installer
chmod +x nanoclaw/setup-openclaw.sh
bash nanoclaw/setup-openclaw.sh
```

Or step by step:

```bash
# 1. Install OpenClaw globally
sudo npm install -g openclaw@latest
openclaw --version

# 2. Run onboarding
openclaw onboard

# 3. Start the gateway
openclaw gateway
```

## Production Setup (systemd)

The included `openclaw.service` runs the gateway as a locked-down system service:

```bash
# Copy and enable the service
sudo cp nanoclaw/openclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw

# Check status
sudo systemctl status openclaw
sudo journalctl -u openclaw -f
```

The Control UI is available at **http://127.0.0.1:18789/**

### Get the gateway token

```bash
sudo -u openclawuser env \
    OPENCLAW_HOME=/opt/openclaw/data \
    HOME=/opt/openclaw/data \
    openclaw config get gateway.auth.token
```

Paste this token into the Control UI when prompted.

## Configuration

The included `openclaw.json` provides sensible Jetson defaults:

- Gateway binds to loopback on port `18789`
- Memory-optimized settings for 8 GB RAM
- Ollama configured as the default local backend
- Recommended models: `qwen3:1.7b` or `gemma3:4b` (fit in ~4 GB)

Edit the config after onboarding:

```bash
openclaw configure
# or edit directly:
nvim /opt/openclaw/data/openclaw.json
```

## AI Backends

| Backend | Type | Notes |
|---------|------|-------|
| Ollama | Local | Best for privacy, ~1.5B models recommended |
| OpenAI | Cloud | GPT-4o, o1, Codex |
| Anthropic | Cloud | Claude via Azure Foundry |
| Google | Cloud | Gemini 2.5 Pro/Flash |
| xAI | Cloud | Grok with x_search |

### Ollama Setup

```bash
# Install Ollama (if not already)
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model that fits in Jetson RAM
ollama pull qwen3:1.7b

# Verify
ollama list
```

## Updating

```bash
sudo npm install -g openclaw@latest
sudo systemctl restart openclaw
openclaw --version
```

## Troubleshooting

- **WebSocket disconnects**: Ensure the gateway token is set in Control UI
- **Out of memory**: Use smaller models (`qwen3:1.7b` over `8b`), disable compositor
- **Port conflict**: Change port in `openclaw.json` or service file
- **Permission denied**: Check `/opt/openclaw/data` ownership is `openclawuser:openclawuser`
- **SyntaxError: Unexpected token '?'** during `npm install -g`: The system Node.js is too old. `sudo` doesn't inherit fnm-managed Node. The install scripts already pass the correct PATH to sudo, but if running manually use: `sudo env "PATH=$(dirname $(command -v node)):$PATH" npm install -g openclaw@latest`

## References

- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [OpenClaw Docs](https://docs.openclaw.ai/)
- [Jetson OpenClaw Guide](https://forums.developer.nvidia.com/t/openclaw-on-nvidia-jetson-orin-nano/361259)
- [OpenClaw Releases](https://github.com/openclaw/openclaw/releases)
