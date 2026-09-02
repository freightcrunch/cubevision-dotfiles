#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Dotfiles installer — Jetson Orin Nano (Ubuntu 22.04 aarch64)       ║
# ║                                                                      ║
# ║  Usage:  ./scripts/install.sh [--all | --zsh | --bspwm | --rust     ║
# ║            | --python | --js | --pytorch | --packages]               ║
# ║                                                                      ║
# ║  With no arguments, installs everything.                             ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

# ─── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ─── Helpers ───────────────────────────────────────────────────────
symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        warn "Backing up existing $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -s "$src" "$dst"
    info "Linked $dst → $src"
}

# ─── System packages ──────────────────────────────────────────────
install_packages() {
    section "System Packages"
    local pkgs=(
        # shell
        zsh fzf zoxide
        # bspwm + utilities
        bspwm sxhkd polybar rofi picom dunst feh scrot xclip
        alacritty thunar
        # dev tools
        git curl wget build-essential cmake pkg-config
        # python
        python3-pip python3-venv python3-dev
        # rust dependencies
        libssl-dev libfontconfig1-dev
        # pytorch/torchvision build deps
        libopenblas-dev libopenmpi-dev libjpeg-dev zlib1g-dev
        # terminal / editors
        tmux neovim
        # search
        silversearcher-ag
        # file manager
        ranger
        # misc
        htop neofetch ripgrep fd-find bat tree jq stow unzip
    )

    info "Updating package lists..."
    sudo apt-get update -qq

    info "Installing packages..."
    sudo apt-get install -y -qq "${pkgs[@]}" 2>/dev/null || {
        warn "Some packages may not be available. Installing individually..."
        for pkg in "${pkgs[@]}"; do
            sudo apt-get install -y -qq "$pkg" 2>/dev/null || warn "Skipped: $pkg"
        done
    }

    # make zsh the default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
    fi
}

# ─── Zsh ──────────────────────────────────────────────────────────
install_zsh() {
    section "Zsh Configuration"
    mkdir -p "$HOME/.local/state/zsh"
    mkdir -p "$HOME/.cache/zsh"

    # install oh-my-zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing oh-my-zsh..."
        RUNZSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        info "oh-my-zsh already installed."
    fi

    # install oh-my-zsh plugins not bundled by default
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    fi
    if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
        git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
    fi

    info "oh-my-zsh plugins installed:"
    info "  Bundled:  git, tmux, command-not-found, colored-man-pages, extract, z"
    info "  Custom:   zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, fzf-tab"

    symlink "$DOTFILES/zsh/.zshrc"  "$HOME/.zshrc"
    symlink "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"

    info "Run 'p10k configure' after first launch to set up Powerlevel10k."
}

# ─── Ranger ──────────────────────────────────────────────────────
install_ranger() {
    section "Ranger File Manager"

    mkdir -p "$HOME/.config/ranger"

    symlink "$DOTFILES/ranger/rc.conf"    "$HOME/.config/ranger/rc.conf"
    symlink "$DOTFILES/ranger/rifle.conf" "$HOME/.config/ranger/rifle.conf"
    symlink "$DOTFILES/ranger/scope.sh"   "$HOME/.config/ranger/scope.sh"

    chmod +x "$DOTFILES/ranger/scope.sh"

    info "Ranger config installed."
}

# ─── bspwm + sxhkd + picom + polybar ─────────────────────────────
install_bspwm() {
    section "bspwm + sxhkd + picom + polybar"

    # bspwm
    symlink "$DOTFILES/bspwm/bspwmrc"  "$HOME/.config/bspwm/bspwmrc"
    chmod +x "$DOTFILES/bspwm/bspwmrc"

    # sxhkd
    symlink "$DOTFILES/sxhkd/sxhkdrc"  "$HOME/.config/sxhkd/sxhkdrc"

    # picom (compositor)
    symlink "$DOTFILES/picom/picom.conf" "$HOME/.config/picom/picom.conf"

    # polybar (status bar)
    symlink "$DOTFILES/polybar/config.ini" "$HOME/.config/polybar/config.ini"
    symlink "$DOTFILES/polybar/launch.sh"  "$HOME/.config/polybar/launch.sh"
    chmod +x "$DOTFILES/polybar/launch.sh"

    # screenshots directory
    mkdir -p "$HOME/Pictures/screenshots"

    info "bspwm + picom + polybar configs installed."
    info ""
    info "Switch to bspwm:"
    info "  bash $DOTFILES/scripts/select-bspwm.sh"
    info ""
    info "If Firefox/Chromium won't launch (Snap 2.70+ bug):"
    info "  bash $DOTFILES/scripts/fix-snap-browsers.sh"
}

