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
# ║  MODEL: a curated key (lfm2.5-2.6b · ling-3-tiny · gemma4-e4b ·      ║
# ║  qwen3.5-9b), `auto` (default — best curated key as ranked by        ║
# ║  whichllm for this hardware), or `top` (whichllm's #1 GGUF overall). ║
# ║                                                                      ║
# ║  Ranking env (all optional, github.com/Andyyyy64/whichllm):          ║
# ║    WHICHLLM_GPU       simulated GPU (default "Jetson Orin Nano Super"║
# ║                       — set empty to use whichllm's auto-detection)  ║
# ║    WHICHLLM_PROFILE   general | coding | vision | math               ║
# ║    WHICHLLM_CONTEXT   ctx used for fit estimation (default 8k)       ║
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

# Curated, TurboQuant-tuned configs for 8 GB unified memory.
# key -> "rank_id|hf_repo|hf_quant|size|context|turboquant_kv|description"
#   rank_id  — HF model id whichllm scores (usually the base model); the
#              GGUF hf_repo also matches whichllm's artifact_repo_id.
#   hf_quant — may be empty (repo ships a single default GGUF).
# Order is not hand-maintained: see rank_models / resolve_model.
declare -A MODELS=(
    ["lfm2.5-2.6b"]="LiquidAI/LFM2.5-2.6B|LiquidAI/LFM2.5-2.6B-GGUF||~1.8 GB|131072|turbo4|dense 2.6B, agentic-tuned — fastest, lightest 24/7 gateway"
    ["ling-3-tiny"]="SC117/Ling-3.0-tiny-abliterated-APEX-GGUF|SC117/Ling-3.0-tiny-abliterated-APEX-GGUF|APEX-I-Compact|~4.0 GB|65536|turbo4|7.9B MoE / 1.3B active, abliterated (uncensored)"
    ["gemma4-e4b"]="google/gemma-4-E4B-it|google/gemma-4-E4B-it-qat-q4_0-gguf||~5.15 GB|131072|turbo4|multimodal (text/image/audio), verified on Orin Nano by NVIDIA"
    ["qwen3.5-9b"]="Qwen/Qwen3.5-9B|mradermacher/Qwen3.5-9B-GGUF|Q4_K_M|~5.7 GB|100000|turbo4|dense 9B — needs TurboQuant KV (-ctv turbo3/turbo4) to fit 100K+ ctx on 8GB"
)
# Tiebreak order for models whichllm can't score, and the whole order when
# whichllm is unavailable (offline). The first entry is the offline default.
MODEL_KEYS=("lfm2.5-2.6b" "gemma4-e4b" "qwen3.5-9b" "ling-3-tiny")

# ─── whichllm (hardware-aware model ranking) ─────────────────────
# Scores models from merged live benchmarks (LiveBench, Artificial Analysis,
# Aider, Arena) × quant penalty × evidence confidence × fit × speed.
# Jetson unified memory isn't reliably auto-detected, so simulate it by
# default, and pass --gpu-only since partial offload is meaningless there.
# Rank at a short context: whichllm assumes an fp16 KV cache, while the
# context actually served below relies on TurboQuant KV compression.
WHICHLLM="${WHICHLLM:-whichllm}"
WHICHLLM_GPU="${WHICHLLM_GPU-Jetson Orin Nano Super}"
WHICHLLM_PROFILE="${WHICHLLM_PROFILE:-general}"
WHICHLLM_CONTEXT="${WHICHLLM_CONTEXT:-8k}"
WHICHLLM_TOP="${WHICHLLM_TOP:-100}"
WHICHLLM_JSON=""
WHICHLLM_FAILED=""
# Served context/KV type for `top` picks (not in the curated table).
LLAMACPP_CTX="${LLAMACPP_CTX:-32768}"
LLAMACPP_CTV="${LLAMACPP_CTV:-turbo4}"

# ─── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" >&2; }
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

# ─── Model ranking (whichllm) ────────────────────────────────────
ensure_whichllm() {
    command -v "${WHICHLLM%% *}" &>/dev/null && return 0

    if ! command -v uv &>/dev/null; then
        info "Installing uv (user-local) to manage whichllm..." >&2
        curl -LsSf https://astral.sh/uv/install.sh | sh >&2 || return 1
        export PATH="$HOME/.local/bin:$PATH"
    fi
    info "Installing whichllm: uv tool install whichllm" >&2
    uv tool install whichllm >&2 || return 1
    export PATH="$HOME/.local/bin:$PATH"
    command -v "${WHICHLLM%% *}" &>/dev/null
}

