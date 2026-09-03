# NemoClaw — NVIDIA NemoClaw on Jetson Orin Nano

[NVIDIA NemoClaw](https://github.com/NVIDIA/NemoClaw) is an open source reference stack for
running always-on AI agents — [OpenClaw](https://openclaw.ai) (default), [Hermes](https://get-hermes.ai/),
or [LangChain Deep Agents Code](https://docs.langchain.com/oss/python/deepagents/code/overview) —
more safely inside [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) sandboxes, with guided
onboarding, routed inference, network policy, and lifecycle management via a single `nemoclaw` CLI.

> NemoClaw is in **alpha** (early preview since March 2026). APIs and config schemas can change
> between releases — do not use in production.

## Overview

NemoClaw is *not* a standalone npm package you install like a typical CLI tool — it installs its
own Node.js CLI, then creates a Docker container ("OpenShell sandbox") that runs the selected agent
(OpenClaw/Hermes/Deep Agents) with hardened network policy and managed inference routing. You then
`connect` to that sandbox to chat with the agent.

On the Jetson, `nemoclaw/setup-openclaw.sh` optionally also builds and runs a self-hosted
**llama.cpp (TurboQuant fork)** inference server as a *custom OpenAI-compatible provider* you can
select during onboarding — giving you fully local/offline inference on Jetson's unified memory.

## Prerequisites

- **JetPack 6.2+** (Jetson Linux 36.5)
- **Node.js 22.19+** and **npm 10+** (installed by `host/Makefile` → `make node`, or by NemoClaw's own installer)
- **Docker** (Engine, Desktop, or Colima) — required to run the OpenShell sandbox. The installer can
  install it for you (will prompt for `sudo`), or use `host/Makefile`/apt to install it yourself first.
- **cmake, git, build-essential** — only if using `--with-llamacpp` for local inference
- Enough free disk for Docker images (a few GB) plus any local model download

## Quick Start

```bash
# Optional: build + run a local llama.cpp (TurboQuant) inference server first,
# so it's ready to select as a "custom OpenAI-compatible endpoint" during onboarding.
chmod +x nemoclaw/setup-openclaw.sh
bash nemoclaw/setup-openclaw.sh --with-llamacpp            # default model: LFM2.5-2.6B
bash nemoclaw/setup-openclaw.sh --with-llamacpp=gemma4-e4b # pick a specific model
bash nemoclaw/setup-openclaw.sh --list-models              # see all model keys

# Install NemoClaw + run guided onboarding (interactive by default)
bash nemoclaw/setup-openclaw.sh
```

Or run the official installer directly:

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
# Select an agent (OpenClaw is default), choose a provider/model, name your sandbox.
```

For Hermes instead of OpenClaw:

```bash
NEMOCLAW_AGENT=hermes bash nemoclaw/setup-openclaw.sh
# or, after install: nemohermes onboard
```

## Chat With Your Agent

```bash
nemoclaw <sandbox-name> connect
```

Inside the sandbox shell (for OpenClaw):

```bash
openclaw tui                                           # terminal UI
openclaw agent --agent main --local -m "hello" --session-id test  # one-shot message
```

## Using the Local llama.cpp (TurboQuant) Endpoint as a Provider

During `nemoclaw onboard`, when asked for a provider, choose **"Other OpenAI-compatible endpoint"**
and enter:

| Field | Value |
|---|---|
| Endpoint | `http://127.0.0.1:8080/v1` (or your host's LAN IP if the sandbox can't reach `127.0.0.1` directly) |
| Model | any name — the loaded GGUF answers all requests |
| API key | not needed (use a placeholder like `not-needed`) |

| Model key | Params | Size | Context | Notes |
|---|---|---|---|---|
| `lfm2.5-2.6b` (default) | 2.6B dense | ~1.8 GB | 128K | Agentic-tuned, fastest, lightest |
| `ling-3-tiny` | 7.9B MoE / 1.3B active | ~4.0 GB | 64K | Abliterated (uncensored) |
| `gemma4-e4b` | 4.5B effective / 8B | ~5.15 GB | 128K | Multimodal, verified on Orin Nano by NVIDIA |
| `qwen3.5-9b` | 9B dense | ~5.7 GB | 100K (turbo4) / 128K (turbo3) | Needs TurboQuant KV to fit long context on 8 GB |

The server builds under `~/llama-cpp-turboquant` (no `sudo` needed) and runs as a **systemd `--user`
service** (`llama-server`), so it survives logout only if linger is enabled — the script does this
automatically via `loginctl enable-linger`.

```bash
systemctl --user status llama-server
journalctl --user -u llama-server -f
```

See `guides/11-ollama-llm.md` for full model details, TurboQuant KV-cache tuning, and direct API usage.

## Updating

```bash
# NemoClaw CLI + sandbox
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
nemoclaw onboard   # re-run onboarding if you need to recreate the sandbox

# llama.cpp (TurboQuant fork) local inference
bash nemoclaw/setup-openclaw.sh --with-llamacpp=<same-model-key>
```

Avoid `openshell self-update`, `npm update -g openshell`, or `openshell sandbox create` directly —
use `nemoclaw onboard` so NemoClaw's own lifecycle management stays consistent.

## Troubleshooting

- **`nemoclaw` not found after install**: `source ~/.bashrc` (or `~/.zshrc`), or open a new terminal
- **Docker permission errors**: `sudo usermod -aG docker $(whoami) && newgrp docker`
- **Low disk space**: unused Docker images/build cache are often reclaimable —
  `docker system df` to inspect, `docker system prune -a --volumes` to clean up (review first!)
- **llama-server won't start**: `journalctl --user -u llama-server -f` — first run downloads the GGUF and can take several minutes
- **llama-server service doesn't survive logout**: `sudo loginctl enable-linger $(whoami)`
- **Qwen3.5-9B unstable at 128K ctx**: switch `-ctv turbo3` → `-ctv turbo4` and drop context to 100K (see forum reference below)

## References

- [NVIDIA/NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw)
- [NemoClaw Docs](https://docs.nvidia.com/nemoclaw/)
- [NemoClaw Prerequisites](https://docs.nvidia.com/nemoclaw/latest/get-started/prerequisites.html)
- [OpenClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html)
- [Hermes Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart-hermes.html)
- [llama-cpp-turboquant (TheTom)](https://github.com/TheTom/llama-cpp-turboquant)
- [NVIDIA Forums: Qwen3.5 9B on Orin Nano Super w/ TurboQuant4](https://forums.developer.nvidia.com/t/weekend-home-lab-qwen3-5-9b-on-jetson-orin-nano-super-with-turboquant4-100k-token-window/366306)