# ─── Rust ─────────────────────────────────────────────────────────
install_rust() {
    section "Rust Configuration"

    # install rustup if not present
    if ! command -v rustup &>/dev/null; then
        info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source "$HOME/.cargo/env"
    else
        info "Rust already installed: $(rustc --version)"
    fi

    mkdir -p "$HOME/.cargo"
    symlink "$DOTFILES/rust/cargo-config.toml" "$HOME/.cargo/config.toml"
    symlink "$DOTFILES/rust/rustfmt.toml"      "$HOME/.config/rustfmt.toml"
    symlink "$DOTFILES/rust/clippy.toml"       "$HOME/.config/clippy.toml"

    # useful components
    rustup component add clippy rustfmt rust-analyzer 2>/dev/null || true
    info "Rust toolchain configured."
}

# ─── Python ───────────────────────────────────────────────────────
install_python() {
    section "Python Configuration"

    mkdir -p "$HOME/.config/pip"
    mkdir -p "$HOME/.config/ruff"

    symlink "$DOTFILES/python/pip.conf"  "$HOME/.config/pip/pip.conf"
    symlink "$DOTFILES/python/ruff.toml" "$HOME/.config/ruff/ruff.toml"

    # install ruff globally (it's a single fast binary)
    if ! command -v ruff &>/dev/null; then
        info "Installing ruff..."
        pip install --user --break-system-packages ruff 2>/dev/null || \
        pip install --user ruff 2>/dev/null || \
        warn "Could not install ruff globally. Install in a venv instead."
    fi

    info "Python config installed."
    info "Template pyproject.toml available at: $DOTFILES/python/pyproject-template.toml"
}

# ─── JavaScript / Node ───────────────────────────────────────────
install_js() {
    section "JavaScript / Node.js Configuration"

    mkdir -p "$HOME/.config/npm"

    symlink "$DOTFILES/javascript/npmrc"             "$HOME/.config/npm/npmrc"
    symlink "$DOTFILES/javascript/.eslintrc.json"    "$HOME/.config/.eslintrc.json"
    symlink "$DOTFILES/javascript/.prettierrc.json"  "$HOME/.config/.prettierrc.json"

    # install nvm if not present
    if [ ! -d "$HOME/.nvm" ]; then
        info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        nvm install --lts
    else
        info "nvm already installed."
    fi

    info "JavaScript config installed."
}

# ─── PyTorch ──────────────────────────────────────────────────────
install_pytorch() {
    section "PyTorch / TorchVision (Jetson)"

    chmod +x "$DOTFILES/pytorch/setup-pytorch-jetson.sh"
    info "PyTorch setup script ready at:"
    info "  $DOTFILES/pytorch/setup-pytorch-jetson.sh [venv_path]"
    info ""
    info "Run it manually when you're ready to install PyTorch:"
    info "  bash $DOTFILES/pytorch/setup-pytorch-jetson.sh ~/.venvs/torch"
    info ""
    info "Smoke test available at: $DOTFILES/pytorch/torch-test.py"
}

# ─── mmWave Radar ────────────────────────────────────────────────
install_mmwave() {
    section "mmWave Radar (RS-2944A / AWR2944)"

    chmod +x "$DOTFILES/mmwave/setup-mmwave.sh"
    info "mmWave setup script ready at:"
    info "  $DOTFILES/mmwave/setup-mmwave.sh"
    info ""
    info "Run it manually when you're ready:"
    info "  bash $DOTFILES/mmwave/setup-mmwave.sh               # basic driver setup"
    info "  bash $DOTFILES/mmwave/setup-mmwave.sh --ros         # with ROS Melodic (Docker)"
    info "  bash $DOTFILES/mmwave/setup-mmwave.sh --check       # check current state"
    info ""
    info "See mmwave/README.md for full documentation."
}