# Runs whichllm at most once per invocation, saving its JSON to WHICHLLM_JSON.
# Returns non-zero if ranking is unavailable. Call it in the current shell
# (not inside $(...)) before the rank_* helpers so the result is cached.
whichllm_rank() {
    [ -n "$WHICHLLM_JSON" ] && return 0
    [ -n "$WHICHLLM_FAILED" ] && return 1
    WHICHLLM_FAILED=1
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found — can't parse whichllm output; using curated order."
        return 1
    fi
    if ! ensure_whichllm; then
        warn "whichllm unavailable — using curated order."
        return 1
    fi

    local args=(--gpu-only --json --top "$WHICHLLM_TOP"
                --profile "$WHICHLLM_PROFILE" --context-length "$WHICHLLM_CONTEXT")
    [ -n "$WHICHLLM_GPU" ] && args+=(--gpu "$WHICHLLM_GPU")

    local out
    out="$(mktemp)"
    # WHICHLLM may be a multi-word command (e.g. WHICHLLM="uvx whichllm@latest").
    # shellcheck disable=SC2086
    if ! $WHICHLLM "${args[@]}" >"$out" 2>/dev/null \
        || ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))["models"]' "$out" 2>/dev/null; then
        warn "whichllm ranking failed (gpu: ${WHICHLLM_GPU:-auto-detect}) — using curated order."
        rm -f "$out"
        return 1
    fi
    WHICHLLM_JSON="$out"
    WHICHLLM_FAILED=""
}

# Prints curated keys best-first as "key<TAB>score<TAB>tok/s<TAB>size".
# Scored models sort by whichllm quality_score; unscored ones follow in
# MODEL_KEYS order.
rank_models() {
    local key rank_id hf_repo size rows=""
    for key in "${MODEL_KEYS[@]}"; do
        IFS='|' read -r rank_id hf_repo _ size _ <<< "${MODELS[$key]}"
        rows+="${key}"$'\t'"${rank_id}"$'\t'"${hf_repo}"$'\t'"${size}"$'\n'
    done

    if ! whichllm_rank; then
        printf '%s' "$rows" | awk -F'\t' 'NF { printf "%s\t-\t-\t%s\n", $1, $4 }'
        return 0
    fi

    printf '%s' "$rows" | python3 -c '
import json, sys

by_id = {}
for m in json.load(open(sys.argv[1]))["models"]:  # best-first
    for mid in (m.get("model_id"), m.get("artifact_repo_id")):
        if mid:
            by_id.setdefault(mid.lower(), m)

ranked, unranked = [], []
for i, line in enumerate(l for l in sys.stdin.read().splitlines() if l):
    key, rank_id, hf_repo, size = line.split("\t")
    m = by_id.get(rank_id.lower()) or by_id.get(hf_repo.lower())
    if m:
        ranked.append((-m["quality_score"], i, key, "%.1f" % m["quality_score"],
                       "%.0f" % m["estimated_tok_per_sec"], size))
    else:
        unranked.append((0, i, key, "-", "-", size))

for row in sorted(ranked) + unranked:
    print("\t".join(row[2:]))
' "$WHICHLLM_JSON"
}

# Prints whichllm's best GGUF picks (loadable via llama-server -hf) as
# "hf_repo<TAB>quant<TAB>score<TAB>tok/s<TAB>size<TAB>model_id".
top_gguf_models() {
    whichllm_rank || return 1
    python3 -c '
import json, sys

n = int(sys.argv[2])
for m in json.load(open(sys.argv[1]))["models"]:
    if not m.get("artifact_repo_id"):
        continue
    print("\t".join([m["artifact_repo_id"], m["quant_type"], "%.1f" % m["quality_score"],
                     "%.0f" % m["estimated_tok_per_sec"], "~%.1f GB" % (m["file_size_bytes"] / 1e9),
                     m["model_id"]]))
    n -= 1
    if n == 0:
        break
' "$WHICHLLM_JSON" "${1:-5}"
}

