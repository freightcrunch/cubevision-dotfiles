#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  NemoClaw — NVIDIA NemoClaw installer for Jetson Orin Nano            ║
# ║  https://github.com/NVIDIA/NemoClaw                                  ║
# ║                                                                      ║
# ║  Runs the official NemoClaw installer (Node.js CLI + Docker/OpenShell║
# ║  sandbox) and optionally builds a local llama.cpp (TurboQuant fork)  ║
# ║  server you can select as a custom OpenAI-compatible provider during ║
# ║  `nemoclaw onboard`.                                                 ║
# ║                                                                      ║
# ║  Usage:  bash nemoclaw/setup-openclaw.sh [--with-llamacpp[=MODEL]]   ║
# ║                                          [--list-models]              ║
# ║                                                                      ║
# ║  MODEL keys (see list_models below):                                 ║
# ║    lfm2.5-2.6b   (default) · ling-3-tiny · gemma4-e4b · qwen3.5-9b   ║
# ║                                                                      ║
# ║  Env passthrough to the NemoClaw installer (all optional):           ║
# ║    NEMOCLAW_AGENT      openclaw (default) | hermes | langchain-...  ║
# ║    NEMOCLAW_PROVIDER   custom | ollama | vllm | openai | ...        ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

LLAMACPP_DIR="${LLAMACPP_DIR:-$HOME/llama-cpp-turboquant}"
LLAMACPP_REPO="https://github.com/TheTom/llama-cpp-turboquant"
LLAMACPP_BRANCH="feature/turboquant-kv-cache"
LLAMACPP_PORT="${LLAMACPP_PORT:-8080}"
LLAMACPP_CACHE="${LLAMA_CACHE:-$HOME/.cache/llama.cpp}"

# key -> "hf_repo|hf_quant|size|context|turboquant_kv|description"
# hf_quant may be empty (repo ships a single default GGUF).
declare -A MODELS=(
    ["lfm2.5-2.6b"]="LiquidAI/LFM2.5-2.6B-GGUF||~1.8 GB|131072|turbo4|dense 2.6B, agentic-tuned — fastest, best default for a 24/7 gateway"
    ["ling-3-tiny"]="SC117/Ling-3.0-tiny-abliterated-APEX-GGUF|APEX-I-Compact|~4.0 GB|65536|turbo4|7.9B MoE / 1.3B active, abliterated (uncensored)"
    ["gemma4-e4b"]="google/gemma-4-E4B-it-qat-q4_0-gguf||~5.15 GB|131072|turbo4|multimodal (text/image/audio), verified on Orin Nano by NVIDIA"
    ["qwen3.5-9b"]="mradermacher/Qwen3.5-9B-GGUF|Q4_K_M|~5.7 GB|100000|turbo4|dense 9B — needs TurboQuant KV (-ctv turbo3/turbo4) to fit 100K+ ctx on 8GB"
)
DEFAULT_MODEL_KEY="lfm2.5-2.6b"

# ─── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ─── Preflight ─────────────────────────────────────────────────────
preflight() {
    section "Preflight Checks"

    if ! command -v node &>/dev/null; then
        error "Node.js 22.19+ is required (NemoClaw's official installer can install it too)."
        exit 1
    fi

    local node_version node_major node_minor
    node_version=$(node -v | sed 's/v//')
    node_major=$(echo "$node_version" | cut -d. -f1)
    node_minor=$(echo "$node_version" | cut -d. -f2)
    if [ "$node_major" -lt 22 ] || { [ "$node_major" -eq 22 ] && [ "$node_minor" -lt 19 ]; }; then
        error "Node.js 22.19+ required (found: v$node_version)."
        exit 1
    fi
    info "Node.js v$node_version — OK"

    if ! command -v npm &>/dev/null; then
        error "npm is required."
        exit 1
    fi
    info "npm $(npm -v) — OK"

    if ! command -v docker &>/dev/null; then
        warn "Docker not found. NemoClaw runs agents inside Docker/OpenShell sandboxes."
        warn "Its installer can install Docker for you (will prompt for sudo)."
    elif docker info &>/dev/null; then
        info "Docker $(docker --version | sed 's/Docker version //;s/,.*//') — OK, accessible without sudo"
    else
        warn "Docker is installed but not accessible without sudo or the daemon isn't running."
        warn "You may need: sudo usermod -aG docker \$(whoami) && newgrp docker"
    fi

    local free_gb
    free_gb=$(df -BG --output=avail "$HOME" 2>/dev/null | tail -1 | tr -dc '0-9')
    if [ -n "$free_gb" ] && [ "$free_gb" -lt 8 ]; then
        warn "Only ${free_gb}GB free disk space in \$HOME. Sandbox images and models can be large."
    elif [ -n "$free_gb" ]; then
        info "Disk space: ${free_gb}GB free — OK"
    fi
}