# ─── Infrastructure (OpenTofu, Ansible, K3s tools) ────────────
install_infra() {
    section "Infrastructure (OpenTofu + Ansible)"

    # --- OpenTofu ---
    if ! command -v tofu &>/dev/null; then
        info "Installing OpenTofu..."
        curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh
        chmod +x /tmp/install-opentofu.sh
        sudo /tmp/install-opentofu.sh --install-method deb 2>/dev/null || \
        sudo /tmp/install-opentofu.sh --install-method standalone 2>/dev/null || {
            warn "Auto-install failed. Installing via snap..."
            sudo snap install opentofu --classic 2>/dev/null || \
                warn "Could not install OpenTofu. Install manually: https://opentofu.org/docs/intro/install/"
        }
        rm -f /tmp/install-opentofu.sh
    else
        info "OpenTofu already installed: $(tofu --version | head -1)"
    fi

    # --- Ansible ---
    if ! command -v ansible &>/dev/null; then
        info "Installing Ansible..."
        sudo apt-get install -y -qq software-properties-common 2>/dev/null || true
        sudo add-apt-repository --yes --update ppa:ansible/ansible 2>/dev/null || true
        sudo apt-get install -y -qq ansible 2>/dev/null || {
            info "Falling back to pip install..."
            pip install --user ansible ansible-lint
        }
    else
        info "Ansible already installed: $(ansible --version | head -1)"
    fi

    # --- Ansible Galaxy collections ---
    if [ -f "$DOTFILES/infra/ansible/requirements.yml" ]; then
        info "Installing Ansible Galaxy collections..."
        ansible-galaxy collection install -r "$DOTFILES/infra/ansible/requirements.yml" --force 2>/dev/null || \
            warn "Could not install Ansible collections. Run manually:"
            warn "  ansible-galaxy collection install -r infra/ansible/requirements.yml"
    fi

    # --- kubectl ---
    if ! command -v kubectl &>/dev/null; then
        info "Installing kubectl..."
        local arch="amd64"
        [[ "$(uname -m)" == "aarch64" ]] && arch="arm64"
        curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${arch}/kubectl" \
            -o /tmp/kubectl
        sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
        rm -f /tmp/kubectl
    else
        info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
    fi

    # --- Helm ---
    if ! command -v helm &>/dev/null; then
        info "Installing Helm..."
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
        info "Helm already installed: $(helm version --short)"
    fi

    # --- Flux CLI ---
    if ! command -v flux &>/dev/null; then
        info "Installing Flux CLI..."
        curl -fsSL https://fluxcd.io/install.sh | bash
    else
        info "Flux already installed: $(flux --version)"
    fi

    # --- kustomize ---
    if ! command -v kustomize &>/dev/null; then
        info "Installing kustomize..."
        curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
        sudo mv kustomize /usr/local/bin/
    else
        info "kustomize already installed: $(kustomize version --short 2>/dev/null || kustomize version)"
    fi

    info ""
    info "Infrastructure tools installed."
    info "  OpenTofu: $(tofu --version 2>/dev/null | head -1 || echo 'not found')"
    info "  Ansible:  $(ansible --version 2>/dev/null | head -1 || echo 'not found')"
    info "  kubectl:  $(kubectl version --client --short 2>/dev/null || echo 'not found')"
    info "  Helm:     $(helm version --short 2>/dev/null || echo 'not found')"
    info "  Flux:     $(flux --version 2>/dev/null || echo 'not found')"
    info ""
    info "Next steps:"
    info "  1. cd $DOTFILES/infra/terraform"
    info "  2. cp env/build-server.tfvars.example env/build-server.tfvars"
    info "  3. tofu init && tofu plan -var-file=env/build-server.tfvars"
    info "  4. tofu apply -var-file=env/build-server.tfvars"
}