list_models() {
    section "Curated Models — ranked by whichllm (gpu: ${WHICHLLM_GPU:-auto-detect}, profile: $WHICHLLM_PROFILE)"
    whichllm_rank || true
    local ranking
    ranking="$(rank_models)"

    printf "  %-3s %-13s %-6s %-6s %-9s %-7s %s\n" "#" "key" "score" "tok/s" "size" "ctx" "description"
    local i=0 key score toks size repo quant ctx desc
    while IFS=$'\t' read -r key score toks size; do
        i=$((i + 1))
        IFS='|' read -r _ repo quant _ ctx _ desc <<< "${MODELS[$key]}"
        [ -n "$quant" ] && repo="${repo}:${quant}"
        printf "  %-3s %-13s %-6s %-6s %-9s %-7s %s\n" "$i" "$key" "$score" "$toks" "$size" "$ctx" "$desc"
        printf "      hf: %s\n" "$repo"
    done <<< "$ranking"
    echo "  score '-' = not in whichllm's benchmark set (ordered by MODEL_KEYS)"

    if [ -n "$WHICHLLM_JSON" ]; then
        section "whichllm Top GGUF Picks (install #1 with --with-llamacpp=top)"
        local picks mid
        picks="$(top_gguf_models 5)"
        while IFS=$'\t' read -r repo quant score toks size mid; do
            printf "  %-6s %-6s %-9s %s:%s\n" "$score" "$toks" "$size" "$repo" "$quant"
        done <<< "$picks"
    fi
}

# Resolves a model selector (curated key | auto | top) into MODEL_* globals.
resolve_model() {
    local sel="${1:-auto}"

    whichllm_rank || true

    if [ "$sel" = "auto" ]; then
        sel="$(rank_models | awk -F'	' 'NR == 1 { print $1 }')"
        info "Auto-selected '$sel' — best-ranked curated model (see --list-models)"
    elif [ "$sel" = "top" ]; then
        local row repo quant score toks size mid
        row="$(top_gguf_models 1)" || true
        if [ -z "$row" ]; then
            error "whichllm returned no GGUF pick — use a curated key instead."
            exit 1
        fi
        IFS=$'\t' read -r repo quant score toks size mid <<< "$row"
        MODEL_LABEL="$mid"
        MODEL_HF_REF="${repo}:${quant}"
        MODEL_SIZE="$size"
        MODEL_CTX="$LLAMACPP_CTX"
        MODEL_CTV="$LLAMACPP_CTV"
        MODEL_DESC="whichllm #1 GGUF (score $score, ~$toks tok/s est.)"
        return 0
    fi

    if [ -z "${MODELS[$sel]:-}" ]; then
        error "Unknown model: $sel"
        list_models
        exit 1
    fi

    local hf_repo hf_quant
    IFS='|' read -r _ hf_repo hf_quant MODEL_SIZE MODEL_CTX MODEL_CTV MODEL_DESC <<< "${MODELS[$sel]}"
    MODEL_LABEL="$sel"
    MODEL_HF_REF="$hf_repo"
    if [ -n "$hf_quant" ]; then
        MODEL_HF_REF="${hf_repo}:${hf_quant}"
    fi
}

# ─── llama.cpp (TurboQuant fork, optional local inference) ───────
# Builds in $HOME (no sudo) and runs as a systemd --user service, so it can
# be pointed to from NemoClaw onboarding as a "custom OpenAI-compatible
# endpoint" provider (http://127.0.0.1:$LLAMACPP_PORT/v1).
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

# Expects MODEL_* globals set by resolve_model.
install_llama_service() {
    local hf_ref="$MODEL_HF_REF" ctx="$MODEL_CTX" ctv="$MODEL_CTV"

    info "Selected model: $MODEL_LABEL ($MODEL_SIZE) — $MODEL_DESC"
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
    # Resolve before the (slow) build so a bad selector fails fast.
    resolve_model "${1:-auto}"
    build_llamacpp
    install_llama_service
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  NemoClaw — NVIDIA NemoClaw on Jetson Orin Nano             ║"
    echo "║  https://github.com/NVIDIA/NemoClaw                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    trap 'rm -f "$WHICHLLM_JSON"' EXIT

    if [ "${1:-}" = "--list-models" ]; then
        list_models
        exit 0
    fi

    preflight

    # Optional llama.cpp (TurboQuant fork) local inference — build this
    # BEFORE onboarding so the endpoint is ready to select as a provider.
    case "${1:-}" in
        --with-llamacpp)
            install_llamacpp auto
            ;;
        --with-llamacpp=*)
            install_llamacpp "${1#--with-llamacpp=}"
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