# ─── Install real NemoClaw (github.com/NVIDIA/NemoClaw) ──────────
install_nemoclaw() {
    section "NVIDIA NemoClaw"

    if command -v nemoclaw &>/dev/null; then
        warn "nemoclaw already installed: $(nemoclaw --version 2>/dev/null || echo unknown)"
        info "Re-running the installer will update the CLI and can re-run onboarding."
    fi

    info "Running the official installer: curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash"
    [ -n "${NEMOCLAW_AGENT:-}" ]    && info "NEMOCLAW_AGENT=$NEMOCLAW_AGENT"
    [ -n "${NEMOCLAW_PROVIDER:-}" ] && info "NEMOCLAW_PROVIDER=$NEMOCLAW_PROVIDER"
    info "This launches the guided onboard wizard (choose agent/provider/model interactively"
    info "unless the NEMOCLAW_* env vars above are set for a non-interactive run)."

    curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash

    if command -v nemoclaw &>/dev/null; then
        info "nemoclaw CLI installed: $(nemoclaw --version 2>/dev/null || echo unknown)"
    else
        warn "'nemoclaw' not found in this shell yet. Run: source ~/.bashrc (or ~/.zshrc), or open a new terminal."
    fi
}

# ─── llama.cpp (TurboQuant fork, optional local inference) ───────
# Builds in $HOME (no sudo) and runs as a systemd --user service, so it can
# be pointed to from NemoClaw onboarding as a "custom OpenAI-compatible
# endpoint" provider (http://127.0.0.1:$LLAMACPP_PORT/v1).
list_models() {
    section "Available Models"
    for key in "${!MODELS[@]}"; do
        IFS='|' read -r repo quant size ctx ctv desc <<< "${MODELS[$key]}"
        local ref="$repo"; [ -n "$quant" ] && ref="${repo}:${quant}"
        printf "  %-14s %-8s ctx=%-7s %s\n" "$key" "$size" "$ctx" "$desc"
        printf "                 hf: %s\n" "$ref"
    done
}

build_llamacpp() {
    section "llama.cpp (TurboQuant fork) — Build"

    if ! command -v cmake &>/dev/null || ! command -v git &>/dev/null; then
        error "cmake and git are required. Run 'sudo apt install cmake git build-essential' first."
        exit 1
    fi

    if [ -d "$LLAMACPP_DIR/.git" ]; then
        info "llama-cpp-turboquant already cloned at $LLAMACPP_DIR. Updating..."
        git -C "$LLAMACPP_DIR" fetch origin "$LLAMACPP_BRANCH"
        git -C "$LLAMACPP_DIR" checkout "$LLAMACPP_BRANCH"
        git -C "$LLAMACPP_DIR" pull --ff-only origin "$LLAMACPP_BRANCH"
    else
        info "Cloning $LLAMACPP_REPO ($LLAMACPP_BRANCH) into $LLAMACPP_DIR..."
        git clone --branch "$LLAMACPP_BRANCH" --depth 1 "$LLAMACPP_REPO" "$LLAMACPP_DIR"
    fi

    info "Building for CUDA (Jetson Orin, sm_87)..."
    cmake -B "$LLAMACPP_DIR/build" -S "$LLAMACPP_DIR" \
        -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=87 -DCMAKE_BUILD_TYPE=Release
    cmake --build "$LLAMACPP_DIR/build" --config Release -j"$(nproc)"

    if [ ! -x "$LLAMACPP_DIR/build/bin/llama-server" ]; then
        error "Build failed — llama-server binary not found."
        exit 1
    fi
    info "llama-server built at $LLAMACPP_DIR/build/bin/llama-server"
}

