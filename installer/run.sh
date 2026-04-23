#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  cubevision-dotfiles — Interactive TUI Installer                 ║
# ║                                                                  ║
# ║  Bootstraps Go (if needed), builds the Bubble Tea TUI, and      ║
# ║  launches the interactive module selector.                       ║
# ║                                                                  ║
# ║  Usage:  bash installer/run.sh                                   ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="/tmp/cubevision-installer"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${RED}[!]${NC} $*"; }
step()  { echo -e "${CYAN}[~]${NC} $*"; }

# ─── Ensure Go is available ────────────────────────────────────────
if ! command -v go &>/dev/null; then
    step "Go not found. Installing Go 1.23..."
    GO_VERSION="1.23.4"
    ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    info "Go $(go version | awk '{print $3}') installed"
else
    info "Go already available: $(go version | awk '{print $3}')"
fi

# ─── Build the TUI ────────────────────────────────────────────────
step "Building installer TUI..."
cd "$SCRIPT_DIR"
go mod tidy 2>/dev/null || true
go build -o "$BIN" .
info "Built → $BIN"

# ─── Run ───────────────────────────────────────────────────────────
cd "$DOTFILES"
exec "$BIN"