# ─── NanoClaw (OpenClaw) ────────────────────────────────────────
install_nanoclaw() {
    section "NanoClaw (OpenClaw)"

    chmod +x "$DOTFILES/nanoclaw/setup-openclaw.sh"
    info "NanoClaw setup script ready at:"
    info "  $DOTFILES/nanoclaw/setup-openclaw.sh"
    info ""
    info "Run it manually when you're ready:"
    info "  bash $DOTFILES/nanoclaw/setup-openclaw.sh              # without Ollama"
    info "  bash $DOTFILES/nanoclaw/setup-openclaw.sh --with-ollama # with Ollama"
    info ""
    info "See nanoclaw/README.md for full documentation."
}

# ─── JetPack update / version check ────────────────────────────
install_jetpack() {
    section "JetPack Version Check / Update"

    chmod +x "$DOTFILES/scripts/update-jetpack.sh"
    info "Running update-jetpack.sh (read-only check) ..."
    echo
    bash "$DOTFILES/scripts/update-jetpack.sh" --check || true
    echo
    info "JetPack update script ready at:"
    info "  $DOTFILES/scripts/update-jetpack.sh"
    info ""
    info "Usage:"
    info "  bash scripts/update-jetpack.sh --check   # current vs latest"
    info "  bash scripts/update-jetpack.sh --apply   # in-place apt upgrade (same major)"
    info "  bash scripts/update-jetpack.sh --post    # post-update dependency sync"
    info ""
    info "Note: JetPack 7.x (Ubuntu 24.04, CUDA 13.2) requires a reflash via"
    info "SDK Manager from an x86_64 host — see guides/01-flash-system.md."
}

# ─── Git config ─────────────────────────────────────────────────
install_git() {
    section "Git Configuration"

    if ! git config --global user.name &>/dev/null; then
        warn "Git user.name not set. Configure with:"
        warn "  git config --global user.name 'Your Name'"
        warn "  git config --global user.email 'you@example.com'"
    fi

    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global core.autocrlf input
    git config --global core.editor nvim
    git config --global diff.algorithm histogram

    info "Git global config updated."
}

# ─── Main ─────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [--all | --packages | --zsh | --ranger | --bspwm | --rust | --python | --js | --pytorch | --mmwave | --nanoclaw | --infra | --jetpack]"
    echo "  No arguments = install everything"
}

main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Dotfiles Installer — Jetson Orin Nano                      ║"
    echo "║  Ubuntu 22.04 · aarch64 · 8GB RAM · 6-core ARM             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Dotfiles directory: $DOTFILES"

    if [ $# -eq 0 ] || [ "$1" = "--all" ]; then
        install_packages
        install_git
        install_zsh
        install_ranger
        install_bspwm
        install_rust
        install_python
        install_js
        install_pytorch
        install_mmwave
        install_nanoclaw
        install_infra
        install_jetpack
    else
        for arg in "$@"; do
            case "$arg" in
                --packages) install_packages ;;
                --zsh)      install_zsh ;;
                --ranger)   install_ranger ;;
                --bspwm)    install_bspwm ;;
                --rust)     install_rust ;;
                --python)   install_python ;;
                --js)       install_js ;;
                --pytorch)  install_pytorch ;;
                --mmwave)   install_mmwave ;;
                --nanoclaw) install_nanoclaw ;;
                --infra)    install_infra ;;
                --jetpack)  install_jetpack ;;
                --git)      install_git ;;
                --help|-h)  usage; exit 0 ;;
                *)          error "Unknown option: $arg"; usage; exit 1 ;;
            esac
        done
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ Installation complete!                                    ║"
    echo "║                                                              ║"
    echo "║  Next steps:                                                 ║"
    echo "║  1. Log out and back in (or run: exec zsh)                   ║"
    echo "║  2. Run 'p10k configure' to set up your prompt              ║"
    echo "║  3. Select bspwm from your display manager                   ║"
    echo "║  4. Run the PyTorch installer when ready                     ║"
    echo "║  5. Run mmwave/setup-mmwave.sh for radar driver              ║"
    echo "║  6. Run nanoclaw/setup-openclaw.sh for AI gateway             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

main "$@"