install_llama_service() {
    local key="${1:-$DEFAULT_MODEL_KEY}"

    if [ -z "${MODELS[$key]:-}" ]; then
        error "Unknown model key: $key"
        list_models
        exit 1
    fi

    IFS='|' read -r hf_repo hf_quant size ctx ctv desc <<< "${MODELS[$key]}"
    local hf_ref="$hf_repo"; [ -n "$hf_quant" ] && hf_ref="${hf_repo}:${hf_quant}"

    info "Selected model: $key ($size) — $desc"
    info "HF ref: $hf_ref  |  context: $ctx  |  KV compression: -ctv $ctv"

    mkdir -p "$LLAMACPP_CACHE" "$HOME/.config/systemd/user"

    cat > "$HOME/.config/systemd/user/llama-server.service" <<EOF
[Unit]
Description=llama.cpp (TurboQuant) inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=LLAMA_CACHE=$LLAMACPP_CACHE
ExecStart=$LLAMACPP_DIR/build/bin/llama-server \\
    -hf $hf_ref \\
    -ngl 99 -fa on \\
    -ctk q8_0 -ctv $ctv \\
    -c $ctx \\
    --host 127.0.0.1 --port $LLAMACPP_PORT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now llama-server
    loginctl enable-linger "$(whoami)" 2>/dev/null || warn "Could not enable linger — the service will stop when you log out. Run: sudo loginctl enable-linger \$(whoami)"

    info "Waiting for server to start (first run downloads the GGUF — can take a while)..."
    sleep 5
    if systemctl --user is-active --quiet llama-server; then
        info "llama-server running on http://127.0.0.1:$LLAMACPP_PORT/"
        info "Use this as a custom OpenAI-compatible endpoint during 'nemoclaw onboard':"
        info "  endpoint: http://127.0.0.1:$LLAMACPP_PORT/v1   model: (any name)   key: not-needed"
    else
        warn "Still starting/downloading. Check: journalctl --user -u llama-server -f"
    fi
}

install_llamacpp() {
    local model_key="${1:-$DEFAULT_MODEL_KEY}"
    build_llamacpp
    install_llama_service "$model_key"
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  NemoClaw — NVIDIA NemoClaw on Jetson Orin Nano             ║"
    echo "║  https://github.com/NVIDIA/NemoClaw                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    preflight

    # Optional llama.cpp (TurboQuant fork) local inference — build this
    # BEFORE onboarding so the endpoint is ready to select as a provider.
    case "${1:-}" in
        --with-llamacpp)
            install_llamacpp "$DEFAULT_MODEL_KEY"
            ;;
        --with-llamacpp=*)
            install_llamacpp "${1#--with-llamacpp=}"
            ;;
        --list-models)
            list_models
            exit 0
            ;;
        *)
            info "Skipping llama.cpp. Run with --with-llamacpp[=MODEL] first if you want a local"
            info "custom-endpoint provider ready before onboarding. See models: $0 --list-models"
            ;;
    esac

    install_nemoclaw

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ NemoClaw setup complete!                                 ║"
    echo "║                                                              ║"
    echo "║  Next steps:                                                 ║"
    echo "║    nemoclaw <name> connect   — chat with your sandbox        ║"
    echo "║    openclaw tui               — (inside the sandbox shell)   ║"
    echo "║                                                              ║"
    echo "║  Local inference (if built):                                 ║"
    echo "║    systemctl --user status llama-server                      ║"
    echo "║    journalctl --user -u llama-server -f                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

main "$@"
