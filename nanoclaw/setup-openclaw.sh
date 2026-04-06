#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  NanoClaw — OpenClaw installer for Jetson Orin Nano                  ║
# ║                                                                      ║
# ║  Installs OpenClaw as a systemd service with a dedicated user,       ║
# ║  optionally sets up Ollama for local inference.                      ║
# ║                                                                      ║
# ║  Usage:  bash nanoclaw/setup-openclaw.sh [--with-ollama]             ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_HOME="/opt/openclaw/data"
OPENCLAW_PORT=18789

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
        error "Node.js is required. Run 'make node' from host/ first."
        exit 1
    fi

    local node_major
    node_major=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$node_major" -lt 22 ]; then
        error "Node.js 22+ required (found: $(node -v)). Update via 'make node' in host/."
        exit 1
    fi

    info "Node.js $(node -v) — OK"

    if ! command -v npm &>/dev/null; then
        error "npm is required."
        exit 1
    fi

    info "npm $(npm -v) — OK"
}

# ─── Install OpenClaw ──────────────────────────────────────────────
install_openclaw() {
    section "Installing OpenClaw"

    if command -v openclaw &>/dev/null; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        warn "OpenClaw already installed: $current_version"
        info "Upgrading to latest..."
    fi

    # Use the current user's node/npm (e.g. fnm-managed) even under sudo,
    # since the system Node.js may be too old for OpenClaw's postinstall scripts.
    local node_bin
    node_bin="$(dirname "$(command -v node)")"
    sudo env "PATH=$node_bin:$PATH" npm install -g openclaw@latest
    info "OpenClaw $(openclaw --version) installed"
}

# ─── Create system user ───────────────────────────────────────────
create_user() {
    section "System User & State Directory"

    if id openclawuser &>/dev/null; then
        info "User 'openclawuser' already exists"
    else
        sudo adduser \
            --system \
            --home "$OPENCLAW_HOME" \
            --group \
            --shell /usr/sbin/nologin \
            openclawuser
        info "Created system user 'openclawuser'"
    fi

    sudo mkdir -p "$OPENCLAW_HOME"
    sudo chown -R openclawuser:openclawuser "$OPENCLAW_HOME"
    sudo chmod 750 "$OPENCLAW_HOME"
    info "State directory: $OPENCLAW_HOME"
}

# ─── Install Linuxbrew (for skill/tool installs) ──────────────────
install_brew() {
    section "Homebrew (Linuxbrew)"

    if command -v brew &>/dev/null; then
        info "Homebrew already installed: $(brew --version | head -1)"
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    # Create brew group and add users
    sudo groupadd -f brew
    sudo usermod -aG brew "$(whoami)"
    sudo usermod -aG brew openclawuser
    sudo chgrp -R brew /home/linuxbrew/.linuxbrew
    sudo chmod -R g+w /home/linuxbrew/.linuxbrew
    sudo find /home/linuxbrew/.linuxbrew -type d -exec chmod g+s {} \;

    # Brew caches for openclawuser
    sudo mkdir -p "$OPENCLAW_HOME/.cache/Homebrew" "$OPENCLAW_HOME/.logs/Homebrew"
    sudo chown -R openclawuser:openclawuser "$OPENCLAW_HOME/.cache" "$OPENCLAW_HOME/.logs"
    sudo chmod -R 750 "$OPENCLAW_HOME/.cache" "$OPENCLAW_HOME/.logs"

    info "Homebrew configured for openclawuser"
}

# ─── Copy default config ──────────────────────────────────────────
install_config() {
    section "OpenClaw Configuration"

    if [ -f "$OPENCLAW_HOME/openclaw.json" ]; then
        warn "Config already exists at $OPENCLAW_HOME/openclaw.json — skipping"
    else
        sudo cp "$DOTFILES/nanoclaw/openclaw.json" "$OPENCLAW_HOME/openclaw.json"
        sudo chown openclawuser:openclawuser "$OPENCLAW_HOME/openclaw.json"
        sudo chmod 640 "$OPENCLAW_HOME/openclaw.json"
        info "Default config installed"
    fi
}

# ─── Onboarding ───────────────────────────────────────────────────
run_onboard() {
    section "OpenClaw Onboarding"

    local OPENCLAW_BIN
    OPENCLAW_BIN="$(command -v openclaw)"

    info "Running onboarding (skip daemon — we use our own systemd service)..."
    sudo -u openclawuser sh -lc "
        cd $OPENCLAW_HOME || exit 1
        export OPENCLAW_HOME=$OPENCLAW_HOME
        export HOME=$OPENCLAW_HOME
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin
        exec '$OPENCLAW_BIN' onboard --skip-daemon
    "

    info "Onboarding complete"
}

# ─── systemd service ──────────────────────────────────────────────
install_service() {
    section "systemd Service"

    sudo cp "$DOTFILES/nanoclaw/openclaw.service" /etc/systemd/system/openclaw.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now openclaw

    # Wait for port to bind
    info "Waiting for gateway to start..."
    sleep 3

    if sudo systemctl is-active --quiet openclaw; then
        info "OpenClaw gateway is running on http://127.0.0.1:$OPENCLAW_PORT/"
    else
        warn "Service may still be starting. Check: sudo journalctl -u openclaw -f"
    fi
}

# ─── Ollama (optional) ────────────────────────────────────────────
install_ollama() {
    section "Ollama (Local Inference)"

    if command -v ollama &>/dev/null; then
        info "Ollama already installed"
    else
        info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    info "Pulling recommended model (qwen3:1.7b)..."
    ollama pull qwen3:1.7b || warn "Could not pull model. Run 'ollama pull qwen3:1.7b' manually."

    info "Ollama ready. Available models:"
    ollama list 2>/dev/null || true
}

# ─── Print token ──────────────────────────────────────────────────
print_token() {
    section "Gateway Token"

    local token
    token=$(sudo -u openclawuser env \
        OPENCLAW_HOME="$OPENCLAW_HOME" \
        HOME="$OPENCLAW_HOME" \
        openclaw config get gateway.auth.token 2>/dev/null || echo "")

    if [ -n "$token" ]; then
        info "Gateway token (paste into Control UI):"
        echo ""
        echo "  $token"
        echo ""
    else
        warn "Token not yet generated. It will be available after first gateway start."
        warn "Retrieve it with:"
        echo "  sudo -u openclawuser env OPENCLAW_HOME=$OPENCLAW_HOME HOME=$OPENCLAW_HOME openclaw config get gateway.auth.token"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  NanoClaw — OpenClaw on Jetson Orin Nano                    ║"
    echo "║  Latest stable: 2026.3.28                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    preflight
    install_openclaw
    create_user
    install_brew
    install_config
    run_onboard
    install_service

    # Optional Ollama
    if [[ "${1:-}" == "--with-ollama" ]]; then
        install_ollama
    else
        info "Skipping Ollama. Run with --with-ollama to install, or manually later."
    fi

    print_token

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ NanoClaw installation complete!                          ║"
    echo "║                                                              ║"
    echo "║  Control UI:  http://127.0.0.1:$OPENCLAW_PORT/                      ║"
    echo "║                                                              ║"
    echo "║  Commands:                                                   ║"
    echo "║    sudo systemctl status openclaw    — check status          ║"
    echo "║    sudo journalctl -u openclaw -f    — view logs             ║"
    echo "║    openclaw configure                — edit config           ║"
    echo "║    openclaw update                   — update OpenClaw       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

main "$@"
